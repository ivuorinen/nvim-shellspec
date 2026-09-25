#!/bin/bash
# Cross-implementation parity tests.
#
# The same formatting algorithm exists three times -- lua/shellspec/format.lua,
# autoload/shellspec.vim and bin/shellspec-format -- and they had silently
# drifted apart on block-keyword anchoring, quoted HEREDOC detection and indent
# width. This suite runs one fixture set through all three and requires
# byte-identical output, so the next divergence fails a test instead of
# surfacing as "the formatter behaves differently in Vim".

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FORMATTER="$PROJECT_ROOT/bin/shellspec-format"

TMPFILES=()
cleanup() { [[ ${#TMPFILES[@]} -gt 0 ]] && rm -f "${TMPFILES[@]}"; }
# INT/TERM exit explicitly (EXIT then runs cleanup): a handler that only
# cleans up lets bash resume, so an interrupted run kept executing cases.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Counters use $(( )) rather than ((x++)): under `set -e` a bare ((x++)) exits 1
# when x is 0, because post-increment evaluates to the old value.
print_test() { echo -e "${YELLOW}[PARITY]${NC} $1"; }
print_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}
print_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Fixtures exercising every axis the three implementations had drifted on.
read -r -d '' FIXTURE <<'SPEC' || true
Describe "parity"
# top level comment
Context "heredocs"
It "unquoted"
When call cat <<EOF
  preserved
EOF
The output should include "preserved"
End
It "single quoted"
When call cat <<'DATA'
  preserved
DATA
The output should include "preserved"
End
It "double quoted"
When call cat <<"SCRIPT"
  preserved
SCRIPT
The output should include "preserved"
End
It "here-string is not a heredoc"
When call grep foo <<<"$input"
The status should be success
End
End
Context "POSIX heredoc spellings"
It "space after <<"
When call cat << EOF
  preserved
EOF
End
It "lowercase and backslash-quoted"
When call cat <<eof
  preserved
eof
When call cat <<\EOF
  preserved
EOF
End
It "arithmetic shift is not a heredoc"
When call echo $(( a << b ))
End
End
Context "modifier blocks"
Mock date
echo 2019
End
It "data"
Data:raw
#|raw
End
Data:expand
#|$x
End
When call f
End
Parameters:matrix
a b
End
End
Context "lookalikes"
Items=3
Examples=()
# comment naming <<EOF
BeforeEach
setup
End
End
End
SPEC

run_parity_case() {
  local name="$1" content="$2"

  print_test "Testing $name"

  local lua_out vim_out bin_out
  lua_out=$(mktemp -t "parity_lua_XXXXXX.spec.sh")
  vim_out=$(mktemp -t "parity_vim_XXXXXX.spec.sh")
  bin_out=$(mktemp -t "parity_bin_XXXXXX.spec.sh")
  TMPFILES+=("$lua_out" "$vim_out" "$bin_out")

  printf '%s\n' "$content" >"$lua_out"
  cp "$lua_out" "$vim_out"

  # Lua path
  timeout 10 nvim --headless -u NONE \
    -c "set rtp+=$PROJECT_ROOT" \
    -c "lua vim.fn.writefile(require('shellspec.format').format_lines(vim.fn.readfile('$lua_out')), '$lua_out')" \
    -c "quit" </dev/null >/dev/null 2>&1

  # VimScript fallback. 'expandtab' and 'shiftwidth' are set explicitly because
  # that path derives its indent unit from them.
  timeout 10 nvim --headless -u NONE \
    -c "set rtp+=$PROJECT_ROOT expandtab shiftwidth=2" \
    -c "source $PROJECT_ROOT/autoload/shellspec.vim" \
    -c "call writefile(shellspec#format_lines(readfile('$vim_out')), '$vim_out')" \
    -c "quit" </dev/null >/dev/null 2>&1

  # Standalone CLI
  printf '%s\n' "$content" | timeout 10 "$FORMATTER" >"$bin_out"

  local failed=0
  if ! diff -u "$lua_out" "$vim_out" >/dev/null; then
    print_fail "$name: Lua and VimScript output differ"
    diff -u --label lua --label vimscript "$lua_out" "$vim_out" || true
    failed=1
  fi
  if ! diff -u "$lua_out" "$bin_out" >/dev/null; then
    print_fail "$name: Lua and bin/shellspec-format output differ"
    diff -u --label lua --label bin "$lua_out" "$bin_out" || true
    failed=1
  fi
  if [[ $failed -eq 0 ]]; then
    print_pass "$name: all three implementations agree"
  fi

  rm -f "$lua_out" "$vim_out" "$bin_out"
}

echo "Running nvim-shellspec cross-implementation parity tests..."
echo "Project root: $PROJECT_ROOT"
echo ""

if [[ ! -x "$FORMATTER" ]]; then
  echo -e "${RED}Error: Formatter not found or not executable: $FORMATTER${NC}"
  exit 1
fi

run_parity_case "mixed fixture" "$FIXTURE"

echo ""
echo "Parity Test Results:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Implementations have drifted apart!${NC}"
  exit 1
fi
echo -e "${GREEN}All parity tests passed!${NC}"
