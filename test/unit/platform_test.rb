# frozen_string_literal: true

# Test platform detection functionality

require_relative '../helper'

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

      def run_command_via_connection(_cmd)
        if @mock_output
          MockResult.new(@mock_output, 0)
        else
          MockResult.new('', 1, 'Command failed')
        end
      end

      def connected?
        !@mock_output.nil?
      end

      attr_reader :logger
    end
  end

  # Mock result class for testing
  class MockResult
    attr_reader :stdout, :exit_status, :stderr

    def initialize(stdout, exit_status = 0, stderr = '')
      @stdout = stdout
      @exit_status = exit_status
      @stderr = stderr
    end
  end

  describe 'version detection' do
    it 'should detect standard JunOS version format' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>lab-srx</host-name>
            <product-model>SRX240H2</product-model>
            <product-name>srx240h2</product-name>
            <junos-version>12.1X47-D15.4</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)
      version = test_connection.send(:detect_junos_version)
      _(version).must_equal('12.1X47-D15.4')
    end

    it 'should cache version detection results' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>lab-srx</host-name>
            <product-model>SRX240H2</product-model>
            <product-name>srx240h2</product-name>
            <junos-version>12.1X47-D15.4</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)

      # Mock run_command_via_connection to track call count
      call_count = 0
      test_connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        call_count += 1
        MockResult.new(version_output, 0)
      end

      # First call should execute command
      version1 = test_connection.send(:detect_junos_version)
      _(version1).must_equal('12.1X47-D15.4')
      _(call_count).must_equal(1)

      # Second call should use cached result
      version2 = test_connection.send(:detect_junos_version)
      _(version2).must_equal('12.1X47-D15.4')
      _(call_count).must_equal(1) # Should not increase
    end

    it 'should detect JUNOS Software Release format' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/21.4R3/junos">
          <software-information>
            <host-name>srx300</host-name>
            <product-model>srx300</product-model>
            <product-name>srx300</product-name>
            <junos-version>21.4R3.15</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)
      version = test_connection.send(:detect_junos_version)
      _(version).must_equal('21.4R3.15')
    end

    it 'should detect simple Junos version format' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/23.4R1/junos">
          <software-information>
            <host-name>firewall01</host-name>
            <product-model>SRX1500</product-model>
            <product-name>srx1500</product-name>
            <junos-version>23.4R1.9</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)
      version = test_connection.send(:detect_junos_version)
      _(version).must_equal('23.4R1.9')
    end

    it 'should handle version detection failure gracefully' do
      test_connection = connection.new('No version information')
      version = test_connection.send(:detect_junos_version)
      _(version).must_be_nil
    end

    it 'should handle command execution failure' do
      test_connection = connection.new(nil) # Will return failed command
      version = test_connection.send(:detect_junos_version)
      _(version).must_be_nil
    end

    it 'should extract version from complex output' do
      complex_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/20.4R3/junos">
          <software-information>
            <host-name>core-router</host-name>
            <product-model>MX960</product-model>
            <product-name>mx960</product-name>
            <junos-version>20.4R3.8</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(complex_output)
      version = test_connection.send(:detect_junos_version)
      _(version).must_equal('20.4R3.8')
    end
  end

  describe 'version extraction from XML' do
    let(:mock_connection) { connection.new('') }

    it 'should extract version from XML output' do
      output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>lab-srx</host-name>
            <product-model>SRX240H2</product-model>
            <product-name>srx240h2</product-name>
            <junos-version>19.1R1.6</junos-version>
          </software-information>
        </rpc-reply>
      XML
      version = mock_connection.send(:extract_version_from_xml, output)
      _(version).must_equal('19.1R1.6')
    end

    it 'should handle empty XML output' do
      version = mock_connection.send(:extract_version_from_xml, '')
      _(version).must_be_nil
    end

    it 'should handle nil XML output' do
      version = mock_connection.send(:extract_version_from_xml, nil)
      _(version).must_be_nil
    end

    it 'should handle malformed XML gracefully' do
      output = '<invalid>xml<content'
      version = mock_connection.send(:extract_version_from_xml, output)
      _(version).must_be_nil
    end
  end

  describe 'architecture detection' do
    it 'should detect SRX model as x86_64' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>lab-srx</host-name>
            <product-model>SRX240H2</product-model>
            <product-name>srx240h2</product-name>
            <junos-version>12.1X47-D15.4</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)
      arch = test_connection.send(:detect_junos_architecture)
      _(arch).must_equal('x86_64')
    end

    it 'should detect MX model as x86_64' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/20.4R3/junos">
          <software-information>
            <host-name>core-router</host-name>
            <product-model>MX960</product-model>
            <product-name>mx960</product-name>
            <junos-version>20.4R3.8</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)
      arch = test_connection.send(:detect_junos_architecture)
      _(arch).must_equal('x86_64')
    end

    it 'should detect EX model as arm64' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/18.4R2/junos">
          <software-information>
            <host-name>switch01</host-name>
            <product-model>EX4300-48T</product-model>
            <product-name>ex4300-48t</product-name>
            <junos-version>18.4R2.7</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)
      arch = test_connection.send(:detect_junos_architecture)
      _(arch).must_equal('arm64')
    end

    it 'should handle architecture detection failure gracefully' do
      test_connection = connection.new('No architecture information')
      arch = test_connection.send(:detect_junos_architecture)
      _(arch).must_be_nil
    end

    it 'should handle command execution failure for architecture' do
      test_connection = connection.new(nil) # Will return failed command
      arch = test_connection.send(:detect_junos_architecture)
      _(arch).must_be_nil
    end

    it 'should cache architecture detection results' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>lab-srx</host-name>
            <product-model>SRX240H2</product-model>
            <product-name>srx240h2</product-name>
            <junos-version>12.1X47-D15.4</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)

      # Mock run_command_via_connection to track call count
      call_count = 0
      test_connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        call_count += 1
        MockResult.new(version_output, 0)
      end

      # First call should execute command
      arch1 = test_connection.send(:detect_junos_architecture)
      _(arch1).must_equal('x86_64')
      _(call_count).must_equal(1)

      # Second call should use cached result
      arch2 = test_connection.send(:detect_junos_architecture)
      _(arch2).must_equal('x86_64')
      _(call_count).must_equal(1) # Should not increase
    end

    it 'should share cached result between version and architecture detection' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>lab-srx</host-name>
            <product-model>SRX240H2</product-model>
            <product-name>srx240h2</product-name>
            <junos-version>12.1X47-D15.4</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)

      # Mock run_command_via_connection to track call count
      call_count = 0
      test_connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        call_count += 1
        MockResult.new(version_output, 0)
      end

      # First call for version detection
      version = test_connection.send(:detect_junos_version)
      _(version).must_equal('12.1X47-D15.4')
      _(call_count).must_equal(1)

      # Architecture detection will make another call (different command)
      arch = test_connection.send(:detect_junos_architecture)
      _(arch).must_equal('x86_64')
      _(call_count).must_equal(2) # Different commands now

      # Subsequent calls should also use cache
      version2 = test_connection.send(:detect_junos_version)
      arch2 = test_connection.send(:detect_junos_architecture)
      _(version2).must_equal('12.1X47-D15.4')
      _(arch2).must_equal('x86_64')
      _(call_count).must_equal(2) # Still should not increase
    end
  end

  describe 'architecture extraction from XML' do
    let(:mock_connection) { connection.new('') }

    it 'should extract architecture from SRX model in XML' do
      output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>lab-srx</host-name>
            <product-model>SRX1500</product-model>
            <product-name>srx1500</product-name>
            <junos-version>19.1R1.6</junos-version>
          </software-information>
        </rpc-reply>
      XML
      arch = mock_connection.send(:extract_architecture_from_xml, output)
      _(arch).must_equal('x86_64')
    end

    it 'should extract architecture from QFX model in XML' do
      output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>switch01</host-name>
            <product-model>QFX5100-48S</product-model>
            <product-name>qfx5100-48s</product-name>
            <junos-version>18.4R2.7</junos-version>
          </software-information>
        </rpc-reply>
      XML
      arch = mock_connection.send(:extract_architecture_from_xml, output)
      _(arch).must_equal('x86_64')
    end

    it 'should extract architecture from EX model as arm64' do
      output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>switch02</host-name>
            <product-model>EX4300-48T</product-model>
            <product-name>ex4300-48t</product-name>
            <junos-version>18.4R2.7</junos-version>
          </software-information>
        </rpc-reply>
      XML
      arch = mock_connection.send(:extract_architecture_from_xml, output)
      _(arch).must_equal('arm64')
    end

    it 'should return nil when no model in XML' do
      output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>unknown</host-name>
          </software-information>
        </rpc-reply>
      XML
      arch = mock_connection.send(:extract_architecture_from_xml, output)
      _(arch).must_be_nil
    end

    it 'should handle empty XML output for architecture' do
      arch = mock_connection.send(:extract_architecture_from_xml, '')
      _(arch).must_be_nil
    end

    it 'should handle nil XML output for architecture' do
      arch = mock_connection.send(:extract_architecture_from_xml, nil)
      _(arch).must_be_nil
    end

    it 'should handle malformed XML for architecture' do
      output = '<invalid>xml'
      arch = mock_connection.send(:extract_architecture_from_xml, output)
      _(arch).must_be_nil
    end
  end

  describe 'platform method caching' do
    it 'should cache platform detection results across multiple calls' do
      version_output = <<~OUTPUT
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <software-information>
            <host-name>lab-srx</host-name>
            <product-model>SRX240H2</product-model>
            <product-name>srx240h2</product-name>
            <junos-version>12.1X47-D15.4</junos-version>
          </software-information>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(version_output)

      # Mock run_command_via_connection to track call count
      call_count = 0
      test_connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        call_count += 1
        MockResult.new(version_output, 0)
      end

      # Mock the platform registration and force_platform! methods
      test_connection.define_singleton_method(:platform) do
        # Call both detection methods (simulating platform method behavior)
        detect_junos_version
        detect_junos_architecture

        # Return mock platform object
        {
          name: 'juniper',
          release: '12.1X47-D15.4',
          arch: 'x86_64',
          families: %w[bsd unix os]
        }
      end

      # First platform call should execute commands
      platform1 = test_connection.platform
      _(platform1[:release]).must_equal('12.1X47-D15.4')
      _(platform1[:arch]).must_equal('x86_64')
      _(call_count).must_equal(2) # Two commands now (version and arch)

      # Second platform call should use cached results
      platform2 = test_connection.platform
      _(platform2[:release]).must_equal('12.1X47-D15.4')
      _(platform2[:arch]).must_equal('x86_64')
      _(call_count).must_equal(2) # Should not increase - cached

      # Third platform call should also use cache
      platform3 = test_connection.platform
      _(platform3[:release]).must_equal('12.1X47-D15.4')
      _(platform3[:arch]).must_equal('x86_64')
      _(call_count).must_equal(2) # Still should not increase
    end
  end

  describe 'serial number detection' do
    it 'should detect serial number from chassis hardware XML output' do
      hardware_output = <<~OUTPUT
        <rpc-reply>
          <chassis-inventory>
            <chassis>
              <name>Chassis</name>
              <serial-number>JN123456</serial-number>
              <description>SRX240H2</description>
            </chassis>
          </chassis-inventory>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(hardware_output)
      serial = test_connection.send(:detect_junos_serial)
      _(serial).must_equal('JN123456')
    end

    it 'should return nil when receiving non-XML output' do
      hardware_output = <<~OUTPUT
        Serial number: SRX240-12345
      OUTPUT

      test_connection = connection.new(hardware_output)
      serial = test_connection.send(:detect_junos_serial)
      _(serial).must_be_nil  # No XML parsing means no serial
    end

    it 'should return nil with malformed XML' do
      hardware_output = <<~OUTPUT
        <rpc-reply>
        <chassis-inventory>
        <chassis>
        <serial-number>ABC123DEF</serial-number>
        <!-- Missing closing tags to trigger XML error -->
      OUTPUT

      test_connection = connection.new(hardware_output)
      serial = test_connection.send(:detect_junos_serial)
      _(serial).must_be_nil  # Malformed XML returns nil
    end

    it 'should handle no serial number gracefully' do
      hardware_output = <<~OUTPUT
        No chassis information available
      OUTPUT

      test_connection = connection.new(hardware_output)
      serial = test_connection.send(:detect_junos_serial)
      _(serial).must_be_nil
    end

    it 'should handle command failure for serial detection' do
      test_connection = connection.new(nil) # Will return failed command
      serial = test_connection.send(:detect_junos_serial)
      _(serial).must_be_nil
    end

    it 'should cache serial detection results' do
      hardware_output = <<~OUTPUT
        <rpc-reply>
          <chassis-inventory>
            <chassis>
              <serial-number>JN123456</serial-number>
            </chassis>
          </chassis-inventory>
        </rpc-reply>
      OUTPUT

      test_connection = connection.new(hardware_output)

      # Mock run_command_via_connection to track call count
      call_count = 0
      test_connection.define_singleton_method(:run_command_via_connection) do |_cmd|
        call_count += 1
        MockResult.new(hardware_output, 0)
      end

      # First call should execute command
      serial1 = test_connection.send(:detect_junos_serial)
      _(serial1).must_equal('JN123456')
      _(call_count).must_equal(1)

      # Second call should use cached result
      serial2 = test_connection.send(:detect_junos_serial)
      _(serial2).must_equal('JN123456')
      _(call_count).must_equal(1) # Should not increase
    end
  end

  describe 'serial extraction patterns' do
    let(:mock_connection) { connection.new('') }

    it 'should extract serial from XML format' do
      output = <<~XML
        <rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">
          <chassis-inventory xmlns="http://xml.juniper.net/junos/12.1X47/junos-chassis">
            <chassis junos:style="inventory">
              <name>Chassis</name>
              <serial-number>JN123456</serial-number>
              <description>SRX240H2</description>
            </chassis>
          </chassis-inventory>
        </rpc-reply>
      XML
      serial = mock_connection.send(:extract_serial_from_xml, output)
      _(serial).must_equal('JN123456')
    end

    it 'should handle empty output in XML' do
      serial = mock_connection.send(:extract_serial_from_xml, '')
      _(serial).must_be_nil
    end

    it 'should handle nil output in XML' do
      serial = mock_connection.send(:extract_serial_from_xml, nil)
      _(serial).must_be_nil
    end

    it 'should return nil if XML parsing fails' do
      output = 'Invalid XML content'
      serial = mock_connection.send(:extract_serial_from_xml, output)
      _(serial).must_be_nil
    end
  end
end
