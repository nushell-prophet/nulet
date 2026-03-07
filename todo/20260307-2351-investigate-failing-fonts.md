---
task-name: investigate-failing-fonts
status: draft
created: 2026-03-07
updated: 2026-03-07
related_files:
  - nulet/parse.nu
  - toolkit.nu
---

# Investigate fonts failing to compile with "Input type not supported"

## Task from user (original)

Investigate the 76 fonts that fail during `toolkit.nu compile` with "Input type not supported" error.

## Task description (extended version)

During `toolkit.nu compile`, 76 out of 423 fonts fail with "Input type not supported". The error originates in `parse.nu:116` where `str contains` is called on the raw font data to check for ANSI escape codes. Some fonts are read as binary by `open --raw` and `str contains` doesn't accept binary input.

These fonts work with `figlet` itself, so they are valid FIGfonts — the issue is in our parser's handling of binary vs string data.

## Requirements

- [ ] All valid FIGfont .flf files should parse and compile successfully
- [ ] Fix should not regress existing 66/66 test suite
- [ ] Binary-encoded fonts (likely Latin-1 or other non-UTF-8) must be handled

## Implementation plan

- [ ] Step 1: Identify why some fonts come back as binary from `open --raw` (encoding detection)
- [ ] Step 2: Fix the `str contains` call on line 116 — either convert binary to string first, or use `bytes` operations for the ANSI check
- [ ] Step 3: Re-run `toolkit.nu compile` and verify the failure count drops to 0 (or only truly invalid fonts remain)
- [ ] Step 4: Run `toolkit.nu test` to confirm no regressions

## Affected files

- `nulet/parse.nu` — the `load-font` function, specifically the ANSI detection and line splitting logic
