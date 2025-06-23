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
        port = @options[:port].to_i
        raise Train::ClientError, "Invalid port: #{@options[:port]} (must be 1-65535)" unless port.between?(1, 65_535)
      end

      # Validate timeout is positive number
      def validate_timeout!
        timeout = @options[:timeout]
        raise Train::ClientError, "Invalid timeout: #{timeout} (must be positive number)" unless timeout.is_a?(Numeric) && timeout.positive?
      end

      # Validate bastion port is in valid range
      def validate_bastion_port!
        port = @options[:bastion_port].to_i
        raise Train::ClientError, "Invalid bastion_port: #{@options[:bastion_port]} (must be 1-65535)" unless port.between?(1, 65_535)
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
