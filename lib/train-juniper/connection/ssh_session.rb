# frozen_string_literal: true

module TrainPlugins
  module Juniper
    # Handles SSH session management and configuration
    module SSHSession
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
      # Rationale: Network devices often regenerate SSH keys after firmware updates
      # and operate in controlled environments where MITM attacks are mitigated by
      # network segmentation. This matches standard network automation practices.
      SSH_DEFAULTS = {
        verify_host_key: :never
      }.freeze

      # Establish SSH connection to Juniper device
      def connect
        return if connected?

        # :nocov: Real SSH connections cannot be tested without actual devices
        begin
          # Use direct SSH connection (network device pattern)
          # Defensive loading - only require if not fully loaded
          require 'net/ssh' unless defined?(Net::SSH) && Net::SSH.respond_to?(:start)

          @logger.debug('Establishing SSH connection to Juniper device')

          ssh_options = build_ssh_options

          # Add bastion host support if configured
          if @options[:bastion_host]
            log_bastion_connection(@options[:bastion_host])
            configure_bastion_proxy(ssh_options)
          end

          log_connection_attempt(@options[:host], @options[:port])
          log_ssh_options(ssh_options)

          # Direct SSH connection
          @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
          log_connection_success(@options[:host])

          # Configure JunOS session for automation
          test_and_configure_session
        rescue StandardError => e
          handle_connection_error(e)
        end
        # :nocov:
      end

      # Check if SSH connection is active
      # @return [Boolean] true if connected, false otherwise
      def connected?
        return true if @options[:mock]

        !@ssh_session.nil?
      rescue StandardError
        false
      end

      # Check if running in mock mode
      # @return [Boolean] true if in mock mode
      def mock?
        @options[:mock] == true
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

      private

      # Build SSH connection options from @options
      def build_ssh_options
        SSH_DEFAULTS.merge(
          SSH_OPTION_MAPPING.each_with_object({}) do |(ssh_key, option_key), opts|
            value = option_key.is_a?(Proc) ? option_key.call(@options) : @options[option_key]
            opts[ssh_key] = value unless value.nil?
          end
        )
      end
    end
  end
end
