-- Unit tests for ShellSpec formatting functions
-- Run with: make test-unit
--   (nvim --headless -u NONE -c "set rtp+=." -c "luafile tests/format_spec.lua" -c "quit")
--
-- Requires Neovim. This file used to install a `vim` stub so it could also run
-- under plain `lua`, but the stub's tbl_deep_extend was a shallow merge and it
-- omitted vim.log.levels.DEBUG -- so the two invocations exercised different
-- behaviour and passing under one proved nothing about the other.

if not vim then
  io.stderr:write("tests/format_spec.lua requires Neovim: run `make test-unit`\n")
  os.exit(1)
end

package.path = "./lua/?.lua;" .. package.path

local config = require("shellspec.config")
local format = require("shellspec.format")

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, test_name)
  if type(expected) == "table" and type(actual) == "table" then
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

local DEFAULT_OPTS = { indent_comments = true, indent_size = 2, use_spaces = true }

--- Run `fn` with `opts` merged over the defaults, restoring them afterwards.
local function with_config(opts, fn)
  config.setup(opts)
  local ok, err = pcall(fn)
  config.setup(DEFAULT_OPTS)
  if not ok then
    error(err)
  end
end

config.setup(DEFAULT_OPTS)

print("Running formatting tests...")
print("")

-- Test 1: Basic block indentation
assert_equal(
  {
    'Describe "test"',
    '  It "should work"',
    "  End",
    "End",
  },
  format.format_lines({
    'Describe "test"',
    'It "should work"',
    "End",
    "End",
  }),
  "Basic block indentation"
)

-- Test 2: Comment indentation
assert_equal(
  {
    'Describe "test"',
    "  # Comment at Describe level",
    '  It "should work"',
    "    # Comment at It level",
    '    When call echo "test"',
    "  End",
    "End",
  },
  format.format_lines({
    'Describe "test"',
    "# Comment at Describe level",
    'It "should work"',
    "# Comment at It level",
    'When call echo "test"',
    "End",
    "End",
  }),
  "Comment indentation"
)

-- Test 3: HEREDOC preservation.
-- The EOF terminator stays at column 0: a non-`<<-` HEREDOC whose delimiter is
-- indented is never closed, and the rest of the file becomes HEREDOC body.
assert_equal(
  {
    'Describe "test"',
    '  It "handles heredoc"',
    "    When call cat <<EOF",
    "  This should be preserved",
    "    Even nested",
    "EOF",
    '    The output should include "test"',
    "  End",
    "End",
  },
  format.format_lines({
    'Describe "test"',
    'It "handles heredoc"',
    "When call cat <<EOF",
    "  This should be preserved",
    "    Even nested",
    "EOF",
    'The output should include "test"',
    "End",
    "End",
  }),
  "HEREDOC preservation"
)

-- Test 4: Nested contexts
assert_equal(
  {
    'Describe "outer"',
    '  Context "when something"',
    '    It "should work"',
    '      When call echo "test"',
    '      The output should equal "test"',
    "    End",
    "  End",
    "End",
  },
  format.format_lines({
    'Describe "outer"',
    'Context "when something"',
    'It "should work"',
    'When call echo "test"',
    'The output should equal "test"',
    "End",
    "End",
    "End",
  }),
  "Nested contexts"
)

-- Test 5: Hook keywords
assert_equal(
  {
    'Describe "test"',
    "  BeforeEach",
    "    setup_test",
    "  End",
    '  It "works"',
    "    When call test_function",
    "  End",
    "End",
  },
  format.format_lines({
    'Describe "test"',
    "BeforeEach",
    "setup_test",
    "End",
    'It "works"',
    "When call test_function",
    "End",
    "End",
  }),
  "Hook keywords"
)

-- Test 6: every detect_heredoc_start branch. Only the <<EOF branch had
-- coverage, so the quoted and <<- forms were never exercised.
for _, case in ipairs({
  { open = "When call cat <<EOF", close = "EOF", name = "unquoted" },
  { open = "When call cat <<'DATA'", close = "DATA", name = "single-quoted" },
  { open = 'When call cat <<"SCRIPT"', close = "SCRIPT", name = "double-quoted" },
  { open = "When call cat <<-TABBED", close = "TABBED", name = "dash-prefixed" },
}) do
  assert_equal(
    {
      'Describe "x"',
      "  " .. case.open,
      "      body stays put",
      case.close,
      "End",
    },
    format.format_lines({
      'Describe "x"',
      case.open,
      "      body stays put",
      case.close,
      "End",
    }),
    "HEREDOC delimiter: " .. case.name
  )
