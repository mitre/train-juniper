# frozen_string_literal: true

# Unit tests for Juniper Train plugin Transport class.
# Verifies plugin registration and transport functionality.

# Include our test harness
require_relative '../helper'

# Load the class under test, the Plugin definition.
require 'train-juniper/transport'

# Because InSpec is a Spec-style test suite, we're going to use MiniTest::Spec
# here, for familiar look and feel. However, this isn't InSpec (or RSpec) code.
describe TrainPlugins::Juniper::Transport do
  # Test helper variables
  let(:plugin_class) { TrainPlugins::Juniper::Transport }

  it 'should be registered with the plugin registry without the train- prefix' do
    # Note that Train uses String keys here, not Symbols
    _(Train::Plugins.registry.keys).wont_include('train-juniper')
    _(Train::Plugins.registry.keys).must_include('juniper')
  end

  it 'should inherit from the Train plugin base' do
    # For Class, '<' means 'is a descendant of'
    _(plugin_class < Train.plugin(1)).must_equal(true)
  end

  it 'should provide a connection() method' do
    # false passed to instance_methods says 'don't use inheritance'
    _(plugin_class.instance_methods(false)).must_include(:connection)
  end

  describe 'transport options' do
    let(:transport) { plugin_class.new }

    it 'should define required connection options' do
      # Test that all required options are defined
      required_options = %i[host user]
      required_options.each do |option|
        _(transport.class.default_options.keys).must_include(option)
      end
    end

    it 'should define proxy/bastion options' do
      # Test Train-standard proxy options
      proxy_options = %i[bastion_host bastion_user bastion_port proxy_command]
      proxy_options.each do |option|
        _(transport.class.default_options.keys).must_include(option)
      end
    end

    it 'should have correct default values' do
      defaults = transport.class.default_options
      _(defaults[:port][:default]).must_equal(22)
      _(defaults[:bastion_user][:default]).must_be_nil # Changed to nil for env var support
      _(defaults[:bastion_port][:default]).must_equal(22)
      _(defaults[:timeout][:default]).must_equal(30)
      _(defaults[:keepalive][:default]).must_equal(true)
    end
  end

  describe 'connection creation' do
    let(:basic_options) { { host: 'test.device', user: 'admin', password: 'secret', mock: true } }

    it 'should create connection with basic options' do
      transport = plugin_class.new
      transport.instance_variable_set(:@options, basic_options)
      connection = transport.connection
      _(connection).must_be_instance_of(TrainPlugins::Juniper::Connection)
    end

    it 'should create connection with proxy options' do
      proxy_options = basic_options.merge({
                                            bastion_host: 'jump.host',
                                            bastion_user: 'admin',
                                            bastion_port: 2222
                                          })
      transport = plugin_class.new
      transport.instance_variable_set(:@options, proxy_options)
      connection = transport.connection
      _(connection).must_be_instance_of(TrainPlugins::Juniper::Connection)
    end
  end
end
