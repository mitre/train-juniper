# frozen_string_literal: true

require 'train-juniper/constants'

module TrainPlugins
  module Juniper
    # File abstraction for Juniper configuration and operational data
    class JuniperFile
      # Initialize a new JuniperFile
      # @param connection [Connection] The Juniper connection instance
      # @param path [String] The virtual file path
      def initialize(connection, path)
        @connection = connection
        @path = path
      end

      # Get the content of the virtual file
      # @return [String] The command output based on the path
      # @example
      #   file = connection.file('/config/interfaces')
      #   file.content  # Returns output of 'show configuration interfaces'
      def content
        # For Juniper devices, translate file paths to appropriate commands
        case @path
        when Constants::CONFIG_PATH_PATTERN
          # Configuration sections: /config/interfaces -> show configuration interfaces
          section = ::Regexp.last_match(1)
          result = @connection.run_command("show configuration #{section}")
          result.stdout
        when Constants::OPERATIONAL_PATH_PATTERN
          # Operational data: /operational/interfaces -> show interfaces
          section = ::Regexp.last_match(1)
          result = @connection.run_command("show #{section}")
          result.stdout
        else
          # Default to treating path as a show command
          result = @connection.run_command("show #{@path}")
          result.stdout
        end
      end

      # Check if the file exists (has content)
      # @return [Boolean] true if the file has content, false otherwise
      def exist?
        !content.empty?
      rescue StandardError
        false
      end

      # Return string representation of file path
      # @return [String] the file path
      def to_s
        @path
      end

      # File upload not supported for network devices
      # @raise [NotImplementedError] always raises as upload is not supported
      def upload(_content)
        raise NotImplementedError, Constants::UPLOAD_NOT_SUPPORTED
      end

      # File download not supported for network devices
      # @raise [NotImplementedError] always raises as download is not supported
      def download(_local_path)
        raise NotImplementedError, Constants::DOWNLOAD_NOT_SUPPORTED
      end
    end
  end
end
