# nulet development toolkit

export def main [] {
    print "Available commands:"
    print "  toolkit.nu setup-fonts — fetch font submodules + compile fonts"
    print "  toolkit.nu test        — run tests against figlet"
}

# Fetch font submodules and compile fonts
export def "main setup-fonts" [
    --no-compile  # Skip font pre-compilation step
] {
    print "Initializing font submodules..."
    ^git submodule update --init
    # Only check out the fonts/ directory from FIGfonts
    ^git -C font-submodules/FIGfonts sparse-checkout set fonts
    if not $no_compile {
        print "Compiling fonts..."
        compile-fonts
    }
    print "Done."
}

# Pre-compile .flf fonts to JSON for ~25x faster loading
def compile-fonts [
    --font (-f): string  # Compile a specific font (default: all)
] {
    use nulet/parse.nu [load-font]
    use nulet/fonts.nu [all-font-files, font-display-name]
    let out_dir = $env.FILE_PWD | path join 'compiled'
    mkdir $out_dir

    let fonts = if $font != null {
        all-font-files | where { $in.name | font-display-name | $in == $font }
    } else {
        all-font-files
    }
    | insert display { $in.name | font-display-name }
    | uniq-by display

    let results = $fonts | par-each --keep-order {|f|
        let name = $f.name | font-display-name
        try {
            let parsed = load-font $f.name
            let out_path = $out_dir | path join $"($name).json"
            $parsed | to json | save -f $out_path
            {font: $name, status: "ok"}
        } catch {|e|
            {font: $name, status: $"error: ($e.msg)"}
        }
    }

    let ok = $results | where status == "ok" | length
    let errors = $results | where status != "ok"
    print $"Compiled ($ok)/($results | length) fonts to compiled/"
    if not ($errors | is-empty) {
        print "\nFailed:"
        $errors | print
    }
}

# Run tests comparing nulet output against figlet
export def "main test" [
    --font (-f): string  # Test a specific font (default: all common fonts)
] {
    use nulet/parse.nu [load-font]
    use nulet [render-text]
    let all_fonts = if $font != null {
        [$"($font).flf"]
    } else {
        ['Small.flf' 'Standard.flf' 'Big.flf' 'Doom.flf' 'Banner.flf'
         'Slant.flf' 'Block.flf' 'Lean.flf' 'Mini.flf' 'Script.flf' 'Shadow.flf']
    }
    let words = ['Hello' 'Hi' 'Test 123' 'FIG' 'Hello World!' 'nulet']
    let results = $all_fonts | each {|f|
        let path = $"font-submodules/figlet-fonts/($f)"
        let font = try { load-font $path } catch {|e| return [{font: $f, text: "", ok: false, error: $e.msg}] }
        $words | each {|w|
            let mine = try { render-text $w $font | str trim --right } catch { "" }
            let ref = try { ^figlet -w 400 -f $path $w | str trim --right } catch { "" }
            {font: $f, text: $w, ok: ($mine == $ref)}
        }
    } | flatten
    let pass = $results | where ok | length
    let fail = $results | where { not $in.ok }
    print $"($pass)/($results | length) tests passed"
    if not ($fail | is-empty) {
        print "\nFailed:"
        $fail | select font text | print
    }
}
