# frozen_string_literal: true

module TrainPlugins
  module Juniper
    # Validation methods for connection options
    module Validation
      # Validate all connection options
      def validate_connection_options!
        validate_required_options!
        validate_option_types!
        validate_proxy_options!
      end

      # Validate required options are present
      def validate_required_options!
        raise Train::ClientError, 'Host is required' unless @options[:host]
        raise Train::ClientError, 'User is required' unless @options[:user]
      end

      # Validate option types and ranges
      def validate_option_types!
        validate_port! if @options[:port]
        validate_timeout! if @options[:timeout]
        validate_bastion_port! if @options[:bastion_port]
      end

      # Validate port is in valid range
      def validate_port!
        validate_port_value!(:port)
      end

      # Validate timeout is positive number
      def validate_timeout!
        timeout = @options[:timeout]
        raise Train::ClientError, "Invalid timeout: #{timeout} (must be positive number)" unless timeout.is_a?(Numeric) && timeout.positive?
      end

      # Validate bastion port is in valid range
      def validate_bastion_port!
        validate_port_value!(:bastion_port)
      end

      private

      # DRY method for validating port values
      # @param port_key [Symbol] The options key containing the port value
      # @param port_name [String] The name to use in error messages (defaults to port_key)
      def validate_port_value!(port_key, port_name = nil)
        port_name ||= port_key.to_s.tr('_', ' ')
        port = @options[port_key].to_i
        raise Train::ClientError, "Invalid #{port_name}: #{@options[port_key]} (must be 1-65535)" unless port.between?(1, 65_535)
      end

      # Validate proxy configuration options (Train standard)
      def validate_proxy_options!
        # Cannot use both bastion_host and proxy_command simultaneously
        if @options[:bastion_host] && @options[:proxy_command]
          raise Train::ClientError, 'Cannot specify both bastion_host and proxy_command'
        end
      end
    end
  end
end
