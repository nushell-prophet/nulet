# nulet — FIGlet renderer for Nushell
#
# Usage:
#   Script mode (recommended):  nu nulet/mod.nu "Hello World" -f Standard
#   Module mode:                use nulet; nulet "Hello World" -f Standard
#   Subcommands:                nu nulet/mod.nu fonts
#                               nu nulet/mod.nu info -f Big
#                               nu nulet/mod.nu preview -f Slant

export use parse.nu [load-font, parse-header, layout-mode, char-to-code]
export use render.nu [render-text]

const FONTS_DIR = (path self | path dirname | path join '..' 'figlet-fonts')
const DEFAULT_FONT = 'Small.flf'

# Complete font names from the bundled fonts directory
def font-names []: nothing -> list<string> {
    ls $FONTS_DIR
    | where name =~ '\.flf$'
    | each { get name | path basename | str replace '.flf' '' }
    | sort
    | each {|name| if ($name | str contains ' ') { $"'($name)'" } else { $name } }
}

# Resolve font path: absolute path, relative path, or font name in bundled fonts
def resolve-font [font: string] {
    if ($font | path exists) {
        return $font
    }
    let candidate = $FONTS_DIR | path join $font
    if ($candidate | path exists) {
        return $candidate
    }
    let with_ext = $FONTS_DIR | path join ($font + '.flf')
    if ($with_ext | path exists) {
        return $with_ext
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
    ls $FONTS_DIR
    | where name =~ '\.flf$'
    | select name
    | update name { path basename | str replace '.flf' '' }
    | rename font
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