end

-- Test 7: a here-string is not a HEREDOC. `<<<` contains `<<"` at offset 1 and
-- used to match the double-quoted pattern, after which nothing was formatted.
assert_equal(
  {
    'Describe "x"',
    '  It "y"',
    '    When call grep foo <<<"$input"',
    "    The status should be success",
    "  End",
    "End",
  },
  format.format_lines({
    'Describe "x"',
    'It "y"',
    'When call grep foo <<<"$input"',
    "The status should be success",
    "End",
    "End",
  }),
  "Here-string is not a HEREDOC"
)

-- Test 8: the HEREDOC check used to run before the comment check.
assert_equal(
  {
    'Describe "x"',
    "  # note: uses <<EOF here",
    '  It "y"',
    "    When call echo hi",
    "  End",
    "End",
  },
  format.format_lines({
    'Describe "x"',
    "# note: uses <<EOF here",
    'It "y"',
    "When call echo hi",
    "End",
    "End",
  }),
  "Comment mentioning a HEREDOC is not a HEREDOC"
)

-- Test 9: a line that is both a block keyword and a HEREDOC opener must do both.
assert_equal(
  {
    'Describe "x"',
    '  It "y" <<EOF',
    "body",
    "EOF",
    "  End",
    "End",
  },
  format.format_lines({
    'Describe "x"',
    'It "y" <<EOF',
    "body",
    "EOF",
    "End",
    "End",
  }),
  "Block keyword that also opens a HEREDOC"
)

-- Test 10: block keywords need a following space, hooks need end of line.
-- Without those anchors `Items=3` matched `It` and opened a block.
assert_equal(
  {
    'Describe "x"',
    "  Items=3",
    "  Examples=()",
    "  Before_hand=1",
    "End",
  },
  format.format_lines({
    'Describe "x"',
    "Items=3",
    "Examples=()",
    "Before_hand=1",
    "End",
  }),
  "Lookalike identifiers do not open blocks"
)

-- Test 11: start_indent seeds the level, so a sub-range keeps its place.
assert_equal(
  {
    '    It "y"',
    "      When call echo hi",
    "    End",
  },
  format.format_lines({
    'It "y"',
    "When call echo hi",
    "End",
  }, 2),
  "format_lines honours start_indent"
)

-- Test 12: unbalanced End clamps at zero rather than going negative.
assert_equal(
  {
    "End",
    "End",
    'Describe "x"',
  },
  format.format_lines({
    "End",
    "End",
    'Describe "x"',
  }),
  "Unbalanced End clamps at zero"
)

-- Test 13: empty input
assert_equal({}, format.format_lines({}), "Empty input")

-- Test 14: configuration actually changes the output.
with_config({ indent_size = 4 }, function()
  assert_equal({
    'Describe "x"',
    '    It "y"',
    "    End",
    "End",
  }, format.format_lines({ 'Describe "x"', 'It "y"', "End", "End" }), "indent_size = 4")
end)

with_config({ use_spaces = false }, function()
  assert_equal({
    'Describe "x"',
    '\tIt "y"',
    "\tEnd",
    "End",
  }, format.format_lines({ 'Describe "x"', 'It "y"', "End", "End" }), "use_spaces = false emits tabs")
end)

with_config({ indent_comments = false }, function()
  assert_equal(
    {
      'Describe "x"',
      "# left where it was",
      '  It "y"',
      "  End",
      "End",
    },
    format.format_lines({
      'Describe "x"',
      "# left where it was",
      'It "y"',
      "End",
      "End",
    }),
    "indent_comments = false preserves comment columns"
  )
end)

with_config({ heredoc_patterns = { "<<@@(%u+)" } }, function()
  assert_equal(
    {
      'Describe "x"',
      "  When call cat <<@@BODY",
      "      untouched",
      "BODY",
      "End",
    },
    format.format_lines({
      'Describe "x"',
      "When call cat <<@@BODY",
      "      untouched",
      "BODY",
      "End",
    }),
    "heredoc_patterns is honoured"
  )
end)

-- Test 14b: a capture-less heredoc_pattern (the shape this project's own README
-- published while the option was dead config) must not be used as a delimiter --
-- it would yield "<<EOF" instead of "EOF" and halt formatting at that line.
with_config({
  heredoc_patterns = { "<<[A-Z_][A-Z0-9_]*", "<<'[^']*'", '<<"[^"]*"', "<<-[A-Z_][A-Z0-9_]*" },
}, function()
  assert_equal(
    {
      'Describe "x"',
      '  It "y"',
      "    When call cat <<EOF",
      "body",
      "EOF",
      '    The output should equal "body"',
      "  End",
      "End",
    },
    format.format_lines({
      'Describe "x"',
      'It "y"',
      "When call cat <<EOF",
      "body",
      "EOF",
      'The output should equal "body"',
      "End",
      "End",
    }),
    "capture-less heredoc_patterns fall back to defaults"
  )
end)

