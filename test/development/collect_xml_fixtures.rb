#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to collect XML fixture data from real Juniper devices
# This helps us build accurate test fixtures for InSpec resources

# Find the project root directory (contains train-juniper.gemspec)
def find_project_root
  current_dir = __dir__
  while current_dir != '/'
    return current_dir if File.exist?(File.join(current_dir, 'train-juniper.gemspec'))

    current_dir = File.dirname(current_dir)
  end
  raise 'Could not find project root (train-juniper.gemspec not found)'
end

# Add lib directory to load path and require our plugin
project_root = find_project_root
$LOAD_PATH.unshift(File.join(project_root, 'lib'))

require 'bundler/setup'
require 'logger'
require 'train-juniper'
require 'fileutils'

# Enable verbose logging
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Load environment variables if .env file exists
env_file = File.join(File.dirname(__FILE__), '.env')
if File.exist?(env_file)
  File.readlines(env_file).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    ENV[key] = value if key && value
  end
end

# Connection configuration from environment variables
options = {
  mock: false,
  host: ENV['JUNIPER_HOST'] || 'localhost',
  port: (ENV['JUNIPER_PORT'] || '22').to_i,
  user: ENV['JUNIPER_USER'] || 'admin',
  password: ENV['JUNIPER_PASSWORD'] || 'admin123',
  timeout: (ENV['CONNECTION_TIMEOUT'] || '60').to_i,
  logger: logger
}

# Configure bastion host if environment variables are set
if ENV['JUNIPER_BASTION_HOST'] && ENV['JUNIPER_BASTION_USER']
  options[:bastion_host] = ENV['JUNIPER_BASTION_HOST']
  options[:bastion_user] = ENV['JUNIPER_BASTION_USER']
  options[:bastion_port] = ENV['JUNIPER_BASTION_PORT']&.to_i || 22
  options[:bastion_password] = ENV['JUNIPER_BASTION_PASSWORD'] || ENV.fetch('JUNIPER_PASSWORD', nil)
end

# Create output directory for fixtures
fixtures_dir = File.join(project_root, 'test', 'fixtures', 'xml_from_device')
FileUtils.mkdir_p(fixtures_dir)

puts 'Collecting XML fixtures from Juniper device...'
puts "Connecting to #{options[:host]}:#{options[:port]} as #{options[:user]}"
puts "Fixtures will be saved to: #{fixtures_dir}"

# Commands to collect for InSpec resources
# Based on our implementation matrix
commands = {
  # Phase 1 resources (46% coverage)
  'show_system_syslog' => 'show system syslog',
  'show_system_login' => 'show system login',
  'show_system_login_password' => 'show system login password',
  'show_system_login_retry_options' => 'show system login retry-options',
  'show_system_services' => 'show system services',

  # Phase 2 resources (10% more coverage)
  'show_system_radius_server' => 'show system radius-server',
  'show_system_tacplus_server' => 'show system tacplus-server',
  'show_system_authentication_order' => 'show system authentication-order',
  'show_system_accounting' => 'show system accounting',
  'show_snmp' => 'show snmp',
  'show_snmp_v3' => 'show snmp v3',
  'show_security_screen_ids_option' => 'show security screen ids-option',
  'show_firewall_filter' => 'show firewall filter',

  # Phase 3 resources
  'show_interfaces' => 'show interfaces',
  'show_security_ipsec' => 'show security ipsec',
  'show_routing_options' => 'show routing-options',
  'show_system_archival' => 'show system archival',
  'show_vlans' => 'show vlans',

  # Also get RPC names for future reference
  'show_version_rpc' => 'show version | display xml rpc',
  'show_system_syslog_rpc' => 'show system syslog | display xml rpc'
}

begin
  transport = Train.create('juniper', options)
  connection = transport.connection

  puts "\n✓ Connection established successfully!"

  # Collect each command's XML output
  commands.each do |filename, command|
    puts "\n--- Collecting: #{command} ---"

    # Run command with XML output
    xml_command = command.include?('| display') ? command : "#{command} | display xml"
    result = connection.run_command(xml_command)

    if result.exit_status.zero? && !result.stdout.empty?
      # Save fixture
      fixture_path = File.join(fixtures_dir, "#{filename}.xml")
      File.write(fixture_path, result.stdout)
      puts "✓ Saved to: #{filename}.xml (#{result.stdout.size} bytes)"

      # Also save first few lines as preview
      preview = result.stdout.lines.first(10).join
      puts 'Preview:'
      puts preview
      puts '...' if result.stdout.lines.size > 10
    else
      puts "✗ Failed: Exit status #{result.exit_status}"
      puts "Error: #{result.stderr}" unless result.stderr.empty?
    end
  end

  # Also collect some failure cases for error handling tests
  puts "\n--- Collecting error cases ---"
  error_commands = {
    'show_invalid_command' => 'show invalid-command-test',
    'show_system_missing_config' => 'show system missing-config'
  }

  error_commands.each do |filename, command|
    puts "\nCollecting error case: #{command}"
    result = connection.run_command("#{command} | display xml")

    next unless result.exit_status != 0 || !result.stderr.empty?

    fixture_path = File.join(fixtures_dir, "#{filename}_error.txt")
    File.write(fixture_path, "Exit Status: #{result.exit_status}\nSTDOUT:\n#{result.stdout}\nSTDERR:\n#{result.stderr}")
    puts "✓ Saved error case to: #{filename}_error.txt"
  end

  puts "\n✓ Fixture collection complete!"
  puts "Fixtures saved to: #{fixtures_dir}"

  # Summary
  fixture_count = Dir[File.join(fixtures_dir, '*.xml')].size
  error_count = Dir[File.join(fixtures_dir, '*_error.txt')].size
  puts "\nSummary:"
  puts "- XML fixtures collected: #{fixture_count}"
  puts "- Error cases collected: #{error_count}"
rescue StandardError => e
  puts "✗ Collection failed: #{e.message}"
  puts "  Error class: #{e.class}"
  puts '  Backtrace:'
  puts(e.backtrace[0..5].map { |line| "    #{line}" })
end
