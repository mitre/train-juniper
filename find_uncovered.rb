#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simplecov'
require 'json'

# Load the resultset
resultset = SimpleCov::ResultMerger.resultset
result = SimpleCov::Result.from_hash(resultset)

# Find files with uncovered lines
result.files.each do |file|
  uncovered = file.lines.select { |line| line.coverage.zero? && line.src.strip != '' && !line.src.strip.start_with?('#') }
  next unless uncovered.any?

  puts "\n#{file.filename}:"
  uncovered.each do |line|
    puts "  Line #{line.number}: #{line.src.strip}"
  end
end

puts "\nTotal coverage: #{result.covered_percent.round(2)}%"
