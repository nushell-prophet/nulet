# nulet development toolkit

export def main [] {
    print "Available commands:"
    print "  toolkit.nu setup    — fetch font submodules"
    print "  toolkit.nu test     — run tests against figlet"
}

# Fetch font submodules (figlet-fonts, FIGfonts)
export def "main setup" [] {
    print "Initializing font submodules..."
    ^git submodule update --init
    # Only check out the fonts/ directory from FIGfonts
    ^git -C font-submodules/FIGfonts sparse-checkout set fonts
    print "Done."
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
