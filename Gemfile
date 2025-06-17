source "https://rubygems.org"

# This is Gemfile, which is used by bundler
# to ensure a coherent set of gems is installed.
# This file lists dependencies needed when outside
# of a gem (the gemspec lists deps for gem deployment)

# Use train-core for lighter weight (matches community plugin pattern)
gem "train-core", "~> 3.12.13"

# Use Train's SSH dependencies to avoid version conflicts
gem "net-ssh", ">= 7.0"

# Bundler should refer to the gemspec for any dependencies.
gemspec

# Remaining group is only used for development.
group :development do
  gem "bundler"
  gem "byebug"
  # gem "inspec" # Not needed for plugin development, only for end-user testing
  gem "minitest"
  gem "rake"
  gem "rubocop"
  gem "simplecov" # Code coverage analysis
  
  # Security testing gems
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  # gem "overcommit", require: false  # TODO: Fix Ruby 3.1.6 compatibility issue
end

group :security do
  # Additional security analysis
  gem "license_finder", require: false
end
