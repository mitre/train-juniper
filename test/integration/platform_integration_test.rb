# frozen_string_literal: true

# Integration tests for platform detection functionality
# Tests the actual platform registration and detection logic

require_relative '../helper'

describe 'Platform Detection Integration' do
  let(:connection_options) do
    {
      host: 'test.example.com',
      user: 'testuser',
      password: 'testpass',
      mock: true # Use mock mode to avoid real connections
    }
  end

  describe 'platform registration' do
    it 'should register juniper platform in Train registry' do
      connection = TrainPlugins::Juniper::Connection.new(connection_options)

      # Access the platform method to trigger registration
      platform_obj = connection.platform

      # Verify platform is registered
      _(platform_obj).wont_be_nil
      _(platform_obj.name).must_equal('juniper')
      _(platform_obj.title).must_equal('Juniper JunOS')
      _(platform_obj.family).must_equal('bsd')
    end

    it 'should force platform without detection when connection not ready' do
      # Use non-mock mode to test fallback behavior
      options = connection_options.merge(mock: false, skip_connect: true)
      connection = TrainPlugins::Juniper::Connection.new(options)

      # Ensure no connection
      connection.instance_variable_set(:@ssh_session, nil)

      platform_obj = connection.platform

      # Should use plugin version as fallback when not connected
      _(platform_obj.release).must_equal(TrainPlugins::Juniper::VERSION)
      # Arch is not set since we removed it to fix family detection
    end

    it 'should use plugin version as fallback when version detection fails' do
      # Use non-mock mode to test fallback behavior
      options = connection_options.merge(mock: false, skip_connect: true)
      connection = TrainPlugins::Juniper::Connection.new(options)

      # Mark as connected but make version detection fail
      connection.define_singleton_method(:connected?) { true }
      connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        raise StandardError, 'Command failed'
      end

      platform_obj = connection.platform

      # Should use plugin version as fallback
      _(platform_obj.release).must_equal(TrainPlugins::Juniper::VERSION)
    end
  end

  describe 'version detection error handling' do
    it 'should handle connection failure during version detection' do
      # Use non-mock mode to test error handling
      options = connection_options.merge(mock: false, skip_connect: true)
      connection = TrainPlugins::Juniper::Connection.new(options)

      # Override run_command_via_connection to simulate failure
      connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        TrainPlugins::Juniper::CommandResult.new('', 'Connection failed', 1)
      end

      # Mark as connected
      connection.define_singleton_method(:connected?) { true }

      version = connection.send(:detect_junos_version)
      _(version).must_be_nil
    end

    it 'should handle malformed version output gracefully' do
      # Use non-mock mode to test error handling
      options = connection_options.merge(mock: false, skip_connect: true)
      connection = TrainPlugins::Juniper::Connection.new(options)

      # Override run_command_via_connection with invalid output
      connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        TrainPlugins::Juniper::CommandResult.new('No version info here', '', 0)
      end

      # Mark as connected
      connection.define_singleton_method(:connected?) { true }

      version = connection.send(:detect_junos_version)
      _(version).must_be_nil
    end

    it 'should handle exceptions during version detection' do
      # Use non-mock mode to test error handling
      options = connection_options.merge(mock: false, skip_connect: true)
      connection = TrainPlugins::Juniper::Connection.new(options)

      # Override run_command_via_connection to raise exception
      connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        raise StandardError, 'Network timeout'
      end

      # Mark as connected
      connection.define_singleton_method(:connected?) { true }

      version = connection.send(:detect_junos_version)
      _(version).must_be_nil
    end

    it 'should detect version in mock mode' do
      mock_options = connection_options.merge(mock: true)
      connection = TrainPlugins::Juniper::Connection.new(mock_options)

      version = connection.send(:detect_junos_version)
      _(version).must_equal '12.1X47-D15.4'
    end

    it 'should skip version detection when not connected' do
      # Use non-mock mode to test not connected state
      options = connection_options.merge(mock: false, skip_connect: true)
      connection = TrainPlugins::Juniper::Connection.new(options)

      # Ensure not connected
      connection.instance_variable_set(:@ssh_session, nil)

      version = connection.send(:detect_junos_version)
      _(version).must_be_nil
    end
  end

  describe 'version extraction edge cases' do
    let(:connection) { TrainPlugins::Juniper::Connection.new(connection_options) }

    it 'should handle nil output gracefully' do
      version = connection.send(:extract_version_from_xml, nil)
      _(version).must_be_nil
    end

    it 'should handle empty output gracefully' do
      version = connection.send(:extract_version_from_xml, '')
      _(version).must_be_nil
    end

    it 'should extract version from XML output' do
      output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/21.4R3/junos">
          <software-information>
            <host-name>test-device</host-name>
            <product-model>SRX300</product-model>
            <junos-version>21.4R3.15</junos-version>
          </software-information>
        </rpc-reply>
      XML
      version = connection.send(:extract_version_from_xml, output)
      _(version).must_equal('21.4R3.15')
    end

    it 'should extract version from XML with namespace' do
      output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/20.4R1/junos">
          <software-information>
            <host-name>test-device</host-name>
            <product-model>MX960</product-model>
            <junos-version>20.4R1.12</junos-version>
          </software-information>
        </rpc-reply>
      XML
      version = connection.send(:extract_version_from_xml, output)
      _(version).must_equal('20.4R1.12')
    end

    it 'should handle complex multi-line version output' do
      complex_output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/19.4R3/junos">
          <software-information>
            <host-name>test-device</host-name>
            <product-model>MX960</product-model>
            <product-name>mx960</product-name>
            <junos-version>19.4R3.11</junos-version>
          </software-information>
        </rpc-reply>
      XML

      version = connection.send(:extract_version_from_xml, complex_output)
      _(version).must_equal('19.4R3.11')
    end
  end
end
