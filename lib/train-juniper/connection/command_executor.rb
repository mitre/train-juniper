# frozen_string_literal: true

module TrainPlugins
  module Juniper
    # Handles command execution, sanitization, and output formatting
    module CommandExecutor
      # Command sanitization patterns
      # Note: Pipe (|) is allowed as it's commonly used in JunOS commands
      DANGEROUS_COMMAND_PATTERNS = [
        /[;&<>$`]/,     # Shell metacharacters (excluding pipe)
        /\n|\r/,        # Newlines that could inject commands
        /\\(?![nrt])/   # Escape sequences (except valid ones like \n, \r, \t)
      ].freeze

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
          Train::Extras::CommandResult.new('', e.message, 1)
        end
      end

      private

      # Sanitize command to prevent injection attacks
      def sanitize_command(cmd)
        cmd_str = cmd.to_s.strip

        if DANGEROUS_COMMAND_PATTERNS.any? { |pattern| cmd_str.match?(pattern) }
          raise Train::ClientError, "Invalid characters in command: #{cmd_str.inspect}"
        end

        cmd_str
      end

      # Format JunOS command results
      def format_junos_result(output, cmd)
        # Parse JunOS-specific error patterns
        if junos_error?(output)
          Train::Extras::CommandResult.new('', output, 1)
        else
          Train::Extras::CommandResult.new(clean_output(output, cmd), '', 0)
        end
      end

      # Clean command output
      def clean_output(output, cmd)
        # Handle nil output gracefully
        return '' if output.nil?

        # Remove command echo and prompts
        lines = output.to_s.split("\n")
        lines.reject! { |line| line.strip == cmd.strip }

        # Remove JunOS prompt patterns from the end
        lines.pop while lines.last&.strip&.match?(/^[%>$#]+\s*$/)

        lines.join("\n")
      end

      # Mock command execution for testing
      def mock_command_result(cmd)
        output, exit_status = MockResponses.response_for(cmd)
        Train::Extras::CommandResult.new(output, '', exit_status)
      end
    end
  end
end
