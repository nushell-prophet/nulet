# nulet — FIGlet renderer for Nushell
#
# Usage:
#   Script mode (recommended):  nu nulet/mod.nu "Hello World" -f Standard
#   Module mode:                use nulet; nulet "Hello World" -f Standard
#   Subcommands:                nu nulet/mod.nu fonts
#                               nu nulet/mod.nu info -f Big
#                               nu nulet/mod.nu preview -f Slant
#   Module mode:                use nulet; nulet showcase -t "Hi"

export use render.nu [ render-text ]
export use color.nu [ colorize ]
use parse.nu [ load-font layout-mode ]
use fonts.nu [ DEFAULT_FONT font-display-name all-font-files font-names resolve-font ]
use color.nu [ color-names gradient-names ]

# Render text as FIGlet ASCII art
export def main [
    ...text: string # Text to render (joined with spaces)
    --font (-f): string@font-names # Font name or path to .flf file
    --layout (-l): string # Layout mode: full, fit, smush
    --color (-c): string@color-names # Color: name, "rainbow", or "from:to" gradient
    --gradient (-g): string@gradient-names # Direction: horizontal (default) or vertical
    --reverse (-r) # Reverse the gradient direction
]: nothing -> string {
    if ($text | is-empty) {
        error make {msg: "No text provided. Usage: nulet <text> [-f font] [-l layout]"}
    }
    let font_path = resolve-font ($font | default $DEFAULT_FONT)
    let f = load-font $font_path
    let input = $text | str join ' ' | str replace --all '\n' (char nl)
    let result = render-text $input $f --layout-override $layout
    if $color != null {
        $result | colorize $color --direction $gradient --reverse=$reverse
    } else {
        $result
    }
}

# List available fonts
def "main fonts" []: nothing -> table {
    all-font-files
    | select name
    | update name { font-display-name }
    | rename font
    | uniq-by font
    | sort-by font
}

# Show font info (header + layout mode)
def "main info" [
    --font (-f): string@font-names # Font name or path
]: nothing -> record {
    let font_path = resolve-font ($font | default $DEFAULT_FONT)
    let f = load-font $font_path
    let lm = layout-mode $f.header
    $f.header | merge ($lm | reject old_smush) | insert char_count ($f.chars | columns | length)
}

# Showcase fonts with sample text
#
# By default, displays 5 random fonts. Use --all-fonts to render every
# installed font (with ~400 fonts this takes 6 seconds or more).
export def showcase [
    --text (-t): string # Sample text (default: "Hello")
    --all-fonts (-a) # Render all fonts instead of a random sample
    --num (-n): int # Number of random fonts to show (default: 5)
    --color (-c): string@color-names # Color: name, "rainbow", or "from:to" gradient
    --gradient (-g): string@gradient-names # Direction: horizontal (default) or vertical
    --reverse (-r) # Reverse the gradient direction
]: nothing -> record {
    let sample = $text | default "Hello"
    let fonts = all-font-files | sort-by name
    let selection = if $all_fonts {
        $fonts
    } else {
        $fonts | shuffle | first ($num | default 5)
    }
    $selection
    | par-each --keep-order {|f|
        let name = $f.name | font-display-name
        try {
            let rendered = render-text $sample (load-font $f.name)
            let result = if $color != null {
                $rendered | colorize $color --direction $gradient --reverse=$reverse
            } else {
                $rendered
            }
            [($name) $result]
        } catch {
            null
        }
    }
    | compact
    | into record
}

# Preview a font with sample text
def "main preview" [
    --font (-f): string@font-names # Font name or path
    --text (-t): string # Sample text (default: font name)
    --color (-c): string@color-names # Color: name, "rainbow", or "from:to" gradient
    --gradient (-g): string@gradient-names # Direction: horizontal (default) or vertical
    --reverse (-r) # Reverse the gradient direction
]: nothing -> string {
    let font_file = $font | default $DEFAULT_FONT
    let sample = $text | default ($font_file | str replace '.flf' '')
    let f = load-font (resolve-font $font_file)
    let result = render-text $sample $f
    if $color != null {
        $result | colorize $color --direction $gradient --reverse=$reverse
    } else {
        $result
    }
}
