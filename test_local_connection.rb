#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for connecting to a real Juniper device
# Usage: ruby test_local_connection.rb

require 'bundler/setup'
require_relative 'lib/train-juniper'
require 'logger'

# Configure logging
logger = Logger.new($stdout)
logger.level = Logger::DEBUG

# Load environment variables from .env file if it exists
env_file = File.join(File.dirname(__FILE__), '.env')
if File.exist?(env_file)
  puts "Loading environment from #{env_file}"
  File.readlines(env_file).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    ENV[key] = value if key && value
  end
end

# Connection options
options = {
  host: ENV['JUNIPER_HOST'] || '192.168.1.1',  # Replace with your device IP
  user: ENV['JUNIPER_USER'] || 'admin',        # Replace with your username
  password: ENV.fetch('JUNIPER_PASSWORD', nil), # Set via environment variable
  port: (ENV['JUNIPER_PORT'] || '22').to_i,
  timeout: (ENV['CONNECTION_TIMEOUT'] || '60').to_i,
  logger: logger

  # Optional: SSH key authentication
  # key_files: ['~/.ssh/id_rsa'],
  # verify_host_key: false,                     # Disable host key verification (dev only)
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
puts

begin
  # Create connection
  train = Train.create('juniper', options)
  conn = train.connection

  # Test connection
  puts 'Testing connection...'
  conn.connect

  # Display connection info
  puts "\n=== Connection Info ==="
  puts "URI: #{conn.uri}"
  puts "Unique Identifier: #{conn.unique_identifier}"

  # Get platform information
  platform = conn.platform
  puts "\n=== Platform Info ==="
  puts "Name: #{platform.name}"
  puts "Release: #{platform.release}"
  puts "Architecture: #{platform.arch}"
  puts "Family: #{platform.family}"

  # Run some test commands
  puts "\n=== Running Test Commands ==="

  # Basic command
  puts "\n1. Running 'show version':"
  result = conn.run_command('show version')
  puts "Exit Status: #{result.exit_status}"
  puts "Output (first 200 chars): #{result.stdout[0..200]}..."

  # XML command (what we use internally)
  puts "\n2. Running 'show version | display xml':"
  result = conn.run_command('show version | display xml')
  puts "Exit Status: #{result.exit_status}"
  puts "Output (first 300 chars): #{result.stdout[0..300]}..."

  # Chassis info
  puts "\n3. Running 'show chassis hardware':"
  result = conn.run_command('show chassis hardware')
  puts "Exit Status: #{result.exit_status}"
  puts "Output (first 200 chars): #{result.stdout[0..200]}..."

  # Test error handling
  puts "\n4. Testing error handling with invalid command:"
  result = conn.run_command('show invalid-command')
  puts "Exit Status: #{result.exit_status}"
  puts "Error: #{result.stderr}"

  puts "\n✅ Connection test successful!"
rescue StandardError => e
  puts "\n❌ Connection failed: #{e.message}"
  puts e.backtrace.join("\n") if ENV['DEBUG']
ensure
  conn&.close
  puts "\nConnection closed."
end
