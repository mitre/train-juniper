#!/usr/bin/env ruby
# frozen_string_literal: true

# Test direct connection to Juniper device (no bastion)
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

# Load environment variables manually
ENV['JUNIPER_HOST'] ||= '10.1.1.1'
ENV['JUNIPER_USER'] ||= 'your_username'
ENV['JUNIPER_PASSWORD'] ||= 'your_password'

puts 'Testing train-juniper plugin direct connection...'
puts "Connecting to #{ENV.fetch('JUNIPER_HOST', nil)}:22 as #{ENV.fetch('JUNIPER_USER', nil)}"

connection_options = {
  mock: false,
  host: ENV.fetch('JUNIPER_HOST', nil),
  port: 22,
  user: ENV.fetch('JUNIPER_USER', nil),
  password: ENV.fetch('JUNIPER_PASSWORD', nil),
  timeout: 60,
  logger: Logger.new(STDOUT, level: Logger::DEBUG)
}

puts "Connection options: #{connection_options.except(:password)}"
puts ''
puts '=== Creating Train transport ==='

begin
  # Create transport
  transport = TrainPlugins::Juniper::Transport.new
  transport.instance_variable_set(:@options, connection_options)

  puts ''
  puts '=== Establishing direct connection ==='

  # Create connection
  connection = transport.connection

  puts '✓ Direct connection established successfully!'
  puts ''
  puts 'Testing command execution...'
  puts ''

  # Test basic commands
  [
    'show version',
    'show chassis hardware',
    'show interfaces terse',
    'show version | display json',
    'show configuration security policies | display json',
    'show configuration security zones | display json'
  ].each do |cmd|
    puts "--- Running: #{cmd} ---"
    result = connection.run_command_via_connection(cmd)
    puts "Exit status: #{result.exit_status}"
    puts 'Output:'
    puts result.stdout.length > 500 ? "#{result.stdout[0..500]}..." : result.stdout
    puts "Stderr: #{result.stderr}" unless result.stderr.empty?
    puts ''
  end

  puts '--- Platform Detection ---'
  platform = connection.platform
  puts "Platform: #{platform.name}"
  puts "Release: #{platform.release}"
  puts ''

  puts '✓ All tests completed successfully!'
rescue StandardError => e
  puts "✗ Connection failed: #{e.message}"
  puts "  Error class: #{e.class}"
  puts '  Backtrace:'
  e.backtrace[0..5].each { |line| puts "    #{line}" }

  puts "  Original error: #{e.cause.message}" if e.respond_to?(:cause) && e.cause
end
