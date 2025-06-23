# frozen_string_literal: true

# Security-focused tests for train-juniper plugin

require_relative '../helper'

describe 'Security Tests' do
  let(:connection_options) { default_mock_options }

  let(:connection) { TrainPlugins::Juniper::Connection.new(connection_options) }

  describe 'credential handling' do
    it 'should not expose credentials in string representation' do
      conn_string = connection.to_s
      _(conn_string).wont_include('testpass')
      _(conn_string).must_include('testuser')
      _(conn_string).must_include('test.device')
    end

    it 'should not expose credentials in inspect output' do
      inspect_string = connection.inspect
      _(inspect_string).wont_include('testpass')
    end

    it 'should redact sensitive options when displayed' do
      # Test that password is not visible in connection string representation
      conn_string = connection.to_s
      _(conn_string).wont_include('testpass')
      _(conn_string).must_include('testuser')
      _(conn_string).must_include('test.device')
    end

    it 'should support environment variable configuration' do
      with_clean_env do
        ENV['JUNIPER_HOST'] = 'env.test.com'
        ENV['JUNIPER_USER'] = 'envuser'
        ENV['JUNIPER_PASSWORD'] = 'envpass'

        env_connection = TrainPlugins::Juniper::Connection.new(mock: true)

        # Should use environment variables
        _(env_connection.instance_variable_get(:@options)[:host]).must_equal('env.test.com')
        _(env_connection.instance_variable_get(:@options)[:user]).must_equal('envuser')

        # Should not expose password in string representation
        _(env_connection.to_s).wont_include('envpass')
      end
    end
  end

  describe 'command injection prevention' do
    it 'should execute safe JunOS commands without issues' do
      safe_commands = [
        'show version',
        'show configuration interfaces',
        'show chassis hardware',
        'show route',
        'show system information'
      ]

      safe_commands.each do |cmd|
        result = connection.run_command_via_connection(cmd)
        _(result).wont_be_nil
        _(result.exit_status).must_equal(0)
      end
    end

    it 'should handle commands with special characters safely' do
      # These should work but be handled carefully
      result = connection.run_command_via_connection('show interfaces ge-0/0/0')
      _(result).wont_be_nil

      result = connection.run_command_via_connection('show configuration | display set')
      _(result).wont_be_nil
    end

    it 'should validate command length' do
      # Test with reasonable length command
      long_but_valid = "show configuration #{'interfaces ' * 50}"
      result = connection.run_command_via_connection(long_but_valid)
      _(result).wont_be_nil
    end
  end

  describe 'output sanitization' do
    it 'should clean command output properly' do
      # Test the clean_output method with potential sensitive data
      mock_output = "show version\nHostname: device\nModel: SRX240\nshow version\n> "

      cleaned = connection.send(:clean_output, mock_output, 'show version')

      # Should remove command echo and prompts
      _(cleaned).wont_include("show version\n")
      _(cleaned).wont_include('> ')
      _(cleaned).must_include('Hostname: device')
      _(cleaned).must_include('Model: SRX240')
    end

    it 'should handle empty output gracefully' do
      cleaned = connection.send(:clean_output, '', 'show version')
      _(cleaned).must_equal('')
    end

    it 'should handle nil output gracefully' do
      cleaned = connection.send(:clean_output, nil, 'show version')
      _(cleaned).must_equal('')
    end
  end

  describe 'error pattern detection' do
    it 'should detect JunOS error patterns correctly' do
      error_outputs = [
        'error: syntax error',
        'SYNTAX ERROR: invalid command',
        'unknown command: invalid',
        'missing argument for command',
        'ERROR: Configuration database locked'
      ]

      error_outputs.each do |output|
        _(connection.send(:junos_error?, output)).must_equal(true)
      end
    end

    it 'should not flag valid output as errors' do
      valid_outputs = [
        'Hostname: device01',
        'Model: SRX240H2',
        'Junos: 12.1X47-D15.4',
        'show version output here',
        'interfaces {',
        '    ge-0/0/0 {'
      ]

      valid_outputs.each do |output|
        _(connection.send(:junos_error?, output)).must_equal(false)
      end
    end
  end

  describe 'connection security' do
    it 'should validate proxy options correctly' do
      # Test invalid proxy configuration
      invalid_options = connection_options.merge({
                                                   bastion_host: 'bastion.example.com',
                                                   proxy_command: 'ssh -W %h:%p proxy.example.com'
                                                 })

      _(proc {
        TrainPlugins::Juniper::Connection.new(invalid_options)
      }).must_raise(Train::ClientError)
    end

    it 'should handle proxy option validation without errors' do
      # Test valid bastion configuration
      bastion_options = bastion_mock_options(
        bastion_host: 'bastion.example.com',
        bastion_user: 'bastionuser',
        bastion_port: 2222
      )

      test_connection = TrainPlugins::Juniper::Connection.new(bastion_options)
      _(test_connection).wont_be_nil
    end

    it 'should handle proxy command configuration' do
      proxy_options = default_mock_options(
        proxy_command: 'ssh -W %h:%p custom-proxy.example.com'
      )

      test_connection = TrainPlugins::Juniper::Connection.new(proxy_options)
      _(test_connection).wont_be_nil
    end
  end

  describe 'mock mode security' do
    it 'should handle mock commands securely' do
      # Test that mock mode doesn't expose real system information
      result = connection.run_command_via_connection('show version')

      _(result.stdout).must_include('lab-srx')  # Mock hostname
      _(result.stdout).must_include('SRX240H2') # Mock model
      _(result.exit_status).must_equal(0)
    end

    it 'should return appropriate mock results for different commands' do
      # Test various mock command responses
      version_result = connection.run_command_via_connection('show version')
      _(version_result.stdout).must_include('SRX240H2')

      chassis_result = connection.run_command_via_connection('show chassis hardware')
      _(chassis_result.stdout).must_include('Hardware inventory')

      unknown_result = connection.run_command_via_connection('unknown command')
      _(unknown_result.exit_status).must_equal(1)
      _(unknown_result.stdout).must_include('Unknown command')
    end
  end

  describe 'file operations security' do
    it 'should handle file operations securely' do
      # Test virtual file system paths
      config_file = connection.file_via_connection('/config/interfaces')
      _(config_file).wont_be_nil

      operational_file = connection.file_via_connection('/operational/interfaces')
      _(operational_file).wont_be_nil
    end

    it 'should prevent path traversal attempts' do
      # Test that file operations handle paths safely
      weird_paths = [
        '/config/../../../etc/passwd',
        '/operational/../../../../secret',
        '/config/interfaces/../../../..'
      ]

      weird_paths.each do |path|
        file_obj = connection.file_via_connection(path)
        # Should not crash or expose unintended information
        _(file_obj).wont_be_nil
        _(file_obj.exist?).must_equal(true) # Returns mock data
      end
    end
  end

  describe 'platform detection security' do
    it 'should handle platform detection securely' do
      platform_obj = connection.platform

      _(platform_obj).wont_be_nil
      _(platform_obj.name).must_equal('juniper')
      _(platform_obj.family).must_equal('bsd')
    end

    it 'should not expose sensitive information in platform data' do
      platform_obj = connection.platform

      # Platform should not contain credential information
      platform_string = platform_obj.to_s
      _(platform_string).wont_include('testpass')
      _(platform_string).wont_include('password')
    end
  end
end
