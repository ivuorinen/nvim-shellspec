# Task Completion Checklist

When completing any development task in the nvim-shellspec project, follow this checklist:

## 1. Code Quality Checks (MANDATORY)

```bash
# Run all pre-commit hooks
pre-commit run --all-files
```

This runs:

- **ShellCheck** - Shell script linting and static analysis
- **shfmt** - Shell script formatting
- **yamllint** - YAML file validation
- **markdownlint** - Markdown linting and formatting
- **Various pre-commit hooks** - Trailing whitespace, end-of-file, etc.

## 2. EditorConfig Compliance (BLOCKING)

- All files must follow `.editorconfig` rules
- 2-space indentation, LF line endings, UTF-8 encoding
- 160 character line limit
- Trim trailing whitespace (except Markdown)
- End files with newline

## 3. Dual Implementation Testing (NEW - CRITICAL)

### 3a. Neovim Lua Implementation Testing

```bash
# Test in Neovim 0.7+
nvim test_example.spec.sh

# Verify Lua path is used
:lua print("Using Lua implementation")
:checkhealth shellspec

# Test formatting with HEREDOC
:ShellSpecFormat

# Test configuration
:lua require('shellspec').setup({auto_format = true})
```

### 3b. VimScript Fallback Testing

```bash
# Test in older Neovim or Vim
vim test_example.spec.sh  # or nvim --clean with older version

# Verify VimScript path is used
:echo "Using VimScript implementation"

# Test same formatting features work
:ShellSpecFormat
```

## 4. Advanced Formatting Feature Testing

### 4a. HEREDOC Preservation Testing

Create test content:

```shellspec
Describe "HEREDOC test"
  It "preserves formatting"
    cat <<EOF
      This should stay as-is
        Even with nested indentation
    Back to normal
EOF
  End
End
```

Apply `:ShellSpecFormat` and verify HEREDOC content is unchanged.

### 4b. Comment Indentation Testing  

Create test content:

```shellspec
Describe "Comment test"
# Top level comment
  It "handles comments"
  # This should be indented to It level
    When call echo "test"
    # This should be indented to When level
  End
# Back to top level
End
```

Apply `:ShellSpecFormat` and verify comments align with code levels.

## 5. Configuration Testing

### 5a. Lua Configuration (Neovim)

```lua
-- Test different configurations
require('shellspec').setup({
  auto_format = true,
  indent_size = 4,
  indent_comments = false,
})
```

### 5b. VimScript Configuration (Vim/Legacy)

```vim
let g:shellspec_auto_format = 1
let g:shellspec_indent_comments = 0
```

## 6. Plugin-Specific Testing

### Manual Testing Steps

1. **Create test ShellSpec file**:

   ```bash
   cp test_example.spec.sh my_test.spec.sh
   ```

2. **Test filetype detection**:

   ```vim
   # In Neovim/Vim, open the file and verify:
   :set filetype?  # Should show "filetype=shellspec"
   ```

3. **Test syntax highlighting**:
   - Add ShellSpec DSL content and verify highlighting
   - Test with HEREDOC blocks
   - Test with various comment styles

4. **Test formatting commands**:

   ```vim
   :ShellSpecFormat
   :ShellSpecFormatRange (in visual mode)
   ```

5. **Test auto-format on save** (if enabled):
   - Make changes and save file
   - Verify automatic formatting occurs

6. **Test health check** (Neovim only):

   ```vim
   :checkhealth shellspec
   ```

## 7. Standalone Formatter Testing

```bash
# Test the standalone formatter
echo 'Describe "test"
# Comment
It "works"
cat <<EOF
  preserved
EOF
When call echo
The output should equal
End
End' | ./bin/shellspec-format
```

## 8. Performance Testing (NEW)

```bash
# Test with larger files
time nvim +':ShellSpecFormat' +':wq' large_spec_file.spec.sh

# Compare implementations if possible
```

## 9. Module Integration Testing (Neovim)

```lua
-- Test module loading
:lua local ok, mod = pcall(require, 'shellspec'); print(ok)
:lua print(vim.inspect(require('shellspec.config').defaults))
:lua require('shellspec.format').format_lines({"test"})
```

## 10. Git Workflow

```bash
# Stage changes
git add .

# Commit (pre-commit hooks run automatically)
git commit -m "descriptive commit message"

# Ensure both implementations are included in commit
git log --name-status -1
```

## 11. Documentation Updates

- Update README.md if adding new features
- Include both Lua and VimScript examples
- Document any breaking changes
- Update health check descriptions if modified
- Ensure all configuration examples are correct

## Error Resolution Priority

1. **EditorConfig violations** - Fix immediately (blocking)
2. **Dual implementation failures** - Both Lua and VimScript must work
3. **HEREDOC/Comment formatting issues** - Core feature failures
4. **ShellCheck errors** - Fix all warnings and errors
5. **Health check failures** - Neovim integration issues
6. **YAML/JSON syntax errors** - Must be valid
7. **Markdownlint issues** - Fix formatting and style issues

## Before Pull Request

- [ ] All linting passes without errors
- [ ] Both Lua (Neovim) and VimScript (Vim) implementations tested
- [ ] HEREDOC preservation verified
- [ ] Comment indentation working correctly
- [ ] Health check passes (`:checkhealth shellspec`)
- [ ] Manual plugin testing completed
- [ ] Documentation is updated with dual examples
- [ ] Commit messages are descriptive
- [ ] No sensitive information in commits

## Regression Testing

When modifying core formatting logic:

- [ ] Test with complex nested ShellSpec structures
- [ ] Test with mixed HEREDOC types (`<<EOF`, `<<'EOF'`, `<<"EOF"`)
- [ ] Test with edge cases (empty files, comment-only files)
- [ ] Test auto-format behavior
- [ ] Test with different indent_size configurations
