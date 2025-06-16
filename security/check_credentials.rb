#!/usr/bin/env ruby
# Security script to check for hardcoded credentials and insecure patterns

require 'find'

class SecurityChecker
  def initialize
    @issues_found = 0
  end

  def run_all_checks
    puts "🔒 Running security checks for train-juniper plugin..."
    puts

    check_hardcoded_credentials
    check_logging_security
    check_file_permissions
    check_gemfile_security

    puts
    if @issues_found == 0
      puts "✅ All security checks passed!"
      exit(0)
    else
      puts "⚠️  Found #{@issues_found} security issue(s)"
      exit(1)
    end
  end

  private

  # Check for hardcoded credentials in source code
  def check_hardcoded_credentials
    puts "🔍 Checking for hardcoded credentials..."

    credential_patterns = [
      { pattern: /password\s*[=:]\s*["'][^"']+["']/i, name: "password" },
      { pattern: /secret\s*[=:]\s*["'][^"']+["']/i, name: "secret" },
      { pattern: /key\s*[=:]\s*["'][^"']+["']/i, name: "SSH key" },
      { pattern: /token\s*[=:]\s*["'][^"']+["']/i, name: "token" },
      { pattern: /api[_-]?key\s*[=:]\s*["'][^"']+["']/i, name: "API key" }
    ]

    safe_patterns = [
      /ENV\[/,           # Environment variables are OK
      /REDACTED/,        # Redacted values are OK
      /\[MASK/,          # Masked values are OK
      /test/,            # Test values are usually OK
      /mock/,            # Mock values are OK
      /example/,         # Example values are OK
      /placeholder/      # Placeholder values are OK
    ]

    scan_files(["lib", "test"], "*.rb") do |path, line, line_num|
      credential_patterns.each do |cred|
        if line.match?(cred[:pattern])
          # Check if this is a safe pattern
          is_safe = safe_patterns.any? { |safe| line.match?(safe) }
          
          unless is_safe
            report_issue("Potential hardcoded #{cred[:name]}", path, line_num, line)
          end
        end
      end
    end

    puts "   ✅ Hardcoded credential check completed"
  end

  # Check for insecure logging patterns
  def check_logging_security
    puts "🔍 Checking for insecure logging patterns..."

    insecure_patterns = [
      { pattern: /logger\.(debug|info|warn|error).*password/i, name: "password logging" },
      { pattern: /logger\.(debug|info|warn|error).*secret/i, name: "secret logging" },
      { pattern: /puts.*password/i, name: "password output" },
      { pattern: /print.*password/i, name: "password printing" },
      { pattern: /p\s+.*password/i, name: "password debugging" }
    ]

    safe_patterns = [
      /REDACTED/,
      /sanitize/,
      /mask/,
      /hide/,
      /\[FILTERED\]/
    ]

    scan_files(["lib"], "*.rb") do |path, line, line_num|
      insecure_patterns.each do |pattern_info|
        if line.match?(pattern_info[:pattern])
          is_safe = safe_patterns.any? { |safe| line.match?(safe) }
          
          unless is_safe
            report_issue("Potential #{pattern_info[:name]}", path, line_num, line)
          end
        end
      end
    end

    puts "   ✅ Logging security check completed"
  end

  # Check file permissions for security-sensitive files
  def check_file_permissions
    puts "🔍 Checking file permissions..."

    sensitive_files = [
      "train-juniper.gemspec",
      "lib/train-juniper/connection.rb",
      "lib/train-juniper/transport.rb"
    ]

    sensitive_files.each do |file|
      if File.exist?(file)
        mode = File.stat(file).mode & 0777
        
        # Should not be world-writable
        if (mode & 0002) != 0
          report_issue("World-writable file", file, nil, "File mode: #{mode.to_s(8)}")
        end
        
        # Note: 644 permissions (world-readable) are standard for Ruby source files
        # Only report if file contains actual secrets (which it shouldn't in our case)
      end
    end

    puts "   ✅ File permissions check completed"
  end

  # Check Gemfile for security-related configurations
  def check_gemfile_security
    puts "🔍 Checking Gemfile security..."

    if File.exist?("Gemfile")
      gemfile_content = File.read("Gemfile")
      
      # Check for insecure gem sources
      if gemfile_content.match?(/source\s+["']http:\/\//)
        report_issue("Insecure HTTP gem source", "Gemfile", nil, "Use HTTPS for gem sources")
      end
      
      # Check for security gems
      security_gems = %w[bundler-audit brakeman]
      missing_security_gems = security_gems.reject do |gem|
        gemfile_content.include?(gem)
      end
      
      if missing_security_gems.any?
        puts "   ⚠️  Recommendation: Consider adding security gems: #{missing_security_gems.join(', ')}"
      end
    end

    puts "   ✅ Gemfile security check completed"
  end

  # Helper method to scan files
  def scan_files(directories, pattern = "*")
    directories.each do |dir|
      next unless Dir.exist?(dir)
      
      Find.find(dir) do |path|
        next unless File.file?(path)
        next unless File.fnmatch(pattern, File.basename(path))
        
        File.readlines(path).each_with_index do |line, index|
          yield(path, line, index + 1)
        end
      end
    end
  end

  # Helper method to report security issues
  def report_issue(issue_type, file, line_num, details)
    @issues_found += 1
    location = line_num ? "#{file}:#{line_num}" : file
    puts "   ⚠️  #{issue_type} in #{location}"
    puts "      #{details.strip}" if details
  end
end

# Run security checks if executed directly
if __FILE__ == $0
  SecurityChecker.new.run_all_checks
end