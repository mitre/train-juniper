#!/usr/bin/env ruby
# frozen_string_literal: true

# Coverage Analysis Tool for train-juniper
# This script analyzes the coverage report and provides detailed information
# about which files and lines need coverage improvements

require 'json'
require 'optparse'

def parse_options
  options = { format: :human }

  OptionParser.new do |opts|
    opts.banner = 'Usage: coverage_analysis.rb [options]'

    opts.on('-f', '--format FORMAT', %i[human json markdown],
            'Output format: human (default), json, or markdown') do |format|
      options[:format] = format
    end

    opts.on('-o', '--output FILE', 'Output to file instead of stdout') do |file|
      options[:output] = file
    end

    opts.on('-h', '--help', 'Show this message') do
      puts opts
      exit
    end
  end.parse!

  options
end

def analyze_coverage(options = {})
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
    covered = lines.compact.count { |n| n&.positive? }
    total = lines.compact.count
    percentage = total.positive? ? (covered.to_f / total * 100).round(2) : 0

    files[file.split('/').last] = {
      covered: covered,
      total: total,
      percentage: percentage,
      uncovered: lines.each_with_index.select { |n, _i| n.zero? }.map { |_, i| i + 1 },
      full_path: file
    }
  end

  # Sort by percentage (lowest first)
  sorted = files.sort_by { |_, v| v[:percentage] }

  # Calculate overall statistics
  total_covered = files.values.sum { |v| v[:covered] }
  total_lines = files.values.sum { |v| v[:total] }
  overall = (total_covered.to_f / total_lines * 100).round(2)

  # Categorize files
  incomplete_files = sorted.select { |_, data| data[:percentage] < 100 }
  complete_files = sorted.select { |_, data| data[:percentage] == 100 }

  # Find impact files
  impact_files = incomplete_files.sort_by do |_, data|
    uncovered_count = data[:total] - data[:covered]
    importance = data[:total].to_f / total_lines * 100
    uncovered_count * importance
  end.reverse.first(3)

  # Format output based on selected format
  output = case options[:format]
           when :json
             format_json_output(files, overall, total_lines, total_covered, incomplete_files, complete_files, impact_files)
           when :markdown
             format_markdown_output(files, overall, total_lines, total_covered, incomplete_files, complete_files, impact_files)
           else
             format_human_output(files, overall, total_lines, total_covered, incomplete_files, complete_files, impact_files)
           end

  # Write to file or stdout
  if options[:output]
    File.write(options[:output], output)
    puts "Coverage analysis written to: #{options[:output]}"
  else
    puts output
  end
end

def format_human_output(files, overall, total_lines, total_covered, incomplete_files, complete_files, impact_files)
  output = []

  output << 'Coverage Analysis for train-juniper'
  output << ('=' * 60)
  output << ''

  if incomplete_files.any?
    output << 'Files needing coverage improvements:'
    output << ('-' * 60)
    incomplete_files.each do |file, data|
      output << "\n#{file}: #{data[:percentage]}% (#{data[:covered]}/#{data[:total]})"
      if data[:uncovered].any?
        output << "  Uncovered lines: #{data[:uncovered].join(', ')}"
        output << "  Full path: #{data[:full_path]}"
      end
    end
  else
    output << '🎉 All files have 100% coverage!'
  end

  if complete_files.any?
    output << "\n#{'=' * 60}"
    output << 'Files with complete coverage (100%):'
    output << ('-' * 60)
    complete_files.each do |file, data|
      output << "✓ #{file}: #{data[:covered]} lines"
    end
  end

  output << "\n#{'=' * 60}"
  output << 'Overall Coverage Statistics:'
  output << ('-' * 60)
  output << "Total lines: #{total_lines}"
  output << "Covered lines: #{total_covered}"
  output << "Overall coverage: #{overall}%"

  output << "\n#{'=' * 60}"
  output << 'Summary:'
  output << ('-' * 60)
  output << "Files analyzed: #{files.count}"
  output << "Files with 100% coverage: #{complete_files.count}"
  output << "Files needing improvement: #{incomplete_files.count}"

  output << if overall >= 90
              "\n✅ Coverage exceeds 90% threshold - excellent!"
            elsif overall >= 80
              "\n✅ Coverage meets 80% industry standard"
            else
              "\n⚠️  Coverage below 80% industry standard"
            end

  if impact_files.any?
    output << "\n#{'=' * 60}"
    output << 'Recommendations:'
    output << ('-' * 60)
    output << 'Focus on these files for maximum coverage improvement:'
    impact_files.each_with_index do |(file, data), i|
      uncovered = data[:total] - data[:covered]
      output << "#{i + 1}. #{file}: #{uncovered} uncovered lines (currently #{data[:percentage]}%)"
    end
  end

  output.join("\n")
