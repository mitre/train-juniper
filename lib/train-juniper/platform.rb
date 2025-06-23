# frozen_string_literal: true

# Platform definition file for Juniper network devices.
# This defines the "juniper" platform within Train's platform detection system.

module TrainPlugins::Juniper
  # Platform detection mixin for Juniper network devices
  # @note This module is mixed into the Connection class to provide platform detection
  module Platform
    # Platform name constant for consistency
    PLATFORM_NAME = 'juniper'

    # Platform detection for Juniper network devices
    # @return [Train::Platform] Platform object with JunOS details
    # @note Uses force_platform! to bypass Train's automatic detection
    # @example
    #   platform = connection.platform
    #   platform.name     #=> "juniper"
    #   platform.release  #=> "12.1X47-D15.4"
    #   platform.arch     #=> "x86_64"
    def platform
      # Return cached platform if already computed
      return @platform if defined?(@platform)

      # Register the juniper platform in Train's platform registry
      # JunOS devices are FreeBSD-based, so inherit from bsd family for InSpec resource compatibility
      # This allows InSpec resources like 'command' to work with Juniper devices
      Train::Platforms.name(PLATFORM_NAME).title('Juniper JunOS').in_family('bsd')

      # Try to detect actual JunOS version and architecture from device
      device_version = detect_junos_version || TrainPlugins::Juniper::VERSION
      device_arch = detect_junos_architecture || 'unknown'
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
      @platform = platform_obj
    end

    private

    # Generic detection helper for version and architecture
    # @param attribute_name [String] Name of the attribute to detect
    # @param command [String] Command to run (default: 'show version')
    # @yield [String] Block that extracts the attribute from command output
    # @return [String, nil] Detected attribute value or nil
    def detect_attribute(attribute_name, command = 'show version', &extraction_block)
      cache_var = "@detected_#{attribute_name}"
      return instance_variable_get(cache_var) if instance_variable_defined?(cache_var)

      unless respond_to?(:run_command_via_connection)
        logger&.debug('run_command_via_connection not available yet')
        return instance_variable_set(cache_var, nil)
      end

      logger&.debug("Mock mode: #{@options&.dig(:mock)}, Connected: #{connected?}")

      begin
        return instance_variable_set(cache_var, nil) unless connected?

        # Reuse cached command result if available
        result = @cached_show_version_result || run_command_via_connection(command)
        @cached_show_version_result ||= result if command == 'show version' && result&.exit_status&.zero?

        return instance_variable_set(cache_var, nil) unless result&.exit_status&.zero?

        value = extraction_block.call(result.stdout)

        if value
          logger&.debug("Detected #{attribute_name}: #{value}")
          instance_variable_set(cache_var, value)
        else
          logger&.debug("Could not parse #{attribute_name} from: #{result.stdout[0..100]}")
          instance_variable_set(cache_var, nil)
        end
      rescue StandardError => e
        logger&.debug("#{attribute_name} detection failed: #{e.message}")
        instance_variable_set(cache_var, nil)
      end
    end

    # Detect JunOS version from device output
    # @return [String, nil] JunOS version string or nil if not detected
    # @note This runs safely after the connection is established
    def detect_junos_version
      detect_attribute('junos_version') { |output| extract_version_from_output(output) }
    end

    # Extract version string from JunOS show version output
    # @param output [String] Raw output from 'show version' command
    # @return [String, nil] Extracted version string or nil
    def extract_version_from_output(output)
      return nil if output.nil? || output.empty?

      # Try multiple JunOS version patterns
      patterns = [
        /Junos:\s+([\w\d.-]+)/,                           # "Junos: 12.1X47-D15.4"
        /JUNOS Software Release \[([\w\d.-]+)\]/,         # "JUNOS Software Release [12.1X47-D15.4]"
        /junos version ([\w\d.-]+)/i,                     # "junos version 21.4R3"
        /Model: \S+, JUNOS Base OS boot \[([\w\d.-]+)\]/, # Some hardware variants
        /([\d]+\.[\d]+[\w.-]*)/                           # Generic version pattern
      ]

      patterns.each do |pattern|
        match = output.match(pattern)
        return match[1] if match
      end

      nil
    end

    # Detect JunOS architecture from device output
    # @return [String, nil] Architecture string or nil if not detected
    # @note This runs safely after the connection is established
    def detect_junos_architecture
      detect_attribute('junos_architecture') { |output| extract_architecture_from_output(output) }
    end

    # Extract architecture string from JunOS show version output
    # @param output [String] Raw output from 'show version' command
    # @return [String, nil] Architecture string (x86_64, arm64, etc.) or nil
    def extract_architecture_from_output(output)
      return nil if output.nil? || output.empty?

      # Try multiple JunOS architecture patterns
      patterns = [
        /Model:\s+(\S+)/, # "Model: SRX240H2" -> extract model as arch indicator
        /Junos:\s+[\w\d.-]+\s+built\s+[\d-]+\s+[\d:]+\s+by\s+builder\s+on\s+(\S+)/, # Build architecture
        /JUNOS.*\[([\w-]+)\]/,                                 # JUNOS package architecture
        /Architecture:\s+(\S+)/i,                              # Direct architecture line
        /Platform:\s+(\S+)/i,                                  # Platform designation
        /Processor.*:\s*(\S+)/i # Processor type
      ]

      patterns.each do |pattern|
        match = output.match(pattern)
        next unless match

        arch_value = match[1]
        # Convert model names to architecture indicators
        case arch_value
        when /SRX\d+/i
          return 'x86_64'  # Most SRX models are x86_64
        when /MX\d+/i
          return 'x86_64'  # MX routers are typically x86_64
        when /EX\d+/i
          return 'arm64'   # Many EX switches use ARM
        when /QFX\d+/i
          return 'x86_64'  # QFX switches typically x86_64
        when /^(x86_64|amd64|i386|arm64|aarch64|sparc|mips)$/i
          return arch_value.downcase
        else
          # Return the model as-is if we can't map it
          return arch_value
        end
      end

      nil
    end
  end
end
