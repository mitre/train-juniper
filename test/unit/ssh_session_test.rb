# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/connection'

describe 'SSHSession module' do
  let(:connection_class) { TrainPlugins::Juniper::Connection }
  let(:connection) { connection_class.new(default_mock_options(skip_connect: true)) }
  
  describe 'build_ssh_options' do
    it 'should build SSH options with password' do
      options = default_mock_options(
        password: 'secret',
        port: 2222,
        timeout: 60,
        keepalive: true,
        keepalive_interval: 60
      )
      conn = connection_class.new(options.merge(skip_connect: true))
      
      ssh_opts = conn.send(:build_ssh_options)
      
      _(ssh_opts[:password]).must_equal('secret')
      _(ssh_opts[:port]).must_equal(2222)
      _(ssh_opts[:timeout]).must_equal(60)
      _(ssh_opts[:keepalive]).must_equal(true)
      _(ssh_opts[:keepalive_interval]).must_equal(60)
      _(ssh_opts[:verify_host_key]).must_equal(:never)
    end
    
    it 'should build SSH options with key files' do
      options = default_mock_options(
        key_files: ['/path/to/key1', '/path/to/key2'],
        keys_only: true
      )
      conn = connection_class.new(options.merge(skip_connect: true))
      
      ssh_opts = conn.send(:build_ssh_options)
      
      _(ssh_opts[:keys]).must_equal(['/path/to/key1', '/path/to/key2'])
      _(ssh_opts[:keys_only]).must_equal(true)
    end
    
    it 'should handle single key file' do
      options = default_mock_options(
        key_files: '/path/to/single_key'
      )
      conn = connection_class.new(options.merge(skip_connect: true))
      
      ssh_opts = conn.send(:build_ssh_options)
      
      _(ssh_opts[:keys]).must_equal(['/path/to/single_key'])
    end
    
    it 'should omit nil values' do
      options = default_mock_options
      options.delete(:password) # No password
      conn = connection_class.new(options.merge(skip_connect: true))
      
      ssh_opts = conn.send(:build_ssh_options)
      
      _(ssh_opts.key?(:password)).must_equal(false)
      _(ssh_opts.key?(:keys)).must_equal(false)
      _(ssh_opts.key?(:keys_only)).must_equal(false)
    end
  end
  
  describe 'test_and_configure_session' do
    it 'should configure JunOS session with complete-on-space disabled' do
      options = default_mock_options(
        disable_complete_on_space: true,
        skip_connect: true
      )
      conn = connection_class.new(options)
      
      # Mock SSH session
      ssh_session = Minitest::Mock.new
      ssh_session.expect :exec!, nil, ['echo "connection test"']
      ssh_session.expect :exec!, nil, ['set cli screen-length 0']
      ssh_session.expect :exec!, nil, ['set cli screen-width 0']
      ssh_session.expect :exec!, nil, ['set cli complete-on-space off']
      
      conn.instance_variable_set(:@ssh_session, ssh_session)
      
      # Mock logger
      logger = Minitest::Mock.new
      logger.expect :debug, nil, ['Testing SSH connection and configuring JunOS session']
      logger.expect :debug, nil, ['SSH connection test successful']
      logger.expect :debug, nil, ['JunOS session configured successfully']
      conn.instance_variable_set(:@logger, logger)
      
      conn.send(:test_and_configure_session)
      
      ssh_session.verify
      logger.verify
    end
    
    it 'should handle session configuration errors gracefully' do
      # Mock SSH session that fails
      ssh_session = Minitest::Mock.new
      ssh_session.expect :exec!, nil, ['echo "connection test"']
      ssh_session.expect :exec!, nil do |cmd|
        raise StandardError, 'Command failed'
      end
      
      connection.instance_variable_set(:@ssh_session, ssh_session)
      
      # Mock logger
      logger = Minitest::Mock.new
      logger.expect :debug, nil, ['Testing SSH connection and configuring JunOS session']
      logger.expect :debug, nil, ['SSH connection test successful']
      logger.expect :warn, nil, ['Failed to configure JunOS session: Command failed']
      connection.instance_variable_set(:@logger, logger)
      
      # Should not raise error
      connection.send(:test_and_configure_session)
      
      ssh_session.verify
      logger.verify
    end
  end
  
  describe 'connect' do
    it 'should return early if already connected' do
      options = default_mock_options(mock: false, skip_connect: true)
      conn = connection_class.new(options)
      
      # Simulate already connected
      conn.instance_variable_set(:@ssh_session, Object.new)
      
      # Mock logger to ensure no connection attempt is made
      logger = Minitest::Mock.new
      # No expectations - connect should return early
      conn.instance_variable_set(:@logger, logger)
      
      # Call connect - should return early at line 26
      conn.send(:connect)
      
      # Verify logger had no calls
      logger.verify
    end
  end
  
  describe 'connected?' do
    it 'should return true when ssh_session exists' do
      options = default_mock_options(mock: false, skip_connect: true)
      conn = connection_class.new(options)
      conn.instance_variable_set(:@ssh_session, Object.new)
      _(conn.send(:connected?)).must_equal(true)
    end
    
    it 'should return false when ssh_session is nil' do
      options = default_mock_options(mock: false, skip_connect: true)
      conn = connection_class.new(options)
      conn.instance_variable_set(:@ssh_session, nil)
      _(conn.send(:connected?)).must_equal(false)
    end
    
    it 'should handle exceptions and return false' do
      options = default_mock_options(mock: false, skip_connect: true)
      conn = connection_class.new(options)
      
      # Create an object that raises when accessed
      bad_session = Object.new
      def bad_session.nil?
        raise 'Connection lost'
      end
      
      conn.instance_variable_set(:@ssh_session, bad_session)
      _(conn.send(:connected?)).must_equal(false)
    end
  end
  
  describe 'mock?' do
    it 'should return true when mock option is true' do
      options = default_mock_options(mock: true)
      conn = connection_class.new(options)
      _(conn.send(:mock?)).must_equal(true)
    end
    
    it 'should return false when mock option is false' do
      options = default_mock_options(mock: false, skip_connect: true)
      conn = connection_class.new(options)
      _(conn.send(:mock?)).must_equal(false)
    end
    
    it 'should return false when mock option is not set' do
      options = default_mock_options
      options.delete(:mock)
      conn = connection_class.new(options.merge(skip_connect: true))
      _(conn.send(:mock?)).must_equal(false)
    end
  end
end