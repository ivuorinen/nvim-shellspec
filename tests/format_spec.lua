-- Unit tests for ShellSpec formatting functions
-- Run with: nvim --headless -u NONE -c "set rtp+=." -c "luafile tests/format_spec.lua" -c "quit"

-- Add the parent directory to package.path to find our modules
package.path = "./lua/?.lua;" .. package.path

-- Mock vim API for standalone lua execution
if not vim then
  vim = {
    tbl_deep_extend = function(behavior, ...)
      local result = {}
      for _, tbl in ipairs({ ... }) do
        if tbl then
          for k, v in pairs(tbl) do
            result[k] = v
          end
        end
      end
      return result
    end,
    notify = function(msg, level)
      print("NOTIFY: " .. msg)
    end,
    log = {
      levels = {
        WARN = 2,
        ERROR = 3,
      },
    },
    trim = function(s)
      return s:match("^%s*(.-)%s*$")
    end,
    g = {
      -- Mock global variables
      shellspec_debug = true, -- Enable debug mode for testing
    },
  }
end

-- Load the modules
local config = require("shellspec.config")
local format = require("shellspec.format")

-- Test framework
local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, test_name)
  if type(expected) == "table" and type(actual) == "table" then
    -- Compare tables line by line
    if #expected ~= #actual then
      print("FAIL: " .. test_name)
      print("  Expected " .. #expected .. " lines, got " .. #actual .. " lines")
      tests_failed = tests_failed + 1
      return
    end

    for i, expected_line in ipairs(expected) do
      if expected_line ~= actual[i] then
        print("FAIL: " .. test_name)
        print("  Line " .. i .. ":")
        print("    Expected: '" .. expected_line .. "'")
        print("    Actual:   '" .. (actual[i] or "nil") .. "'")
        tests_failed = tests_failed + 1
        return
      end
    end

    print("PASS: " .. test_name)
    tests_passed = tests_passed + 1
  else
    if expected == actual then
      print("PASS: " .. test_name)
      tests_passed = tests_passed + 1
    else
      print("FAIL: " .. test_name)
      print("  Expected: " .. tostring(expected))
      print("  Actual:   " .. tostring(actual))
      tests_failed = tests_failed + 1
    end
  end
end

-- Initialize configuration for tests
config.setup({
  indent_comments = true,
  indent_size = 2,
  use_spaces = true,
})

-- Test 1: Basic block indentation
print("Running formatting tests...")
print("")

local test1_input = {
  'Describe "test"',
  'It "should work"',
  "End",
  "End",
}

local test1_expected = {
  'Describe "test"',
  '  It "should work"',
  "  End",
  "End",
}

local test1_result = format.format_lines(test1_input)
assert_equal(test1_expected, test1_result, "Basic block indentation")

-- Test 2: Comment indentation
local test2_input = {
  'Describe "test"',
  "# Comment at Describe level",
  'It "should work"',
  "# Comment at It level",
  'When call echo "test"',
  "End",
  "End",
}

local test2_expected = {
  'Describe "test"',
  "  # Comment at Describe level",
  '  It "should work"',
  "    # Comment at It level",
  '    When call echo "test"',
  "  End",
  "End",
}

local test2_result = format.format_lines(test2_input)
assert_equal(test2_expected, test2_result, "Comment indentation")

-- Test 3: HEREDOC preservation
local test3_input = {
  'Describe "test"',
  'It "handles heredoc"',
  "When call cat <<EOF",
  "  This should be preserved",
  "    Even nested",
  "EOF",
  'The output should include "test"',
  "End",
  "End",
}

local test3_expected = {
  'Describe "test"',
  '  It "handles heredoc"',
  "    When call cat <<EOF",
  "  This should be preserved",
  "    Even nested",
  "    EOF",
  '    The output should include "test"',
  "  End",
  "End",
}

local test3_result = format.format_lines(test3_input)
assert_equal(test3_expected, test3_result, "HEREDOC preservation")

-- Test 4: Nested contexts
local test4_input = {
  'Describe "outer"',
  'Context "when something"',
  'It "should work"',
  'When call echo "test"',
  'The output should equal "test"',
  "End",
  "End",
  "End",
}

local test4_expected = {
  'Describe "outer"',
  '  Context "when something"',
  '    It "should work"',
  '      When call echo "test"',
  '      The output should equal "test"',
  "    End",
  "  End",
  "End",
}

local test4_result = format.format_lines(test4_input)
assert_equal(test4_expected, test4_result, "Nested contexts")

-- Test 5: Hook keywords
local test5_input = {
  'Describe "test"',
  "BeforeEach",
  "setup_test",
  "End",
  'It "works"',
  "When call test_function",
  "End",
  "End",
}

local test5_expected = {
  'Describe "test"',
  "  BeforeEach",
  "    setup_test",
  "  End",
  '  It "works"',
  "    When call test_function",
  "  End",
  "End",
}

local test5_result = format.format_lines(test5_input)
assert_equal(test5_expected, test5_result, "Hook keywords")

-- Print results
print("")
print("Test Results:")
print("  Passed: " .. tests_passed)
print("  Failed: " .. tests_failed)
print("  Total:  " .. (tests_passed + tests_failed))

if tests_failed > 0 then
  print("")
  print("Some tests failed. Please check the formatting logic.")
  os.exit(1)
else
  print("")
  print("All tests passed!")
end
