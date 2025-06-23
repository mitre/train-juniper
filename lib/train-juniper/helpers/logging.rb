# frozen_string_literal: true

module TrainPlugins
  module Juniper
    # Provides consistent logging patterns across the plugin
    module Logging
      # Log a command execution attempt
      # @param cmd [String] The command being executed
      def log_command(cmd)
        @logger.debug("Executing command: #{cmd}")
      end

      # Log a connection attempt
      # @param target [String] The host/target being connected to
      # @param port [Integer] The port number
      def log_connection_attempt(target, port = nil)
        if port
          @logger.debug("Attempting connection to #{target}:#{port}")
        else
          @logger.debug("Attempting connection to #{target}")
        end
      end

      # Log an error with consistent formatting
      # @param error [Exception, String] The error to log
      # @param context [String] Additional context for the error
      def log_error(error, context = nil)
        message = if error.is_a?(Exception)
                    "#{error.class}: #{error.message}"
                  else
                    error.to_s
                  end

        if context
          @logger.error("#{context}: #{message}")
        else
          @logger.error(message)
        end
      end

      # Log successful connection
      # @param target [String] The host that was connected to
      def log_connection_success(target)
        @logger.info("Successfully connected to #{target}")
      end

      # Log SSH session details (redacting sensitive info)
      # @param options [Hash] SSH options hash
      def log_ssh_options(options)
        safe_options = options.dup
        safe_options[:password] = '[REDACTED]' if safe_options[:password]
        safe_options[:passphrase] = '[REDACTED]' if safe_options[:passphrase]
        safe_options[:keys] = safe_options[:keys]&.map { |k| File.basename(k) } if safe_options[:keys]

        @logger.debug("SSH options: #{safe_options.inspect}")
      end

      # Log platform detection results
      # @param platform_name [String] Detected platform name
      # @param version [String] Detected version
      def log_platform_detection(platform_name, version)
        @logger.info("Platform detected: #{platform_name} #{version}")
      end

      # Log bastion connection attempt
      # @param bastion_host [String] The bastion host
      def log_bastion_connection(bastion_host)
        @logger.debug("Connecting through bastion host: #{bastion_host}")
      end

      # Log mock mode activation
      def log_mock_mode
        @logger.info('Running in mock mode - no real device connection')
      end
    end
  end
end
