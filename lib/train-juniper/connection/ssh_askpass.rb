# frozen_string_literal: true

require 'tempfile'

module TrainPlugins
  module Juniper
    # SSH_ASKPASS script management for automated password authentication
    module SshAskpass
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
        if Gem.win_platform?
          create_windows_askpass_script(password)
        else
          create_unix_askpass_script(password)
        end
      end

      private

      # Create Windows PowerShell script for SSH_ASKPASS
      # @param password [String] The password to use
      # @return [String] Path to the wrapper batch file
      def create_windows_askpass_script(password)
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
      end

      # Create Unix shell script for SSH_ASKPASS
      # @param password [String] The password to use
      # @return [String] Path to the created script
      def create_unix_askpass_script(password)
        script = Tempfile.new(['ssh_askpass', '.sh'])
        script.write("#!/bin/bash\necho '#{password}'\n")
        script.close
        File.chmod(0o755, script.path)

        @logger.debug("Created SSH_ASKPASS script at #{script.path}")
        script.path
      end
    end
  end
end
