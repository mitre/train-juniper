#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick test script to verify our train-juniper plugin works with real Juniper devices

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

# Enable verbose logging
logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

# Load environment variables if .env file exists (look in script directory)
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
  mock: false, # Test real connection - plugin architecture now works!
  host: ENV['JUNIPER_HOST'] || 'localhost',
  port: (ENV['JUNIPER_PORT'] || '22').to_i,
  user: ENV['JUNIPER_USER'] || 'admin',
  password: ENV['JUNIPER_PASSWORD'] || 'admin123',
  timeout: (ENV['CONNECTION_TIMEOUT'] || '60').to_i,
  logger: logger # Add logger to connection options
}

# Configure bastion host if environment variables are set
if ENV['JUNIPER_BASTION_HOST'] && ENV['JUNIPER_BASTION_USER']
  options[:bastion_host] = ENV['JUNIPER_BASTION_HOST']
  options[:bastion_user] = ENV['JUNIPER_BASTION_USER']
  options[:bastion_port] = ENV['JUNIPER_BASTION_PORT']&.to_i || 22
  # Use dedicated bastion password or fallback
  options[:bastion_password] = ENV['JUNIPER_BASTION_PASSWORD'] || ENV.fetch('JUNIPER_PASSWORD', nil)
  puts "Using bastion host: #{options[:bastion_user]}@#{options[:bastion_host]}:#{options[:bastion_port]}"
  puts "Bastion authentication: #{options[:bastion_password] ? 'password configured' : 'no password'}"
end

puts 'Testing train-juniper plugin connection...'
puts "Connecting to #{options[:host]}:#{options[:port]} as #{options[:user]}"
puts "Connection options: #{options.except(:password, :bastion_password).inspect}"

begin
  puts "\n=== Creating Train transport ==="
  transport = Train.create('juniper', options)

  puts "\n=== Establishing connection ==="
  connection = transport.connection

  puts '✓ Connection established successfully!'

  # Test basic command execution
  puts "\nTesting command execution..."

  # Test STIG-relevant commands with JSON output for InSpec resource development
  commands = [
    'show version',
    'show chassis hardware',
    'show interfaces terse',
    'show version | display json',
    'show configuration security policies | display json',
    'show configuration security zones | display json'
  ]

  commands.each do |cmd|
    puts "\n--- Running: #{cmd} ---"
    result = connection.run_command(cmd)
    puts "Exit status: #{result.exit_status}"
    puts 'Output:'
    puts result.stdout
    puts "Stderr: #{result.stderr}" unless result.stderr.empty?
  end

  # Test platform detection
  puts "\n--- Platform Detection ---"
  platform = connection.platform
  puts "Platform: #{platform.name}"
  puts "Release: #{platform.release}" if platform.respond_to?(:release)

  puts "\n✓ All tests completed successfully!"
rescue StandardError => e
  puts "✗ Connection failed: #{e.message}"
  puts "  Error class: #{e.class}"
  puts '  Backtrace:'
  puts(e.backtrace[0..5].map { |line| "    #{line}" })
end
