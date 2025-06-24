# frozen_string_literal: true

require 'train-juniper/constants'
require 'train-juniper/connection/windows_proxy'
require 'train-juniper/connection/ssh_askpass'

module TrainPlugins
  module Juniper
    # Handles bastion host proxy configuration and authentication
    module BastionProxy
      include WindowsProxy
      include SshAskpass

      # Configure bastion proxy for SSH connection
      # @param ssh_options [Hash] SSH options to modify
      def configure_bastion_proxy(ssh_options)
        bastion_user = @options[:bastion_user] || @options[:user]
        bastion_port = @options[:bastion_port]
        bastion_password = @options[:bastion_password] || @options[:password]

        # On Windows with password auth, use plink.exe if available
        if Gem.win_platform? && bastion_password && plink_available?
          configure_plink_proxy(ssh_options, bastion_user, bastion_port, bastion_password)
        else
          configure_standard_proxy(ssh_options, bastion_user, bastion_port)
        end
      end

      private

      # Configure standard SSH proxy using Net::SSH::Proxy::Jump
      # @param ssh_options [Hash] SSH options to modify
      # @param bastion_user [String] Username for bastion
      # @param bastion_port [Integer] Port for bastion
      def configure_standard_proxy(ssh_options, bastion_user, bastion_port)
        require 'net/ssh/proxy/jump' unless defined?(Net::SSH::Proxy::Jump)

        proxy_jump = build_proxy_jump_string(bastion_user, bastion_port)
        @logger.debug("Using bastion host: #{proxy_jump}")

        # Set up automated password authentication via SSH_ASKPASS
        setup_bastion_password_auth

        ssh_options[:proxy] = Net::SSH::Proxy::Jump.new(proxy_jump)
      end

      # Configure plink.exe proxy for Windows password authentication
      # @param ssh_options [Hash] SSH options to modify
      # @param bastion_user [String] Username for bastion
      # @param bastion_port [Integer] Port for bastion
      # @param bastion_password [String] Password for bastion
      def configure_plink_proxy(ssh_options, bastion_user, bastion_port, bastion_password)
        require 'net/ssh/proxy/command' unless defined?(Net::SSH::Proxy::Command)

        proxy_cmd = build_plink_proxy_command(
          @options[:bastion_host],
          bastion_user,
          bastion_port,
          bastion_password
        )

        @logger.debug('Using plink.exe for bastion proxy')
        ssh_options[:proxy] = Net::SSH::Proxy::Command.new(proxy_cmd)
      end

      # Build proxy jump string from bastion options
      # @param bastion_user [String] Username for bastion
      # @param bastion_port [Integer] Port for bastion
      # @return [String] Proxy jump string
      def build_proxy_jump_string(bastion_user, bastion_port)
        if bastion_port == Constants::DEFAULT_SSH_PORT
          "#{bastion_user}@#{@options[:bastion_host]}"
        else
          "#{bastion_user}@#{@options[:bastion_host]}:#{bastion_port}"
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
        jump_host = build_proxy_jump_string(bastion_user, bastion_port)
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
