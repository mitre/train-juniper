# frozen_string_literal: true

# Integration tests for Juniper Train plugin proxy connection functionality
# Tests Train URI parsing and InSpec integration patterns

require_relative '../helper'
require 'train-juniper'

describe 'Juniper Plugin Proxy Integration' do
  describe 'Train.create with proxy options' do
    it 'should create transport with bastion host options' do
      transport = Train.create('juniper', {
                                 host: 'device.local',
                                 user: 'admin',
                                 password: 'test_credential',  # Test only - not real
                                 bastion_host: 'jump.host',
                                 bastion_user: 'netadmin',
                                 bastion_port: 2222,
                                 mock: true
                               })

      _(transport).must_be_instance_of(TrainPlugins::Juniper::Transport)

      connection = transport.connection
      options = connection.instance_variable_get(:@options)
      _(options[:bastion_host]).must_equal('jump.host')
      _(options[:bastion_user]).must_equal('netadmin')
      _(options[:bastion_port]).must_equal(2222)
    end

    it 'should create transport with proxy command' do
      transport = Train.create('juniper', {
                                 host: 'device.local',
                                 user: 'admin',
                                 password: 'test_credential',  # Test only - not real
                                 proxy_command: 'ssh jump.example.com -W %h:%p',
                                 mock: true
                               })

      _(transport).must_be_instance_of(TrainPlugins::Juniper::Transport)

      connection = transport.connection
      options = connection.instance_variable_get(:@options)
      _(options[:proxy_command]).must_equal('ssh jump.example.com -W %h:%p')
    end
  end

  describe 'Train.target_config URI parsing' do
    it 'should parse basic juniper URI' do
      config = Train.target_config(target: 'juniper://admin@device.local')

      _(config[:backend]).must_equal('juniper')
      _(config[:host]).must_equal('device.local')
      _(config[:user]).must_equal('admin')
    end

    it 'should parse juniper URI with port' do
      config = Train.target_config(target: 'juniper://admin@device.local:2222')

      _(config[:backend]).must_equal('juniper')
      _(config[:host]).must_equal('device.local')
      _(config[:user]).must_equal('admin')
      _(config[:port]).must_equal(2222)
    end

    it 'should parse juniper URI with bastion parameters' do
      uri = 'juniper://admin@device.local?bastion_host=jump.host&bastion_user=netadmin&bastion_port=2222'
      config = Train.target_config(target: uri)

      _(config[:backend]).must_equal('juniper')
      _(config[:host]).must_equal('device.local')
      _(config[:user]).must_equal('admin')
      _(config[:bastion_host]).must_equal('jump.host')
      _(config[:bastion_user]).must_equal('netadmin')
      _(config[:bastion_port]).must_equal('2222') # URI params are strings
    end

    it 'should parse juniper URI with proxy command' do
      # URL encode the proxy command
      proxy_cmd = 'ssh%20jump.host%20-W%20%25h:%25p'
      uri = "juniper://admin@device.local?proxy_command=#{proxy_cmd}"
      config = Train.target_config(target: uri)

      _(config[:backend]).must_equal('juniper')
      _(config[:proxy_command]).must_equal('ssh jump.host -W %h:%p')
    end

    it 'should parse juniper URI with bastion_password parameter' do
      uri = 'juniper://admin@device.local?bastion_host=jump.host&bastion_user=netadmin&bastion_password=secret'
      config = Train.target_config(target: uri)

      _(config[:backend]).must_equal('juniper')
      _(config[:host]).must_equal('device.local')
      _(config[:user]).must_equal('admin')
      _(config[:bastion_host]).must_equal('jump.host')
      _(config[:bastion_user]).must_equal('netadmin')
      _(config[:bastion_password]).must_equal('secret')
    end
  end

  describe 'end-to-end connection with proxy' do
    it 'should establish mock connection through bastion host' do
      transport = Train.create('juniper', {
                                 host: 'internal.device',
                                 user: 'admin',
                                 password: 'test_credential', # Test only - not real
                                 bastion_host: 'jump.company.com',
                                 bastion_user: 'netops',
                                 mock: true
                               })

      connection = transport.connection

      # Test that connection works
      result = connection.run_command('show version')
      _(result.exit_status).must_equal(0)
      _(result.stdout).must_match(/Junos:/)

      # Test that the connection is properly configured with proxy options
      options = connection.instance_variable_get(:@options)
      _(options[:bastion_host]).must_equal('jump.company.com')
      _(options[:bastion_user]).must_equal('netops')
    end

    it 'should establish mock connection with proxy command' do
      transport = Train.create('juniper', {
                                 host: 'secure.device',
                                 user: 'admin',
                                 password: 'test_credential', # Test only - not real
                                 proxy_command: 'ssh proxy.host -W %h:%p',
                                 mock: true
                               })

      connection = transport.connection

      # Test that connection works
      result = connection.run_command('show version')
      _(result.exit_status).must_equal(0)

      # Test file operations work
      config_file = connection.file('/config/interfaces')
      _(config_file).must_be_instance_of(TrainPlugins::Juniper::JuniperFile)
    end
  end

  describe 'bastion host configuration' do
    it 'should handle bastion host with all options' do
      transport = Train.create('juniper', {
                                 host: 'device.local',
                                 user: 'admin',
                                 password: 'device_pass',
                                 bastion_host: 'bastion.host',
                                 bastion_user: 'bastion_user',
                                 bastion_port: 2222,
                                 bastion_password: 'bastion_pass',
                                 mock: true
                               })

      connection = transport.connection
      options = connection.instance_variable_get(:@options)

      _(options[:bastion_host]).must_equal('bastion.host')
      _(options[:bastion_user]).must_equal('bastion_user')
      _(options[:bastion_port]).must_equal(2222)
      _(options[:bastion_password]).must_equal('bastion_pass')
      _(options[:password]).must_equal('device_pass') # Different from bastion password
    end

    it 'should fallback to device password for bastion authentication' do
      transport = Train.create('juniper', {
                                 host: 'device.local',
                                 user: 'admin',
                                 password: 'shared_pass',
                                 bastion_host: 'bastion.host',
                                 bastion_user: 'bastion_user',
                                 # No bastion_password - should use device password
                                 mock: true
                               })

      connection = transport.connection
      options = connection.instance_variable_get(:@options)

      _(options[:bastion_host]).must_equal('bastion.host')
      _(options[:bastion_user]).must_equal('bastion_user')
      _(options[:password]).must_equal('shared_pass')
      _(options[:bastion_password]).must_be_nil # Not explicitly set
    end
  end

  describe 'error handling' do
    it 'should reject both bastion_host and proxy_command' do
      _(lambda {
        transport = Train.create('juniper', {
                                   host: 'device.local',
                                   user: 'admin',
                                   bastion_host: 'jump.host',
                                   proxy_command: 'ssh proxy -W %h:%p',
                                   mock: true
                                 })
        # Error occurs when creating connection, not transport
        transport.connection
      }).must_raise(Train::ClientError)
    end

    it 'should handle missing required options gracefully' do
      # This should work - transport validates options, not Train.create
      transport = Train.create('juniper', { mock: true })
      _(transport).must_be_instance_of(TrainPlugins::Juniper::Transport)
    end
  end

  describe 'InSpec command line simulation' do
    # These tests simulate what happens when someone runs:
    # inspec detect -t "juniper://user@host?bastion_host=jump"

    it 'should work with inspec detect style commands' do
      # Simulate InSpec's target parsing
      target_string = 'juniper://admin@switch.local?bastion_host=jump.corp.com'
      config = Train.target_config(target: target_string)
      config[:mock] = true # Add mock mode

      # Create transport like InSpec would
      transport = Train.create(config[:backend], config)
      _(transport).must_be_instance_of(TrainPlugins::Juniper::Transport)

      # Get connection like InSpec would
      connection = transport.connection
      _(connection).must_be_instance_of(TrainPlugins::Juniper::Connection)

      # Test that connection is established
      result = connection.run_command('show version')
      _(result.exit_status).must_equal(0)
    end

    it 'should work with complex proxy scenarios' do
      # Simulate complex corporate network scenario
      target_string = 'juniper://netadmin@core-switch.internal.corp?bastion_host=jump.dmz.corp&bastion_user=svc_inspec&bastion_port=2222'
      config = Train.target_config(target: target_string)
      config[:mock] = true

      transport = Train.create(config[:backend], config)
      connection = transport.connection

      # Verify options were parsed correctly
      options = connection.instance_variable_get(:@options)
      _(options[:host]).must_equal('core-switch.internal.corp')
      _(options[:user]).must_equal('netadmin')
      _(options[:bastion_host]).must_equal('jump.dmz.corp')
      _(options[:bastion_user]).must_equal('svc_inspec')
      _(options[:bastion_port]).must_equal('2222') # String from URI parsing

      # Test functionality
      result = connection.run_command('show version')
      _(result.exit_status).must_equal(0)
    end
  end
end
