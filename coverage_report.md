# Coverage Analysis for train-juniper

Generated: 2025-06-23 01:36:49

## Overall Statistics

| Metric | Value |
|--------|-------|
| Overall Coverage | **94.77%** |
| Total Lines | 421 |
| Covered Lines | 399 |
| Files Analyzed | 13 |
| Files with 100% | 11 |
| Files Needing Work | 2 |

## Files Needing Coverage Improvements

| File | Coverage | Lines | Uncovered Lines |
|------|----------|-------|-----------------|
| `ssh_session.rb` | 66.67% | 28/42 | 26, 32, 34, 36, 39... |
| `command_executor.rb` | 79.49% | 31/39 | 31, 33, 36, 38, 41... |

## Files with Complete Coverage (100%)

| File | Lines Covered |
|------|---------------|
| ✅ `constants.rb` | 12 |
| ✅ `platform.rb` | 59 |
| ✅ `validation.rb` | 29 |
| ✅ `error_handling.rb` | 18 |
| ✅ `bastion_proxy.rb` | 42 |
| ✅ `environment.rb` | 11 |
| ✅ `logging.rb` | 30 |
| ✅ `mock_responses.rb` | 14 |
| ✅ `transport.rb` | 28 |
| ✅ `juniper_file.rb` | 26 |
| ✅ `connection.rb` | 71 |

## Recommendations

Focus on these files for maximum coverage improvement:

1. **ssh_session.rb**: 14 uncovered lines (currently 66.67%)
   - Lines to cover: 26, 32, 34, 36, 39, 40, 41, 44, 45, 48, 49, 52, 53, 54
2. **command_executor.rb**: 8 uncovered lines (currently 79.49%)
   - Lines to cover: 31, 33, 36, 38, 41, 42, 43, 45

---

✅ **Coverage exceeds 90% threshold - excellent!**