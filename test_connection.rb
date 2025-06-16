#!/usr/bin/env ruby

# Quick test script to verify our train-juniper plugin works with real Juniper devices

require 'bundler/setup'
require 'logger'
require_relative 'lib/train-juniper'

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
  mock: false,  # Test real connection - plugin architecture now works!
  host: ENV['JUNIPER_HOST'] || 'localhost',
  port: (ENV['JUNIPER_PORT'] || '22').to_i,
  user: ENV['JUNIPER_USER'] || 'admin',
  password: ENV['JUNIPER_PASSWORD'] || 'admin123',
  timeout: (ENV['CONNECTION_TIMEOUT'] || '60').to_i,
  logger: logger  # Add logger to connection options
}

# Re-enable jumpbox now that plugin architecture works
if ENV['JUMPBOX_HOST'] && ENV['JUMPBOX_USER']
  options[:proxy_jump] = "#{ENV['JUMPBOX_USER']}@#{ENV['JUMPBOX_HOST']}"
  options[:proxy_password] = ENV['JUMPBOX_PASSWORD'] if ENV['JUMPBOX_PASSWORD']
  puts "Using jumpbox: #{ENV['JUMPBOX_USER']}@#{ENV['JUMPBOX_HOST']}"
  puts "Proxy jump string: #{options[:proxy_jump]}"
  puts "Proxy authentication: #{options[:proxy_password] ? 'password configured' : 'no password'}"
end

# Re-enable jumpbox using the WORKING approach from old version
if ENV['JUNIPER_BASTION_HOST'] && ENV['JUNIPER_BASTION_USER']
  options[:proxy_jump] = "#{ENV['JUNIPER_BASTION_USER']}@#{ENV['JUNIPER_BASTION_HOST']}"
  options[:proxy_password] = ENV['JUNIPER_PASSWORD'] if ENV['JUNIPER_PASSWORD']  # Use same password
  puts "Using jumpbox: #{ENV['JUNIPER_BASTION_USER']}@#{ENV['JUNIPER_BASTION_HOST']}"
  puts "Proxy jump string: #{options[:proxy_jump]}"
  puts "Proxy authentication: #{options[:proxy_password] ? 'password configured' : 'no password'}"
end

puts "Testing train-juniper plugin connection..."
puts "Connecting to #{options[:host]}:#{options[:port]} as #{options[:user]}"
puts "Connection options: #{options.reject { |k,v| [:password, :proxy_password].include?(k) }.inspect}"

begin
  puts "\n=== Creating Train transport ==="
  transport = Train.create('juniper', options)
  
  puts "\n=== Establishing connection ==="
  connection = transport.connection
  
  puts "✓ Connection established successfully!"
  
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
    puts "Output:"
    puts result.stdout
    if !result.stderr.empty?
      puts "Stderr: #{result.stderr}"
    end
  end
  
  # Test platform detection
  puts "\n--- Platform Detection ---"
  platform = connection.platform
  puts "Platform: #{platform.name}"
  puts "Release: #{platform.release}" if platform.respond_to?(:release)
  
  puts "\n✓ All tests completed successfully!"
  
rescue => e
  puts "✗ Connection failed: #{e.message}"
  puts "  Error class: #{e.class}"
  puts "  Backtrace:"
  puts e.backtrace[0..5].map { |line| "    #{line}" }
end