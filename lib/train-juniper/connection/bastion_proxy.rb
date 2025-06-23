# frozen_string_literal: true

require 'train-juniper/constants'

module TrainPlugins
  module Juniper
    # Handles bastion host proxy configuration and authentication
    module BastionProxy
      # Configure bastion proxy for SSH connection
      # @param ssh_options [Hash] SSH options to modify
      def configure_bastion_proxy(ssh_options)
        require 'net/ssh/proxy/jump' unless defined?(Net::SSH::Proxy::Jump)

        # Build proxy jump string from bastion options
        bastion_user = @options[:bastion_user] || @options[:user]
        bastion_port = @options[:bastion_port]

        proxy_jump = if bastion_port == Constants::DEFAULT_SSH_PORT
                       "#{bastion_user}@#{@options[:bastion_host]}"
                     else
                       "#{bastion_user}@#{@options[:bastion_host]}:#{bastion_port}"
                     end

        @logger.debug("Using bastion host: #{proxy_jump}")

        # Set up automated password authentication via SSH_ASKPASS
        setup_bastion_password_auth

        ssh_options[:proxy] = Net::SSH::Proxy::Jump.new(proxy_jump)
      end

      # Set up SSH_ASKPASS for bastion password authentication
      def setup_bastion_password_auth
        bastion_password = @options[:bastion_password] || @options[:password]
        return unless bastion_password

        @ssh_askpass_script = create_ssh_askpass_script(bastion_password)
        ENV['SSH_ASKPASS'] = @ssh_askpass_script
        ENV['SSH_ASKPASS_REQUIRE'] = 'force'
        @logger.debug('Configured SSH_ASKPASS for automated bastion authentication')
      end

      # Create temporary SSH_ASKPASS script for automated password authentication
      # @param password [String] The password to use
      # @return [String] Path to the created script
      def create_ssh_askpass_script(password)
        require 'tempfile'

        if Gem.win_platform?
          # :nocov:
          # Create Windows PowerShell script
          script = Tempfile.new(['ssh_askpass', '.ps1'])
          # PowerShell handles escaping better, just escape quotes
          escaped_password = password.gsub("'", "''")
          script.write("Write-Output '#{escaped_password}'\r\n")
          script.close

          # Create a wrapper batch file to execute PowerShell with bypass policy
          wrapper = Tempfile.new(['ssh_askpass_wrapper', '.bat'])
          wrapper.write("@echo off\r\npowershell.exe -ExecutionPolicy Bypass -File \"#{script.path}\"\r\n")
          wrapper.close

          @logger.debug("Created SSH_ASKPASS PowerShell script at #{script.path} with wrapper at #{wrapper.path}")
          wrapper.path
          # :nocov:
        else
          # Create Unix shell script
          script = Tempfile.new(['ssh_askpass', '.sh'])
          script.write("#!/bin/bash\necho '#{password}'\n")
          script.close
          File.chmod(0o755, script.path)

          @logger.debug("Created SSH_ASKPASS script at #{script.path}")
          script.path
        end
      end

      # Generate SSH proxy command for bastion host using ProxyJump (-J)
      # @param bastion_user [String] Username for bastion
      # @param bastion_port [Integer] Port for bastion
      # @return [String] SSH command string
      def generate_bastion_proxy_command(bastion_user, bastion_port)
        args = ['ssh']

        # SSH options for connection
        Constants::STANDARD_SSH_OPTIONS.each do |key, value|
          args += ['-o', "#{key}=#{value}"]
        end

        # Use ProxyJump (-J) which handles password authentication properly
        jump_host = if bastion_port == Constants::DEFAULT_SSH_PORT
                      "#{bastion_user}@#{@options[:bastion_host]}"
                    else
                      "#{bastion_user}@#{@options[:bastion_host]}:#{bastion_port}"
                    end
        args += ['-J', jump_host]

        # Add SSH keys if specified
        if @options[:key_files]
          Array(@options[:key_files]).each do |key_file|
            args += ['-i', key_file]
          end
        end

        # Target connection - %h and %p will be replaced by Net::SSH
        args += ['%h', '-p', '%p']

        args.join(' ')
      end
    end
  end
end
