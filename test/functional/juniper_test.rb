# Functional tests for the Train Juniper Plugin.

# These tests verify end-to-end behavior of the Juniper transport plugin,
# including connection establishment, command execution, and platform detection.
# Tests use mock mode to avoid requiring actual Juniper hardware.

# Include our test harness
require_relative "../helper"

# Because InSpec is a Spec-style test suite, and Train has a close relationship
# to InSpec, we're going to use MiniTest::Spec here, for familiar look and
# feel. However, this isn't InSpec (or RSpec) code.
describe "train-juniper" do
  # Functional tests for the standalone train-juniper plugin

  # Test scenarios for Juniper plugin:
  # * Plugin registration and instantiation
  # * SSH connection establishment (mocked)
  # * Command execution with JunOS CLI
  # * Platform detection and version parsing
  # * File operations for configuration access

  describe "creating a train instance with this transport" do
    it "should not explode on create" do
      # Verify plugin can be instantiated without errors
      Train.create("juniper")
      _(proc { Train.create("juniper") }).must_be_silent
    end

    it "should not explode on connect with mock mode" do
      # Test connection with mock options to avoid needing real hardware
      options = { mock: true, host: "test-router", user: "admin", password: "secret" }
      transport = Train.create("juniper", options)
      transport.connection
      _(proc { transport.connection }).must_be_silent
    end
  end

  describe "reading configuration files" do
    it "should support configuration section access" do
      options = { mock: true, host: "test-router", user: "admin", password: "secret" }
      conn = Train.create("juniper", options).connection
      
      # Test accessing configuration via file-like interface
      file_obj = conn.file("/config/interfaces")
      _(file_obj.exist?).must_equal(true)
    end
  end

  describe "running commands" do
    let(:options) { { mock: true, host: "test-router", user: "admin", password: "secret" } }
    let(:conn) { Train.create("juniper", options).connection }
    
    it "should execute show version successfully" do
      result = conn.run_command("show version")
      _(result.exit_status).must_equal(0)
      _(result.stdout).must_match(/Junos:/)
      _(result.stdout).must_match(/SRX240H2/)
    end
    
    it "should execute show chassis hardware successfully" do
      result = conn.run_command("show chassis hardware")
      _(result.exit_status).must_equal(0)
      _(result.stdout).must_match(/Hardware inventory:/)
    end
    
    it "should handle invalid commands gracefully" do
      result = conn.run_command("invalid command")
      _(result.exit_status).must_equal(1)
      _(result.stdout).must_match(/Unknown command/)
    end
  end
end
