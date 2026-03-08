# nulet

A FIGlet text renderer implemented as a Nushell module. Parses FIGfont (.flf) files and renders text as ASCII art.

## Setup

```bash
nu toolkit.nu setup-fonts
```

This fetches bundled fonts from [xero/figlet-fonts](https://github.com/xero/figlet-fonts) and [PhMajerus/FIGfonts](https://github.com/PhMajerus/FIGfonts) into `font-submodules/`. System figlet fonts (from `figlet -I2`) are also discovered at runtime.

A vendored `Small` font in `fonts/` ensures nulet works out of the box without submodules or system figlet.

## Demo

```nu
> use nulet; nulet "Hello World" -f Standard
 _   _      _ _        __        __         _     _
| | | | ___| | | ___   \ \      / /__  _ __| | __| |
| |_| |/ _ \ | |/ _ \   \ \ /\ / / _ \| '__| |/ _` |
|  _  |  __/ | | (_) |   \ V  V / (_) | |  | | (_| |
|_| |_|\___|_|_|\___/     \_/\_/ \___/|_|  |_|\__,_|
```

## Usage

```nushell
use nulet

# Render text
nulet "Hello World" -f Standard

# Showcase random fonts
nulet showcase -t "Hi"
nulet showcase -t "Hi" --all-fonts    # render all fonts
nulet showcase -t "Hi" -n 10         # 10 random fonts

# Subcommands (script mode only)
nu nulet/mod.nu fonts               # list available fonts
nu nulet/mod.nu info -f Big          # font header, layout mode, char count
nu nulet/mod.nu preview -f Slant    # preview a font
```

### Color

All rendering commands support `--color (-c)`, `--gradient (-g)`, and `--reverse (-r)`:

```nushell
use nulet

# Solid color (named or hex)
nulet "Hello" -f Standard --color red
nulet "Hello" -f Standard --color '#ff6600'

# Rainbow
nulet "Hello" -f Standard --color rainbow

# Gradient presets: g-sunset, g-ocean, g-fire, g-ice, g-neon, g-pastel, g-gold, g-matrix
nulet "Hello" -f Standard --color g-sunset

# Custom gradient between two colors
nulet "Hello" -f Standard --color 'red:blue'

# Vertical gradient
nulet "Hello" -f Standard --color g-ocean --gradient vertical

# Reverse gradient (long arc around the hue circle)
nulet "Hello" -f Standard --color 'red:blue' --reverse
```

## Development

`toolkit.nu` provides development commands:

```bash
nu toolkit.nu setup-fonts        # fetch font submodules + compile
nu toolkit.nu test               # run all tests (requires figlet binary)
nu toolkit.nu test -f Standard   # test a single font
```

Tests compare nulet output against the system `figlet` binary.
