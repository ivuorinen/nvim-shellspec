#!/bin/bash
# Golden master tests for nvim-shellspec formatting
# Uses dynamic test generation to avoid pre-commit interference

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Counters use $(( )) rather than ((x++)): under `set -e` a bare ((x++)) exits 1
# when x is 0, because post-increment evaluates to the old value -- which
# aborted the whole suite at its first passing assertion.

# Temp files are registered here so an interrupted run does not leave them in
# $TMPDIR; the per-test `rm -f` only covers the success path.
TMPFILES=()
cleanup() { [[ ${#TMPFILES[@]} -gt 0 ]] && rm -f "${TMPFILES[@]}"; }
# INT/TERM exit explicitly (EXIT then runs cleanup): a handler that only
# cleans up lets bash resume, so an interrupted run kept executing cases.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Helper functions
print_test() {
  echo -e "${YELLOW}[GOLDEN]${NC} $1"
}

print_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_summary() {
  echo ""
  echo "Golden Master Test Results:"
  echo "  Passed: $TESTS_PASSED"
  echo "  Failed: $TESTS_FAILED"
  echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"

  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Some golden master tests failed!${NC}"
    exit 1
  else
    echo -e "${GREEN}All golden master tests passed!${NC}"
  fi
}

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Running nvim-shellspec golden master tests..."
echo "Project root: $PROJECT_ROOT"
echo ""

# Test case definitions: add_case NAME INPUT EXPECTED.
#
# Parallel arrays rather than one "name|input|expected" string: ShellSpec data
# blocks use `#|` lines and specs use shell pipes, and splitting on `|` cut
# such a case at the wrong place.
CASE_NAMES=()
CASE_INPUTS=()
CASE_EXPECTED=()
add_case() {
  CASE_NAMES+=("$1")
  CASE_INPUTS+=("$2")
  CASE_EXPECTED+=("$3")
}

add_case basic_nesting "Describe \"basic nesting test\"
Context \"when something happens\"
It \"should work correctly\"
When call echo \"test\"
The output should equal \"test\"
End
End
End" "Describe \"basic nesting test\"
  Context \"when something happens\"
    It \"should work correctly\"
      When call echo \"test\"
      The output should equal \"test\"
    End
  End
End"

add_case comments_and_hooks "Describe \"comments and hooks test\"
# Top level comment
BeforeAll
setup_global_state
End
# Another top level comment
Context \"with hooks and comments\"
# Context level comment
BeforeEach
setup_test
End
# More context comments
It \"should handle everything correctly\"
# Comment inside It block
When call test_function
# Another comment in It
The status should be success
End
AfterEach
cleanup_test
End
End
AfterAll
cleanup_global_state
End
End" "Describe \"comments and hooks test\"
  # Top level comment
  BeforeAll
    setup_global_state
  End
  # Another top level comment
  Context \"with hooks and comments\"
    # Context level comment
    BeforeEach
      setup_test
    End
    # More context comments
    It \"should handle everything correctly\"
      # Comment inside It block
      When call test_function
      # Another comment in It
      The status should be success
    End
    AfterEach
      cleanup_test
    End
  End
  AfterAll
    cleanup_global_state
  End
End"

add_case heredoc_complex "Describe \"complex HEREDOC test\"
Context \"with multiple HEREDOC types\"
It \"handles regular HEREDOC\"
When call cat <<EOF
This should be preserved
  Even nested indentation
Back to normal
EOF
The output should include \"preserved\"
End
It \"handles quoted HEREDOC\"
When call cat <<'DATA'
# Comments in heredoc should not be touched
Some \$variable should not be expanded
DATA
The output should include \"variable\"
End
It \"handles double-quoted HEREDOC\"
When call cat <<\"SCRIPT\"
echo \"This is a script\"
# Script comment
SCRIPT
The status should be success
End
End
End" "Describe \"complex HEREDOC test\"
  Context \"with multiple HEREDOC types\"
    It \"handles regular HEREDOC\"
      When call cat <<EOF
This should be preserved
  Even nested indentation
Back to normal
EOF
      The output should include \"preserved\"
    End
    It \"handles quoted HEREDOC\"
      When call cat <<'DATA'
# Comments in heredoc should not be touched
Some \$variable should not be expanded
DATA
      The output should include \"variable\"
    End
    It \"handles double-quoted HEREDOC\"
      When call cat <<\"SCRIPT\"
echo \"This is a script\"
# Script comment
SCRIPT
      The status should be success
    End
  End
End"

# Data blocks, mocks and pipes: exercises `#|` and `|` in case content, and the
# Mock / Data:raw / Parameters:block openers.
add_case blocks_and_pipes "Describe \"blocks\"
Mock date
echo 2019
End
It \"reads data\"
Data:raw
#|line one
#|line two
End
When call cat | tr a b
The output should be present
End
Parameters:block
\"a\" 1
End
End" "Describe \"blocks\"
  Mock date
    echo 2019
  End
  It \"reads data\"
    Data:raw
      #|line one
      #|line two
    End
    When call cat | tr a b
    The output should be present
  End
  Parameters:block
    \"a\" 1
  End
End"

# Function to run a single test case
run_test_case() {
  local test_name="$1"
  local input_content="$2"
  local expected_content="$3"

  print_test "Testing $test_name"

  # Create temporary files
  local input_file
  local expected_file
  local actual_file
  input_file=$(mktemp -t "shellspec_input_XXXXXX.spec.sh")
  TMPFILES+=("${input_file}")
  expected_file=$(mktemp -t "shellspec_expected_XXXXXX.spec.sh")
  TMPFILES+=("${expected_file}")
  actual_file=$(mktemp -t "shellspec_actual_XXXXXX.spec.sh")
  TMPFILES+=("${actual_file}")

  # Write test data to files
  printf "%s\n" "$input_content" >"$input_file"
  printf "%s\n" "$expected_content" >"$expected_file"
  cp "$input_file" "$actual_file"

  # Format the actual file using nvim-shellspec
  if timeout 10 nvim --headless -u NONE \
    -c "set rtp+=$PROJECT_ROOT" \
    -c "source plugin/shellspec.vim" \
    -c "edit $actual_file" \
    -c "set filetype=shellspec" \
    -c "ShellSpecFormat" \
    -c "write" \
    -c "quit" </dev/null >/dev/null 2>&1; then

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

# Run all test cases
for i in "${!CASE_NAMES[@]}"; do
  run_test_case "${CASE_NAMES[$i]}" "${CASE_INPUTS[$i]}" "${CASE_EXPECTED[$i]}"
done

print_summary
