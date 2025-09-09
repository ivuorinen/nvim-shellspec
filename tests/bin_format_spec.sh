#!/bin/bash
# Unit tests for bin/shellspec-format standalone formatter
# Tests the CLI formatter against the same test cases used for Lua implementation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FORMATTER="$PROJECT_ROOT/bin/shellspec-format"

# Helper functions
print_test() {
  echo -e "${YELLOW}[BIN-TEST]${NC} $1"
  # Force flush
  exec 1>&1
}

print_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((TESTS_PASSED++))
  # Force flush
  exec 1>&1
}

print_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((TESTS_FAILED++))
  # Force flush
  exec 1>&1
}

print_summary() {
  echo ""
  echo "Standalone Formatter Test Results:"
  echo "  Passed: $TESTS_PASSED"
  echo "  Failed: $TESTS_FAILED"
  echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"

  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Some standalone formatter tests failed!${NC}"
    exit 1
  else
    echo -e "${GREEN}All standalone formatter tests passed!${NC}"
  fi
}

# Function to run a formatting test
run_format_test() {
  local test_name="$1"
  local input_content="$2"
  local expected_content="$3"

  print_test "Testing $test_name"

  # Create temporary files
  local input_file
  local expected_file
  local actual_file
  input_file=$(mktemp -t "bin_format_input_XXXXXX.spec.sh")
  expected_file=$(mktemp -t "bin_format_expected_XXXXXX.spec.sh")
  actual_file=$(mktemp -t "bin_format_actual_XXXXXX.spec.sh")

  # Debug: Show what we're testing
  if [[ -n "${DEBUG:-}" ]]; then
    echo "  Input file: $input_file"
    echo "  Expected file: $expected_file"
    echo "  Actual file: $actual_file"
  fi

  # Write test data to files
  printf "%s\n" "$input_content" >"$input_file"
  printf "%s\n" "$expected_content" >"$expected_file"

  # Format using the standalone formatter
  if timeout 10 "$FORMATTER" <"$input_file" >"$actual_file" 2>/dev/null; then
    # Compare with expected output
    if diff -u "$expected_file" "$actual_file" >/dev/null; then
      print_pass "$test_name formatting matches expected output"
    else
      print_fail "$test_name formatting does not match expected output"
      echo "Expected:"
      cat "$expected_file"
      echo ""
      echo "Actual:"
      cat "$actual_file"
      echo ""
      echo "Diff:"
      diff -u "$expected_file" "$actual_file" || true
      echo ""
    fi
  else
    print_fail "$test_name formatting command failed"
  fi

  # Clean up
  rm -f "$input_file" "$expected_file" "$actual_file"
}

# Function to test CLI options
test_cli_options() {
  local test_name="$1"
  local options="$2"
  local input_content="$3"
  local expected_content="$4"

  print_test "Testing $test_name"

  # Create temporary files
  local input_file
  local expected_file
  local actual_file
  input_file=$(mktemp -t "bin_format_cli_input_XXXXXX.spec.sh")
  expected_file=$(mktemp -t "bin_format_cli_expected_XXXXXX.spec.sh")
  actual_file=$(mktemp -t "bin_format_cli_actual_XXXXXX.spec.sh")

  # Write test data to files
  printf "%s\n" "$input_content" >"$input_file"
  printf "%s\n" "$expected_content" >"$expected_file"

  # Format using the standalone formatter with options
  if timeout 10 bash -c "$FORMATTER $options < '$input_file' > '$actual_file'" 2>/dev/null; then
    # Compare with expected output
    if diff -u "$expected_file" "$actual_file" >/dev/null; then
      print_pass "$test_name formatting with options matches expected output"
    else
      print_fail "$test_name formatting with options does not match expected output"
      echo "Options: $options"
      echo "Expected:"
      cat "$expected_file"
      echo ""
      echo "Actual:"
      cat "$actual_file"
      echo ""
      echo "Diff:"
      diff -u "$expected_file" "$actual_file" || true
      echo ""
    fi
  else
    print_fail "$test_name formatting command with options failed"
  fi

  # Clean up
  rm -f "$input_file" "$expected_file" "$actual_file"
}

