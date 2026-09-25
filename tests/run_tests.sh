#!/bin/bash
# Main test runner for nvim-shellspec plugin
# Runs all test suites: unit tests, integration tests, and golden master tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test suite results
UNIT_PASSED=false
INTEGRATION_PASSED=false
GOLDEN_PASSED=false
BIN_FORMAT_PASSED=false
PARITY_PASSED=false

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} nvim-shellspec Test Suite Runner      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Project root: $PROJECT_ROOT"
echo ""

# Function to run a test suite
run_test_suite() {
  local suite_name="$1"
  local test_type="$2"
  local test_script="$3"
  local result_var="$4"

  echo -e "${YELLOW}Running $suite_name...${NC}"
  echo ""

  local success=false

  case "$test_type" in
  "script")
    if "$test_script"; then
      success=true
    fi
    ;;
  "nvim_lua")
    # stderr is kept: a Lua error in the test file goes there, and discarding it
    # left a failing suite indistinguishable from a passing one.
    #
    # dofile under pcall, not `luafile`: nvim still exits 0 when a -c command
    # raises, so a test file that crashed before its own os.exit(1) reported
    # PASSED. cquit turns the error into a non-zero exit status.
    if nvim --headless -u NONE -c "set rtp+=." \
      -c "lua local ok, err = pcall(dofile, '$test_script'); if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end" \
      -c "quit"; then
      success=true
    fi
    ;;
  esac

  if [ "$success" = true ]; then
    echo -e "${GREEN}✓ $suite_name PASSED${NC}"
    eval "$result_var=true"
  else
    echo -e "${RED}✗ $suite_name FAILED${NC}"
    eval "$result_var=false"
  fi

  echo ""
  echo -e "${BLUE}----------------------------------------${NC}"
  echo ""
}

# Change to project root
cd "$PROJECT_ROOT"

# Run unit tests
run_test_suite "Unit Tests" "nvim_lua" "tests/format_spec.lua" UNIT_PASSED

# Both suites are gated on their real exit status and keep their output.
# They used to be forced to PASSED in the failure branch, with the failure
# blamed on "nvim shell interaction" -- the actual cause was a bare ((x++))
# under `set -e` aborting each suite after its first passing assertion.
run_test_suite "Integration Tests" "script" "./tests/integration_test.sh" INTEGRATION_PASSED

run_test_suite "Golden Master Tests" "script" "./tests/golden_master_test.sh" GOLDEN_PASSED

# Run bin formatter tests
run_test_suite "Standalone Formatter Tests" "script" "./tests/bin_format_spec.sh" BIN_FORMAT_PASSED

# Run cross-implementation parity tests
run_test_suite "Parity Tests" "script" "./tests/parity_test.sh" PARITY_PASSED

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} Test Results Summary                   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$UNIT_PASSED" = true ]; then
  echo -e "${GREEN}✓ Unit Tests: PASSED${NC}"
else
  echo -e "${RED}✗ Unit Tests: FAILED${NC}"
fi

if [ "$INTEGRATION_PASSED" = true ]; then
  echo -e "${GREEN}✓ Integration Tests: PASSED${NC}"
else
  echo -e "${RED}✗ Integration Tests: FAILED${NC}"
fi

if [ "$GOLDEN_PASSED" = true ]; then
  echo -e "${GREEN}✓ Golden Master Tests: PASSED${NC}"
else
  echo -e "${RED}✗ Golden Master Tests: FAILED${NC}"
fi

if [ "$BIN_FORMAT_PASSED" = true ]; then
  echo -e "${GREEN}✓ Standalone Formatter Tests: PASSED${NC}"
else
  echo -e "${RED}✗ Standalone Formatter Tests: FAILED${NC}"
fi

if [ "$PARITY_PASSED" = true ]; then
  echo -e "${GREEN}✓ Parity Tests: PASSED${NC}"
else
  echo -e "${RED}✗ Parity Tests: FAILED${NC}"
fi

echo ""

# Overall result
if [ "$UNIT_PASSED" = true ] && [ "$INTEGRATION_PASSED" = true ] &&
  [ "$GOLDEN_PASSED" = true ] && [ "$BIN_FORMAT_PASSED" = true ] && [ "$PARITY_PASSED" = true ]; then
  echo -e "${GREEN}🎉 ALL TESTS COMPLETED SUCCESSFULLY! 🎉${NC}"
  echo ""
  echo -e "${GREEN}The nvim-shellspec plugin is ready for use!${NC}"
  echo ""
  echo -e "${BLUE}Manual verification:${NC}"
  echo "1. Create a test file with .spec.sh extension"
  echo "2. Add some ShellSpec content like:"
  echo "   Describe \"test\""
  echo "   It \"works\""
  echo "   End"
  echo "   End"
  echo "3. Open in Neovim and run :ShellSpecFormat"
  echo "4. Verify proper indentation is applied"
  exit 0
else
  echo -e "${RED}❌ CRITICAL TESTS FAILED ❌${NC}"
  echo ""
  echo -e "${RED}Unit tests must pass for plugin to work correctly.${NC}"
  exit 1
fi
