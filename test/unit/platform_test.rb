# Test platform detection functionality

require_relative "../helper"

describe TrainPlugins::Juniper::Platform do
  let(:connection) do
    # Create a test double that responds to run_command
    Class.new do
      include TrainPlugins::Juniper::Platform
      
      def initialize(mock_output = nil)
        @mock_output = mock_output
        @options = { mock: false }
        @logger = Logger.new(StringIO.new)
      end
      
      def run_command_via_connection(cmd)
        if @mock_output
          MockResult.new(@mock_output, 0)
        else
          MockResult.new("", 1, "Command failed")
        end
      end
      
      def connected?
        !@mock_output.nil?
      end
      
      def logger
        @logger
      end
    end
  end
  
  # Mock result class for testing
  class MockResult
    attr_reader :stdout, :exit_status, :stderr
    
    def initialize(stdout, exit_status = 0, stderr = "")
      @stdout = stdout
      @exit_status = exit_status
      @stderr = stderr
    end
  end
  
  describe "version detection" do
    it "should detect standard JunOS version format" do
      version_output = <<~OUTPUT
        Hostname: lab-srx
        Model: SRX240H2
        Junos: 12.1X47-D15.4
        JUNOS Software Release [12.1X47-D15.4]
      OUTPUT
      
      test_connection = connection.new(version_output)
      version = test_connection.send(:detect_junos_version)
      _(version).must_equal("12.1X47-D15.4")
    end
    
    it "should detect JUNOS Software Release format" do
      version_output = <<~OUTPUT
        JUNOS Software Release [21.4R3.15]
        Model: srx300
        Package: [21.4R3.15]
      OUTPUT
      
      test_connection = connection.new(version_output)
      version = test_connection.send(:detect_junos_version)
      _(version).must_equal("21.4R3.15")
    end
    
    it "should detect simple Junos version format" do
      version_output = <<~OUTPUT
        Hostname: firewall01
        Model: SRX1500
        Junos: 23.4R1.9
        Base OS boot [23.4R1.9]
      OUTPUT
      
      test_connection = connection.new(version_output)
      version = test_connection.send(:detect_junos_version)
      _(version).must_equal("23.4R1.9")
    end
    
    it "should handle version detection failure gracefully" do
      test_connection = connection.new("No version information")
      version = test_connection.send(:detect_junos_version)
      _(version).must_be_nil
    end
    
    it "should handle command execution failure" do
      test_connection = connection.new(nil) # Will return failed command
      version = test_connection.send(:detect_junos_version)
      _(version).must_be_nil
    end
    
    it "should extract version from complex output" do
      complex_output = <<~OUTPUT
        Hostname: core-router
        Model: MX960
        Junos: 20.4R3.8
        JUNOS Base OS boot [20.4R3.8]
        JUNOS Base OS Software Suite [20.4R3.8]
        JUNOS Kernel Software Suite [20.4R3.8]
        JUNOS Crypto Software Suite [20.4R3.8]
        JUNOS Packet Forwarding Engine Support (MX Common) [20.4R3.8]
        JUNOS Packet Forwarding Engine Support (M/T Common) [20.4R3.8]
        JUNOS Online Documentation [20.4R3.8]
        JUNOS Routing Software Suite [20.4R3.8]
      OUTPUT
      
      test_connection = connection.new(complex_output)
      version = test_connection.send(:detect_junos_version)
      _(version).must_equal("20.4R3.8")
    end
  end
  
  describe "version extraction patterns" do
    let(:mock_connection) { connection.new("") }
    
    it "should extract version from JUNOS Software Release pattern" do
      output = "JUNOS Software Release [19.1R1.6]"
      version = mock_connection.send(:extract_version_from_output, output)
      _(version).must_equal("19.1R1.6")
    end
    
    it "should extract version from Junos: pattern" do
      output = "Junos: 18.4R2.7"
      version = mock_connection.send(:extract_version_from_output, output)
      _(version).must_equal("18.4R2.7")
    end
    
    it "should extract version from general version pattern" do
      output = "Some text with version 22.3R1.1 embedded"
      version = mock_connection.send(:extract_version_from_output, output)
      _(version).must_equal("22.3R1.1")
    end
    
    it "should return nil when no version pattern matches" do
      output = "No version information here"
      version = mock_connection.send(:extract_version_from_output, output)
      _(version).must_be_nil
    end
    
    it "should handle empty output" do
      version = mock_connection.send(:extract_version_from_output, "")
      _(version).must_be_nil
    end
  end
end