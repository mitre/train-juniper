# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/connection'

describe 'Logging module' do
  let(:connection_class) { TrainPlugins::Juniper::Connection }
  let(:connection) { connection_class.new(default_mock_options(skip_connect: true)) }
  let(:logger) { Minitest::Mock.new }

  before do
    connection.instance_variable_set(:@logger, logger)
  end

  describe 'log_command' do
    it 'should log command execution' do
      logger.expect :debug, nil, ['Executing command: show version']

      connection.send(:log_command, 'show version')
      logger.verify
    end
  end

  describe 'log_connection_attempt' do
    it 'should log connection attempt with port' do
      logger.expect :debug, nil, ['Attempting connection to router.example.com:22']

      connection.send(:log_connection_attempt, 'router.example.com', 22)
      logger.verify
    end

    it 'should log connection attempt without port' do
      logger.expect :debug, nil, ['Attempting connection to router.example.com']

      connection.send(:log_connection_attempt, 'router.example.com')
      logger.verify
    end
  end

  describe 'log_error' do
    it 'should log exception with context' do
      error = StandardError.new('Connection refused')
      logger.expect :error, nil, ['Failed to connect: StandardError: Connection refused']

      connection.send(:log_error, error, 'Failed to connect')
      logger.verify
    end

    it 'should log exception without context' do
      error = Train::ClientError.new('Invalid host')
      logger.expect :error, nil, ['Train::ClientError: Invalid host']

      connection.send(:log_error, error)
      logger.verify
    end

    it 'should log string error with context' do
      logger.expect :error, nil, ['Command failed: Syntax error']

      connection.send(:log_error, 'Syntax error', 'Command failed')
      logger.verify
    end

    it 'should log string error without context' do
      logger.expect :error, nil, ['Unknown error occurred']

      connection.send(:log_error, 'Unknown error occurred')
      logger.verify
    end
  end

  describe 'log_connection_success' do
    it 'should log successful connection' do
      logger.expect :info, nil, ['Successfully connected to router.local']

      connection.send(:log_connection_success, 'router.local')
      logger.verify
    end
  end

  describe 'log_ssh_options' do
    it 'should redact password in options' do
      options = {
        host: 'device.local',
        password: 'secret123',
        port: 22,
        user: 'admin'
      }

      logger.expect :debug, nil, [/SSH options:.*password.*REDACTED/]

      connection.send(:log_ssh_options, options)
      logger.verify
    end

    it 'should redact passphrase in options' do
      options = {
        host: 'device.local',
        passphrase: 'key_secret',
        port: 22,
        user: 'admin'
      }

      logger.expect :debug, nil, [/SSH options:.*passphrase.*REDACTED/]

      connection.send(:log_ssh_options, options)
      logger.verify
    end

    it 'should show only basenames for key files' do
      options = {
        host: 'device.local',
        keys: ['/home/user/.ssh/id_rsa', '/home/user/.ssh/id_ed25519'],
        port: 22,
        user: 'admin'
      }

      logger.expect :debug, nil, [/SSH options:.*keys.*\["id_rsa", "id_ed25519"\]/]

      connection.send(:log_ssh_options, options)
      logger.verify
    end

    it 'should handle options without sensitive data' do
      options = {
        host: 'device.local',
        port: 22,
        user: 'admin',
        timeout: 30
      }

      logger.expect :debug, nil, [/SSH options:.*host.*device\.local.*port.*22/]

      connection.send(:log_ssh_options, options)
      logger.verify
    end
  end

  describe 'log_platform_detection' do
    it 'should log detected platform and version' do
      logger.expect :info, nil, ['Platform detected: juniper 12.1X47-D15.4']

      connection.send(:log_platform_detection, 'juniper', '12.1X47-D15.4')
      logger.verify
    end
  end

  describe 'log_bastion_connection' do
    it 'should log bastion host connection' do
      logger.expect :debug, nil, ['Connecting through bastion host: jump.example.com']

      connection.send(:log_bastion_connection, 'jump.example.com')
      logger.verify
    end
  end

  describe 'log_mock_mode' do
    it 'should log mock mode activation' do
      logger.expect :info, nil, ['Running in mock mode - no real device connection']

      connection.send(:log_mock_mode)
      logger.verify
    end
  end
end
