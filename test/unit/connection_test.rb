# This is a unit test for the example Train plugin, LocalRot13.
# Its job is to verify that the Connection class is setup correctly.

# Include our test harness
require_relative "../helper"

# Load the class under test, the Connection definition.
require "train-juniper/connection"

# Because InSpec is a Spec-style test suite, we're going to use MiniTest::Spec
# here, for familiar look and feel. However, this isn't InSpec (or RSpec) code.
describe TrainPlugins::Juniper::Connection do

  # Test helper variables
  let(:connection_class) { TrainPlugins::Juniper::Connection }
  let(:mock_options) { { host: "test-router", user: "admin", password: "secret", mock: true } }

  it "should inherit from the Train Connection base" do
    # Verify proper inheritance from BaseConnection
    _((connection_class < Train::Plugins::Transport::BaseConnection)).must_equal(true)
  end

  # Verify required connection methods are implemented
  %i{
    file_via_connection
    run_command_via_connection
  }.each do |method_name|
    it "should provide a #{method_name}() method" do
      _(connection_class.instance_methods(false)).must_include(method_name)
    end
  end
  
  describe "when mocking" do
    let(:connection) { connection_class.new(mock_options) }
    
    it "should execute show version command" do
      result = connection.run_command("show version")
      _(result.exit_status).must_equal(0)
      _(result.stdout).must_match(/Junos:/)
    end
    
    it "should execute show chassis hardware command" do
      result = connection.run_command("show chassis hardware")
      _(result.exit_status).must_equal(0)
      _(result.stdout).must_match(/Hardware inventory:/)
    end
    
    it "should handle unknown commands" do
      result = connection.run_command("invalid command")
      _(result.exit_status).must_equal(1)
      _(result.stdout).must_match(/Unknown command/)
    end
  end
  
  describe "proxy connection configuration" do
    let(:bastion_options) do
      mock_options.merge({
        bastion_host: "jump.example.com",
        bastion_user: "netadmin",
        bastion_port: 2222
      })
    end
    
    let(:proxy_command_options) do
      mock_options.merge({
        proxy_command: "ssh jump.host -W %h:%p"
      })
    end
    
    it "should accept bastion host configuration" do
      connection = connection_class.new(bastion_options)
      options = connection.instance_variable_get(:@options)
      _(options[:bastion_host]).must_equal("jump.example.com")
      _(options[:bastion_user]).must_equal("netadmin")
      _(options[:bastion_port]).must_equal(2222)
    end
    
    it "should accept proxy command configuration" do
      connection = connection_class.new(proxy_command_options)
      options = connection.instance_variable_get(:@options)
      _(options[:proxy_command]).must_equal("ssh jump.host -W %h:%p")
    end
    
    it "should generate correct bastion proxy command" do
      connection = connection_class.new(bastion_options)
      proxy_command = connection.send(:generate_bastion_proxy_command)
      
      _(proxy_command).must_match(/ssh/)
      _(proxy_command).must_match(/netadmin@jump.example.com/)
      _(proxy_command).must_match(/-p 2222/)
      _(proxy_command).must_match(/-W %h:%p/)
    end
    
    it "should reject both bastion_host and proxy_command" do
      invalid_options = mock_options.merge({
        bastion_host: "jump.host",
        proxy_command: "ssh proxy -W %h:%p"
      })
      
      _(-> { connection_class.new(invalid_options) }).must_raise(Train::ClientError)
    end
  end
  
  describe "environment variable support" do
    before do
      # Clean environment before each test
      %w[JUNIPER_HOST JUNIPER_USER JUNIPER_PASSWORD JUNIPER_PORT
         JUNIPER_BASTION_HOST JUNIPER_BASTION_USER JUNIPER_BASTION_PORT
         JUNIPER_PROXY_COMMAND].each { |var| ENV.delete(var) }
    end
    
    after do
      # Clean environment after each test
      %w[JUNIPER_HOST JUNIPER_USER JUNIPER_PASSWORD JUNIPER_PORT
         JUNIPER_BASTION_HOST JUNIPER_BASTION_USER JUNIPER_BASTION_PORT
         JUNIPER_PROXY_COMMAND].each { |var| ENV.delete(var) }
    end
    
    it "should use environment variables for basic connection" do
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
    
    it "should use environment variables for proxy configuration" do
      ENV['JUNIPER_BASTION_HOST'] = 'env.jump.host'
      ENV['JUNIPER_BASTION_USER'] = 'envjump'
      ENV['JUNIPER_BASTION_PORT'] = '2222'
      
      connection = connection_class.new(mock_options)
      options = connection.instance_variable_get(:@options)
      
      _(options[:bastion_host]).must_equal('env.jump.host')
      _(options[:bastion_user]).must_equal('envjump')
      _(options[:bastion_port]).must_equal(2222)
    end
    
    it "should prioritize explicit options over environment variables" do
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
  
  describe "file operations" do
    let(:connection) { connection_class.new(mock_options) }
    
    it "should handle configuration file paths" do
      file = connection.file('/config/interfaces')
      _(file).must_be_instance_of(TrainPlugins::Juniper::JuniperFile)
    end
    
    it "should handle operational file paths" do
      file = connection.file('/operational/interfaces')
      _(file).must_be_instance_of(TrainPlugins::Juniper::JuniperFile)
    end
  end
  
  describe "file transfer operations" do
    let(:connection) { connection_class.new(mock_options) }
    
    it "should raise NotImplementedError for upload" do
      _(-> { connection.upload('local_file.txt', '/remote/path') }).must_raise(NotImplementedError)
    end
    
    it "should raise NotImplementedError for download" do
      _(-> { connection.download(['/remote/file.txt'], '/local/path') }).must_raise(NotImplementedError)
    end
    
    it "should provide helpful error message for upload" do
      error = _(-> { connection.upload('test.txt', '/config/test.txt') }).must_raise(NotImplementedError)
      _(error.message).must_match(/does not implement #upload/)
      _(error.message).must_match(/network devices use command-based configuration/)
    end
    
    it "should provide helpful error message for download" do
      error = _(-> { connection.download(['/config/test.txt'], '.') }).must_raise(NotImplementedError)
      _(error.message).must_match(/does not implement #download/)
      _(error.message).must_match(/use run_command.*to retrieve configuration data/)
    end
    
    it "should handle upload with array of local files" do
      _(-> { connection.upload(['file1.txt', 'file2.txt'], '/remote/') }).must_raise(NotImplementedError)
    end
    
    it "should handle download with array of remote files" do
      _(-> { connection.download(['/file1.txt', '/file2.txt'], '/local/') }).must_raise(NotImplementedError)
    end
  end
end
