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
      # Return cached platform if already computed
      return @cached_platform_obj if defined?(@cached_platform_obj)
      
      # Register the juniper platform in Train's platform registry
      # JunOS devices are FreeBSD-based, so inherit from bsd family for InSpec resource compatibility
      # This allows InSpec resources like 'command' to work with Juniper devices
      Train::Platforms.name(PLATFORM_NAME).title("Juniper JunOS").in_family("bsd")
      
      # Try to detect actual JunOS version and architecture from device
      device_version = detect_junos_version || TrainPlugins::Juniper::VERSION
      device_arch = detect_junos_architecture || "unknown"
      logger&.debug("Detected device architecture: #{device_arch}")
      
      # Bypass Train's platform detection and declare our known platform
      # Include architecture in the platform details to ensure it's properly set
      platform_details = {
        release: device_version,
        arch: device_arch
      }
      
      platform_obj = force_platform!(PLATFORM_NAME, platform_details)
      logger&.debug("Set platform data: #{platform_obj.platform}")
      
      # Cache the platform object to prevent repeated calls
      @cached_platform_obj = platform_obj
    end
    
    private
    
    # Detect JunOS version from device output
    # This runs safely after the connection is established
    def detect_junos_version
      # Return cached version if already detected
      return @detected_junos_version if defined?(@detected_junos_version)
      
      # Only try version detection if we have an active connection
      return @detected_junos_version = nil unless respond_to?(:run_command_via_connection)
      return @detected_junos_version = nil if @options&.dig(:mock) # Skip in mock mode
      
      begin
        # Check if connection is ready before running commands
        return @detected_junos_version = nil unless connected?
        
        # Execute 'show version' command to get JunOS information
        result = run_command_via_connection("show version")
        return @detected_junos_version = nil unless result&.exit_status == 0
        
        # Cache the result for architecture detection to avoid duplicate calls
        @cached_show_version_result = result
        
        # Parse JunOS version from output using multiple patterns
        version = extract_version_from_output(result.stdout)
        
        if version
          logger&.debug("Detected JunOS version: #{version}")
          @detected_junos_version = version
        else
          logger&.debug("Could not parse JunOS version from: #{result.stdout[0..100]}")
          @detected_junos_version = nil
        end
      rescue => e
        # If version detection fails, log and return nil
        logger&.debug("JunOS version detection failed: #{e.message}")
        @detected_junos_version = nil
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
    
    # Detect JunOS architecture from device output
    # This runs safely after the connection is established
    def detect_junos_architecture
      # Return cached architecture if already detected
      return @detected_junos_architecture if defined?(@detected_junos_architecture)
      
      # Only try architecture detection if we have an active connection
      return @detected_junos_architecture = nil unless respond_to?(:run_command_via_connection)
      return @detected_junos_architecture = nil if @options&.dig(:mock) # Skip in mock mode
      
      begin
        # Check if connection is ready before running commands
        return @detected_junos_architecture = nil unless connected?
        
        # Reuse version detection result to avoid duplicate 'show version' calls
        # Both version and architecture come from the same command output
        if defined?(@detected_junos_version) && @detected_junos_version
          # We already have the output from version detection, parse architecture from it
          result = @cached_show_version_result
        else
          # Execute 'show version' command and cache the result
          result = run_command_via_connection("show version")
          @cached_show_version_result = result if result&.exit_status == 0
        end
        
        return @detected_junos_architecture = nil unless result&.exit_status == 0
        
        # Parse architecture from output using multiple patterns
        arch = extract_architecture_from_output(result.stdout)
        
        if arch
          logger&.debug("Detected JunOS architecture: #{arch}")
          @detected_junos_architecture = arch
        else
          logger&.debug("Could not parse JunOS architecture from: #{result.stdout[0..100]}")
          @detected_junos_architecture = nil
        end
      rescue => e
        # If architecture detection fails, log and return nil
        logger&.debug("JunOS architecture detection failed: #{e.message}")
        @detected_junos_architecture = nil
      end
    end
    
    # Extract architecture string from JunOS show version output
    def extract_architecture_from_output(output)
      return nil if output.nil? || output.empty?
      
      # Try multiple JunOS architecture patterns
      patterns = [
        /Model:\s+(\S+)/,                                      # "Model: SRX240H2" -> extract model as arch indicator
        /Junos:\s+[\d\w\.-]+\s+built\s+[\d-]+\s+[\d:]+\s+by\s+builder\s+on\s+(\S+)/,  # Build architecture
        /JUNOS.*\[([\w-]+)\]/,                                 # JUNOS package architecture
        /Architecture:\s+(\S+)/i,                              # Direct architecture line
        /Platform:\s+(\S+)/i,                                  # Platform designation
        /Processor.*:\s*(\S+)/i,                              # Processor type
      ]
      
      patterns.each do |pattern|
        match = output.match(pattern)
        if match
          arch_value = match[1]
          # Convert model names to architecture indicators
          case arch_value
          when /SRX\d+/i
            return "x86_64"  # Most SRX models are x86_64
          when /MX\d+/i
            return "x86_64"  # MX routers are typically x86_64
          when /EX\d+/i
            return "arm64"   # Many EX switches use ARM
          when /QFX\d+/i
            return "x86_64"  # QFX switches typically x86_64
          when /^(x86_64|amd64|i386|arm64|aarch64|sparc|mips)$/i
            return arch_value.downcase
          else
            # Return the model as-is if we can't map it
            return arch_value
          end
        end
      end
      
      nil
    end
  end
end
