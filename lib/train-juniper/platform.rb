# Platform definition file for Juniper network devices.
# This defines the "juniper" platform within Train's platform detection system.

module TrainPlugins::Juniper
  # Platform detection mixin for Juniper network devices
  module Platform
    # Platform name constant for consistency
    PLATFORM_NAME = "juniper".freeze
    
    # Platform detection for Juniper network devices
    # 
    # For dedicated transport plugins, we use force_platform! to bypass
    # Train's automatic platform detection, which might run commands before
    # the connection is ready. This is the standard pattern used by official
    # Train plugins like train-k8s-container.
    def platform
      # Register the juniper platform in Train's platform registry
      # This defines juniper as a network device platform
      Train::Platforms.name(PLATFORM_NAME).title("Juniper JunOS").in_family("network")
      
      # Bypass Train's platform detection and declare our known platform
      # This prevents Train from running detection commands before connection is ready
      force_platform!(PLATFORM_NAME, {
        release: detect_junos_version || TrainPlugins::Juniper::VERSION,
        arch: "network"
      })
    end
    
    private
    
    # Detect JunOS version from device output
    # This runs safely after the connection is established
    def detect_junos_version
      # Only try version detection if we have an active connection
      return nil unless respond_to?(:run_command_via_connection)
      return nil if @options&.dig(:mock) # Skip in mock mode
      
      begin
        # Check if connection is ready before running commands
        return nil unless connected?
        
        # Execute 'show version' command to get JunOS information
        result = run_command_via_connection("show version")
        return nil unless result&.exit_status == 0
        
        # Parse JunOS version from output using multiple patterns
        version = extract_version_from_output(result.stdout)
        
        if version
          logger&.debug("Detected JunOS version: #{version}")
          version
        else
          logger&.debug("Could not parse JunOS version from: #{result.stdout[0..100]}")
          nil
        end
      rescue => e
        # If version detection fails, log and return nil
        logger&.debug("JunOS version detection failed: #{e.message}")
        nil
      end
    end
    
    # Extract version string from JunOS show version output
    def extract_version_from_output(output)
      return nil if output.nil? || output.empty?
      
      # Try multiple JunOS version patterns
      patterns = [
        /Junos:\s+([\d\w\.-]+)/,                           # "Junos: 12.1X47-D15.4"
        /JUNOS Software Release \[([\d\w\.-]+)\]/,         # "JUNOS Software Release [12.1X47-D15.4]"
        /junos version ([\d\w\.-]+)/i,                     # "junos version 21.4R3"
        /Model: \S+, JUNOS Base OS boot \[([\d\w\.-]+)\]/, # Some hardware variants
        /([\d]+\.[\d]+[\w\.-]*)/                           # Generic version pattern
      ]
      
      patterns.each do |pattern|
        match = output.match(pattern)
        return match[1] if match
      end
      
      nil
    end
  end
end
