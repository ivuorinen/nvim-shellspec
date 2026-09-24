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

# Counters use $(( )) rather than ((x++)): under `set -e` a bare ((x++)) exits 1
# when x is 0, because post-increment evaluates to the old value -- which
# aborted the whole suite at its first passing assertion.

# Temp files are registered here so an interrupted run does not leave them in
# $TMPDIR; the per-test `rm -f` only covers the success path. `rm -rf` because
# FT_DIR is a directory, which `rm -f` refuses to remove.
TMPFILES=()
cleanup() { [[ ${#TMPFILES[@]} -gt 0 ]] && rm -rf -- "${TMPFILES[@]}"; }
trap cleanup EXIT INT TERM

# Helper functions
print_test() {
  echo -e "${YELLOW}[TEST]${NC} $1"
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

# Test 2: Plugin loads without errors (Neovim path).
# Asserts on stderr, not the exit status: the plugin catches its own load error
# and reports it through vim.notify, after which nvim still exits 0 -- so a
# status check passed for a plugin that failed to load.
print_test "Plugin loads in Neovim without errors"
LOAD_ERR=$(timeout 10 nvim --headless -u NONE -c "set rtp+=$PROJECT_ROOT" -c "source plugin/shellspec.vim" -c "quit" </dev/null 2>&1 >/dev/null || true)
if [[ "$LOAD_ERR" == *"Failed to load"* || "$LOAD_ERR" == *"E5108"* || "$LOAD_ERR" == *"Error"* ]]; then
  print_fail "Plugin failed to load in Neovim: $LOAD_ERR"
else
  print_pass "Plugin loads successfully in Neovim"
fi

# Evaluate a Vimscript expression in a throwaway Neovim and echo the result.
#
# The result is written to a file rather than read off stdout: under --headless
# Neovim sends :echo output to stderr, so the `... 2>/dev/null | grep SUCCESS`
# form these assertions used could never match, and every one of them reported a
# working feature as broken.
nvim_eval() {
  local expr="$1"
  shift
  local out
  out=$(mktemp -t "shellspec_probe_XXXXXX")
  TMPFILES+=("$out")
  # Absolute source path: callers may run this from another directory to probe
  # relative-path filetype detection, and a relative `source` would silently
  # load nothing there, making every probe look like a plugin failure.
  #
  # The runtimepath is set and `filetype on` run via --cmd, before startup
  # finishes, as in a real session: -u NONE leaves filetype detection off, and
  # ftdetect/shellspec.vim -- the only detection source -- is sourced by it.
  timeout 10 nvim --headless -u NONE \
    --cmd "set rtp^=$PROJECT_ROOT" \
    --cmd "filetype on" \
    -c "source $PROJECT_ROOT/plugin/shellspec.vim" \
    "$@" \
    -c "call writefile([$expr], '$out')" \
    -c "quit" </dev/null >/dev/null 2>&1 || true
  cat "$out" 2>/dev/null
  rm -f "$out"
}

# Test 3: Commands are registered
for cmd in ShellSpecFormat ShellSpecFormatRange ShellSpecFormatAsync; do
  print_test "Commands are registered ($cmd)"
  if [[ "$(nvim_eval "string(exists(':$cmd'))")" == "2" ]]; then
    print_pass "$cmd command is registered"
  else
    print_fail "$cmd command not found"
  fi
done

# Test 4: Filetype detection
print_test "Filetype detection for .spec.sh files"
TEST_FILE=$(mktemp -t "shellspec_test_XXXXXX.spec.sh")
TMPFILES+=("${TEST_FILE}")
echo 'Describe "test"' >"$TEST_FILE"
if [[ "$(nvim_eval "&filetype" -c "edit $TEST_FILE")" == "shellspec" ]]; then
  print_pass "Filetype correctly detected as 'shellspec'"
else
  print_fail "Filetype not detected correctly"
fi
rm -f "$TEST_FILE"

# Test 4b: filetype detection boundaries.
#
# Each case is probed by BOTH a relative and an absolute path: Vim matches a
# slash-bearing pattern against the name as typed as well as the full path, so a
# rule can work for one form and not the other. Testing only absolute paths once
# led to the wrong conclusion that the directory rules never fired at all.
FT_DIR=$(mktemp -d)
TMPFILES+=("${FT_DIR}")
mkdir -p "$FT_DIR/spec/unit" "$FT_DIR/test"
printf '#!/bin/bash\n' >"$FT_DIR/spec/plain.sh"
printf '#!/bin/bash\n' >"$FT_DIR/spec/unit/deep.sh"
printf '#!/bin/bash\n' >"$FT_DIR/test/helper.sh"
printf '#!/bin/bash\n' >"$FT_DIR/test/thing_spec.sh"

# relpath|expected filetype
for case in \
  "spec/plain.sh|shellspec" \
  "spec/unit/deep.sh|shellspec" \
  "test/thing_spec.sh|shellspec" \
  "test/helper.sh|sh"; do
  rel="${case%%|*}"
  want="${case#*|}"
  print_test "Filetype for $rel (want '${want:-none}')"
  got_rel=$(cd "$FT_DIR" && nvim_eval "&filetype" -c "edit $rel")
  got_abs=$(nvim_eval "&filetype" -c "edit $FT_DIR/$rel")
  if [[ "$got_rel" == "$want" && "$got_abs" == "$want" ]]; then
    print_pass "$rel -> '${want:-none}' by both relative and absolute path"
  else
    print_fail "$rel: relative gave '$got_rel', absolute gave '$got_abs', wanted '$want'"
  fi
done
rm -rf "$FT_DIR"

# Test 5: Actual formatting works
print_test "Formatting functionality works correctly"
TEST_FILE=$(mktemp -t "shellspec_test_XXXXXX.spec.sh")
TMPFILES+=("${TEST_FILE}")
EXPECTED_FILE=$(mktemp -t "shellspec_expected_XXXXXX.spec.sh")
TMPFILES+=("${EXPECTED_FILE}")

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
TMPFILES+=("${TEST_FILE}")
EXPECTED_FILE=$(mktemp -t "shellspec_expected_XXXXXX.spec.sh")
TMPFILES+=("${EXPECTED_FILE}")

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

# Test 7: Health check.
# Asserts the report has no ERROR lines, not merely that it printed something:
# vim.health.report_start was removed from Neovim, and a check that only looked
# for the plugin name would still have passed on the resulting traceback.
print_test "Health check functionality"
HEALTH_FILE=$(mktemp -t "shellspec_health_XXXXXX.txt")
TMPFILES+=("${HEALTH_FILE}")
timeout 10 nvim --headless -u NONE \
  -c "set rtp+=$PROJECT_ROOT" \
  -c "source plugin/shellspec.vim" \
  -c "checkhealth shellspec" \
  -c "write! $HEALTH_FILE" \
  -c "quit" </dev/null >/dev/null 2>&1 || true

if ! grep -q "ShellSpec.nvim" "$HEALTH_FILE"; then
  print_fail "Health check did not produce a ShellSpec.nvim report"
elif grep -qE "ERROR|E5108|attempt to call" "$HEALTH_FILE"; then
  print_fail "Health check reported errors"
  grep -nE "ERROR|E5108|attempt to call" "$HEALTH_FILE"
else
  print_pass "Health check works"
fi
rm -f "$HEALTH_FILE"

# Test 7b: indentexpr. `End` directly after its opener used to be dedented from
# the opener instead of aligned with it.
print_test "indentexpr aligns End with an empty block's opener"
INDENT_FILE=$(mktemp -t "shellspec_indent_XXXXXX.spec.sh")
TMPFILES+=("${INDENT_FILE}")
printf 'Describe "x"\nIt "todo"\nEnd\nMock date\necho 1\nEnd\nEnd\n' >"$INDENT_FILE"
timeout 10 nvim --headless -u NONE --cmd "set rtp^=$PROJECT_ROOT" --cmd "filetype plugin indent on" \
  -c "edit $INDENT_FILE" -c "set expandtab shiftwidth=2" -c "normal! gg=G" -c "write" -c "quit" </dev/null >/dev/null 2>&1 || true
if [[ "$(cat "$INDENT_FILE")" == $'Describe "x"\n  It "todo"\n  End\n  Mock date\n    echo 1\n  End\nEnd' ]]; then
  print_pass "gg=G indents empty blocks and Mock blocks correctly"
else
  print_fail "gg=G produced:"
  cat "$INDENT_FILE"
fi
rm -f "$INDENT_FILE"

# Test 8: Vim fallback (if vim is available).
# Formats a real file rather than probing for a command name: the fallback had a
# quoting defect that broke <<'EOF' detection, which a command-exists check
# could never have caught.
if command -v vim >/dev/null 2>&1; then
  print_test "Vim fallback compatibility"
  VIM_FILE=$(mktemp -t "shellspec_vim_XXXXXX.spec.sh")
  VIM_EXPECTED=$(mktemp -t "shellspec_vimexp_XXXXXX.spec.sh")
  TMPFILES+=("${VIM_FILE}" "${VIM_EXPECTED}")

  cat >"$VIM_FILE" <<'SPEC'
Describe "vim fallback"
It "preserves quoted heredocs"
When call cat <<'DATA'
      preserved
DATA
The output should include "preserved"
End
End
SPEC

  cat >"$VIM_EXPECTED" <<'SPEC'
Describe "vim fallback"
  It "preserves quoted heredocs"
    When call cat <<'DATA'
      preserved
DATA
    The output should include "preserved"
  End
End
SPEC

  # -e -s is vim's equivalent of --headless; the timeout and </dev/null match
  # the nvim invocations above, without which this one can block on a terminal.
  timeout 10 vim -N -e -s -u NONE \
    -c "set rtp+=$PROJECT_ROOT expandtab shiftwidth=2" \
    -c "source $PROJECT_ROOT/autoload/shellspec.vim" \
    -c "edit $VIM_FILE" \
    -c "call shellspec#format_buffer()" \
    -c "write" \
    -c "quit" </dev/null >/dev/null 2>&1 || true

  if diff -u "$VIM_EXPECTED" "$VIM_FILE" >/dev/null; then
    print_pass "Vim fallback formats correctly"
  else
    print_fail "Vim fallback output does not match expected"
    diff -u "$VIM_EXPECTED" "$VIM_FILE" || true
  fi
  rm -f "$VIM_FILE" "$VIM_EXPECTED"

  # Vim detection: ftdetect used `setfiletype`, which loses to the runtime's
  # own *.sh rule, so every spec opened as `sh` and the fallback never ran.
  print_test "Vim detects *_spec.sh as shellspec"
  VIM_FT_FILE=$(mktemp -t "shellspec_vimft_XXXXXX_spec.sh")
  VIM_FT_OUT=$(mktemp -t "shellspec_vimft_out_XXXXXX")
  TMPFILES+=("${VIM_FT_FILE}" "${VIM_FT_OUT}")
  printf 'Describe "x"\nEnd\n' >"$VIM_FT_FILE"
  timeout 10 vim -N -e -s -u NONE --cmd "set rtp^=$PROJECT_ROOT" -c "filetype on" \
    -c "edit $VIM_FT_FILE" -c "call writefile([&filetype], '$VIM_FT_OUT')" -c "qa!" </dev/null >/dev/null 2>&1 || true
  if [[ "$(cat "$VIM_FT_OUT")" == "shellspec" ]]; then
    print_pass "Vim sets filetype=shellspec"
  else
    print_fail "Vim set filetype '$(cat "$VIM_FT_OUT")', wanted 'shellspec'"
  fi

  # Vim :{range}ShellSpecFormatRange: the range used to be ignored in favour of
  # the '< '> marks, and a whole-buffer range gained a trailing empty line.
  print_test "Vim :ShellSpecFormatRange honours an explicit range"
  VIM_RANGE_FILE=$(mktemp -t "shellspec_vimrange_XXXXXX.spec.sh")
  TMPFILES+=("${VIM_RANGE_FILE}")
  printf 'Describe "x"\nIt "y"\nWhen call f\nEnd\nEnd\n' >"$VIM_RANGE_FILE"
  timeout 10 vim -N -e -s -u NONE --cmd "set rtp^=$PROJECT_ROOT" -c "runtime plugin/shellspec.vim" \
    -c "edit $VIM_RANGE_FILE" -c "set expandtab shiftwidth=2" -c "1,\$ShellSpecFormatRange" -c "write" -c "qa!" </dev/null >/dev/null 2>&1 || true
  if [[ "$(cat "$VIM_RANGE_FILE")" == $'Describe "x"\n  It "y"\n    When call f\n  End\nEnd' ]]; then
    print_pass "Vim range formatting covers the range and adds no lines"
  else
    print_fail "Vim range formatting produced:"
    cat -A "$VIM_RANGE_FILE"
  fi
  rm -f "$VIM_RANGE_FILE" "$VIM_FT_FILE" "$VIM_FT_OUT"
else
  print_test "Vim fallback compatibility (skipped - vim not available)"
fi

print_summary