-- Test 14c-a: validation keeps only patterns with exactly one capture group.
-- `"<<(E)(OF)"` used to be accepted, and string.match's first capture "E" became
-- the delimiter, so `EOF` never closed the HEREDOC. `%%(` is a literal percent
-- followed by a real capture; `%(` is an escaped paren and no capture at all.
-- Parens inside a `[...]` set are set members, not captures, including after a
-- leading `]` member. Malformed patterns -- unclosed or unopened capture,
-- nested captures, trailing `%`, unterminated set -- are rejected as well.
assert_equal(
  { "<<%%(x)", "<<([%a_]+)", "<<'([%w_()]+)'", "<<([]()]+)", "<<[(](x)" },
  config.validate_heredoc_patterns({
    "<<(E)(OF)",
    "<<%(EOF%)",
    "<<()EOF",
    "<<%%(x)",
    "<<([%a_]+)",
    "<<'([%w_()]+)'",
    "<<([]()]+)",
    "<<[(](x)",
    "<<(%w+",
    "<<(x))",
    "<<((x))",
    "<<(x)%",
    "<<(%w+)[abc",
    "<<(EOF)%f",
    "<<(EOF)%b(",
  }),
  "heredoc_patterns need exactly one well-formed non-position capture"
)

-- Use-site guard: a malformed pattern that reaches format_lines anyway (set
-- here directly, bypassing validation) is skipped instead of raising, and the
-- next pattern still detects the HEREDOC.
do
  local saved = config.config.heredoc_patterns
  config.config.heredoc_patterns = { "<<(EOF)%f", "<<%-?%s*\\?([%a_][%w_]*)" }
  local ok, result = pcall(format.format_lines, { 'It "x"', "When call cat <<EOF", "  body", "EOF", "End" })
  config.config.heredoc_patterns = saved
  assert_equal(true, ok, "a pattern that raises at match time does not abort format_lines")
  assert_equal({ 'It "x"', "  When call cat <<EOF", "  body", "EOF", "End" }, ok and result or {}, "the remaining patterns still detect the HEREDOC")
end

-- A malformed pattern used to pass validation and then raise "unfinished
-- capture" from format_lines. It is now dropped, the defaults apply, and the
-- buffer is formatted.
with_config({ heredoc_patterns = { "<<(%w+" } }, function()
  local ok, result = pcall(format.format_lines, { 'It "x"', "When call cat <<EOF", "body", "EOF", "End" })
  assert_equal(true, ok, "malformed heredoc_pattern does not make format_lines raise")
  assert_equal({ 'It "x"', "  When call cat <<EOF", "body", "EOF", "End" }, ok and result or {}, "malformed heredoc_pattern falls back to the defaults")
end)

-- A set containing parens stays usable end to end: the quoted delimiter
-- `A(B)` keeps its HEREDOC body verbatim instead of falling back to defaults.
with_config({ heredoc_patterns = { "<<'([%w_()]+)'" } }, function()
  assert_equal(
    { 'It "x"', "  When call cat <<'A(B)'", "    kept as is", "A(B)", "End" },
    format.format_lines({ 'It "x"', "When call cat <<'A(B)'", "    kept as is", "A(B)", "End" }),
    "heredoc_pattern with parens in a set keeps the body verbatim"
  )
end)

-- Test 14c: the deprecated aliases exported at v2.0.2 stay callable.
do
  local shellspec = require("shellspec")
  local ok = type(shellspec.health) == "function"
    and type(shellspec.format_buffer_compat) == "function"
    and type(shellspec.format_selection_compat) == "function"
  assert_equal(true, ok, "deprecated public aliases remain exported")
end

-- Test 15: format_selection keeps the lines around the range untouched.
do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    'Describe "x"',
    '  Context "c"',
    '    It "y"',
    "When call echo hi",
    '      The output should equal "hi"',
    "    End",
    "  End",
    "End",
  })
  format.format_selection(buf, 3, 5)
  assert_equal({
    'Describe "x"',
    '  Context "c"',
    '    It "y"',
    "      When call echo hi",
    '      The output should equal "hi"',
    "    End",
    "  End",
    "End",
  }, vim.api.nvim_buf_get_lines(buf, 0, -1, false), "format_selection preserves surrounding indent")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- Test 16: format_buffer rewrites the whole buffer.
