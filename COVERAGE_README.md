# Coverage Testing Script

This project includes a coverage testing script that fails if coverage is below a specified threshold.

## Usage

```bash
# Run with default threshold (80%)
./test_with_coverage.sh

# Run with custom threshold
./test_with_coverage.sh 60
```

## Current Coverage Status

- **Current Coverage**: 44.0%
- **Files Covered**: 16 files
- **Lines Hit**: 481 of 1094 lines

## How it Works

1. Runs `flutter test --coverage` to generate test coverage data
2. Generates an HTML coverage report using `genhtml`
3. Extracts the coverage percentage
4. Compares against the threshold
5. Exits with error code 1 if coverage is below threshold

## Coverage Report

After running the script, you can view the detailed coverage report:
- Open `coverage/html/index.html` in your browser
- Shows line-by-line coverage for each file

## Examples

```bash
# This will PASS (44% >= 40%)
./test_with_coverage.sh 40

# This will FAIL (44% < 50%)
./test_with_coverage.sh 50

# This will FAIL (44% < 80% - default)
./test_with_coverage.sh
```

## CI/CD Integration

Add to your CI pipeline to enforce coverage standards:

```yaml
- name: Check coverage
  run: ./test_with_coverage.sh 45
```

## Dependencies

The script requires:
- `flutter` command
- `genhtml` (from lcov package) - Install with `brew install lcov`