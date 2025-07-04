# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/connection'

describe 'Platform edge cases' do
  let(:connection_class) { TrainPlugins::Juniper::Connection }

  describe 'detect_attribute edge cases' do
    it 'should handle when run_command_via_connection is not available' do
      # Create a minimal object with only the Platform module
      conn = Object.new
      conn.extend(TrainPlugins::Juniper::Platform)
      conn.instance_variable_set(:@options, {})

      # Create a mock logger that expects one debug call
      logger = Minitest::Mock.new
      logger.expect :debug, nil, ['run_command_via_connection not available yet']

      # Stub the logger method
      conn.define_singleton_method(:logger) { logger }

      # DON'T define run_command_via_connection so respond_to? returns false
      # This tests the early return path at line 65

      # Test the edge case where method is not available
      result = conn.send(:detect_attribute, 'test_attr') { |output| output }

      _(result).must_be_nil
      _(conn.instance_variable_get(:@detected_test_attr)).must_be_nil

      logger.verify
    end
  end

  describe 'architecture detection edge cases' do
    let(:connection) { connection_class.new(default_mock_options) }

    it 'should handle direct architecture values' do
      # Test model to architecture mapping
      test_cases = {
        'SRX240' => 'x86_64',
        'MX960' => 'x86_64',
        'EX4300' => 'arm64',
        'QFX5100' => 'x86_64',
        'Unknown' => 'x86_64' # Default
      }

      test_cases.each do |input, expected|
        output = <<~XML
          <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
            <software-information>
              <host-name>test-device</host-name>
              <product-model>#{input}</product-model>
              <product-name>test</product-name>
              <junos-version>12.1X47-D15.4</junos-version>
            </software-information>
          </rpc-reply>
        XML
        result = connection.send(:extract_architecture_from_xml, output)
        _(result).must_equal(expected)
      end
    end

    it 'should return x86_64 for unknown architecture' do
      output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>test-device</host-name>
            <product-model>CUSTOM-DEVICE-9000</product-model>
            <product-name>custom</product-name>
            <junos-version>12.1X47-D15.4</junos-version>
          </software-information>
        </rpc-reply>
      XML
      result = connection.send(:extract_architecture_from_xml, output)
      _(result).must_equal('x86_64') # Default for unknown
    end
  end

  describe 'connection initialization without mock mode' do
    it 'should attempt connection when not in mock mode and skip_connect is false' do
      # Create a connection that will try to connect
      options = default_mock_options.merge(mock: false)

      # We need to stub the connect method to avoid real SSH
      connection_class.class_eval do
        alias_method :original_connect, :connect
        define_method(:connect) { @connect_called = true }
      end

      conn = connection_class.new(options)
      _(conn.instance_variable_get(:@connect_called)).must_equal(true)

      # Restore original method
      connection_class.class_eval do
        alias_method :connect, :original_connect
        remove_method :original_connect
      end
    end
  end
end
