# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.2] - 2026-03-08

### Added

- Full Unicode and extended glyph support in compiled fonts
- Font pre-compilation to JSON for ~40x faster loading

### Fixed

- Incorrect horizontal smushing with Big X (Rule 5)
- Fonts with binary-encoded data failing to load

### Changed

- Rename `setup` to `setup-fonts`; font compilation is now part of setup

## [0.0.1] - 2026-03-07

### Added

- FIGlet text renderer for Nushell with full FIGfont Version 2 support
- Tab completions for `--font` and `--gradient` flags
- `showcase` subcommand to browse all installed fonts
- ANSI color and gradient support with named presets
- Multiline text support via `\n`
- `--reverse` flag to flip rendered output
- Discover system-installed figlet fonts alongside bundled ones
- Support for loading zip-compressed font files
- Ship with bundled Small font as fallback

[Unreleased]: https://github.com/nushell-prophet/nulet/compare/0.0.2...HEAD
[0.0.2]: https://github.com/nushell-prophet/nulet/compare/0.0.1...0.0.2
[0.0.1]: https://github.com/nushell-prophet/nulet/releases/tag/0.0.1
