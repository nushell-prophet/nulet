# Font discovery, resolution, and completions

const BUNDLED_FONT_DIRS = [
    (path self | path dirname | path join '..' 'figlet-fonts'),
    (path self | path dirname | path join '..' 'FIGfonts' 'fonts'),
]
export const DEFAULT_FONT = 'Small.flf'

# Get system figlet font directory, or null if figlet is not installed
def system-font-dir []: nothing -> any {
    try { ^figlet -I2 | str trim } catch { null }
}

# Directories to search for .flf font files (bundled + system)
def font-dirs []: nothing -> list<string> {
    let sys = system-font-dir
    let dirs = if $sys != null and ($sys | path exists) {
        $BUNDLED_FONT_DIRS | append $sys
    } else {
        $BUNDLED_FONT_DIRS
    }
    $dirs | where { path exists }
}

# Strip .flf extension to get a display name
export def font-display-name []: string -> string {
    path basename | str replace '.flf' ''
}

# Collect all .flf files from bundled + system font directories
export def all-font-files []: nothing -> table {
    font-dirs | each {|d| try { ls $d | where name =~ '\.flf$' } catch { [] } } | flatten
}

# Complete font names from all known font directories
export def font-names []: nothing -> list<string> {
    all-font-files
    | each { get name | font-display-name }
    | uniq
    | sort
    | each {|name| if ($name | str contains ' ') { $"'($name)'" } else { $name } }
}

# Resolve font path: absolute path, relative path, or font name in known directories
export def resolve-font [font: string] {
    if ($font | path exists) {
        return $font
    }
    for dir in (font-dirs) {
        let candidate = $dir | path join $font
        if ($candidate | path exists) { return $candidate }
        let with_ext = $dir | path join ($font + '.flf')
        if ($with_ext | path exists) { return $with_ext }
    }
    error make {msg: $"Font not found: ($font). Use `nulet fonts` to list available fonts."}
}
