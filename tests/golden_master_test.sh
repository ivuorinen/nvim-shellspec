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

# Helper functions
print_test() {
  echo -e "${YELLOW}[GOLDEN]${NC} $1"
}

print_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((TESTS_PASSED++))
}

print_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((TESTS_FAILED++))
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

# Test case definitions
# Format: "test_name|input_content|expected_content"
declare -a TEST_CASES=(
  "basic_nesting|Describe \"basic nesting test\"
Context \"when something happens\"
It \"should work correctly\"
When call echo \"test\"
The output should equal \"test\"
End
End
End|Describe \"basic nesting test\"
  Context \"when something happens\"
    It \"should work correctly\"
      When call echo \"test\"
      The output should equal \"test\"
    End
  End
End"

  "comments_and_hooks|Describe \"comments and hooks test\"
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
End|Describe \"comments and hooks test\"
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

  "heredoc_complex|Describe \"complex HEREDOC test\"
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
End|Describe \"complex HEREDOC test\"
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
)

# Function to run a single test case
run_test_case() {
  local test_data="$1"

  # Parse test data using parameter expansion (more reliable for multiline content)
  local test_name="${test_data%%|*}"       # Everything before first |
  local remaining="${test_data#*|}"        # Everything after first |
  local input_content="${remaining%%|*}"   # Everything before next |
  local expected_content="${remaining#*|}" # Everything after second |

  print_test "Testing $test_name"

  # Create temporary files
  local input_file
  local expected_file
  local actual_file
  input_file=$(mktemp -t "shellspec_input_XXXXXX.spec.sh")
  expected_file=$(mktemp -t "shellspec_expected_XXXXXX.spec.sh")
  actual_file=$(mktemp -t "shellspec_actual_XXXXXX.spec.sh")

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
for test_case in "${TEST_CASES[@]}"; do
  run_test_case "$test_case"
done

print_summary
