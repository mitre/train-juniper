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

# Juniper-specific platform detection
require 'train-juniper/platform'
require 'train-juniper/connection/validation'
require 'train-juniper/connection/command_executor'
require 'train-juniper/connection/error_handling'
require 'train-juniper/helpers/environment'
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

      # Alias for Train CommandResult for backward compatibility
      CommandResult = Train::Extras::CommandResult

      attr_reader :ssh_session

      # Configuration mapping for environment variables
      ENV_CONFIG = {
        host: { env: 'JUNIPER_HOST' },
        user: { env: 'JUNIPER_USER' },
        password: { env: 'JUNIPER_PASSWORD' },
        port: { env: 'JUNIPER_PORT', type: :int, default: 22 },
        timeout: { env: 'JUNIPER_TIMEOUT', type: :int, default: 30 },
        bastion_host: { env: 'JUNIPER_BASTION_HOST' },
        bastion_user: { env: 'JUNIPER_BASTION_USER' },
        bastion_port: { env: 'JUNIPER_BASTION_PORT', type: :int, default: 22 },
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
        @logger.debug('Attempting to connect to Juniper device...')
        connect unless @options[:mock] || @options[:skip_connect]
      end

      # Secure string representation (never expose credentials)
      def to_s
        "#<#{self.class.name}:0x#{object_id.to_s(16)} @host=#{@options[:host]} @user=#{@options[:user]}>"
      end

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
        raise NotImplementedError, "#{self.class} does not implement #upload() - network devices use command-based configuration"
      end

      # Download files from Juniper device (not supported)
      # @param remotes [String, Array<String>] Remote file path(s)
      # @param local [String] Local destination path
      # @raise [NotImplementedError] Always raises as downloads are not supported
      # @note Use run_command() to retrieve configuration data instead
      def download(remotes, local)
        raise NotImplementedError, "#{self.class} does not implement #download() - use run_command() to retrieve configuration data"
      end



      # SSH option mapping configuration
      SSH_OPTION_MAPPING = {
        port: :port,
        password: :password,
        timeout: :timeout,
        keepalive: :keepalive,
        keepalive_interval: :keepalive_interval,
        keys: ->(opts) { Array(opts[:key_files]) if opts[:key_files] },
        keys_only: ->(opts) { opts[:keys_only] if opts[:key_files] }
      }.freeze

      # Default SSH options for Juniper connections
      # @note verify_host_key is set to :never for network device compatibility
      SSH_DEFAULTS = {
        verify_host_key: :never
      }.freeze


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


      # Establish SSH connection to Juniper device
      def connect
        return if connected?

        begin
          # Use direct SSH connection (network device pattern)
          # Defensive loading - only require if not fully loaded
          require 'net/ssh' unless defined?(Net::SSH) && Net::SSH.respond_to?(:start)

          @logger.debug('Establishing SSH connection to Juniper device')

          ssh_options = build_ssh_options

          # Add bastion host support if configured
          configure_bastion_proxy(ssh_options) if @options[:bastion_host]

          @logger.debug("Connecting to #{@options[:host]}:#{@options[:port]} as #{@options[:user]}")

          # Direct SSH connection
          @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
          @logger.debug('SSH connection established successfully')

          # Configure JunOS session for automation
          test_and_configure_session
        rescue StandardError => e
          handle_connection_error(e)
        end
      end

      # Check if SSH connection is active
      def connected?
        return true if @options[:mock]

        !@ssh_session.nil?
      rescue StandardError
        false
      end

      # Check if running in mock mode
      def mock?
        @options[:mock] == true
      end

      # Configure bastion proxy for SSH connection
      def configure_bastion_proxy(ssh_options)
        require 'net/ssh/proxy/jump' unless defined?(Net::SSH::Proxy::Jump)

        # Build proxy jump string from bastion options
        bastion_user = @options[:bastion_user] || @options[:user]
        bastion_port = @options[:bastion_port]

        proxy_jump = if bastion_port == 22
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




      # Test connection and configure JunOS session
      def test_and_configure_session
        @logger.debug('Testing SSH connection and configuring JunOS session')

        # Test connection first
        @ssh_session.exec!('echo "connection test"')
        @logger.debug('SSH connection test successful')

        # Optimize CLI for automation
        @ssh_session.exec!('set cli screen-length 0')
        @ssh_session.exec!('set cli screen-width 0')
        @ssh_session.exec!('set cli complete-on-space off') if @options[:disable_complete_on_space]

        @logger.debug('JunOS session configured successfully')
      rescue StandardError => e
        @logger.warn("Failed to configure JunOS session: #{e.message}")
      end




      # Build SSH connection options from @options
      def build_ssh_options
        SSH_DEFAULTS.merge(
          SSH_OPTION_MAPPING.each_with_object({}) do |(ssh_key, option_key), opts|
            value = option_key.is_a?(Proc) ? option_key.call(@options) : @options[option_key]
            opts[ssh_key] = value unless value.nil?
          end
        )
      end

      # Create temporary SSH_ASKPASS script for automated password authentication
      def create_ssh_askpass_script(password)
        require 'tempfile'

        script = Tempfile.new(['ssh_askpass', '.sh'])
        script.write("#!/bin/bash\necho '#{password}'\n")
        script.close
        File.chmod(0o755, script.path)

        @logger.debug("Created SSH_ASKPASS script at #{script.path}")
        script.path
      end

      # Generate SSH proxy command for bastion host using ProxyJump (-J)
      def generate_bastion_proxy_command(bastion_user, bastion_port)
        args = ['ssh']

        # SSH options for connection
        args += ['-o', 'UserKnownHostsFile=/dev/null']
        args += ['-o', 'StrictHostKeyChecking=no']
        args += ['-o', 'LogLevel=ERROR']
        args += ['-o', 'ForwardAgent=no']

        # Use ProxyJump (-J) which handles password authentication properly
        jump_host = if bastion_port == 22
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
