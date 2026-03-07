# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

nulet is a FIGlet text renderer implemented as a Nushell module. It parses FIGfont (.flf) files and renders text as ASCII art, matching the FIGfont Version 2 standard (`figlet-standard.txt`).

## Setup

```bash
git submodule update --init   # or: nu toolkit.nu setup
```

This fetches the `figlet-fonts/` submodule (xero/figlet-fonts) which provides ~380 .flf font files. System figlet fonts (from `figlet -I2`) are also discovered at runtime.

## Testing

```bash
nu toolkit.nu test              # all 11 common fonts x 6 test strings
nu toolkit.nu test -f Standard  # single font
```

Tests compare nulet output against the `figlet` binary (must be installed). All 66 tests should pass.

## Usage

```nushell
# Script mode (subcommands work reliably here)
nu nulet/mod.nu "Hello" -f Standard
nu nulet/mod.nu fonts
nu nulet/mod.nu showcase -t "Hi"

# Module mode
use nulet; nulet "Hello" -f Standard
```

**Known limitation:** `main` uses `...text: string` (rest params), which causes nushell to consume subcommand names as positional args in module mode. Subcommands (`fonts`, `info`, `preview`, `showcase`) only work reliably in script mode.

## Architecture

Three files in `nulet/`, split by responsibility:

- **`parse.nu`** — FIGfont parser. `load-font` reads a .flf file and returns `{header: record, chars: record}` where `chars` maps Unicode code points (as strings) to lists of lines. Handles the header, required chars (ASCII 32-126 + 7 Deutsch), and code-tagged chars.

- **`render.nu`** — Renderer. `render-text` assembles FIGcharacters into a FIGure using horizontal layout (full/fit/smush). Implements all 6 smushing rules plus universal smushing. Post-processing strips common leading blanks and replaces hardblanks with spaces.

- **`mod.nu`** — Public API and CLI. Re-exports `load-font`, `render-text`, etc. Provides subcommands (`fonts`, `info`, `preview`, `showcase`). Handles font resolution across bundled submodule and system figlet directories. Contains the `font-names` custom completer for `--font` flags.

## Key concepts

- **Hardblanks**: Displayed as spaces but treated as visible characters during layout. Only smushing rule 6 can merge two hardblanks.
- **Layout modes**: Derived from `full_layout` header field when present, otherwise from `old_layout`. Values: `full` (no overlap), `fit` (touch but don't merge), `smush` (overlap with rules).
- **Font resolution order**: exact path → bundled `figlet-fonts/` dir → system figlet dir (via `figlet -I2`).
- **Completions**: `font-names` pre-quotes names containing spaces (e.g., `'ANSI Regular'`) to work around nushell's custom-completion quoting behavior.

## Nushell patterns used

- `const` with `path self` for compile-time module-relative paths
- `par-each --keep-order` for parallel font rendering in `showcase`
- `reduce --fold` for accumulating FIGcharacters in `render-text`
- Custom completers via `string@completer-fn` on flag types
- `upsert` (not `insert`) for char maps since some fonts define Deutsch chars in both required and code-tagged sections
