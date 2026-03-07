# ANSI color post-processing for FIGlet output

const NAMED_COLORS = {
    black: [0, 0, 0]
    red: [255, 0, 0]
    green: [0, 190, 0]
    blue: [0, 100, 255]
    yellow: [255, 255, 0]
    cyan: [0, 255, 255]
    magenta: [255, 0, 255]
    white: [255, 255, 255]
    orange: [255, 165, 0]
    pink: [255, 105, 180]
    purple: [128, 0, 128]
}

# Color names for shell completion
export def color-names []: nothing -> list<string> {
    $NAMED_COLORS | columns | prepend "rainbow" | sort
}

# Gradient direction names for shell completion
export def gradient-names []: nothing -> list<string> {
    [horizontal vertical]
}

# Resolve a color name or #rrggbb hex to an RGB triple
def resolve-color [spec: string]: nothing -> list<int> {
    let s = $spec | str downcase | str trim
    if ($s | str starts-with '#') {
        let hex = $s | str substring 1..
        [($"0x($hex | str substring 0..1)" | into int)
         ($"0x($hex | str substring 2..3)" | into int)
         ($"0x($hex | str substring 4..5)" | into int)]
    } else if $s in ($NAMED_COLORS | columns) {
        $NAMED_COLORS | get $s
    } else {
        error make {msg: $"Unknown color: ($spec). Use a named color or #rrggbb hex."}
    }
}

# ANSI truecolor foreground escape
def fg [rgb: list<int>]: nothing -> string {
    $"(ansi escape)[38;2;($rgb.0);($rgb.1);($rgb.2)m"
}

# Rainbow RGB for position t in [0, 1]
def rainbow-rgb [t: float]: nothing -> list<int> {
    let h = $t * 6.0
    let sector = $h | math floor | into int
    let f = $h - ($sector | into float)
    let rise = ($f * 255) | math round | into int
    let fall = ((1.0 - $f) * 255) | math round | into int
    match ($sector mod 6) {
        0 => { [255, $rise, 0] }
        1 => { [$fall, 255, 0] }
        2 => { [0, 255, $rise] }
        3 => { [0, $fall, 255] }
        4 => { [$rise, 0, 255] }
        _ => { [255, 0, $fall] }
    }
}

# Linearly interpolate between two RGB colors
def lerp-rgb [c1: list<int>, c2: list<int>, t: float]: nothing -> list<int> {
    [0 1 2] | each {|i|
        let a = $c1 | get $i | into float
        let b = $c2 | get $i | into float
        ($a + ($b - $a) * $t) | math round | into int
    }
}

# Color each character per-column with a given RGB-from-position function
def color-horizontal [lines: list<string>, rgb_fn: closure]: nothing -> string {
    let reset = (ansi reset)
    let max_len = $lines | each { str length -g } | math max | default 1
    $lines | each {|line|
        let chars = $line | split chars
        if ($chars | is-empty) {
            ""
        } else {
            $chars | enumerate | each {|e|
                let t = if $max_len <= 1 { 0.0 } else { ($e.index | into float) / (($max_len - 1) | into float) }
                let rgb = do $rgb_fn $t
                $"(fg $rgb)($e.item)"
            } | str join | $"($in)($reset)"
        }
    } | str join (char nl)
}

# Color each line with a given RGB-from-position function
def color-vertical [lines: list<string>, rgb_fn: closure]: nothing -> string {
    let reset = (ansi reset)
    let n = $lines | length
    $lines | enumerate | each {|e|
        let t = if $n <= 1 { 0.0 } else { ($e.index | into float) / (($n - 1) | into float) }
        let rgb = do $rgb_fn $t
        $"(fg $rgb)($e.item)($reset)"
    } | str join (char nl)
}

# Apply color to FIGlet text
#
# Spec values:
#   "red"        — solid named color
#   "#ff6600"    — solid hex color
#   "rainbow"    — rainbow gradient
#   "red:blue"   — gradient between two colors
export def colorize [
    spec: string          # Color spec
    --direction: string   # horizontal (default) or vertical
]: string -> string {
    let text = $in
    let dir = $direction | default "horizontal"
    let lines = $text | lines
    let is_rainbow = $spec == "rainbow"
    let is_gradient = (not $is_rainbow) and ($spec | str contains ':')

    if (not $is_rainbow) and (not $is_gradient) {
        # Solid color — one escape per line
        let esc = fg (resolve-color $spec)
        let reset = (ansi reset)
        $lines | each {|line| $"($esc)($line)($reset)" } | str join (char nl)
    } else if $is_rainbow {
        if $dir == "vertical" {
            color-vertical $lines {|t| rainbow-rgb $t }
        } else {
            color-horizontal $lines {|t| rainbow-rgb $t }
        }
    } else {
        let parts = $spec | split row ':'
        let c1 = resolve-color ($parts | first)
        let c2 = resolve-color ($parts | last)
        if $dir == "vertical" {
            color-vertical $lines {|t| lerp-rgb $c1 $c2 $t }
        } else {
            color-horizontal $lines {|t| lerp-rgb $c1 $c2 $t }
        }
    }
}
