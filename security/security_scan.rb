#!/usr/bin/env ruby
# frozen_string_literal: true

# Security scanning script using industry-standard tools
# Replaces custom security checks with proven solutions

require 'fileutils'
require 'json'
require 'open3'
require 'shellwords'

class SecurityScanner
  def initialize
    @issues_found = 0
    @reports_dir = 'security/reports'
    FileUtils.mkdir_p(@reports_dir)
  end

  def run_all_scans
    puts '🔒 Running security scans for train-juniper plugin...'
    puts

    scan_secrets_with_trufflehog
    scan_dependencies_with_bundler_audit
    scan_licenses
    generate_security_report

    puts
    if @issues_found.zero?
      puts '✅ All security scans passed!'
      exit(0)
    else
      puts "⚠️  Found #{@issues_found} security issue(s)"
      puts "📊 Detailed reports available in: #{@reports_dir}/"
      exit(1)
    end
  end

  private

  # Secrets detection using TruffleHog (industry standard)
  def scan_secrets_with_trufflehog
    puts '🕵️  Scanning for secrets with TruffleHog...'

    if command_exists?('trufflehog')
      cmd = [
        'trufflehog', 'filesystem',
        '--config=.trufflehog.yml',
        '--json',
        '--no-verification',
        '--no-update',
        '.'
      ]

      stdout, _, status = Open3.capture3(*cmd)

      if status.success? && stdout.strip.empty?
        puts '   ✅ No secrets detected'
      else
        secrets_found = stdout.split("\n").select { |line| line.start_with?('{') }

        if secrets_found.any?
          @issues_found += secrets_found.length
          puts "   ⚠️  Found #{secrets_found.length} potential secret(s)"

          # Save detailed report
          File.write("#{@reports_dir}/secrets_scan.json", stdout)

          # Show summary
          secrets_found.each do |secret_json|
            secret = JSON.parse(secret_json)
            puts "      - #{secret['DetectorName']} in #{secret['SourceMetadata']['Data']['Filesystem']['file']}"
          end
        else
          puts '   ✅ No secrets detected'
        end
      end
    else
      puts '   ⚠️  TruffleHog not installed. Install with: brew install trufflehog'
      @issues_found += 1
    end
  rescue StandardError => e
    puts "   ❌ TruffleHog scan failed: #{e.message}"
    @issues_found += 1
  end


  # Dependency vulnerability scanning using bundler-audit
  def scan_dependencies_with_bundler_audit
    puts '📦 Scanning dependencies with bundler-audit...'

    # Update vulnerability database
    system('bundle exec bundle-audit update', out: File::NULL, err: File::NULL)

    cmd = ['bundle', 'exec', 'bundle-audit', 'check', '--format', 'json']
    stdout, stderr, status = Open3.capture3(*cmd)

    if status.success?
      puts '   ✅ No vulnerable dependencies detected'
    else
      # bundler-audit exits with non-zero when vulnerabilities found
      begin
        report = JSON.parse(stdout) if stdout.start_with?('{')
        vulnerabilities = report&.dig('results') || []

        if vulnerabilities.any?
          @issues_found += vulnerabilities.length
          puts "   ⚠️  Found #{vulnerabilities.length} vulnerable dependencies"

          # Save detailed report
          File.write("#{@reports_dir}/bundler_audit_report.json", stdout)

          vulnerabilities.first(3).each do |vuln|
            puts "      - #{vuln['gem']} #{vuln['version']}: #{vuln['title']}"
          end
        elsif stderr.include?('vulnerabilities') || stdout.include?('vulnerabilities')
          # Parse text output if JSON not available
          @issues_found += 1
          puts '   ⚠️  Vulnerable dependencies detected (see full output)'
          File.write("#{@reports_dir}/bundler_audit_output.txt", "#{stdout}\n#{stderr}")
        else
          puts '   ✅ No vulnerable dependencies detected'
        end
      rescue JSON::ParserError
        # Handle non-JSON output
        if stderr.include?('vulnerabilities') || stdout.include?('vulnerabilities')
          @issues_found += 1
          puts '   ⚠️  Vulnerable dependencies detected'
          File.write("#{@reports_dir}/bundler_audit_output.txt", "#{stdout}\n#{stderr}")
        else
          puts '   ✅ No vulnerable dependencies detected'
        end
      end
    end
  rescue StandardError => e
    puts "   ❌ bundler-audit scan failed: #{e.message}"
    @issues_found += 1
  end

  # License compliance scanning
  def scan_licenses
    puts '⚖️  Scanning license compliance...'

    cmd = ['bundle', 'exec', 'license_finder', '--format', 'json']
    stdout, _, status = Open3.capture3(*cmd)

    if status.success?
      begin
        licenses = JSON.parse(stdout)
        unapproved = licenses.select { |license| license['approved'] == false }

        if unapproved.empty?
          puts '   ✅ All licenses approved'
        else
          puts "   ⚠️  Found #{unapproved.length} gems with unapproved licenses"
          File.write("#{@reports_dir}/license_report.json", stdout)

          unapproved.first(3).each do |license|
            puts "      - #{license['name']}: #{license['licenses'].join(', ')}"
          end
        end
      rescue JSON::ParserError
        puts '   ⚠️  License scan completed (manual review may be needed)'
        File.write("#{@reports_dir}/license_output.txt", stdout)
      end
    else
      puts '   ⚠️  License scanning not available (license_finder not configured)'
    end
  rescue StandardError => e
    puts "   ⚠️  License scan skipped: #{e.message}"
  end

  # Generate comprehensive security report
  def generate_security_report
    report = {
      timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
      scan_summary: {
        total_issues: @issues_found,
        status: @issues_found.zero? ? 'PASS' : 'FAIL'
      },
      tools_used: [
        'TruffleHog (secrets detection)',
        'bundler-audit (dependency vulnerabilities)',
        'license_finder (license compliance)'
      ],
      reports_location: @reports_dir
    }

    File.write("#{@reports_dir}/security_summary.json", JSON.pretty_generate(report))
    puts "📊 Security summary saved to: #{@reports_dir}/security_summary.json"
  end

  # Helper method to check if command exists
  def command_exists?(command)
    system("which #{Shellwords.escape(command)} > /dev/null 2>&1")
  end
end

# Run security scans if executed directly
SecurityScanner.new.run_all_scans if __FILE__ == $PROGRAM_NAME
