# nulet — FIGlet renderer for Nushell
#
# Usage:
#   Script mode (recommended):  nu nulet/mod.nu "Hello World" -f Standard
#   Module mode:                use nulet; nulet "Hello World" -f Standard
#   Subcommands:                nu nulet/mod.nu fonts
#                               nu nulet/mod.nu info -f Big
#                               nu nulet/mod.nu preview -f Slant
#                               nu nulet/mod.nu showcase -t "Hi"

export use parse.nu [load-font]
export use render.nu [render-text]
use parse.nu [parse-header, layout-mode, char-to-code]

const FONTS_DIR = (path self | path dirname | path join '..' 'figlet-fonts')
const DEFAULT_FONT = 'Small.flf'

# Get system figlet font directory, or null if figlet is not installed
def system-font-dir []: nothing -> any {
    try { ^figlet -I2 | str trim } catch { null }
}

# Collect all .flf files from bundled + system font directories
def all-font-files []: nothing -> table {
    let sys = system-font-dir
    let dirs = if $sys != null and ($sys | path exists) {
        [$FONTS_DIR $sys]
    } else {
        [$FONTS_DIR]
    }
    $dirs | each {|d| try { ls $d | where name =~ '\.flf$' } catch { [] } } | flatten
}

# Complete font names from all known font directories
def font-names []: nothing -> list<string> {
    all-font-files
    | each { get name | path basename | str replace '.flf' '' }
    | uniq
    | sort
    | each {|name| if ($name | str contains ' ') { $"'($name)'" } else { $name } }
}

# Resolve font path: absolute path, relative path, or font name in known directories
def resolve-font [font: string] {
    if ($font | path exists) {
        return $font
    }
    # Search bundled fonts, then system figlet fonts
    let sys = system-font-dir
    let dirs = if $sys != null and ($sys | path exists) {
        [$FONTS_DIR $sys]
    } else {
        [$FONTS_DIR]
    }
    for dir in $dirs {
        let candidate = $dir | path join $font
        if ($candidate | path exists) { return $candidate }
        let with_ext = $dir | path join ($font + '.flf')
        if ($with_ext | path exists) { return $with_ext }
    }
    error make {msg: $"Font not found: ($font). Use `nulet fonts` to list available fonts."}
}

# Render text as FIGlet ASCII art
export def main [
    ...text: string          # Text to render (joined with spaces)
    --font (-f): string@font-names  # Font name or path to .flf file
    --layout (-l): string    # Layout mode: full, fit, smush
]: nothing -> string {
    if ($text | is-empty) {
        error make {msg: "No text provided. Usage: nulet <text> [-f font] [-l layout]"}
    }
    let font_path = resolve-font ($font | default $DEFAULT_FONT)
    let f = load-font $font_path
    render-text ($text | str join ' ') $f --layout-override $layout
}

# List available fonts
export def "main fonts" []: nothing -> table {
    all-font-files
    | select name
    | update name { path basename | str replace '.flf' '' }
    | rename font
    | uniq-by font
    | sort-by font
}

# Show font info (header + layout mode)
export def "main info" [
    --font (-f): string@font-names  # Font name or path
]: nothing -> record {
    let font_path = resolve-font ($font | default $DEFAULT_FONT)
    let f = load-font $font_path
    let lm = layout-mode $f.header
    $f.header | merge ($lm | reject old_smush) | insert char_count ($f.chars | columns | length)
}

# Showcase all fonts with sample text
export def "main showcase" [
    --text (-t): string   # Sample text (default: "Hello")
]: nothing -> record {
    let sample = $text | default "Hello"
    all-font-files
    | sort-by name
    | par-each --keep-order {|f|
        let name = $f.name | path basename | str replace '.flf' ''
        try {
            [($name) (render-text $sample (load-font $f.name))]
        } catch {
            null
        }
    }
    | compact
    | into record
}

# Preview a font with sample text
export def "main preview" [
    --font (-f): string@font-names   # Font name or path
    --text (-t): string   # Sample text (default: font name)
]: nothing -> string {
    let font_name = $font | default $DEFAULT_FONT | str replace '.flf' ''
    let sample = $text | default $font_name
    let font_path = resolve-font ($font | default $DEFAULT_FONT)
    let f = load-font $font_path
    render-text $sample $f
}
