# frozen_string_literal: true

require 'time'

namespace :release do # rubocop:disable Metrics/BlockLength
  desc 'Cut a new patch release (e.g., 0.5.0 -> 0.5.1)'
  task :patch do
    release('patch')
  end

  desc 'Cut a new minor release (e.g., 0.5.0 -> 0.6.0)'
  task :minor do
    release('minor')
  end

  desc 'Cut a new major release (e.g., 0.5.0 -> 1.0.0)'
  task :major do
    release('major')
  end

  def release(type)
    # Ensure working directory is clean
    abort 'Error: Working directory is not clean. Commit or stash your changes first.' unless `git status --porcelain`.empty?

    # Ensure we're on main branch
    current_branch = `git rev-parse --abbrev-ref HEAD`.strip
    abort "Error: Must be on main branch to release (currently on #{current_branch})" unless current_branch == 'main'

    # Pull latest changes
    system('git pull origin main') or abort('Failed to pull latest changes')

    # Get current version
    version_file = 'lib/train-juniper/version.rb'
    current_version = File.read(version_file)[/VERSION = ['"](.+)['"]/, 1]
    puts "Current version: #{current_version}"

    # Calculate new version
    major, minor, patch = current_version.split('.').map(&:to_i)
    case type
    when 'major'
      new_version = "#{major + 1}.0.0"
    when 'minor'
      new_version = "#{major}.#{minor + 1}.0"
    when 'patch'
      new_version = "#{major}.#{minor}.#{patch + 1}"
    end
    puts "New version: #{new_version}"

    # Update version file
    content = File.read(version_file)
    content.gsub!(/VERSION = ['"]#{Regexp.escape(current_version)}['"]/, "VERSION = '#{new_version}'")
    File.write(version_file, content)
    puts "✓ Updated #{version_file}"

    # Update Gemfile.lock to reflect new version
    system('bundle install --quiet') or abort('Failed to update Gemfile.lock')
    puts '✓ Updated Gemfile.lock'

    # Update CHANGELOG.md
    update_changelog(new_version)

    # Create release notes
    create_release_notes(new_version)

    # Commit changes
    system("git add lib/train-juniper/version.rb Gemfile.lock CHANGELOG.md docs/release-notes/v#{new_version}.md")
    system("git commit -m 'Bump version to #{new_version}'") or abort('Failed to commit changes')

    puts "\n🎉 Release #{new_version} prepared!"
    puts "\nNext steps:"
    puts '  1. Review the changes: git show'
    puts '  2. Push commits: git push origin main'
    puts '  3. Run release: bundle exec rake release'
    puts "\nThis will:"
    puts "  - Create tag v#{new_version}"
    puts '  - Push the tag to GitHub'
    puts '  - Trigger GitHub Actions to publish the gem'
  end

  def update_changelog(version)
    changelog_file = 'CHANGELOG.md'

    # Generate full changelog using git-cliff if available
    if system('which git-cliff > /dev/null 2>&1')
      # Generate the full changelog with the new version
      system("git-cliff --tag v#{version} -o #{changelog_file}")
      puts '✓ Generated CHANGELOG.md with git-cliff'
    else
      # Manual fallback if git-cliff not available
      puts '⚠️  git-cliff not found. Creating basic changelog entry...'

      # Read current changelog or create new one
      changelog = if File.exist?(changelog_file)
                    File.read(changelog_file)
                  else
                    "# Changelog\n\nAll notable changes to this project will be documented in this file.\n"
                  end

      # Insert new version section
      date = Time.now.strftime('%Y-%m-%d')
      new_section = "\n## [#{version}] - #{date}\n\n"
      history_url = "https://github.com/mitre/train-juniper/compare/v#{current_version}...v#{version}"
      new_section += "- See [commit history](#{history_url}) for changes\n"

      # Insert after the header
      lines = changelog.lines
      header_lines = lines.take_while { |line| !line.start_with?('##') }
      rest_lines = lines.drop(header_lines.length)

      File.write(changelog_file, header_lines.join + new_section + rest_lines.join)
      puts '✓ Updated CHANGELOG.md (manual)'
    end
  end

  def create_release_notes(version)
    notes_dir = 'docs/release-notes'
    FileUtils.mkdir_p(notes_dir)

    notes_file = "#{notes_dir}/v#{version}.md"

    # Get list of changes since last tag
    last_tag = `git describe --tags --abbrev=0 2>/dev/null`.strip
    changes = if last_tag.empty?
                `git log --oneline`.lines.take(10)
              else
                `git log #{last_tag}..HEAD --oneline`.lines
              end

    # Format release notes
    content = <<~NOTES
      # Release Notes for v#{version}

      Released: #{Time.now.strftime('%Y-%m-%d')}

      ## What's Changed

      #{changes.map { |c| "- #{c.strip.sub(/^[a-f0-9]+ /, '')}" }.join("\n")}

      ## Installation

      ```bash
      gem install train-juniper -v #{version}
      ```

      Or add to your Gemfile:

      ```ruby
      gem 'train-juniper', '~> #{version}'
      ```

      ## Full Changelog

      See the [CHANGELOG](../../CHANGELOG.md) for complete details.
    NOTES

    File.write(notes_file, content)
    puts "✓ Created release notes at #{notes_file}"
  end

  def current_version
    File.read('lib/train-juniper/version.rb')[/VERSION = ['"](.+)['"]/, 1]
  end
end

desc 'Show current version'
task :version do
  puts File.read('lib/train-juniper/version.rb')[/VERSION = ['"](.+)['"]/, 1]
end
