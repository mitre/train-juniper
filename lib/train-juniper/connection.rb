# frozen_string_literal: true

# Connection definition for Juniper Train plugin.

# This plugin provides SSH connectivity to Juniper network devices,
# enabling InSpec to connect to and inspect Juniper routers and switches.
# Key capabilities:
# * SSH authentication to Juniper devices
# * Platform detection for JunOS devices
# * Command execution via SSH with prompt handling
# * File operations for configuration inspection

# Base Train transport functionality
require 'train'
require 'logger'

# Juniper-specific modules
require 'train-juniper/constants'
require 'train-juniper/platform'
require 'train-juniper/connection/validation'
require 'train-juniper/connection/command_executor'
require 'train-juniper/connection/error_handling'
require 'train-juniper/connection/ssh_session'
require 'train-juniper/connection/bastion_proxy'
require 'train-juniper/helpers/environment'
require 'train-juniper/helpers/logging'
require 'train-juniper/helpers/mock_responses'
require 'train-juniper/file_abstraction/juniper_file'

# Using Train's SSH transport for connectivity

module TrainPlugins
  module Juniper
    # Main connection class for Juniper devices
    class Connection < Train::Plugins::Transport::BaseConnection
      # Include Juniper-specific platform detection
      include TrainPlugins::Juniper::Platform
      # Include environment variable helpers
      include TrainPlugins::Juniper::Environment
      # Include validation methods
      include TrainPlugins::Juniper::Validation
      # Include command execution methods
      include TrainPlugins::Juniper::CommandExecutor
      # Include error handling methods
      include TrainPlugins::Juniper::ErrorHandling
      # Include SSH session management
      include TrainPlugins::Juniper::SSHSession
      # Include bastion proxy support
      include TrainPlugins::Juniper::BastionProxy
      # Include logging helpers
      include TrainPlugins::Juniper::Logging

      # Alias for Train CommandResult for backward compatibility
      CommandResult = Train::Extras::CommandResult

      attr_reader :ssh_session

      # Configuration mapping for environment variables
      ENV_CONFIG = {
        host: { env: 'JUNIPER_HOST' },
        user: { env: 'JUNIPER_USER' },
        password: { env: 'JUNIPER_PASSWORD' },
        port: { env: 'JUNIPER_PORT', type: :int, default: Constants::DEFAULT_SSH_PORT },
        timeout: { env: 'JUNIPER_TIMEOUT', type: :int, default: 30 },
        bastion_host: { env: 'JUNIPER_BASTION_HOST' },
        bastion_user: { env: 'JUNIPER_BASTION_USER' },
        bastion_port: { env: 'JUNIPER_BASTION_PORT', type: :int, default: Constants::DEFAULT_SSH_PORT },
        bastion_password: { env: 'JUNIPER_BASTION_PASSWORD' },
        proxy_command: { env: 'JUNIPER_PROXY_COMMAND' }
      }.freeze

      # Initialize a new Juniper connection
      # @param options [Hash] Connection options
      # @option options [String] :host The hostname or IP address of the Juniper device
      # @option options [String] :user The username for authentication
      # @option options [String] :password The password for authentication (optional if using key_files)
      # @option options [Integer] :port The SSH port (default: 22)
      # @option options [Integer] :timeout Connection timeout in seconds (default: 30)
      # @option options [String] :bastion_host Jump/bastion host for connection
      # @option options [String] :proxy_command SSH proxy command
      # @option options [Logger] :logger Custom logger instance
      # @option options [Boolean] :mock Enable mock mode for testing
      def initialize(options)
        # Configure SSH connection options for Juniper devices
        # Support environment variables for authentication (following train-vsphere pattern)
        @options = options.dup

        # Apply environment variable configuration using DRY approach
        ENV_CONFIG.each do |key, config|
          # Skip if option already has a value from command line
          next if @options[key]

          # Get value from environment
          env_val = config[:type] == :int ? env_int(config[:env]) : env_value(config[:env])

          # Only apply env value if it exists, otherwise use default (but not for nil CLI values)
          if env_val
            @options[key] = env_val
          elsif !@options.key?(key) && config[:default]
            @options[key] = config[:default]
          end
        end

        @options[:keepalive] = true
        @options[:keepalive_interval] = 60

        # Setup logger
        @logger = @options[:logger] || Logger.new(STDOUT, level: Logger::WARN)

        # JunOS CLI prompt patterns
        @cli_prompt = /[%>$#]\s*$/
        @config_prompt = /[%#]\s*$/

        # Log connection info safely
        log_connection_info

        # Validate all connection options
        validate_connection_options!

        super(@options)

        # Establish SSH connection to Juniper device (unless in mock mode or skip_connect)
        if @options[:mock]
          log_mock_mode
        elsif !@options[:skip_connect]
          @logger.debug('Attempting to connect to Juniper device...')
          connect
        end
      end

      # Secure string representation (never expose credentials)
      def to_s
        "#<#{self.class.name}:0x#{object_id.to_s(16)} @host=#{@options[:host]} @user=#{@options[:user]}>"
      end

      # Secure inspect method that uses to_s
      # @return [String] Secure string representation
      def inspect
        to_s
      end

      # Access Juniper configuration and operational data as pseudo-files
      # @param path [String] The pseudo-file path to access
      # @return [JuniperFile] A file-like object for accessing Juniper data
      # @example Access interface configuration
      #   file = connection.file('/config/interfaces')
      #   puts file.content
      # @example Access operational data
      #   file = connection.file('/operational/interfaces')
      #   puts file.content
      def file_via_connection(path)
        # For Juniper devices, "files" are typically configuration sections
        # or operational command outputs rather than traditional filesystem paths
        JuniperFile.new(self, path)
      end

      # Upload files to Juniper device (not supported)
      # @param locals [String, Array<String>] Local file path(s)
      # @param remote [String] Remote destination path
      # @raise [NotImplementedError] Always raises as uploads are not supported
      # @note Network devices use command-based configuration instead of file uploads
      def upload(locals, remote)
        raise NotImplementedError, Constants::UPLOAD_NOT_SUPPORTED
      end

      # Download files from Juniper device (not supported)
      # @param remotes [String, Array<String>] Remote file path(s)
      # @param local [String] Local destination path
      # @raise [NotImplementedError] Always raises as downloads are not supported
      # @note Use run_command() to retrieve configuration data instead
      def download(remotes, local)
        raise NotImplementedError, Constants::DOWNLOAD_NOT_SUPPORTED
      end

      # Check connection health
      # @return [Boolean] true if connection is healthy, false otherwise
      # @example
      #   if connection.healthy?
      #     puts "Connection is healthy"
      #   end
      def healthy?
        return false unless connected?

        result = run_command_via_connection('show version')
        result.exit_status.zero?
      rescue StandardError
        false
      end

      # List of sensitive option keys to redact in logs
      SENSITIVE_OPTIONS = %i[password bastion_password key_files proxy_command].freeze
      private_constant :SENSITIVE_OPTIONS

      private

      # Log connection info without exposing sensitive data
      def log_connection_info
        safe_options = @options.except(*SENSITIVE_OPTIONS)
        @logger.debug("Juniper connection initialized with options: #{safe_options.inspect}")
        @logger.debug("Environment: JUNIPER_BASTION_USER=#{env_value('JUNIPER_BASTION_USER')} -> bastion_user=#{@options[:bastion_user]}")
      end
    end
  end
end
