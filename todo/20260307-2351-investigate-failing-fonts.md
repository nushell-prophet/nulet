---
task-name: investigate-failing-fonts
status: done
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

During `toolkit.nu compile`, 76 out of 423 fonts failed with "Input type not supported". The root cause: `open --raw` returns binary data, and non-UTF-8 fonts stayed binary. `str contains` on line 116 doesn't accept binary input.

**Fix**: Added early binary-to-string decoding in `load-font` (try UTF-8, fall back to ISO-8859-1) before any string operations. This also simplified the `lines` call which no longer needs its own try/catch fallback.

## Requirements

- [x] All valid FIGfont .flf files should parse and compile successfully — 423/423
- [x] Fix should not regress existing 66/66 test suite — 66/66
- [x] Binary-encoded fonts (likely Latin-1 or other non-UTF-8) must be handled

## Implementation plan

- [x] Step 1: Identified cause — `open --raw` returns binary; non-UTF-8 fonts can't be used with `str contains`
- [x] Step 2: Added `decode utf-8` / `decode iso-8859-1` fallback before ANSI check and `lines`
- [x] Step 3: `toolkit.nu compile` — 423/423 fonts compiled
- [x] Step 4: `toolkit.nu test` — 66/66 tests passed
