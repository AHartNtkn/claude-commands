#!/bin/bash
# Filter out .claude/sessions files from PR diff
gh pr diff "$1" | perl -0pe 's/diff --git a\/\.claude\/sessions\/.*?(?=diff --git|$)//gs'