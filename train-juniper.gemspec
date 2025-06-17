# frozen_string_literal: true

# As plugins are usually packaged and distributed as a RubyGem,
# we have to provide a .gemspec file, which controls the gembuild
# and publish process.  This is a fairly generic gemspec.

# It is traditional in a gemspec to dynamically load the current version
# from a file in the source tree.  The next three lines make that happen.
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'train-juniper/version'

Gem::Specification.new do |spec|
  # Importantly, all Train plugins must be prefixed with `train-`
  spec.name          = 'train-juniper'

  # It is polite to namespace your plugin under TrainPlugins::YourPluginInCamelCase
  spec.version       = TrainPlugins::Juniper::VERSION
  spec.authors       = ['MITRE Corporation']
  spec.email         = ['saf@mitre.org']
  spec.summary       = 'Train transport for Juniper Networks JunOS devices'
  spec.description   = 'Provides SSH connectivity to Juniper Networks devices running JunOS for InSpec compliance testing and ' \
                       'infrastructure inspection. Supports platform detection, command execution, and configuration file access.'
  spec.homepage      = 'https://github.com/mitre/train-juniper'
  spec.license       = 'Apache-2.0'

  # Metadata for better gem discovery
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/mitre/train-juniper/issues',
    'changelog_uri' => 'https://github.com/mitre/train-juniper/blob/main/CHANGELOG.md',
    'documentation_uri' => 'https://mitre.github.io/train-juniper/',
    'homepage_uri' => 'https://github.com/mitre/train-juniper',
    'source_code_uri' => 'https://github.com/mitre/train-juniper',
    'security_policy_uri' => 'https://github.com/mitre/train-juniper/security/policy',
    'rubygems_mfa_required' => 'true'
  }

  # Though complicated-looking, this is pretty standard for a gemspec.
  # It just filters what will actually be packaged in the gem (leaving
  # out tests, etc)
  # Standard pattern for Train plugins - include all lib files and key docs
  spec.files = %w[
    README.md train-juniper.gemspec LICENSE.md NOTICE.md CHANGELOG.md
    CODE_OF_CONDUCT.md CONTRIBUTING.md SECURITY.md
    .env.example Rakefile
  ] + Dir.glob(
    'lib/**/*', File::FNM_DOTMATCH
  ).reject { |f| File.directory?(f) }
  spec.require_paths = ['lib']

  # If you rely on any other gems, list them here with any constraints.
  # This is how `inspec plugin install` is able to manage your dependencies.
  # For example, perhaps you are writing a thing that talks to AWS, and you
  # want to ensure you have `aws-sdk` in a certain version.

  # If you only need certain gems during development or testing, list
  # them in Gemfile, not here.
  # Do not list inspec as a dependency of the train plugin.

  # All plugins should mention train, > 1.4
  spec.required_ruby_version = '>= 3.1.0'

  # Community plugins typically use train-core for smaller footprint
  # train-core provides core functionality without cloud dependencies
  spec.add_dependency 'train-core', '~> 3.12.13'

  # SSH connectivity dependencies - match train-core's exact version range
  spec.add_dependency 'net-ssh', '>= 2.9', '< 8.0'

  # Force compatible FFI version to avoid conflicts with InSpec
  spec.add_dependency 'ffi', '~> 1.16.0'
end
