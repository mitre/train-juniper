# Documentation Guide

## Overview

The train-juniper project uses MkDocs with Material theme for documentation. The docs are automatically built and deployed to GitHub Pages on every push to the main branch.

## Documentation Structure

- **README.md** - Main project documentation (symlinked as docs/index.md)
- **docs/** - Additional documentation pages
- **mkdocs.yml** - MkDocs configuration

## Updating Documentation

### Method 1: Documentation-Only Changes
To update documentation without triggering a gem release:

1. Make your documentation changes
2. Commit with a descriptive message:
   ```bash
   git commit -m "docs: update installation guide"
   git commit -m "docs: fix typos in troubleshooting"
   ```
3. Push to main branch
4. GitHub Actions will automatically build and deploy to GitHub Pages

### Method 2: Manual Trigger
You can manually trigger the documentation build:

1. Go to [Actions tab](https://github.com/mitre/train-juniper/actions)
2. Select "Documentation" workflow
3. Click "Run workflow"

## Material Icons

The documentation uses Material Design icons (e.g., `:material-star:`). These render properly in the MkDocs site but appear as text in plain markdown viewers like GitHub.

This is intentional - the icons enhance the documentation site while remaining readable in plain text.

## Live Documentation

The documentation is available at: https://mitre.github.io/train-juniper/

## Local Preview

To preview documentation locally:

```bash
pip install mkdocs-material mkdocs-git-revision-date-localized-plugin
mkdocs serve
```

Then visit http://localhost:8000