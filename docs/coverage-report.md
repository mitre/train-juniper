---
title: Coverage Report
description: Code coverage analysis for train-juniper
---

# Coverage Analysis

!!! info "Report Generated"
    2025-06-24 17:38:58

## :material-chart-line: Overall Statistics

<div class="grid cards" markdown>

- :material-percent: __Overall Coverage__

    ---

    ### **98.88%**

- :material-file-document-multiple: __Code Metrics__

    ---

    - Total Lines: **446**
    - Covered Lines: **441**
    - Files Analyzed: **15**

- :material-check-all: __Coverage Status__

    ---

    - Files with 100%: **14**
    - Files Needing Work: **1**

</div>

## :material-alert-circle: Files Needing Coverage Improvements

!!! warning "Coverage Gaps"
    The following files have uncovered lines:

| File | Coverage | Lines | Uncovered Lines |
|------|----------|-------|-----------------|
| `bastion_proxy.rb` | **88.1%** | 37/42 | `23, 53, 55, 62, 63` |


## :material-check-circle: Files with Complete Coverage

!!! success "Fully Tested Files"
    These files have achieved 100% code coverage:

<div class="annotate" markdown>

| File | Lines Covered | Status |
|------|---------------|--------|
| `connection.rb` | 71 | :material-check-all:{ .mdx-pulse } |
| `constants.rb` | 12 | :material-check-all:{ .mdx-pulse } |
| `platform.rb` | 59 | :material-check-all:{ .mdx-pulse } |
| `validation.rb` | 29 | :material-check-all:{ .mdx-pulse } |
| `command_executor.rb` | 31 | :material-check-all:{ .mdx-pulse } |
| `error_handling.rb` | 18 | :material-check-all:{ .mdx-pulse } |
| `ssh_session.rb` | 29 | :material-check-all:{ .mdx-pulse } |
| `windows_proxy.rb` | 22 | :material-check-all:{ .mdx-pulse } |
| `ssh_askpass.rb` | 24 | :material-check-all:{ .mdx-pulse } |
| `environment.rb` | 11 | :material-check-all:{ .mdx-pulse } |
| `logging.rb` | 30 | :material-check-all:{ .mdx-pulse } |
| `mock_responses.rb` | 14 | :material-check-all:{ .mdx-pulse } |
| `transport.rb` | 28 | :material-check-all:{ .mdx-pulse } |
| `juniper_file.rb` | 26 | :material-check-all:{ .mdx-pulse } |

</div>


## :material-target: Recommendations

!!! tip "Focus Areas"
    Focus on these files for maximum coverage improvement:

    1. **`bastion_proxy.rb`** - 5 uncovered lines (currently 88.1%)
        - Lines to cover: `23, 53, 55, 62, 63`

## :material-shield-check: Coverage Assessment

!!! success "Excellent Coverage"
    **Coverage exceeds 90% threshold** - Well-tested codebase!