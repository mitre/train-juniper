# frozen_string_literal: true

module TrainPlugins
  module Juniper
    # Helper methods for safely handling environment variables
    module EnvironmentHelpers
      # Helper method to safely get environment variable value
      # Returns nil if env var is not set or is empty string
      # @param key [String] The environment variable name
      # @return [String, nil] The value or nil if not set/empty
      def env_value(key)
        value = ENV.fetch(key, nil)
        return nil if value.nil? || value.empty?

        value
      end

      # Helper method to get environment variable as integer
      # Returns nil if env var is not set, empty, or not a valid integer
      # @param key [String] The environment variable name
      # @return [Integer, nil] The integer value or nil if not valid
      def env_int(key)
        value = env_value(key)
        return nil unless value

        value.to_i
      rescue ArgumentError
        nil
      end
    end
  end
end
