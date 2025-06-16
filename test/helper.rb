# Test helper file for train-juniper plugin

# This file's job is to collect any libraries needed for testing, as well as provide
# any utilities to make testing a plugin easier.

# Start SimpleCov before loading any application code
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/vendor/"
  
  add_group "Transport", "lib/train-juniper/transport.rb"
  add_group "Connection", "lib/train-juniper/connection.rb"  
  add_group "Platform", "lib/train-juniper/platform.rb"
  add_group "Version", "lib/train-juniper/version.rb"
  add_group "Main", "lib/train-juniper.rb"
end

require "minitest/autorun"
require "minitest/spec"

# Load the Train gem and our plugin
require "train"
require "train-juniper"
