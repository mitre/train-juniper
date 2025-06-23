# frozen_string_literal: true

# Mock responses for Juniper device commands
# This module contains all mock data used in testing and mock mode
module TrainPlugins
  module Juniper
    # Mock responses for common JunOS commands
    # Used when running in mock mode for testing without real devices
    module MockResponses
      # Configuration of mock responses
      # Maps command patterns to response methods or strings
      RESPONSES = {
        'show version' => :mock_show_version_output,
        'show chassis hardware' => :mock_chassis_output,
        'show configuration' => "interfaces {\n    ge-0/0/0 {\n        unit 0;\n    }\n}",
        'show route' => "inet.0: 5 destinations, 5 routes\n0.0.0.0/0       *[Static/5] 00:00:01\n",
        'show system information' => "Hardware: SRX240H2\nOS: JUNOS 12.1X47-D15.4\n",
        'show interfaces' => "Physical interface: ge-0/0/0, Enabled, Physical link is Up\n"
      }.freeze

      # Mock JunOS version output for testing
      # @return [String] mock output for 'show version' command
      def self.mock_show_version_output
        <<~OUTPUT
          Hostname: lab-srx
          Model: SRX240H2
          Junos: 12.1X47-D15.4
          JUNOS Software Release [12.1X47-D15.4]
        OUTPUT
      end

      # Mock chassis hardware output
      # @return [String] mock output for 'show chassis hardware' command
      def self.mock_chassis_output
        <<~OUTPUT
          Hardware inventory:
          Item             Version  Part number  Serial number     Description
          Chassis                                JN123456          SRX240H2
        OUTPUT
      end

      # Get mock response for a command
      # @param cmd [String] the command to get response for
      # @return [Array<String, Integer>] tuple of [output, exit_status]
      def self.response_for(cmd)
        response = RESPONSES.find { |pattern, _| cmd.match?(/#{pattern}/) }

        if response
          output = response[1].is_a?(Symbol) ? send(response[1]) : response[1]
          [output, 0]
        else
          ["% Unknown command: #{cmd}", 1]
        end
      end
    end
  end
end