echo "Running bin/shellspec-format standalone formatter tests..."
echo "Project root: $PROJECT_ROOT"
echo "Formatter: $FORMATTER"
echo ""

# Verify formatter exists and is executable
if [[ ! -x "$FORMATTER" ]]; then
  echo -e "${RED}Error: Formatter not found or not executable: $FORMATTER${NC}"
  exit 1
fi

# Test 1: Basic block indentation (ported from format_spec.lua)
input1='Describe "test"
It "should work"
End
End'
expected1='Describe "test"
  It "should work"
  End
End'
run_format_test "Basic block indentation" "$input1" "$expected1"

# Test 2: Comment indentation (ported from format_spec.lua)
input2='Describe "test"
# Comment at Describe level
It "should work"
# Comment at It level
When call echo "test"
End
End'
expected2='Describe "test"
  # Comment at Describe level
  It "should work"
    # Comment at It level
    When call echo "test"
  End
End'
run_format_test "Comment indentation" "$input2" "$expected2"

# Test 3: HEREDOC preservation (ported from format_spec.lua)
run_format_test \
  "HEREDOC preservation" \
  'Describe "test"
It "handles heredoc"
When call cat <<EOF
  This should be preserved
    Even nested
EOF
The output should include "test"
End
End' \
  'Describe "test"
  It "handles heredoc"
    When call cat <<EOF
  This should be preserved
    Even nested
    EOF
    The output should include "test"
  End
End'

# Test 4: Nested contexts (ported from format_spec.lua)
run_format_test \
  "Nested contexts" \
  'Describe "outer"
Context "when something"
It "should work"
When call echo "test"
The output should equal "test"
End
End
End' \
  'Describe "outer"
  Context "when something"
    It "should work"
      When call echo "test"
      The output should equal "test"
    End
  End
End'

# Test 5: Hook keywords (ported from format_spec.lua)
run_format_test \
  "Hook keywords" \
  'Describe "test"
BeforeEach
setup_test
End
It "works"
When call test_function
End
End' \
  'Describe "test"
  BeforeEach
    setup_test
  End
  It "works"
    When call test_function
  End
End'

# CLI-specific tests

# Test 6: Custom indent size
test_cli_options \
  "Custom indent size (4 spaces)" \
  "--indent-size 4" \
  'Describe "test"
It "should work"
End
End' \
  'Describe "test"
    It "should work"
    End
End'

# Test 7: Tab indentation
input7='Describe "test"
It "should work"
End
End'
expected7='Describe "test"'$'\n\t''It "should work"'$'\n\t''End'$'\n''End'
test_cli_options "Tab indentation" "--tabs" "$input7" "$expected7"

# Test 8: No comment indentation
test_cli_options \
  "No comment indentation" \
  "--no-comment-indent" \
  'Describe "test"
# Top level comment
It "should work"
# Nested comment
End
End' \
  'Describe "test"
# Top level comment
  It "should work"
# Nested comment
  End
End'

# Test 9: Complex combination - tabs with custom indent size
input9='Describe "test"
Context "nested"
It "should work"
End
End
End'
expected9='Describe "test"'$'\n\t''Context "nested"'$'\n\t\t''It "should work"'$'\n\t\t''End'$'\n\t''End'$'\n''End'
test_cli_options "Tabs with custom indent size" "--tabs --indent-size 1" "$input9" "$expected9"

# Test error handling
print_test "Testing error handling - invalid indent size"
if timeout 5 echo 'test' | "$FORMATTER" --indent-size 0 >/dev/null 2>&1; then
  print_fail "Should have failed with invalid indent size"
else
  print_pass "Correctly rejected invalid indent size"
fi

print_test "Testing error handling - unknown option"
if timeout 5 echo 'test' | "$FORMATTER" --unknown-option >/dev/null 2>&1; then
  print_fail "Should have failed with unknown option"
else
  print_pass "Correctly rejected unknown option"
fi

print_summary
