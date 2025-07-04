# frozen_string_literal: true

require 'rexml/document'

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

      # Log platform detection results if logging helpers available
      log_platform_detection(PLATFORM_NAME, device_version) if respond_to?(:log_platform_detection)

      # Cache the platform object to prevent repeated calls
      @platform = platform_obj
    end

    private

    # Generic XML extraction helper
    # @param output [String] XML output from command
    # @param xpath_patterns [Array<String>] XPath patterns to try in order
    # @param command_desc [String] Description of command for error messages
    # @yield [REXML::Element] Optional block to process the found element
    # @return [String, nil] Extracted text or result of block processing
    def extract_from_xml(output, xpath_patterns, command_desc)
      return nil if output.nil? || output.empty?

      doc = REXML::Document.new(output)

      # Try each XPath pattern until we find an element
      element = nil
      xpath_patterns.each do |xpath|
        element = doc.elements[xpath]
        break if element
      end

      return nil unless element

      # If block given, let it process the element, otherwise return text
      block_given? ? yield(element) : element.text&.strip
    rescue StandardError => e
      logger&.warn("Failed to parse XML output from '#{command_desc}': #{e.message}")
      nil
    end

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
      detect_attribute('junos_version', 'show version | display xml') { |output| extract_version_from_xml(output) }
    end

    # Extract version string from JunOS show version XML output
    # @param output [String] XML output from 'show version | display xml' command
    # @return [String, nil] Extracted version string or nil
    def extract_version_from_xml(output)
      xpath_patterns = [
        '//junos-version',
        '//package-information/name[text()="junos"]/following-sibling::comment',
        '//software-information/version'
      ]

      extract_from_xml(output, xpath_patterns, 'show version | display xml')
    end

    # Detect JunOS architecture from device output
    # @return [String, nil] Architecture string or nil if not detected
    # @note This runs safely after the connection is established
    def detect_junos_architecture
      detect_attribute('junos_architecture', 'show version | display xml') { |output| extract_architecture_from_xml(output) }
    end

    # Extract architecture string from JunOS show version XML output
    # @param output [String] XML output from 'show version | display xml' command
    # @return [String, nil] Architecture string (x86_64, arm64, etc.) or nil
    def extract_architecture_from_xml(output)
      xpath_patterns = [
        '//product-model',
        '//software-information/product-model',
        '//chassis-inventory/chassis/description'
      ]

      extract_from_xml(output, xpath_patterns, 'show version | display xml') do |element|
        model = element.text.strip

        # Map model names to architecture
        case model
        when /SRX\d+/i
          'x86_64'  # Most SRX models are x86_64
        when /MX\d+/i
          'x86_64'  # MX routers are typically x86_64
        when /EX\d+/i
          'arm64'   # Many EX switches use ARM
        when /QFX\d+/i
          'x86_64'  # QFX switches typically x86_64
        else
          # Default to x86_64 for unknown models
          'x86_64'
        end
      end
    end

    # Detect JunOS serial number from device output
    # @return [String, nil] Serial number string or nil if not detected
    # @note This runs safely after the connection is established
    def detect_junos_serial
      detect_attribute('junos_serial', 'show chassis hardware | display xml') { |output| extract_serial_from_xml(output) }
    end

    # Extract serial number from JunOS chassis hardware XML output
    # @param output [String] XML output from 'show chassis hardware | display xml' command
    # @return [String, nil] Serial number string or nil
    def extract_serial_from_xml(output)
      xpath_patterns = [
        '//chassis/serial-number',
        '//chassis-sub-module/serial-number',
        '//module/serial-number[1]'
      ]

      extract_from_xml(output, xpath_patterns, 'show chassis hardware | display xml')
    end
  end
end
