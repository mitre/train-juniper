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
      # Test the direct architecture match path
      test_cases = {
        'x86_64' => 'x86_64',
        'AMD64' => 'amd64',
        'i386' => 'i386',
        'ARM64' => 'arm64',
        'aarch64' => 'aarch64',
        'SPARC' => 'sparc',
        'mips' => 'mips'
      }

      test_cases.each do |input, expected|
        output = "Architecture: #{input}"
        result = connection.send(:extract_architecture_from_output, output)
        _(result).must_equal(expected)
      end
    end

    it 'should return unknown architecture as-is' do
      output = 'Model: CUSTOM-DEVICE-9000'
      result = connection.send(:extract_architecture_from_output, output)
      _(result).must_equal('CUSTOM-DEVICE-9000')
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
