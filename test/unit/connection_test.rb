# frozen_string_literal: true

# This is a unit test for the example Train plugin, LocalRot13.
# Its job is to verify that the Connection class is setup correctly.

# Include our test harness
require_relative '../helper'

# Load the class under test, the Connection definition.
require 'train-juniper/connection'

# Because InSpec is a Spec-style test suite, we're going to use MiniTest::Spec
# here, for familiar look and feel. However, this isn't InSpec (or RSpec) code.
describe TrainPlugins::Juniper::Connection do
  # Test helper variables
  let(:connection_class) { TrainPlugins::Juniper::Connection }
  let(:mock_options) { default_mock_options(host: 'test-router', user: 'admin', password: 'secret') }

  it 'should inherit from the Train Connection base' do
    # Verify proper inheritance from BaseConnection
    _(connection_class < Train::Plugins::Transport::BaseConnection).must_equal(true)
  end

  # Verify required connection methods are implemented
  %i[
    file_via_connection
    run_command_via_connection
  ].each do |method_name|
    it "should provide a #{method_name}() method" do
      _(connection_class.instance_methods(false)).must_include(method_name)
    end
  end

  describe 'when mocking' do
    let(:connection) { connection_class.new(mock_options) }

    it 'should execute show version command' do
      result = connection.run_command('show version')
      _(result.exit_status).must_equal(0)
      _(result.stdout).must_match(/Junos:/)
    end

    it 'should execute show chassis hardware command' do
      result = connection.run_command('show chassis hardware')
      _(result.exit_status).must_equal(0)
      _(result.stdout).must_match(/Hardware inventory:/)
    end

    it 'should handle unknown commands' do
      result = connection.run_command('invalid command')
      _(result.exit_status).must_equal(1)
      _(result.stdout).must_match(/Unknown command/)
    end
  end

  describe 'proxy connection configuration' do
    let(:bastion_options) do
      mock_options.merge({
                           bastion_host: 'jump.example.com',
                           bastion_user: 'netadmin',
                           bastion_port: 2222
                         })
    end

    let(:proxy_command_options) do
      mock_options.merge({
                           proxy_command: 'ssh jump.host -W %h:%p'
                         })
    end

    it 'should accept bastion host configuration' do
      connection = connection_class.new(bastion_options)
      options = connection.instance_variable_get(:@options)
      _(options[:bastion_host]).must_equal('jump.example.com')
      _(options[:bastion_user]).must_equal('netadmin')
      _(options[:bastion_port]).must_equal(2222)
    end

    it 'should accept proxy command configuration' do
      connection = connection_class.new(proxy_command_options)
      options = connection.instance_variable_get(:@options)
      _(options[:proxy_command]).must_equal('ssh jump.host -W %h:%p')
    end

    it "should accept bastion proxy configuration for Train's SSH transport" do
      connection = connection_class.new(bastion_options)
      options = connection.instance_variable_get(:@options)

      # Verify Train SSH transport will receive the correct options
      _(options[:bastion_host]).must_equal('jump.example.com')
      _(options[:bastion_user]).must_equal('netadmin')
      _(options[:bastion_port]).must_equal(2222)
    end

    it 'should reject both bastion_host and proxy_command' do
      invalid_options = mock_options.merge({
                                             bastion_host: 'jump.host',
                                             proxy_command: 'ssh proxy -W %h:%p'
                                           })

      _(-> { connection_class.new(invalid_options) }).must_raise(Train::ClientError)
    end
  end

  describe 'environment variable support' do
    before do
      clean_juniper_env
    end

    after do
      clean_juniper_env
    end

    it 'should use environment variables for basic connection' do
      ENV['JUNIPER_HOST'] = 'env.device.com'
      ENV['JUNIPER_USER'] = 'envuser'
      ENV['JUNIPER_PASSWORD'] = 'envpass'
      ENV['JUNIPER_PORT'] = '2022'

      connection = connection_class.new({ mock: true })
      options = connection.instance_variable_get(:@options)

      _(options[:host]).must_equal('env.device.com')
      _(options[:user]).must_equal('envuser')
      _(options[:password]).must_equal('envpass')
      _(options[:port]).must_equal(2022)
    end

    it 'should use environment variables for proxy configuration' do
      ENV['JUNIPER_BASTION_HOST'] = 'env.jump.host'
      ENV['JUNIPER_BASTION_USER'] = 'envjump'
      ENV['JUNIPER_BASTION_PORT'] = '2222'

      connection = connection_class.new(mock_options)
      options = connection.instance_variable_get(:@options)

      _(options[:bastion_host]).must_equal('env.jump.host')
      _(options[:bastion_user]).must_equal('envjump')
      _(options[:bastion_port]).must_equal(2222)
    end

    it 'should prioritize explicit options over environment variables' do
      ENV['JUNIPER_HOST'] = 'env.device.com'
      ENV['JUNIPER_BASTION_HOST'] = 'env.jump.host'

      explicit_options = {
        host: 'explicit.device.com',
        bastion_host: 'explicit.jump.host',
        user: 'admin',
        mock: true
      }

      connection = connection_class.new(explicit_options)
      options = connection.instance_variable_get(:@options)

      _(options[:host]).must_equal('explicit.device.com')
      _(options[:bastion_host]).must_equal('explicit.jump.host')
    end
  end

  describe 'file operations' do
    let(:connection) { connection_class.new(mock_options) }

    it 'should handle configuration file paths' do
      file = connection.file('/config/interfaces')
      _(file).must_be_instance_of(TrainPlugins::Juniper::JuniperFile)
    end

    it 'should handle operational file paths' do
      file = connection.file('/operational/interfaces')
      _(file).must_be_instance_of(TrainPlugins::Juniper::JuniperFile)
    end
  end

  describe 'file transfer operations' do
    let(:connection) { connection_class.new(mock_options) }

    it 'should raise NotImplementedError for upload' do
      _(-> { connection.upload('local_file.txt', '/remote/path') }).must_raise(NotImplementedError)
    end

    it 'should raise NotImplementedError for download' do
      _(-> { connection.download(['/remote/file.txt'], '/local/path') }).must_raise(NotImplementedError)
    end

    it 'should provide helpful error message for upload' do
      error = _(-> { connection.upload('test.txt', '/config/test.txt') }).must_raise(NotImplementedError)
      _(error.message).must_match(/does not implement #upload/)
      _(error.message).must_match(/network devices use command-based configuration/)
    end

    it 'should provide helpful error message for download' do
      error = _(-> { connection.download(['/config/test.txt'], '.') }).must_raise(NotImplementedError)
      _(error.message).must_match(/does not implement #download/)
      _(error.message).must_match(/use run_command.*to retrieve configuration data/)
    end

    it 'should handle upload with array of local files' do
      _(-> { connection.upload(['file1.txt', 'file2.txt'], '/remote/') }).must_raise(NotImplementedError)
    end

    it 'should handle download with array of remote files' do
      _(-> { connection.download(['/file1.txt', '/file2.txt'], '/local/') }).must_raise(NotImplementedError)
    end
  end

  describe 'input validation' do
    it 'should require host option' do
      options = mock_options.dup
      options.delete(:host)
      _(-> { connection_class.new(options) }).must_raise(Train::ClientError)
    end

    it 'should require user option' do
      options = mock_options.dup
      options.delete(:user)
      _(-> { connection_class.new(options) }).must_raise(Train::ClientError)
    end

    it 'should validate port range' do
      options = mock_options.merge(port: 70000)
      err = _(-> { connection_class.new(options) }).must_raise(Train::ClientError)
      _(err.message).must_match(/Invalid port.*must be 1-65535/)
    end

    it 'should accept string ports and convert them' do
      options = mock_options.merge(port: '2222')
      connection = connection_class.new(options)
      _(connection).must_be_kind_of(connection_class)
    end

    it 'should validate timeout is positive' do
      options = mock_options.merge(timeout: -5)
      err = _(-> { connection_class.new(options) }).must_raise(Train::ClientError)
      _(err.message).must_match(/Invalid timeout.*must be positive/)
    end

    it 'should validate bastion port range' do
      options = mock_options.merge(bastion_host: 'jump.host', bastion_port: 0)
      err = _(-> { connection_class.new(options) }).must_raise(Train::ClientError)
      _(err.message).must_match(/Invalid bastion_port.*must be 1-65535/)
    end
  end

  describe 'command sanitization' do
    let(:connection) { connection_class.new(mock_options) }

    it 'should allow safe JunOS commands' do
      safe_commands = [
        'show version',
        'show configuration',
        'show interfaces terse',
        'show configuration | display set',
        'show configuration | match "interface"'
      ]
      
      safe_commands.each do |cmd|
        result = connection.run_command(cmd)
        _(result).must_be_kind_of(Train::Extras::CommandResult)
      end
    end

    it 'should block commands with dangerous shell metacharacters' do
      dangerous_commands = [
        'show version; rm -rf /',
        'show version && malicious',
        'show version & background',
        'show version > /tmp/output',
        'show version < /etc/passwd',
        'show version `evil`',
        'show version $(evil)'
      ]
      
      dangerous_commands.each do |cmd|
        err = _(-> { connection.run_command(cmd) }).must_raise(Train::ClientError)
        _(err.message).must_match(/Invalid characters in command/)
      end
    end

    it 'should block commands with newlines' do
      _(-> { connection.run_command("show version\nmalicious command") }).must_raise(Train::ClientError)
    end

    it 'should block invalid escape sequences but allow valid ones' do
      # Should block invalid escapes
      _(-> { connection.run_command('show version \x00') }).must_raise(Train::ClientError)
      
      # Should allow valid escapes like \n, \r, \t (though unusual in commands)
      result = connection.run_command('show configuration | match "test\n"')
      _(result).must_be_kind_of(Train::Extras::CommandResult)
    end
  end

  describe 'health check' do
    it 'should return true for healthy mock connection' do
      connection = connection_class.new(mock_options)
      _(connection.healthy?).must_equal(true)
    end

    it 'should return false when command fails' do
      connection = connection_class.new(mock_options)
      # Simulate a failed command
      connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        Train::Extras::CommandResult.new('', 'error', 1)
      end
      _(connection.healthy?).must_equal(false)
    end

    it 'should return false when exception occurs' do
      connection = connection_class.new(mock_options)
      # Simulate an exception
      connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        raise StandardError, 'Connection error'
      end
      _(connection.healthy?).must_equal(false)
    end
  end

  describe 'safe logging' do
    it 'should not expose sensitive data in logs' do
      # Capture logger output
      require 'stringio'
      log_output = StringIO.new
      logger = Logger.new(log_output)
      
      sensitive_options = {
        host: 'test.device',
        user: 'admin',
        password: 'super_secret_password',
        bastion_password: 'bastion_secret',
        key_files: ['/path/to/key'],
        proxy_command: 'ssh -W %h:%p proxy',
        mock: true,
        logger: logger
      }
      
      connection_class.new(sensitive_options)
      log_content = log_output.string
      
      # Should not contain sensitive information
      _(log_content).wont_match(/super_secret_password/)
      _(log_content).wont_match(/bastion_secret/)
      _(log_content).wont_match(/\/path\/to\/key/)
      _(log_content).wont_match(/ssh -W/)
      
      # Should contain safe information
      _(log_content).must_match(/test\.device/)
      _(log_content).must_match(/admin/)
    end
  end
end
