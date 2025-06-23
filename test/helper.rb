# frozen_string_literal: true

# Test helper file for train-juniper plugin

# This file's job is to collect any libraries needed for testing, as well as provide
# any utilities to make testing a plugin easier.

# Start SimpleCov before loading any application code
require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'
  
  # Enable nocov comment blocks
  enable_coverage :branch
  nocov_token 'nocov'

  add_group 'Transport', 'lib/train-juniper/transport.rb'
  add_group 'Connection', 'lib/train-juniper/connection.rb'
  add_group 'Platform', 'lib/train-juniper/platform.rb'
  add_group 'Version', 'lib/train-juniper/version.rb'
  add_group 'Main', 'lib/train-juniper.rb'
end

require 'minitest/autorun'
require 'minitest/spec'

# Load the Train gem and our plugin
require 'train'
require 'train-juniper'

# Test helper module for common test utilities
module JuniperTestHelpers
  JUNIPER_ENV_VARS = %w[
    JUNIPER_HOST JUNIPER_USER JUNIPER_PASSWORD JUNIPER_PORT
    JUNIPER_BASTION_HOST JUNIPER_BASTION_USER JUNIPER_BASTION_PORT
    JUNIPER_BASTION_PASSWORD JUNIPER_PROXY_COMMAND JUNIPER_TIMEOUT
  ].freeze

  def clean_juniper_env
    JUNIPER_ENV_VARS.each { |var| ENV.delete(var) }
  end

  def with_clean_env
    clean_juniper_env
    yield
  ensure
    clean_juniper_env
  end

  def default_mock_options(overrides = {})
    {
      host: 'test.device',
      user: 'testuser',
      password: 'testpass',
      mock: true
    }.merge(overrides)
  end

  def bastion_mock_options(overrides = {})
    default_mock_options({
      bastion_host: 'jump.example.com',
      bastion_user: 'netadmin',
      bastion_port: 2222
    }.merge(overrides))
  end
end

# Include helper methods in all test classes
class Minitest::Test
  include JuniperTestHelpers
end
