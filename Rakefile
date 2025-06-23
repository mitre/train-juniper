# frozen_string_literal: true

# A Rakefile defines tasks to help maintain your project.
# Rake provides several task templates that are useful.

#------------------------------------------------------------------#
#                    Test Runner Tasks
#------------------------------------------------------------------#

# This task template will make a task named 'test', and run
# the tests that it finds.
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.test_files = FileList[
    'test/unit/*_test.rb',
    'test/integration/*_test.rb',
    'test/functional/*_test.rb',
    'test/security/*_test.rb'
  ]
  t.verbose = true
  # Ideally, we'd run tests with warnings enabled,
  # but the dependent gems have many warnings. As this
  # is an example, let's disable them so the testing
  # experience is cleaner.
  t.warning = false
end

#------------------------------------------------------------------#
#                    Code Style Tasks
#------------------------------------------------------------------#
require 'rubocop/rake_task'

RuboCop::RakeTask.new(:lint) do |t|
  # Use our local .rubocop.yml configuration
  t.options = ['--display-cop-names', '--config', '.rubocop.yml']
end

#------------------------------------------------------------------#
#                    Security Tasks
#------------------------------------------------------------------#

desc 'Run security tests'
task 'test:security' do
  ruby '-Ilib:test test/security/security_test.rb'
end

desc 'Run dependency vulnerability scan'
task 'security:dependencies' do
  puts 'Running bundler-audit dependency scan...'
  system('bundle exec bundle-audit update') or puts 'Failed to update vulnerability database'
  system('bundle exec bundle-audit check') or abort('Vulnerable dependencies found')
end

desc 'Run secrets scanning'
task 'security:secrets' do
  puts 'Running TruffleHog secrets scan...'
  if system('which trufflehog > /dev/null 2>&1')
    system('trufflehog filesystem --config=.trufflehog.yml --no-verification --no-update .') or abort('Secrets detected')
  else
    puts 'TruffleHog not installed. Install with: brew install trufflehog'
    abort('TruffleHog required for secrets scanning')
  end
end

# Brakeman removed - it's for Rails apps, not Ruby gems

desc 'Run comprehensive security scan'
task 'security:scan' do
  puts 'Running comprehensive security scan...'
  system('ruby security/security_scan.rb') or abort('Security scan failed')
end

desc 'Run all security checks'
task security: %w[security:dependencies test:security]

desc 'Run all tests including security'
task 'test:all' => %w[test security]

#------------------------------------------------------------------#
#                    Load Additional Tasks
#------------------------------------------------------------------#
Dir['tasks/*.rake'].each { |f| load f }

#------------------------------------------------------------------#
#                    Documentation Tasks
#------------------------------------------------------------------#
begin
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    t.files = ['lib/**/*.rb']
    t.options = ['--no-private']
    t.stats_options = ['--list-undoc']
  end
rescue LoadError
  desc 'YARD documentation task'
  task :yard do
    puts 'YARD is not available. Run `bundle install` to install it.'
  end
end

#------------------------------------------------------------------#
#                    Bundler Gem Tasks
#------------------------------------------------------------------#
# Bundler gem tasks disabled - we use GitHub Actions for gem publication
# require 'bundler/gem_tasks'
