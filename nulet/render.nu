# FIGlet renderer — assembles FIGcharacters into FIGures

use parse.nu [char-to-code, layout-mode]

# Get the visible width of a FIGcharacter (width of its first line)
def fig-width [fig: list<string>]: nothing -> int {
    $fig | first | str length -g
}

# Apply horizontal smushing rules.
# Returns the smushed character, or null if no rule applies.
def smush-char [
    left: string
    right: string
    hardblank: string
    rules: int
    old_smush: bool  # Pre-2.2: universal fallback when rules don't match
]: nothing -> any {
    # Universal smushing: no rules, later char wins
    if $rules == 0 {
        if $left == ' ' { return $right }
        if $right == ' ' { return $left }
        if $left == $hardblank { return $right }
        if $right == $hardblank { return $left }
        return $right
    }

    # Handle blanks (applies to all rule sets)
    if $left == ' ' { return $right }
    if $right == ' ' { return $left }

    # Rule 6: Hardblank smushing
    if ($rules bit-and 32) != 0 {
        if $left == $hardblank and $right == $hardblank { return $hardblank }
    }

    # Rule 1: Equal character smushing (not hardblanks)
    if ($rules bit-and 1) != 0 {
        if $left == $right and $left != $hardblank { return $left }
    }

    # Rule 2: Underscore smushing
    if ($rules bit-and 2) != 0 {
        let replace_chars = ['|' '/' '\' '[' ']' '{' '}' '(' ')' '<' '>']
        if $left == '_' and ($right in $replace_chars) { return $right }
        if $right == '_' and ($left in $replace_chars) { return $left }
    }

    # Rule 3: Hierarchy smushing
    if ($rules bit-and 4) != 0 {
        let classes = ['|' '/\' '[]' '{}' '()' '<>']
        let l_class = $classes | enumerate | where {|e| $e.item | str contains $left } | get --optional 0.index
        let r_class = $classes | enumerate | where {|e| $e.item | str contains $right } | get --optional 0.index
        if $l_class != null and $r_class != null and $l_class != $r_class {
            if $l_class > $r_class { return $left } else { return $right }
        }
    }

    # Rule 4: Opposite pair smushing
    if ($rules bit-and 8) != 0 {
        let pair = [$left $right] | str join
        if $pair in ['[]' '][' '{}' '}{' '()' ')('] { return '|' }
    }

    # Rule 5: Big X smushing
    if ($rules bit-and 16) != 0 {
        let pair = [$left $right] | str join
        if $pair == '/\\' { return '|' }
        if $pair == '\\/' { return 'Y' }
        if $pair == '><' { return 'X' }
    }

    # Old-style smushing: universal fallback for visible+visible pairs only
    # Hardblanks remain barriers — only rule 6 can smush them
    if $old_smush and $left != $hardblank and $right != $hardblank {
        return $right
    }

    null
}

# Calculate how many columns two FIGcharacters can overlap
def calc-overlap [
    left: list<string>
    right: list<string>
    hardblank: string
    mode: string
    rules: int
    old_smush: bool
]: nothing -> int {
    if $mode == 'full' { return 0 }
    let l_width = fig-width $left
    if $l_width == 0 { return 0 }

    # For each row, find how far right can move left
    let max_per_row = $left | zip $right | each {|pair|
        let l_row = $pair.0
        let r_row = $pair.1
        let l_len = $l_row | str length -g
        let r_len = $r_row | str length -g

        # Count trailing blanks on left (hardblanks are NOT blank for horizontal ops)
        let l_trail = $l_row | str replace -r '.*?( *)$' '$1' | str length -g

        # Count leading blanks on right
        let r_lead = $r_row | str replace -r '^( *).*' '$1' | str length -g

        let fit_amount = $l_trail + $r_lead

        if $mode == 'smush' {
            # Try smushing one more column
            let smush_col_l = $l_len - $l_trail - 1
            let smush_col_r = $r_lead
            if $smush_col_l >= 0 and $smush_col_r < $r_len {
                let l_chars = $l_row | split chars
                let r_chars = $r_row | split chars
                let lc = $l_chars | get $smush_col_l
                let rc = $r_chars | get $smush_col_r
                let result = smush-char $lc $rc $hardblank $rules $old_smush
                if $result != null {
                    $fit_amount + 1
                } else {
                    $fit_amount
                }
            } else {
                $fit_amount + 1
            }
        } else {
            $fit_amount
        }
    }

    # The overlap is the minimum across all rows, capped at left width
    let overlap = $max_per_row | math min
    [$overlap $l_width] | math min
}

# Combine two FIGcharacters horizontally with a given overlap
def combine-figs [
    left: list<string>
    right: list<string>
    overlap: int
    hardblank: string
    mode: string
    rules: int
    old_smush: bool
]: nothing -> list<string> {
    if $overlap == 0 {
        return ($left | zip $right | each {|pair| $pair.0 + $pair.1 })
    }

    $left | zip $right | each {|pair|
        let l_row = $pair.0
        let r_row = $pair.1
        let l_chars = $l_row | split chars
        let r_chars = $r_row | split chars
        let l_len = $l_chars | length
        let r_len = $r_chars | length

        let l_keep = $l_len - $overlap
        let left_part = if $l_keep > 0 {
            $l_chars | first $l_keep | str join
        } else {
            ""
        }

        let overlap_start_l = [0 $l_keep] | math max
        let overlap_chars = 0..<$overlap | each {|k|
            let li = $overlap_start_l + $k
            let ri = $k
            let lc = if $li < $l_len { $l_chars | get $li } else { ' ' }
            let rc = if $ri < $r_len { $r_chars | get $ri } else { ' ' }
            if $mode == 'smush' {
                let s = smush-char $lc $rc $hardblank $rules $old_smush
                if $s != null { $s } else if $lc == ' ' { $rc } else { $lc }
            } else {
                if $lc == ' ' { $rc } else { $lc }
            }
        } | str join

        let right_part = if $overlap < $r_len {
            $r_chars | skip $overlap | str join
        } else {
            ""
        }

        $left_part + $overlap_chars + $right_part
    }
}

# Render a string using the given font
export def render-text [
    text: string
    font: record
    --layout-override: string  # Override layout mode: full, fit, smush
]: nothing -> string {
    let header = $font.header
    let chars = $font.chars
    let hardblank = $header.hardblank
    let height = $header.height
    let lm = layout-mode $header
    let mode = $layout_override | default $lm.mode
    let rules = $lm.rules
    let old_smush = $lm.old_smush

    # Build empty FIGcharacter (zero width)
    let empty_fig = 0..<$height | each { "" }

    # Look up FIGcharacter for a code, with fallback to code 0 or empty
    let get_fig = {|code|
        let key = $code | into string
        let fig = $chars | get --optional $key
        if $fig != null {
            $fig
        } else {
            let fallback = $chars | get --optional "0"
            $fallback | default $empty_fig
        }
    }

    # Render each character and combine
    let result = $text | split chars | reduce --fold $empty_fig {|ch, acc|
        let code = $ch | char-to-code
        let fig = do $get_fig $code
        let overlap = calc-overlap $acc $fig $hardblank $mode $rules $old_smush
        combine-figs $acc $fig $overlap $hardblank $mode $rules $old_smush
    }

    # Replace hardblanks with spaces in final output
    let lines = $result | each { str replace --all $hardblank ' ' }

    # In fit/smush modes, strip common leading blank columns
    if $mode in ['fit' 'smush'] {
        let min_lead = $lines
        | where { str trim | is-not-empty }
        | each {|line| $line | str replace -r '^( *).*' '$1' | str length -g }
        | math min
        | default 0
        if $min_lead > 0 {
            $lines | each { str substring -g $min_lead.. } | str join (char nl)
        } else {
            $lines | str join (char nl)
        }
    } else {
        $lines | str join (char nl)
    }
}
