# nulet

A FIGlet text renderer implemented as a Nushell module. Parses FIGfont (.flf) files and renders text as ASCII art.

## Setup

```bash
git submodule update --init
```

This fetches bundled fonts from [xero/figlet-fonts](https://github.com/xero/figlet-fonts). System figlet fonts (from `figlet -I2`) are also discovered at runtime — nearly 400 fonts in total.

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

## Testing

```bash
nu toolkit.nu test              # all tests (requires figlet binary)
nu toolkit.nu test -f Standard  # single font
```

Tests compare nulet output against the system `figlet` binary.
