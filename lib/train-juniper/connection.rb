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
require 'train-juniper/mock_responses'
require 'train-juniper/juniper_file'
require 'train-juniper/environment_helpers'
require 'train-juniper/validation'

# Using Train's SSH transport for connectivity

module TrainPlugins
  module Juniper
    # Main connection class for Juniper devices
    class Connection < Train::Plugins::Transport::BaseConnection
      # Include Juniper-specific platform detection
      include TrainPlugins::Juniper::Platform
      # Include environment variable helpers
      include TrainPlugins::Juniper::EnvironmentHelpers
      # Include validation methods
      include TrainPlugins::Juniper::Validation

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

      # Execute commands on Juniper device via SSH
      # @param cmd [String] The JunOS command to execute
      # @return [CommandResult] Result object with stdout, stderr, and exit status
      # @raise [Train::ClientError] If command contains dangerous characters
      # @example
      #   result = connection.run_command('show version')
      #   puts result.stdout
      def run_command_via_connection(cmd)
        # Sanitize command to prevent injection
        safe_cmd = sanitize_command(cmd)

        return mock_command_result(safe_cmd) if @options[:mock]

        begin
          # Ensure we're connected
          connect unless connected?

          @logger.debug("Executing command: #{safe_cmd}")

          # Execute command via SSH session
          output = @ssh_session.exec!(safe_cmd)

          @logger.debug("Command output: #{output}")

          # Format JunOS result
          format_junos_result(output, safe_cmd)
        rescue StandardError => e
          @logger.error("Command execution failed: #{e.message}")
          # Handle connection errors gracefully
          CommandResult.new('', e.message, 1)
        end
      end

      # JunOS error patterns organized by type
      JUNOS_ERRORS = {
        configuration: [/^error:/i, /configuration database locked/i],
        syntax: [/syntax error/i],
        command: [/invalid command/i, /unknown command/i],
        argument: [/missing argument/i]
      }.freeze

      # Flattened error patterns for quick matching
      JUNOS_ERROR_PATTERNS = JUNOS_ERRORS.values.flatten.freeze

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

      # Command sanitization patterns
      # Note: Pipe (|) is allowed as it's commonly used in JunOS commands
      DANGEROUS_COMMAND_PATTERNS = [
        /[;&<>$`]/,     # Shell metacharacters (excluding pipe)
        /\n|\r/,        # Newlines that could inject commands
        /\\(?![nrt])/   # Escape sequences (except valid ones like \n, \r, \t)
      ].freeze

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

      # Sanitize command to prevent injection attacks
      def sanitize_command(cmd)
        cmd_str = cmd.to_s.strip

        if DANGEROUS_COMMAND_PATTERNS.any? { |pattern| cmd_str.match?(pattern) }
          raise Train::ClientError, "Invalid characters in command: #{cmd_str.inspect}"
        end

        cmd_str
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

      # Handle connection errors with helpful messages
      def handle_connection_error(error)
        @logger.error("SSH connection failed: #{error.message}")

        if bastion_auth_error?(error)
          raise Train::TransportError, bastion_error_message(error)
        else
          raise Train::TransportError, "Failed to connect to Juniper device #{@options[:host]}: #{error.message}"
        end
      end

      # Check if error is bastion authentication related
      def bastion_auth_error?(error)
        @options[:bastion_host] &&
          (error.message.include?('Permission denied') || error.message.include?('command failed'))
      end

      # Build helpful bastion error message
      def bastion_error_message(error)
        <<~ERROR
          Failed to connect to Juniper device #{@options[:host]} via bastion #{@options[:bastion_host]}: #{error.message}

          Possible causes:
          1. Incorrect bastion credentials (user: #{@options[:bastion_user] || @options[:user]})
          2. Network connectivity issues to bastion host
          3. Bastion host SSH service not available on port #{@options[:bastion_port]}
          4. Target device not reachable from bastion

          Authentication options:
          - Password: Use --bastion-password (or JUNIPER_BASTION_PASSWORD env var)
          - SSH Key: Use --key-files option to specify SSH private key files
          - SSH Agent: Ensure your SSH agent has the required keys loaded

          For more details, see: https://mitre.github.io/train-juniper/troubleshooting/#bastion-authentication
        ERROR
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

      # Format JunOS command results (from implementation plan)
      def format_junos_result(output, cmd)
        # Parse JunOS-specific error patterns
        if junos_error?(output)
          CommandResult.new('', output, 1)
        else
          CommandResult.new(clean_output(output, cmd), '', 0)
        end
      end

      # Check for JunOS error patterns (from implementation plan)
      def junos_error?(output)
        JUNOS_ERROR_PATTERNS.any? { |pattern| output.match?(pattern) }
      end

      # Clean command output
      def clean_output(output, cmd)
        # Handle nil output gracefully
        return '' if output.nil?

        # Remove command echo and prompts
        lines = output.to_s.split("\n")
        lines.reject! { |line| line.strip == cmd.strip }

        # Remove JunOS prompt patterns from the end
        lines.pop while lines.last && lines.last.strip.match?(/^[%>$#]+\s*$/)

        lines.join("\n")
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

      # Mock command execution for testing
      def mock_command_result(cmd)
        output, exit_status = MockResponses.response_for(cmd)
        CommandResult.new(output, '', exit_status)
      end
    end
  end
end
