# Test error handling and edge cases

require_relative "../helper"

describe "Error Handling and Edge Cases" do
  let(:mock_options) { { host: "test.device", user: "admin", mock: true } }
  let(:connection_class) { TrainPlugins::Juniper::Connection }
  
  describe "command result processing" do
    let(:connection) { connection_class.new(mock_options) }
    
    it "should detect JunOS error patterns" do
      # Test each error pattern defined in JUNOS_ERROR_PATTERNS
      error_outputs = [
        "error: configuration database locked",
        "syntax error: unexpected token",
        "invalid command: unknown option",
        "unknown command: not found",
        "missing argument: required parameter not provided"
      ]
      
      error_outputs.each do |error_output|
        is_error = connection.send(:junos_error?, error_output)
        _(is_error).must_equal(true, "Should detect error in: #{error_output}")
      end
    end
    
    it "should not flag normal output as errors" do
      normal_outputs = [
        "Hostname: lab-device",
        "Interface: ge-0/0/0",
        "Status: Up",
        "Configuration loaded successfully",
        "Connection established"
      ]
      
      normal_outputs.each do |normal_output|
        is_error = connection.send(:junos_error?, normal_output)
        _(is_error).must_equal(false, "Should not detect error in: #{normal_output}")
      end
    end
    
    it "should clean command output correctly" do
      raw_output = "show version\nHostname: device\nshow version\n> "
      command = "show version"
      
      cleaned = connection.send(:clean_output, raw_output, command)
      _(cleaned).must_equal("Hostname: device")
    end
    
    it "should handle empty command output" do
      cleaned = connection.send(:clean_output, "", "show version")
      _(cleaned).must_equal("")
    end
  end
  
  describe "connection validation" do
    it "should validate proxy options correctly" do
      # Test that both bastion_host and proxy_command cannot be specified
      invalid_options = {
        host: "device.com",
        user: "admin", 
        bastion_host: "jump.host",
        proxy_command: "ssh proxy -W %h:%p",
        mock: true
      }
      
      _(-> { connection_class.new(invalid_options) }).must_raise(Train::ClientError)
    end
    
    it "should allow bastion_host without proxy_command" do
      valid_options = {
        host: "device.com",
        user: "admin",
        bastion_host: "jump.host",
        mock: true
      }
      
      connection = connection_class.new(valid_options)
      _(connection).must_be_instance_of(connection_class)
    end
    
    it "should allow proxy_command without bastion_host" do
      valid_options = {
        host: "device.com", 
        user: "admin",
        proxy_command: "ssh proxy -W %h:%p",
        mock: true
      }
      
      connection = connection_class.new(valid_options)
      _(connection).must_be_instance_of(connection_class)
    end
  end
  
  describe "mock mode command execution" do
    let(:connection) { connection_class.new(mock_options) }
    
    it "should return appropriate mock results for known commands" do
      result = connection.run_command("show version")
      _(result.exit_status).must_equal(0)
      _(result.stdout).must_match(/Hostname: lab-srx/)
      _(result.stdout).must_match(/Model: SRX240H2/)
      _(result.stdout).must_match(/Junos: 12.1X47-D15.4/)
    end
    
    it "should return error result for unknown commands" do
      result = connection.run_command("invalid command")
      _(result.exit_status).must_equal(1)
      _(result.stdout).must_match(/% Unknown command/)
    end
    
    it "should handle show chassis hardware command" do
      result = connection.run_command("show chassis hardware")
      _(result.exit_status).must_equal(0)
      _(result.stdout).must_match(/Hardware inventory/)
      _(result.stdout).must_match(/SRX240H2/)
    end
  end
  
  describe "JuniperFile operations" do
    let(:connection) { connection_class.new(mock_options) }
    
    it "should handle configuration file paths" do
      file = connection.file("/config/interfaces")
      _(file).must_be_instance_of(TrainPlugins::Juniper::JuniperFile)
      _(file.exist?).must_equal(true)
    end
    
    it "should handle operational file paths" do
      file = connection.file("/operational/interfaces")
      _(file).must_be_instance_of(TrainPlugins::Juniper::JuniperFile)
      _(file.exist?).must_equal(true)
    end
    
    it "should handle generic show commands" do
      file = connection.file("version")
      content = file.content
      _(content).must_match(/Hostname: lab-srx/)
    end
    
    it "should handle file existence checking" do
      file = connection.file("/config/test")
      # Should not raise an error and return boolean
      exists = file.exist?
      _(exists).must_be_kind_of(TrueClass, FalseClass)
    end
  end
  
  describe "CommandResult class" do
    it "should create result with all parameters" do
      result = Train::Extras::CommandResult.new("output", "error", 0)
      _(result.stdout).must_equal("output")
      _(result.exit_status).must_equal(0)
      _(result.stderr).must_equal("error")
    end
    
    it "should handle string conversion" do
      result = Train::Extras::CommandResult.new("123", "", 0)
      _(result.stdout).must_equal("123")
      _(result.exit_status).must_equal(0)
      _(result.stderr).must_equal("")
    end
    
    it "should provide default values" do
      result = Train::Extras::CommandResult.new("output", "", 1)
      _(result.stderr).must_equal("")
    end
  end
end