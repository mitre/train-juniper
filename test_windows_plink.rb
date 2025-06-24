#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Windows plink.exe support
# Run this on a Windows machine to verify the implementation

require 'bundler/setup'
require 'train'
require 'logger'

# Load .env file if it exists
if File.exist?('.env')
  puts "Loading .env file..."
  File.readlines('.env').each do |line|
    next if line.strip.empty? || line.strip.start_with?('#')
    key, value = line.strip.split('=', 2)
    next unless key && value
    # Remove quotes if present
    value = value.gsub(/^["']|["']$/, '')
    ENV[key] = value
  end
end

# Enable debug logging
logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

puts "=== Train-Juniper Windows Plink Test ==="
puts "Ruby version: #{RUBY_VERSION}"
puts "Platform: #{RUBY_PLATFORM}"
puts "Windows?: #{Gem.win_platform?}"
puts

# Test 1: Check if plink.exe is available
puts "Test 1: Checking for plink.exe..."
plink_found = ENV['PATH'].split(File::PATH_SEPARATOR).any? do |path|
  File.exist?(File.join(path, 'plink.exe'))
end
puts "plink.exe found: #{plink_found}"

if plink_found
  plink_path = ENV['PATH'].split(File::PATH_SEPARATOR).find do |path|
    File.exist?(File.join(path, 'plink.exe'))
  end
  puts "plink.exe location: #{File.join(plink_path, 'plink.exe')}" if plink_path
end
puts

# Test 2: Mock mode test
puts "Test 2: Testing mock mode..."
begin
  transport = Train.create('juniper', 
    host: 'mock-device',
    user: 'admin',
    mock: true,
    logger: logger
  )
  
  conn = transport.connection
  result = conn.run_command('show version')
  puts "Mock command successful: #{result.exit_status == 0}"
  puts "Mock output: #{result.stdout.lines.first.strip}"
  conn.close
rescue => e
  puts "Mock test failed: #{e.message}"
  puts "Error: #{e.class}"
end
puts

# Test 2b: Mock mode with bastion (tests plink detection)
puts "Test 2b: Testing mock mode with bastion..."
begin
  transport = Train.create('juniper', 
    host: 'mock-device',
    user: 'admin',
    password: 'device_pass',
    bastion_host: 'mock-bastion',
    bastion_user: 'jumpuser',
    bastion_password: 'bastion_pass',
    mock: true,
    logger: logger
  )
  
  # Check if it would use plink
  puts "Mock with bastion created successfully"
  if Gem.win_platform? && plink_found
    puts "Expected: Would use plink.exe for bastion connection"
  else
    puts "Expected: Would use standard SSH_ASKPASS"
  end
  
  conn = transport.connection
  result = conn.run_command('show version')
  puts "Mock bastion command successful: #{result.exit_status == 0}"
  conn.close
rescue => e
  puts "Mock bastion test failed: #{e.message}"
  puts "Error: #{e.class}"
end
puts

# Test 3: Test plink command generation (if available)
if plink_found
  puts "Test 3: Testing plink command generation..."
  
  # Create a connection object to test our plink implementation
  require 'train-juniper'
  
  # Create a dummy connection to access the WindowsProxy module
  class TestProxy
    include TrainPlugins::Juniper::WindowsProxy
  end
  
  proxy = TestProxy.new
  
  # Test command generation
  cmd = proxy.build_plink_proxy_command('bastion.example.com', 'jumpuser', 22, 'test_pass')
  puts "Generated plink command:"
  puts "  #{cmd}"
  
  # Test with custom port
  cmd_port = proxy.build_plink_proxy_command('bastion.example.com', 'jumpuser', 2222, 'test_pass')
  puts "With custom port:"
  puts "  #{cmd_port}"
  puts
end

# Test 4: Real connection test (optional)
puts "Test 4: Real connection test"
puts "To test a real connection through a bastion, set these environment variables:"
puts "  SET JUNIPER_HOST=your-device"
puts "  SET JUNIPER_USER=admin"
puts "  SET JUNIPER_PASSWORD=device_password"
puts "  SET BASTION_HOST=your-bastion"
puts "  SET BASTION_USER=jumpuser"
puts "  SET BASTION_PASSWORD=bastion_password"
puts

if ENV['JUNIPER_HOST'] && ENV['BASTION_HOST']
  puts "Attempting real connection..."
  begin
    transport = Train.create('juniper',
      host: ENV['JUNIPER_HOST'],
      user: ENV['JUNIPER_USER'],
      password: ENV['JUNIPER_PASSWORD'],
      bastion_host: ENV['BASTION_HOST'],
      bastion_user: ENV['BASTION_USER'] || ENV['JUNIPER_USER'],
      bastion_password: ENV['BASTION_PASSWORD'] || ENV['JUNIPER_PASSWORD'],
      logger: logger
    )
    
    conn = transport.connection
    result = conn.run_command('show version')
    puts "Connection successful!"
    puts "Device info: #{result.stdout.lines.first.strip}"
    conn.close
  rescue => e
    puts "Connection failed: #{e.message}"
    puts "Backtrace:"
    puts e.backtrace[0..5].join("\n")
  end
else
  puts "(Skipping real connection test - environment variables not set)"
end

puts
puts "=== Test Complete ==="