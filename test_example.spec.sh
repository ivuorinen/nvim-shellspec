#!/bin/bash

Describe "ShellSpec formatting test"
# This is a top-level comment
Context "when testing HEREDOC support"
# Comment inside Context
It "should preserve HEREDOC formatting"
# Comment inside It block
When call cat <<EOF
    This indentation should be preserved
      Even with deeper indentation
    Back to original level
EOF
The output should include "preserved"
End

It "should handle quoted HEREDOC"
When call cat <<'DATA'
  # This comment inside HEREDOC should not be touched
  Some $variable should not be expanded
DATA
The output should include "variable"
End
End

Context "when testing regular formatting"
# Another context comment
It "should indent comments properly"
# This comment should be indented to It level
When call echo "test"
# Another comment at It level
The output should equal "test"
End
End
End
