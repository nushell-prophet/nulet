# FIGfont parser — reads .flf files into structured font records

# Convert a single character to its Unicode code point
export def char-to-code []: string -> int {
    let bytes = $in | encode utf-8
    let len = $bytes | bytes length
    if $len == 1 {
        $bytes | into int
    } else if $len == 2 {
        let b0 = $bytes | bytes at 0..<1 | into int
        let b1 = $bytes | bytes at 1..<2 | into int
        ($b0 - 192) * 64 + ($b1 - 128)
    } else if $len == 3 {
        let b0 = $bytes | bytes at 0..<1 | into int
        let b1 = $bytes | bytes at 1..<2 | into int
        let b2 = $bytes | bytes at 2..<3 | into int
        ($b0 - 224) * 4096 + ($b1 - 128) * 64 + ($b2 - 128)
    } else if $len == 4 {
        let b0 = $bytes | bytes at 0..<1 | into int
        let b1 = $bytes | bytes at 1..<2 | into int
        let b2 = $bytes | bytes at 2..<3 | into int
        let b3 = $bytes | bytes at 3..<4 | into int
        ($b0 - 240) * 262144 + ($b1 - 128) * 4096 + ($b2 - 128) * 64 + ($b3 - 128)
    } else {
        0
    }
}

# Strip endmark characters from the right side of a FIGcharacter line
def strip-endmarks []: string -> string {
    if ($in | is-empty) { return "" }
    let endmark = $in | split chars | last
    $in | str trim --right --char $endmark
}

# Parse the FIGfont header line
export def parse-header []: string -> record {
    let parts = $in | split row ' ' | where $it != ''
    let sig_hb = $parts.0
    if not ($sig_hb | str starts-with 'flf2a') {
        error make {msg: "Invalid FIGfont: signature must start with flf2a"}
    }
    let hardblank = $sig_hb | str substring 5..
    let n = $parts | length
    {
        hardblank: $hardblank
        height: ($parts.1 | into int)
        baseline: ($parts.2 | into int)
        max_length: ($parts.3 | into int)
        old_layout: ($parts.4 | into int)
        comment_lines: ($parts.5 | into int)
        print_direction: (if $n > 6 { $parts.6 | into int } else { 0 })
        full_layout: (if $n > 7 { $parts.7 | into int } else { null })
        codetag_count: (if $n > 8 { $parts.8 | into int } else { null })
    }
}

# Determine horizontal layout mode from header
export def layout-mode [header: record]: nothing -> record {
    let fl = $header.full_layout
    if $fl != null {
        let h_smush = ($fl bit-and 128) != 0
        let h_fit = ($fl bit-and 64) != 0
        let h_rules = $fl bit-and 63
        let mode = if $h_smush {
            "smush"
        } else if $h_fit {
            "fit"
        } else {
            "full"
        }
        # New-style: controlled smushing falls back to fitting
        {mode: $mode, rules: $h_rules, old_smush: false}
    } else {
        # Full_Layout absent — derive from Old_Layout
        # Old_Layout > 0: controlled smushing with those rules (matches figlet 2.2)
        let ol = $header.old_layout
        if $ol == -1 {
            {mode: "full", rules: 0, old_smush: false}
        } else if $ol == 0 {
            {mode: "fit", rules: 0, old_smush: false}
        } else {
            {mode: "smush", rules: $ol, old_smush: false}
        }
    }
}

# Parse a code tag line, returning the character code
def parse-code-tag []: string -> int {
    $in | str trim | split row ' ' | first | str downcase | into int
}

# Load and parse a FIGfont file
export def load-font [path: string]: nothing -> record {
    let raw = if (open --raw $path | bytes at 0..<2) == (0x[504B]) {
        ^unzip -p $path
    } else {
        open --raw $path
    }
    let all_lines = try { $raw | lines } catch { $raw | decode latin1 | lines }
    let header = $all_lines | first | parse-header
    let height = $header.height
    let data_start = 1 + $header.comment_lines
    let data_lines = $all_lines | skip $data_start

    # Required character codes: ASCII 32-126, then Deutsch
    let required_codes = 32..126 | append [196 214 220 228 246 252 223]
    let n_required = $required_codes | length

    # Parse required FIGcharacters
    mut chars = {}
    for i in 0..<$n_required {
        let start = $i * $height
        let fig_lines = $data_lines | skip $start | first $height | each { strip-endmarks }
        let code = $required_codes | get $i
        $chars = $chars | upsert ($code | into string) $fig_lines
    }

    # Parse code-tagged FIGcharacters
    mut idx = $n_required * $height
    let total = $data_lines | length
    while $idx < $total {
        let tag_line = $data_lines | get $idx
        let code = try { $tag_line | parse-code-tag } catch { break }
        $idx = $idx + 1
        if ($idx + $height) > $total { break }
        let fig_lines = $data_lines | skip $idx | first $height | each { strip-endmarks }
        $chars = $chars | upsert ($code | into string) $fig_lines
        $idx = $idx + $height
    }

    {header: $header, chars: $chars}
}
