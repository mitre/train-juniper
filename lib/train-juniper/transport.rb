# frozen_string_literal: true

# Juniper Train Plugin Transport Definition
# Defines the main transport class for connecting to Juniper network devices.
# This transport enables SSH connectivity to JunOS devices for InSpec.
require 'train-juniper/connection'

module TrainPlugins
  module Juniper
    class Transport < Train.plugin(1)
      name 'juniper'

      # Connection options for Juniper devices
      # Following Train SSH transport standard options
      option :host, required: true
      option :port, default: 22
      option :user, required: true
      option :password, default: nil
      option :timeout, default: 30

      # Proxy/Bastion host support (Train standard options)
      option :bastion_host, default: nil
      option :bastion_user, default: nil # Let connection handle env vars and defaults
      option :bastion_port, default: 22
      option :bastion_password, default: nil # Separate password for bastion authentication
      option :proxy_command, default: nil

      # SSH key authentication options
      option :key_files, default: nil
      option :keys_only, default: false

      # Advanced SSH options
      option :keepalive, default: true
      option :keepalive_interval, default: 60
      option :connection_timeout, default: 30
      option :connection_retries, default: 5
      option :connection_retry_sleep, default: 1

      # Standard Train options for compatibility
      option :insecure, default: false
      option :self_signed, default: false

      # Juniper-specific options
      option :mock, default: false
      option :disable_complete_on_space, default: false

      # Create and return a connection to a Juniper device
      def connection(_instance_opts = nil)
        # Cache the connection instance for reuse
        # @options contains parsed connection details from train URI
        @connection ||= TrainPlugins::Juniper::Connection.new(@options)
      end
    end
  end
end
