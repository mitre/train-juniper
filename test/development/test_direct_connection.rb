#!/usr/bin/env ruby

# Test direct connection to Juniper device (no bastion)
require 'bundler/setup'
require_relative 'lib/train-juniper'

# Load environment variables manually
ENV['JUNIPER_HOST'] ||= '10.1.1.1'
ENV['JUNIPER_USER'] ||= 'your_username'
ENV['JUNIPER_PASSWORD'] ||= 'your_password'

puts "Testing train-juniper plugin direct connection..."
puts "Connecting to #{ENV['JUNIPER_HOST']}:22 as #{ENV['JUNIPER_USER']}"

connection_options = {
  mock: false,
  host: ENV['JUNIPER_HOST'],
  port: 22,
  user: ENV['JUNIPER_USER'],
  password: ENV['JUNIPER_PASSWORD'],
  timeout: 60,
  logger: Logger.new(STDOUT, level: Logger::DEBUG)
}

puts "Connection options: #{connection_options.reject { |k,v| k == :password }}"
puts ""
puts "=== Creating Train transport ==="

begin
  # Create transport
  transport = TrainPlugins::Juniper::Transport.new
  transport.instance_variable_set(:@options, connection_options)
  
  puts ""
  puts "=== Establishing direct connection ==="
  
  # Create connection
  connection = transport.connection
  
  puts "✓ Direct connection established successfully!"
  puts ""
  puts "Testing command execution..."
  puts ""
  
  # Test basic commands
  [
    "show version",
    "show chassis hardware", 
    "show interfaces terse",
    "show version | display json",
    "show configuration security policies | display json",
    "show configuration security zones | display json"
  ].each do |cmd|
    puts "--- Running: #{cmd} ---"
    result = connection.run_command_via_connection(cmd)
    puts "Exit status: #{result.exit_status}"
    puts "Output:"
    puts result.stdout.length > 500 ? result.stdout[0..500] + "..." : result.stdout
    puts "Stderr: #{result.stderr}" unless result.stderr.empty?
    puts ""
  end
  
  puts "--- Platform Detection ---"
  platform = connection.platform
  puts "Platform: #{platform.name}"
  puts "Release: #{platform.release}"
  puts ""
  
  puts "✓ All tests completed successfully!"
  
rescue => e
  puts "✗ Connection failed: #{e.message}"
  puts "  Error class: #{e.class}"
  puts "  Backtrace:"
  e.backtrace[0..5].each { |line| puts "    #{line}" }
  
  if e.respond_to?(:cause) && e.cause
    puts "  Original error: #{e.cause.message}"
  end
end