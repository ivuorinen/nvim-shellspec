#!/bin/bash
# Integration tests for nvim-shellspec plugin
# Tests actual plugin loading, command registration, and formatting in Neovim/Vim

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
  echo -e "${YELLOW}[TEST]${NC} $1"
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
  echo "Integration Test Results:"
  echo "  Passed: $TESTS_PASSED"
  echo "  Failed: $TESTS_FAILED"
  echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"

  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
  else
    echo -e "${GREEN}All tests passed!${NC}"
  fi
}

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Running nvim-shellspec integration tests..."
echo "Project root: $PROJECT_ROOT"
echo ""

# Test 1: Check Neovim version compatibility
print_test "Neovim version compatibility"
if command -v nvim >/dev/null 2>&1; then
  NVIM_VERSION=$(nvim --version | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
  MAJOR=$(echo "$NVIM_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
  MINOR=$(echo "$NVIM_VERSION" | cut -d'v' -f2 | cut -d'.' -f2)

  if [ "$MAJOR" -gt 0 ] || [ "$MINOR" -ge 7 ]; then
    print_pass "Neovim $NVIM_VERSION >= 0.7.0"
  else
    print_fail "Neovim $NVIM_VERSION < 0.7.0 (some features may not work)"
  fi
else
  print_fail "Neovim not found"
fi

# Test 2: Plugin loads without errors (Neovim path)
print_test "Plugin loads in Neovim without errors"
if timeout 10 nvim --headless -u NONE -c "set rtp+=$PROJECT_ROOT" -c "source plugin/shellspec.vim" -c "quit" </dev/null >/dev/null 2>&1; then
  print_pass "Plugin loads successfully in Neovim"
else
  print_fail "Plugin failed to load in Neovim"
fi

# Test 3: Commands are registered
print_test "Commands are registered (ShellSpecFormat)"
if timeout 10 nvim --headless -u NONE -c "set rtp+=$PROJECT_ROOT" -c "source plugin/shellspec.vim" -c "if exists(':ShellSpecFormat') | echo 'SUCCESS' | else | cquit | endif" -c "quit" </dev/null 2>/dev/null | grep -q "SUCCESS"; then
  print_pass "ShellSpecFormat command is registered"
else
  print_fail "ShellSpecFormat command not found"
fi

print_test "Commands are registered (ShellSpecFormatRange)"
if timeout 10 nvim --headless -u NONE -c "set rtp+=$PROJECT_ROOT" -c "source plugin/shellspec.vim" -c "if exists(':ShellSpecFormatRange') | echo 'SUCCESS' | else | cquit | endif" -c "quit" </dev/null 2>/dev/null | grep -q "SUCCESS"; then
  print_pass "ShellSpecFormatRange command is registered"
else
  print_fail "ShellSpecFormatRange command not found"
fi

# Test 4: Filetype detection
print_test "Filetype detection for .spec.sh files"
TEST_FILE=$(mktemp -t "shellspec_test_XXXXXX.spec.sh")
echo 'Describe "test"' >"$TEST_FILE"
if timeout 10 nvim --headless -u NONE -c "set rtp+=$PROJECT_ROOT" -c "source plugin/shellspec.vim" -c "edit $TEST_FILE" -c "if &filetype == 'shellspec' | echo 'SUCCESS' | else | cquit | endif" -c "quit" </dev/null 2>/dev/null | grep -q "SUCCESS"; then
  print_pass "Filetype correctly detected as 'shellspec'"
else
  print_fail "Filetype not detected correctly"
fi
rm -f "$TEST_FILE"

# Test 5: Actual formatting works
print_test "Formatting functionality works correctly"
TEST_FILE=$(mktemp -t "shellspec_test_XXXXXX.spec.sh")
EXPECTED_FILE=$(mktemp -t "shellspec_expected_XXXXXX.spec.sh")

# Create test input (unformatted)
cat >"$TEST_FILE" <<'EOF'
Describe "test"
# Comment
It "works"
When call echo "test"
The output should equal "test"
End
End
EOF

# Create expected output (properly formatted)
cat >"$EXPECTED_FILE" <<'EOF'
Describe "test"
  # Comment
  It "works"
    When call echo "test"
    The output should equal "test"
  End
End
EOF

# Format the file
if timeout 10 nvim --headless -u NONE -c "set rtp+=$PROJECT_ROOT" -c "source plugin/shellspec.vim" -c "edit $TEST_FILE" -c "set filetype=shellspec" -c "ShellSpecFormat" -c "write" -c "quit" </dev/null >/dev/null 2>&1; then
  # Compare result with expected
  if diff -u "$EXPECTED_FILE" "$TEST_FILE" >/dev/null; then
    print_pass "Formatting produces correct output"
  else
    print_fail "Formatting output doesn't match expected"
    echo "Expected:"
    cat "$EXPECTED_FILE"
    echo "Actual:"
    cat "$TEST_FILE"
  fi
else
  print_fail "Formatting command failed"
fi

rm -f "$TEST_FILE" "$EXPECTED_FILE"

# Test 6: HEREDOC preservation
print_test "HEREDOC preservation works correctly"
TEST_FILE=$(mktemp -t "shellspec_test_XXXXXX.spec.sh")
EXPECTED_FILE=$(mktemp -t "shellspec_expected_XXXXXX.spec.sh")

# Create test input with HEREDOC (unformatted)
cat >"$TEST_FILE" <<'EOF'
Describe "heredoc test"
It "preserves heredoc"
When call cat <<DATA
  This should be preserved
    Even nested
DATA
The output should include "preserved"
End
End
EOF

# Create expected output (properly formatted with HEREDOC preserved)
cat >"$EXPECTED_FILE" <<'EOF'
Describe "heredoc test"
  It "preserves heredoc"
    When call cat <<DATA
  This should be preserved
    Even nested
    DATA
    The output should include "preserved"
  End
End
EOF

# Format the file
if timeout 10 nvim --headless -u NONE -c "set rtp+=$PROJECT_ROOT" -c "source plugin/shellspec.vim" -c "edit $TEST_FILE" -c "set filetype=shellspec" -c "ShellSpecFormat" -c "write" -c "quit" </dev/null >/dev/null 2>&1; then
  # Compare result with expected
  if diff -u "$EXPECTED_FILE" "$TEST_FILE" >/dev/null; then
    print_pass "HEREDOC preservation works correctly"
  else
    print_fail "HEREDOC preservation failed"
    echo "Expected:"
    cat "$EXPECTED_FILE"
    echo "Actual:"
    cat "$TEST_FILE"
  fi
else
  print_fail "HEREDOC formatting command failed"
fi

rm -f "$TEST_FILE" "$EXPECTED_FILE"

# Test 7: Health check (if available)
print_test "Health check functionality"
if timeout 10 nvim --headless -u NONE -c "set rtp+=$PROJECT_ROOT" -c "source plugin/shellspec.vim" -c "checkhealth shellspec" -c "quit" </dev/null 2>/dev/null | grep -q "ShellSpec.nvim"; then
  print_pass "Health check works"
else
  print_fail "Health check not available or failed"
fi

# Test 8: Vim fallback (if vim is available)
if command -v vim >/dev/null 2>&1; then
  print_test "Vim fallback compatibility"
  if vim -u NONE -c "set rtp+=$PROJECT_ROOT" -c "source plugin/shellspec.vim" -c "if exists(':ShellSpecFormat') | echo 'SUCCESS' | endif" -c "quit" 2>/dev/null | grep -q "SUCCESS"; then
    print_pass "Vim fallback works correctly"
  else
    print_fail "Vim fallback failed"
  fi
else
  print_test "Vim fallback compatibility (skipped - vim not available)"
fi

print_summary
