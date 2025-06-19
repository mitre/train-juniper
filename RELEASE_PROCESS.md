# Release Process

This document describes the release process for the train-juniper gem.

## Overview

The train-juniper project uses a semi-automated release process that follows the RuboCop model:
- Version bumps and changelog generation happen locally
- Changes are committed and tagged locally
- GitHub Actions handles gem publication when tags are pushed

## Prerequisites

1. **Ensure you have git-cliff installed** (for changelog generation):
   ```bash
   brew install git-cliff
   ```

2. **Ensure you're on the main branch with a clean working directory**:
   ```bash
   git checkout main
   git pull origin main
   git status  # Should show no changes
   ```

3. **Ensure all tests pass**:
   ```bash
   bundle exec rake test
   bundle exec rake lint
   bundle exec rake security
   ```

4. **Verify trusted publishing is configured** on RubyGems.org:
   - Go to https://rubygems.org/gems/train-juniper/trusted_publishers
   - Should show: GitHub Repository: `mitre/train-juniper`, Workflow: `release-tag.yml`
   - No API keys needed - uses OIDC authentication!

## Release Steps

### 1. Choose Version Bump Type

Decide on the version bump based on [Semantic Versioning](https://semver.org/):
- **Patch** (0.5.0 → 0.5.1): Bug fixes, minor updates
- **Minor** (0.5.0 → 0.6.0): New features, backward compatible
- **Major** (0.5.0 → 1.0.0): Breaking changes

### 2. Prepare the Release

Execute the appropriate rake task to prepare the release:

```bash
# For patch release (bug fixes)
bundle exec rake release:patch

# For minor release (new features)
bundle exec rake release:minor

# For major release (breaking changes)
bundle exec rake release:major
```

This rake task will automatically:
- ✅ Update `lib/train-juniper/version.rb` with the new version
- ✅ Update `Gemfile.lock` with the new version
- ✅ Generate/update `CHANGELOG.md` using git-cliff (groups commits by type)
- ✅ Create release notes in `docs/release-notes/v{version}.md`
- ✅ Commit all changes with message "Bump version to {version}"
- ❌ Does NOT create a tag (Bundler will do this)

### 3. Review Changes

Before releasing, review what was changed:

```bash
# Review the commit
git show

# Check the updated CHANGELOG.md
cat CHANGELOG.md

# Check the release notes
cat docs/release-notes/v{version}.md
```

### 4. Push Changes

Push your commits to GitHub:

```bash
git push origin main
```

### 5. Create Tag and Publish

Use Bundler's standard release process:

```bash
bundle exec rake release
```

This will:
- ✅ Create tag `v{version}`
- ✅ Push the tag to GitHub
- ⏭️ Trigger GitHub Actions to build and publish the gem

### 5. Automated Publication

Once the tag is pushed, GitHub Actions will automatically:
1. Run the full test suite
2. Run security audits
3. Run linting checks
4. Create a GitHub Release using the pre-generated release notes
5. Build the gem
6. Publish to RubyGems.org using trusted publishing (OIDC authentication)

Monitor the release workflow at: https://github.com/mitre/train-juniper/actions

## Commit Message Convention

For better changelog generation, use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `test:` Test additions or fixes
- `refactor:` Code refactoring
- `chore:` Maintenance tasks
- `ci:` CI/CD changes

Examples:
```bash
git commit -m "feat: add support for JunOS 23.x"
git commit -m "fix: handle SSH timeout gracefully"
git commit -m "docs: update installation instructions"
```

## Manual Steps (if needed)

### Regenerate Changelog

If you need to regenerate the changelog:

```bash
git-cliff --tag v{version} -o CHANGELOG.md
```

### Create GitHub Release Manually

If the automated release fails, create manually:

1. Go to https://github.com/mitre/train-juniper/releases/new
2. Choose the tag you just pushed
3. Copy content from `docs/release-notes/v{version}.md`
4. Publish the release

### Publish Gem Manually

If gem publication fails:

```bash
gem build train-juniper.gemspec
gem push train-juniper-{version}.gem
```

## Troubleshooting

### "Working directory is not clean"
- Commit or stash your changes first
- Run `git status` to see what's changed

### "Must be on main branch"
- Switch to main: `git checkout main`
- Ensure it's up to date: `git pull origin main`

### Changelog not generating properly
- Ensure git-cliff is installed: `brew install git-cliff`
- Check `.cliff.toml` configuration exists
- Use conventional commit messages for better grouping

### GitHub Actions failing
- Check the [Actions tab](https://github.com/mitre/train-juniper/actions)
- Ensure trusted publishing is configured on RubyGems.org
- Verify all tests pass locally first

## Version History

See [CHANGELOG.md](../CHANGELOG.md) for the complete version history.