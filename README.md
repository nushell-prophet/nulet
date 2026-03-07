# nulet

A FIGlet text renderer implemented as a Nushell module. Parses FIGfont (.flf) files and renders text as ASCII art.

## Setup

```bash
nu toolkit.nu setup
```

This fetches bundled fonts from [xero/figlet-fonts](https://github.com/xero/figlet-fonts) and [PhMajerus/FIGfonts](https://github.com/PhMajerus/FIGfonts) into `font-submodules/`. System figlet fonts (from `figlet -I2`) are also discovered at runtime.

## Usage

```nushell
# Script mode
nu nulet/mod.nu "Hello World" -f Standard

# Module mode
use nulet
nulet "Hello World" -f Standard

# List available fonts
nu nulet/mod.nu fonts

# Showcase fonts
nu nulet/mod.nu showcase -t "Hi"
```

## Development

`toolkit.nu` provides development commands:

```bash
nu toolkit.nu setup              # fetch font submodules
nu toolkit.nu test               # run all tests (requires figlet binary)
nu toolkit.nu test -f Standard   # test a single font
```

Tests compare nulet output against the system `figlet` binary.
