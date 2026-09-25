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

# Temp files are registered here so an interrupted run does not leave them in
# $TMPDIR; the per-test `rm -f` only covers the success path.
# `rm -rf` because the symlink test registers a directory.
TMPFILES=()
cleanup() { [[ ${#TMPFILES[@]} -gt 0 ]] && rm -rf -- "${TMPFILES[@]}"; }
# INT/TERM exit explicitly (EXIT then runs cleanup): a handler that only
# cleans up lets bash resume, so an interrupted run kept executing cases.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Helper functions
print_test() {
  echo -e "${YELLOW}[BIN-TEST]${NC} $1"
}

# Counters use $(( )) rather than ((x++)): under `set -e` a bare ((x++)) exits 1
# when x is 0, because post-increment evaluates to the old value -- which
# aborted the whole suite at its first passing assertion.
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
  TMPFILES+=("$input_file" "$expected_file" "$actual_file")

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
  TMPFILES+=("$input_file" "$expected_file" "$actual_file")

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

# Regression: a bare ((indent_level++)) under `set -e` exits 1 the first time a
# block keyword is seen, so stdin mode emitted only its first line. Asserts the
# whole input comes back, not just that the exit status is 0.
print_test "Testing stdin mode emits every line"
stdin_out=$(printf 'Describe "x"\nIt "y"\nWhen call echo hi\nEnd\nEnd\n' | timeout 10 "$FORMATTER")
stdin_lines=$(printf '%s\n' "$stdin_out" | wc -l)
if [[ $stdin_lines -eq 5 ]]; then
  print_pass "stdin mode emitted all 5 lines"
else
  print_fail "stdin mode emitted $stdin_lines of 5 lines"
  printf '%s\n' "$stdin_out"
fi

# Regression: mktemp creates 0600 and mv carries that onto the destination
# inode, so in-place formatting used to strip the executable bit.
print_test "Testing in-place formatting preserves file mode"
mode_file=$(mktemp -t "bin_format_mode_XXXXXX.spec.sh")
TMPFILES+=("$mode_file")
printf 'Describe "x"\nIt "y"\nEnd\nEnd\n' >"$mode_file"
chmod 755 "$mode_file"
timeout 10 "$FORMATTER" "$mode_file"
# GNU stat first: on BSD/macOS `-c` is rejected and the `-f` form runs. The
# reverse order silently succeeds on GNU, where `-f` means --file-system.
actual_mode=$(stat -c '%a' "$mode_file" 2>/dev/null || stat -f '%Lp' "$mode_file")
if [[ "$actual_mode" == "755" ]]; then
  print_pass "In-place formatting preserved mode 755"
else
  print_fail "In-place formatting changed mode 755 -> $actual_mode"
fi
rm -f "$mode_file"

# Regression: `<<<` contains `<<"` at offset 1 and used to match the
# double-quoted HEREDOC pattern, after which nothing was formatted.
# shellcheck disable=SC2016  # $input is literal spec text, not a shell expansion
run_format_test \
  "Here-string is not a HEREDOC" \
  'Describe "x"
It "y"
When call grep foo <<<"$input"
The status should be success
End
End' \
  'Describe "x"
  It "y"
    When call grep foo <<<"$input"
    The status should be success
  End
End'

# Regression: the HEREDOC check used to run before the comment check, so a
# comment merely naming a delimiter stopped all further formatting.
run_format_test \
  "Comment mentioning a HEREDOC is not a HEREDOC" \
  'Describe "x"
# note: uses <<EOF here
It "y"
When call echo hi
End
End' \
  'Describe "x"
  # note: uses <<EOF here
  It "y"
    When call echo hi
  End
End'

# Regression: the HEREDOC branch used to win over the block-keyword check, so a
# line that was both never opened its block and End misaligned.
run_format_test \
  "Block keyword that also opens a HEREDOC" \
  'Describe "x"
It "y" <<EOF
body
EOF
End
End' \
  'Describe "x"
  It "y" <<EOF
body
EOF
  End
End'

# Regression: `while read` skipped a final line with no trailing newline, so
# stdin mode dropped it and in-place mode deleted it from the file.
print_test "Testing a final line without a trailing newline is kept"
nonl_out=$(printf 'Describe "x"\nEnd' | timeout 10 "$FORMATTER")
nonl_file=$(mktemp -t "bin_format_nonl_XXXXXX.spec.sh")
TMPFILES+=("$nonl_file")
printf 'Describe "x"\nEnd' >"$nonl_file"
timeout 10 "$FORMATTER" "$nonl_file"
if [[ "$nonl_out" == $'Describe "x"\nEnd' && "$(cat "$nonl_file")" == $'Describe "x"\nEnd' ]]; then
  print_pass "stdin and in-place modes keep the unterminated last line"
else
  print_fail "unterminated last line lost: stdin='$nonl_out' file='$(cat "$nonl_file")'"
fi
rm -f "$nonl_file"

# Regression: in-place mode ignored write errors, and the truncated temp file
# replaced the original. `ulimit -f 0` with SIGXFSZ ignored makes every write
# fail with EFBIG, the same failure a full disk produces.
print_test "Testing in-place mode keeps the original when writing fails"
wfail_file=$(mktemp -t "bin_format_wfail_XXXXXX.spec.sh")
TMPFILES+=("$wfail_file")
printf 'Describe "x"\nIt "y"\nEnd\nEnd\n' >"$wfail_file"
if bash -c 'trap "" XFSZ; ulimit -f 0; exec "$1" "$2"' _ "$FORMATTER" "$wfail_file" 2>/dev/null; then
  print_fail "write failure exited 0"
elif [[ "$(cat "$wfail_file")" == $'Describe "x"\nIt "y"\nEnd\nEnd' ]]; then
  print_pass "write failure exits non-zero and leaves the file intact"
else
  print_fail "write failure changed the file to: $(cat "$wfail_file")"
fi
rm -f "$wfail_file"

# Regression: renaming onto a symlink replaced it with a regular file and left
# the target unformatted.
print_test "Testing in-place formatting through a symlink"
link_dir=$(mktemp -d)
TMPFILES+=("$link_dir")
printf 'Describe "x"\nIt "y"\nEnd\nEnd\n' >"$link_dir/real_spec.sh"
ln -s real_spec.sh "$link_dir/link_spec.sh"
timeout 10 "$FORMATTER" "$link_dir/link_spec.sh"
if [[ -L "$link_dir/link_spec.sh" && "$(sed -n 2p "$link_dir/real_spec.sh")" == '  It "y"' ]]; then
  print_pass "symlink kept and its target formatted"
else
  print_fail "symlink replaced or target unformatted"
fi
rm -rf "$link_dir"

# Regression: a leading zero made bash read --indent-size as octal.
test_cli_options \
  "Indent size with a leading zero is decimal" \
  "--indent-size 010" \
  'Describe "test"
It "should work"
End
End' \
  'Describe "test"
          It "should work"
          End
End'

# Regression: `<< EOF`, lowercase and backslash-quoted delimiters were not
# detected, so the terminator was indented and the HEREDOC never closed.
run_format_test \
  "POSIX HEREDOC spellings" \
  'Describe "x"
It "y"
When call cat << EOF
  body
EOF
When call cat <<\end
  body
end
End
End' \
  'Describe "x"
  It "y"
    When call cat << EOF
  body
EOF
    When call cat <<\end
  body
end
  End
End'

print_summary
