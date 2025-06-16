# Integration tests for SSH connection functionality
# These tests exercise the real SSH connection logic without requiring hardware

require_relative "../helper"

describe "SSH Connection Integration" do
  let(:connection_options) do
    {
      host: "mock-device.example.com",
      user: "testuser", 
      password: "testpass",
      port: 22,
      timeout: 5,
      mock: true  # Use mock mode for most tests
    }
  end

  let(:connection) { TrainPlugins::Juniper::Connection.new(connection_options) }

  describe "SSH connection establishment" do
    it "should validate connection state correctly" do
      # Test connection state checking - stays in mock mode
      _(connection.send(:connected?)).must_equal(false)
      
      # Mock an SSH session to test connected? method
      mock_ssh = Object.new
      connection.instance_variable_set(:@ssh_session, mock_ssh)
      _(connection.send(:connected?)).must_equal(true)
    end

    it "should validate proxy options during initialization" do
      invalid_options = connection_options.merge({
        bastion_host: "bastion.example.com",
        proxy_command: "ssh -W %h:%p proxy.example.com"
      })
      
      _(proc { 
        TrainPlugins::Juniper::Connection.new(invalid_options)
      }).must_raise(Train::ClientError)
    end

    it "should pass bastion options to Train SSH transport" do
      bastion_options = connection_options.merge({
        bastion_host: "bastion.example.com",
        bastion_user: "bastionuser",
        bastion_port: 2222,
        key_files: ["/path/to/key.pem"]
      })
      
      test_connection = TrainPlugins::Juniper::Connection.new(bastion_options)
      options = test_connection.instance_variable_get(:@options)
      
      # Verify Train SSH transport receives correct bastion options
      _(options[:bastion_host]).must_equal("bastion.example.com")
      _(options[:bastion_user]).must_equal("bastionuser")
      _(options[:bastion_port]).must_equal(2222)
      _(options[:key_files]).must_equal(["/path/to/key.pem"])
    end

    it "should pass proxy command to Train SSH transport" do
      proxy_options = connection_options.merge({
        proxy_command: "ssh -W %h:%p custom-proxy.example.com"
      })
      
      test_connection = TrainPlugins::Juniper::Connection.new(proxy_options)
      options = test_connection.instance_variable_get(:@options)
      
      # Verify Train SSH transport receives correct proxy command
      _(options[:proxy_command]).must_equal("ssh -W %h:%p custom-proxy.example.com")
    end
  end

  describe "command execution" do
    it "should use mock results in mock mode" do
      # Test that mock mode works correctly
      result = connection.run_command_via_connection("show version")
      _(result.stdout).must_include("SRX240H2")
      _(result.exit_status).must_equal(0)
    end

    it "should handle SSH command execution errors gracefully" do
      # Create a failing SSH connection mock in mock mode
      failing_ssh = Class.new do
        def run_command(cmd)
          raise Net::SSH::Exception, "SSH connection lost"
        end
      end.new
      
      connection.instance_variable_set(:@ssh_connection, failing_ssh)
      
      # In mock mode, this should still return mock results
      result = connection.run_command_via_connection("show version")
      _(result.stdout).must_include("SRX240H2")  # Mock response
    end
  end

  describe "session configuration" do
    it "should configure JunOS session when connected" do
      # Mock successful SSH connection
      commands_executed = []
      mock_ssh = Class.new do
        def initialize(commands_array)
          @commands = commands_array
        end
        
        def exec!(cmd)
          @commands << cmd
          "mock output for: #{cmd}"
        end
      end.new(commands_executed)
      
      connection.instance_variable_set(:@ssh_session, mock_ssh)
      
      # This will exercise the test_and_configure_session method
      connection.send(:test_and_configure_session)
      
      _(commands_executed).must_include('echo "connection test"')
      _(commands_executed).must_include('set cli screen-length 0')
      _(commands_executed).must_include('set cli screen-width 0')
    end

    it "should handle session configuration failures gracefully" do
      # Mock SSH that fails on configuration commands
      failing_ssh = Class.new do
        def exec!(cmd)
          if cmd.include?("echo")
            "connection test"
          else
            raise "Configuration failed"
          end
        end
      end.new
      
      connection.instance_variable_set(:@ssh_session, failing_ssh)
      
      # Should not raise an exception, just log a warning
      _(proc { connection.send(:test_and_configure_session) }).must_be_silent
    end
  end

  describe "error pattern detection" do
    it "should detect JunOS error patterns correctly" do
      error_outputs = [
        "error: syntax error",
        "SYNTAX ERROR: invalid command",
        "unknown command: invalid",
        "missing argument for command"
      ]
      
      error_outputs.each do |output|
        _(connection.send(:junos_error?, output)).must_equal(true)
      end
    end

    it "should not flag valid output as errors" do
      valid_outputs = [
        "Hostname: device01",
        "Model: SRX240H2",
        "Junos: 12.1X47-D15.4",
        "show version output here"
      ]
      
      valid_outputs.each do |output|
        _(connection.send(:junos_error?, output)).must_equal(false)
      end
    end

    it "should format JunOS results correctly for errors" do
      error_output = "error: syntax error in command"
      result = connection.send(:format_junos_result, error_output, "show config")
      
      _(result.stdout).must_equal("")
      _(result.stderr).must_equal(error_output)
      _(result.exit_status).must_equal(1)
    end

    it "should format JunOS results correctly for success" do
      success_output = "show version\nHostname: device\nModel: SRX240\nshow version\n> "
      result = connection.send(:format_junos_result, success_output, "show version")
      
      _(result.stdout).must_equal("Hostname: device\nModel: SRX240")
      _(result.stderr).must_equal("")
      _(result.exit_status).must_equal(0)
    end
  end
end