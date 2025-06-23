#!/usr/bin/env ruby
# frozen_string_literal: true

# Coverage Analysis Tool for train-juniper
# This script analyzes the coverage report and provides detailed information
# about which files and lines need coverage improvements

require 'json'

def analyze_coverage
  coverage_file = 'coverage/.resultset.json'
  unless File.exist?(coverage_file)
    puts "Error: Coverage file not found at #{coverage_file}"
    puts "Please run 'bundle exec rake test' first to generate coverage data."
    exit 1
  end

  data = JSON.parse(File.read(coverage_file))
  coverage_data = data['Functional Tests']['coverage']

  # Calculate coverage for each file
  files = {}
  coverage_data.each do |file, line_data|
    next unless file.include?('/lib/train-juniper/')
    next unless line_data.is_a?(Hash) && line_data['lines']
    
    lines = line_data['lines']
    covered = lines.compact.count { |n| n && n > 0 }
    total = lines.compact.count
    percentage = total > 0 ? (covered.to_f / total * 100).round(2) : 0
    
    files[file.split('/').last] = {
      covered: covered,
      total: total,
      percentage: percentage,
      uncovered: lines.each_with_index.select { |n, i| n == 0 }.map { |_, i| i + 1 },
      full_path: file
    }
  end

  # Sort by percentage (lowest first)
  sorted = files.sort_by { |_, v| v[:percentage] }

  puts "Coverage Analysis for train-juniper"
  puts "=" * 60
  puts
  
  # Show files with less than 100% coverage
  incomplete_files = sorted.select { |_, data| data[:percentage] < 100 }
  
  if incomplete_files.any?
    puts "Files needing coverage improvements:"
    puts "-" * 60
    incomplete_files.each do |file, data|
      puts "\n#{file}: #{data[:percentage]}% (#{data[:covered]}/#{data[:total]})"
      if data[:uncovered].any?
        puts "  Uncovered lines: #{data[:uncovered].join(', ')}"
        puts "  Full path: #{data[:full_path]}"
      end
    end
  else
    puts "🎉 All files have 100% coverage!"
  end

  # Show files with 100% coverage
  complete_files = sorted.select { |_, data| data[:percentage] == 100 }
  if complete_files.any?
    puts "\n" + "=" * 60
    puts "Files with complete coverage (100%):"
    puts "-" * 60
    complete_files.each do |file, data|
      puts "✓ #{file}: #{data[:covered]} lines"
    end
  end

  # Overall statistics
  puts "\n" + "=" * 60
  puts "Overall Coverage Statistics:"
  puts "-" * 60
  total_covered = files.values.sum { |v| v[:covered] }
  total_lines = files.values.sum { |v| v[:total] }
  overall = (total_covered.to_f / total_lines * 100).round(2)
  puts "Total lines: #{total_lines}"
  puts "Covered lines: #{total_covered}"
  puts "Overall coverage: #{overall}%"
  
  # Summary
  puts "\n" + "=" * 60
  puts "Summary:"
  puts "-" * 60
  puts "Files analyzed: #{files.count}"
  puts "Files with 100% coverage: #{complete_files.count}"
  puts "Files needing improvement: #{incomplete_files.count}"
  
  if overall >= 90
    puts "\n✅ Coverage exceeds 90% threshold - excellent!"
  elsif overall >= 80
    puts "\n✅ Coverage meets 80% industry standard"
  else
    puts "\n⚠️  Coverage below 80% industry standard"
  end
  
  # Actionable recommendations
  if incomplete_files.any?
    puts "\n" + "=" * 60
    puts "Recommendations:"
    puts "-" * 60
    
    # Find the files with most impact potential
    impact_files = incomplete_files.sort_by { |_, data| 
      # Sort by potential impact (uncovered lines * importance)
      uncovered_count = data[:total] - data[:covered]
      importance = data[:total].to_f / total_lines * 100
      uncovered_count * importance
    }.reverse.first(3)
    
    puts "Focus on these files for maximum coverage improvement:"
    impact_files.each_with_index do |(file, data), i|
      uncovered = data[:total] - data[:covered]
      puts "#{i + 1}. #{file}: #{uncovered} uncovered lines (currently #{data[:percentage]}%)"
    end
  end
end

# Run the analysis
if __FILE__ == $0
  analyze_coverage
end