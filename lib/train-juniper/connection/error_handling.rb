# frozen_string_literal: true

module TrainPlugins
  module Juniper
    # Handles error detection, classification, and messaging
    module ErrorHandling
      # JunOS error patterns organized by type
      JUNOS_ERRORS = {
        configuration: [/^error:/i, /configuration database locked/i],
        syntax: [/syntax error/i],
        command: [/invalid command/i, /unknown command/i],
        argument: [/missing argument/i]
      }.freeze

      # Flattened error patterns for quick matching
      JUNOS_ERROR_PATTERNS = JUNOS_ERRORS.values.flatten.freeze

      # Check for JunOS error patterns
      # @param output [String] Command output to check
      # @return [Boolean] true if output contains error patterns
      def junos_error?(output)
        return false if output.nil? || output.empty?

        JUNOS_ERROR_PATTERNS.any? { |pattern| output.match?(pattern) }
      end

      # Handle connection errors with helpful messages
      # @param error [StandardError] The error that occurred
      # @raise [Train::TransportError] Always raises with formatted message
      def handle_connection_error(error)
        @logger.error("SSH connection failed: #{error.message}")

        if bastion_auth_error?(error)
          raise Train::TransportError, bastion_error_message(error)
        else
          raise Train::TransportError, "Failed to connect to Juniper device #{@options[:host]}: #{error.message}"
        end
      end

      # Check if error is bastion authentication related
      # @param error [StandardError] The error to check
      # @return [Boolean] true if error is bastion-related
      def bastion_auth_error?(error)
        @options[:bastion_host] &&
          (error.message.include?('Permission denied') || error.message.include?('command failed'))
      end

      # Build helpful bastion error message
      # @param error [StandardError] The original error
      # @return [String] Detailed error message with troubleshooting steps
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
    end
  end
end
