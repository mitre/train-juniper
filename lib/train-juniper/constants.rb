# frozen_string_literal: true

require 'logger'

module TrainPlugins
  module Juniper
    # Common constants used across the plugin
    module Constants
      # SSH Configuration
      # @return [Integer] Default SSH port
      DEFAULT_SSH_PORT = 22
      # @return [Range] Valid port range for SSH connections
      PORT_RANGE = (1..65_535)
      # @return [Integer] SSH keepalive interval in seconds
      SSH_KEEPALIVE_INTERVAL = 60
      # @return [Integer] Maximum keepalive count before disconnect
      SSH_KEEPALIVE_MAX_COUNT = 3

      # Logging Configuration
      # @return [Integer] Default log level
      DEFAULT_LOG_LEVEL = Logger::WARN

      # Standard SSH Options for network devices
      STANDARD_SSH_OPTIONS = {
        'UserKnownHostsFile' => '/dev/null',
        'StrictHostKeyChecking' => 'no',
        'LogLevel' => 'ERROR',
        'ForwardAgent' => 'no'
      }.freeze

      # JunOS CLI Prompt Patterns
      # @return [Regexp] Pattern matching JunOS CLI prompts
      CLI_PROMPT = /[%>$#]\s*$/
      # @return [Regexp] Pattern matching JunOS configuration mode prompts
      CONFIG_PROMPT = /[%#]\s*$/

      # File Path Patterns
      # @return [Regexp] Pattern for configuration file paths
      CONFIG_PATH_PATTERN = %r{/config/(.*)}
      # @return [Regexp] Pattern for operational data paths
      OPERATIONAL_PATH_PATTERN = %r{/operational/(.*)}

      # Error Messages
      # @return [String] Error message for unsupported upload operations
      UPLOAD_NOT_SUPPORTED = 'File operations not supported for Juniper devices - use command-based configuration'
      # @return [String] Error message for unsupported download operations
      DOWNLOAD_NOT_SUPPORTED = 'File operations not supported for Juniper devices - use run_command() to retrieve data'
    end
  end
end
