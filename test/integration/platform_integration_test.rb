# Integration tests for platform detection functionality
# Tests the actual platform registration and detection logic

require_relative "../helper"

describe "Platform Detection Integration" do
  let(:connection_options) do
    {
      host: "test.example.com",
      user: "testuser",
      password: "testpass",
      mock: true  # Use mock mode to avoid real connections
    }
  end

  describe "platform registration" do
    it "should register juniper platform in Train registry" do
      connection = TrainPlugins::Juniper::Connection.new(connection_options)
      
      # Access the platform method to trigger registration
      platform_obj = connection.platform
      
      # Verify platform is registered
      _(platform_obj).wont_be_nil
      _(platform_obj.name).must_equal("juniper")
      _(platform_obj.title).must_equal("Juniper JunOS")
      _(platform_obj.family).must_equal("bsd")
    end

    it "should force platform without detection when connection not ready" do
      connection = TrainPlugins::Juniper::Connection.new(connection_options)
      
      # Mock no connection
      connection.instance_variable_set(:@ssh_connection, nil)
      
      platform_obj = connection.platform
      
      # Should use plugin version as fallback
      _(platform_obj.release).must_equal(TrainPlugins::Juniper::VERSION)
      # Arch is not set since we removed it to fix family detection
    end

    it "should use plugin version as fallback when version detection fails" do
      # In mock mode, version detection is skipped
      connection = TrainPlugins::Juniper::Connection.new(connection_options)
      
      platform_obj = connection.platform
      
      # Should use plugin version as fallback
      _(platform_obj.release).must_equal(TrainPlugins::Juniper::VERSION)
    end
  end

  describe "version detection error handling" do
    it "should handle connection failure during version detection" do
      connection = TrainPlugins::Juniper::Connection.new(connection_options)
      
      # Mock failed command execution
      mock_ssh = Class.new do
        def run_command(cmd)
          Train::Extras::CommandResult.new("", "Connection failed", 1)
        end
      end.new
      
      connection.instance_variable_set(:@ssh_connection, mock_ssh)
      def connection.connected?; true; end
      
      version = connection.send(:detect_junos_version)
      _(version).must_be_nil
    end

    it "should handle malformed version output gracefully" do
      connection = TrainPlugins::Juniper::Connection.new(connection_options)
      
      # Mock command with invalid output
      mock_ssh = Class.new do
        def run_command(cmd)
          Train::Extras::CommandResult.new("No version info here", "", 0)
        end
      end.new
      
      connection.instance_variable_set(:@ssh_connection, mock_ssh)
      def connection.connected?; true; end
      
      version = connection.send(:detect_junos_version)
      _(version).must_be_nil
    end

    it "should handle exceptions during version detection" do
      connection = TrainPlugins::Juniper::Connection.new(connection_options)
      
      # Mock command that raises exception
      mock_ssh = Class.new do
        def run_command(cmd)
          raise StandardError, "Network timeout"
        end
      end.new
      
      connection.instance_variable_set(:@ssh_connection, mock_ssh)
      def connection.connected?; true; end
      
      version = connection.send(:detect_junos_version)
      _(version).must_be_nil
    end

    it "should skip version detection in mock mode" do
      mock_options = connection_options.merge(mock: true)
      connection = TrainPlugins::Juniper::Connection.new(mock_options)
      
      version = connection.send(:detect_junos_version)
      _(version).must_be_nil
    end

    it "should skip version detection when not connected" do
      connection = TrainPlugins::Juniper::Connection.new(connection_options)
      
      # Ensure not connected
      connection.instance_variable_set(:@ssh_connection, nil)
      
      version = connection.send(:detect_junos_version)
      _(version).must_be_nil
    end
  end

  describe "version extraction edge cases" do
    let(:connection) { TrainPlugins::Juniper::Connection.new(connection_options) }
    
    it "should handle nil output gracefully" do
      version = connection.send(:extract_version_from_output, nil)
      _(version).must_be_nil
    end

    it "should handle empty output gracefully" do
      version = connection.send(:extract_version_from_output, "")
      _(version).must_be_nil
    end

    it "should extract version from mixed case output" do
      output = "JUNOS software release [21.4R3.15]"
      version = connection.send(:extract_version_from_output, output)
      _(version).must_equal("21.4R3.15")
    end

    it "should prefer specific patterns over generic ones" do
      output = "Some text 1.0.0 Junos: 20.4R1.12 and more 2.0.0"
      version = connection.send(:extract_version_from_output, output)
      _(version).must_equal("20.4R1.12")
    end

    it "should handle complex multi-line version output" do
      complex_output = <<~OUTPUT
        Hostname: test-device
        Model: MX960
        Junos: 19.4R3.11
        JUNOS Base OS boot [19.4R3.11]
        JUNOS Base OS Software Suite [19.4R3.11]
        JUNOS Kernel Software Suite [19.4R3.11]
      OUTPUT
      
      version = connection.send(:extract_version_from_output, complex_output)
      _(version).must_equal("19.4R3.11")
    end
  end
end