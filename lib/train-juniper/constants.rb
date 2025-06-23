# frozen_string_literal: true

module TrainPlugins
  module Juniper
    # Common constants used across the plugin
    module Constants
      # SSH Configuration
      DEFAULT_SSH_PORT = 22
      PORT_RANGE = (1..65_535)

      # Standard SSH Options for network devices
      STANDARD_SSH_OPTIONS = {
        'UserKnownHostsFile' => '/dev/null',
        'StrictHostKeyChecking' => 'no',
        'LogLevel' => 'ERROR',
        'ForwardAgent' => 'no'
      }.freeze

      # JunOS CLI Prompt Patterns
      CLI_PROMPT = /[%>$#]\s*$/
      CONFIG_PROMPT = /[%#]\s*$/

      # File Path Patterns
      CONFIG_PATH_PATTERN = %r{/config/(.*)}
      OPERATIONAL_PATH_PATTERN = %r{/operational/(.*)}

      # Error Messages
      UPLOAD_NOT_SUPPORTED = 'File operations not supported for Juniper devices - use command-based configuration'
      DOWNLOAD_NOT_SUPPORTED = 'File operations not supported for Juniper devices - use run_command() to retrieve data'
    end
  end
end
