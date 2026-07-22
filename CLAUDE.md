# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

nulet is a FIGlet text renderer implemented as a Nushell module. It parses FIGfont (.flf) files and renders text as ASCII art, matching the FIGfont Version 2 standard (`figfont-standard.txt`), with ANSI color and gradient support and ~400 bundled fonts.

In this workspace nulet is also a runtime dependency of `../nushell-show-module` (`npshow`): its cover-screen commands render episode titles with `nulet <text> -f phm-largetype` and `nulet 'nushell-prophet' -f phm-rounded -c g-neon -g vertical`, then pipe the result into `ansi-to-png` (from `../nu-goodies`) to make the YouTube covers.

## Setup

```bash
nu toolkit.nu setup-fonts
```

This is the real entry point: it inits the font submodules in `font-submodules/` ([xero/figlet-fonts](https://github.com/xero/figlet-fonts) and [PhMajerus/FIGfonts](https://github.com/PhMajerus/FIGfonts)), sparse-checkouts the FIGfonts `fonts` dir, and pre-compiles every font to JSON in `compiled/` (gitignored, ~40× faster loading). A bare `git submodule update --init` only fetches the submodules — it skips the sparse-checkout and compilation. System figlet fonts (from `figlet -I2`) are also discovered at runtime.

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

# Module mode — render-text and showcase are top-level exports
use nulet; nulet "Hello" -f Standard
nulet showcase -t "Hi"

# Color and gradients
nulet "Hello" -f Standard -c rainbow
nulet "Hello" -f Standard -c g-neon -g vertical
```

**Known limitation:** `main` uses `...text: string` (rest params), which causes nushell to consume subcommand names as positional args in module mode. The `main <sub>` subcommands (`fonts`, `info`, `preview`) only work reliably in script mode. `render-text`/`main` and `showcase` are top-level `export def`s, so they work in module mode.

## Architecture

Five files in `nulet/`, split by responsibility:

- **`parse.nu`** — FIGfont parser. `load-font` (private) reads a .flf (or pre-compiled .json) file and returns `{header: record, chars: record}` where `chars` maps Unicode code points (as strings) to lists of lines. Handles the header, required chars (ASCII 32-126 + 7 Deutsch), and code-tagged chars.

- **`render.nu`** — Renderer. `render-text` assembles FIGcharacters into a FIGure using horizontal layout (full/fit/smush). Implements all 6 smushing rules plus universal smushing. Post-processing strips common leading blanks and replaces hardblanks with spaces.

- **`fonts.nu`** — Font discovery and resolution. `resolve-font` (compiled JSON → bundled dirs → system figlet → vendored fallback), `all-font-files`, `font-display-name`, and the `font-names` custom completer for `--font` flags. `DEFAULT_FONT` and `COMPILED_FONT_DIR` live here.

- **`color.nu`** — ANSI color and gradients. `colorize` applies a color spec to rendered text; `color-names` and `gradient-names` are the completers. 11 named colors, `#rrggbb` hex, `rainbow`, 8 `g-*` gradient presets (g-sunset, g-ocean, g-fire, g-ice, g-neon, g-pastel, g-gold, g-matrix), and two-color `from:to` gradients, with horizontal/vertical direction and `--reverse` (long-arc HSL interpolation).

- **`mod.nu`** — Thin CLI/routing layer. `export use`s `render-text` (as `main`) and `colorize`; defines `showcase` (top-level export) and the `main <sub>` subcommands (`fonts`, `info`, `preview`). Slimmed to a small public API — `load-font` and the font-resolution internals are private imports from `parse.nu`/`fonts.nu`.

## Key concepts

- **Hardblanks**: Displayed as spaces but treated as visible characters during layout. Only smushing rule 6 can merge two hardblanks.
- **Layout modes**: Derived from `full_layout` header field when present, otherwise from `old_layout`. Values: `full` (no overlap), `fit` (touch but don't merge), `smush` (overlap with rules).
- **Font resolution order** (`fonts.nu resolve-font`): exact path → pre-compiled `.json` in `compiled/` → bundled dirs in `font-submodules/` → system figlet dir (via `figlet -I2`) → vendored `Small.flf` fallback in `fonts/`.
- **Color/gradients** (`color.nu`): `-c/--color` takes a color name, `rainbow`, a `g-*` preset, or a `from:to` pair; `-g/--gradient` picks the direction (horizontal/vertical); `-r/--reverse` flips it. `render-text`, `main`, `showcase`, and `preview` all accept these.
- **Completions**: `font-names` pre-quotes names containing spaces (e.g., `'ANSI Regular'`) to work around nushell's custom-completion quoting behavior.

## Nushell patterns used

- `const` with `path self` for compile-time module-relative paths
- `par-each --keep-order` for parallel font rendering in `showcase`
- `reduce --fold` for accumulating FIGcharacters in `render-text`
- Custom completers via `string@completer-fn` on flag types
- `upsert` (not `insert`) for char maps since some fonts define Deutsch chars in both required and code-tagged sections