end

def format_json_output(files, overall, total_lines, total_covered, incomplete_files, complete_files, impact_files)
  result = {
    overall: {
      percentage: overall,
      total_lines: total_lines,
      covered_lines: total_covered,
      files_analyzed: files.count,
      files_complete: complete_files.count,
      files_incomplete: incomplete_files.count
    },
    files: files.map do |name, data|
      {
        name: name,
        path: data[:full_path],
        percentage: data[:percentage],
        covered: data[:covered],
        total: data[:total],
        uncovered_lines: data[:uncovered]
      }
    end.sort_by { |f| f[:percentage] },
    recommendations: impact_files.map do |file, data|
      {
        file: file,
        current_coverage: data[:percentage],
        uncovered_lines: data[:total] - data[:covered],
        uncovered_line_numbers: data[:uncovered]
      }
    end
  }

  JSON.pretty_generate(result)
end

def format_markdown_output(files, overall, total_lines, total_covered, incomplete_files, complete_files, impact_files)
  output = []

  output << '# Coverage Analysis for train-juniper'
  output << ''
  output << "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  output << ''
  output << '## Overall Statistics'
  output << ''
  output << '| Metric | Value |'
  output << '|--------|-------|'
  output << "| Overall Coverage | **#{overall}%** |"
  output << "| Total Lines | #{total_lines} |"
  output << "| Covered Lines | #{total_covered} |"
  output << "| Files Analyzed | #{files.count} |"
  output << "| Files with 100% | #{complete_files.count} |"
  output << "| Files Needing Work | #{incomplete_files.count} |"
  output << ''

  if incomplete_files.any?
    output << '## Files Needing Coverage Improvements'
    output << ''
    output << '| File | Coverage | Lines | Uncovered Lines |'
    output << '|------|----------|-------|-----------------|'
    incomplete_files.each do |file, data|
      uncovered_summary = data[:uncovered].take(5).join(', ')
      uncovered_summary += '...' if data[:uncovered].length > 5
      output << "| `#{file}` | #{data[:percentage]}% | #{data[:covered]}/#{data[:total]} | #{uncovered_summary} |"
    end
    output << ''
  end

  if complete_files.any?
    output << '## Files with Complete Coverage (100%)'
    output << ''
    output << '| File | Lines Covered |'
    output << '|------|---------------|'
    complete_files.each do |file, data|
      output << "| ✅ `#{file}` | #{data[:covered]} |"
    end
    output << ''
  end

  if impact_files.any?
    output << '## Recommendations'
    output << ''
    output << 'Focus on these files for maximum coverage improvement:'
    output << ''
    impact_files.each_with_index do |(file, data), i|
      uncovered = data[:total] - data[:covered]
      output << "#{i + 1}. **#{file}**: #{uncovered} uncovered lines (currently #{data[:percentage]}%)"
      output << "   - Lines to cover: #{data[:uncovered].join(', ')}"
    end
  end

  output << ''
  output << '---'
  output << ''
  output << if overall >= 90
              '✅ **Coverage exceeds 90% threshold - excellent!**'
            elsif overall >= 80
              '✅ **Coverage meets 80% industry standard**'
            else
              '⚠️ **Coverage below 80% industry standard**'
            end

  output.join("\n")
end

# Run the analysis
if __FILE__ == $PROGRAM_NAME
  options = parse_options
  analyze_coverage(options)
end