do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'Describe "x"', 'It "y"', "End", "End" })
  format.format_buffer(buf)
  assert_equal({ 'Describe "x"', '  It "y"', "  End", "End" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false), "format_buffer formats in place")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- Test 16b: a range starting inside a HEREDOC body keeps the body and
-- terminator verbatim; only the requested lines are rewritten.
do
  local lines = {
    'Describe "x"',
    '  It "y"',
    "    When call cat <<EOF",
    "  body one",
    "body two",
    "EOF",
    '  The output should equal "x"',
    "  End",
    "End",
  }
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  format.format_selection(buf, 4, 9)
  local want = vim.deepcopy(lines)
  want[7] = '    The output should equal "x"'
  assert_equal(want, vim.api.nvim_buf_get_lines(buf, 0, -1, false), "range starting in a HEREDOC body keeps it verbatim")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- Test 17: a range starting on an End line leaves formatted code unchanged.
-- The End sits at its opener's level, so seeding with that level used to shift
-- every following line one level left.
do
  local formatted = {
    'Describe "x"',
    '  It "y"',
    "    When call f",
    "  End",
    '  It "z"',
    "    When call g",
    "  End",
    "End",
  }
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted)
  format.format_selection(buf, 4, 8)
  assert_equal(formatted, vim.api.nvim_buf_get_lines(buf, 0, -1, false), "format_selection starting on End is idempotent")
  format.format_selection(buf, 4, 4)
  assert_equal(formatted, vim.api.nvim_buf_get_lines(buf, 0, -1, false), "single-line range on End is idempotent")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- Test 18: POSIX HEREDOC spellings keep their terminator verbatim, and an
-- arithmetic shift does not open a HEREDOC.
assert_equal(
  {
    'It "x"',
    "  When call cat << EOF",
    "body",
    "EOF",
    "  When call cat <<eof",
    "body",
    "eof",
    "  When call cat <<\\EOF",
    "body",
    "EOF",
    "  When call echo $(( a << b ))",
    "  The status should be success",
    "End",
  },
  format.format_lines({
    'It "x"',
    "When call cat << EOF",
    "body",
    "EOF",
    "When call cat <<eof",
    "body",
    "eof",
    "When call cat <<\\EOF",
    "body",
    "EOF",
    "When call echo $(( a << b ))",
    "The status should be success",
    "End",
  }),
  "POSIX HEREDOC spellings and arithmetic shift"
)

-- Test 19: Mock, Data:<modifier> and Parameters:<modifier> open blocks.
assert_equal(
  {
    'Describe "x"',
    "  Mock date",
    "    echo 2019",
    "  End",
    "  Data:raw",
    "    #|a",
    "  End",
    "  Parameters:matrix",
    "    a b",
    "  End",
    "End",
  },
  format.format_lines({
    'Describe "x"',
    "Mock date",
    "echo 2019",
    "End",
    "Data:raw",
    "#|a",
    "End",
    "Parameters:matrix",
    "a b",
    "End",
    "End",
  }),
  "Mock and modifier blocks open a level"
)

-- Test 20: format_buffer_async formats the buffer that was current when it was
-- called, not whichever buffer is current on the next tick.
do
  local spec = vim.api.nvim_create_buf(false, true)
  local other = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(spec, 0, -1, false, { 'Describe "x"', 'It "y"', "End", "End" })
  vim.api.nvim_buf_set_lines(other, 0, -1, false, { "def f():", "        return 1" })
  vim.api.nvim_set_current_buf(spec)
  local done = false
  format.format_buffer_async(nil, function()
    done = true
  end)
  vim.api.nvim_set_current_buf(other)
  vim.wait(1000, function()
    return done
  end)
  assert_equal({ 'Describe "x"', '  It "y"', "  End", "End" }, vim.api.nvim_buf_get_lines(spec, 0, -1, false), "async formats the original buffer")
  assert_equal({ "def f():", "        return 1" }, vim.api.nvim_buf_get_lines(other, 0, -1, false), "async leaves the newly current buffer alone")
  vim.api.nvim_buf_delete(spec, { force = true })
  vim.api.nvim_buf_delete(other, { force = true })
end

-- Test 21: a non-integer indent_size is rejected and the default kept.
with_config({ indent_size = 2.5 }, function()
  assert_equal(2, config.get("indent_size"), "non-integer indent_size falls back to the default")
end)

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
