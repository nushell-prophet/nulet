# ANSI color post-processing for FIGlet output

const NAMED_COLORS = {
    black: [0 0 0]
    red: [255 0 0]
    green: [0 190 0]
    blue: [0 100 255]
    yellow: [255 255 0]
    cyan: [0 255 255]
    magenta: [255 0 255]
    white: [255 255 255]
    orange: [255 165 0]
    pink: [255 105 180]
    purple: [128 0 128]
}

const GRADIENT_PRESETS = {
    g-sunset: {start: [255 69 0] end: [255 20 147]}
    g-ocean: {start: [0 105 148] end: [64 201 255]}
    g-fire: {start: [255 0 0] end: [255 255 0]}
    g-ice: {start: [224 247 250] end: [0 145 234]}
    g-neon: {start: [57 255 20] end: [255 0 255]}
    g-pastel: {start: [255 182 193] end: [135 206 235]}
    g-gold: {start: [255 140 0] end: [255 215 0]}
    g-matrix: {start: [0 51 0] end: [0 255 0]}
}

# Color and gradient names for shell completion
export def color-names []: nothing -> list<string> {
    $NAMED_COLORS | columns
    | append ($GRADIENT_PRESETS | columns)
    | prepend "rainbow"
    | sort
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
        [
            ($"0x($hex | str substring 0..1)" | into int)
            ($"0x($hex | str substring 2..3)" | into int)
            ($"0x($hex | str substring 4..5)" | into int)
        ]
    } else if $s in ($NAMED_COLORS | columns) {
        $NAMED_COLORS | get $s
    } else {
        error make {msg: $"Unknown color: ($spec). Use a named color or #rrggbb hex."}
    }
}

# Convert RGB triple to 0xrrggbb hex for ansi gradient
def rgb-to-hex []: list<int> -> string {
    $in | each { format number --no-prefix | get lowerhex | fill -a r -c '0' -w 2 } | str join | $"0x($in)"
}

# ANSI truecolor foreground escape
def fg [rgb: list<int>]: nothing -> string {
    $"(ansi escape)[38;2;($rgb.0);($rgb.1);($rgb.2)m"
}

# --- HSL conversions ---

# Convert RGB [0-255] to HSL {h: 0-360, s: 0-1, l: 0-1}
def rgb-to-hsl [rgb: list<int>]: nothing -> record {
    let r = ($rgb.0 | into float) / 255.0
    let g = ($rgb.1 | into float) / 255.0
    let b = ($rgb.2 | into float) / 255.0
    let cmax = [$r $g $b] | math max
    let cmin = [$r $g $b] | math min
    let delta = $cmax - $cmin
    let l = ($cmax + $cmin) / 2.0

    if $delta < 0.001 {
        {h: 0.0 s: 0.0 l: $l}
    } else {
        let s = $delta / (1.0 - ((2.0 * $l - 1.0) | math abs))
        let max_ch = if $r >= $g and $r >= $b { 0 } else if $g >= $b { 1 } else { 2 }
        let h_raw = match $max_ch {
            0 => { 60.0 * (($g - $b) / $delta) }
            1 => { 60.0 * (($b - $r) / $delta + 2.0) }
            _ => { 60.0 * (($r - $g) / $delta + 4.0) }
        }
        let h = if $h_raw < 0.0 { $h_raw + 360.0 } else { $h_raw }
        {h: $h s: $s l: $l}
    }
}

# Convert HSL to RGB [0-255]
def hsl-to-rgb [h: float s: float l: float]: nothing -> list<int> {
    if $s < 0.001 {
        let v = ($l * 255.0) | math round | into int
        return [$v $v $v]
    }
    let c = (1.0 - ((2.0 * $l - 1.0) | math abs)) * $s
    let h_prime = $h / 60.0
    let h_mod2 = $h_prime - 2.0 * ($h_prime / 2.0 | math floor)
    let x = $c * (1.0 - (($h_mod2 - 1.0) | math abs))
    let m = $l - $c / 2.0
    let sector = $h_prime | math floor | into int
    let rgb1 = match ($sector mod 6) {
        0 => { [$c $x 0.0] }
        1 => { [$x $c 0.0] }
        2 => { [0.0 $c $x] }
        3 => { [0.0 $x $c] }
        4 => { [$x 0.0 $c] }
        _ => { [$c 0.0 $x] }
    }
    $rgb1 | each { (($in + $m) * 255.0) | math round | into int }
}

# Interpolate hue along the long arc of the color circle
def hue-long-arc [h1: float h2: float t: float]: nothing -> float {
    let diff = $h2 - $h1
    let h_interp = if ($diff | math abs) <= 180.0 {
        # Direct path is short — go the other way
        if $diff >= 0.0 { $h1 + ($h2 - 360.0 - $h1) * $t } else { $h1 + ($h2 + 360.0 - $h1) * $t }
    } else {
        # Direct path is already long
        $h1 + $diff * $t
    }
    # Normalize to [0, 360)
    $h_interp - 360.0 * ($h_interp / 360.0 | math floor)
}

# --- Color application ---

# Rainbow RGB for position t in [0, 1]
def rainbow-rgb [t: float]: nothing -> list<int> {
    let h = $t * 6.0
    let sector = $h | math floor | into int
    let f = $h - ($sector | into float)
    let rise = ($f * 255) | math round | into int
    let fall = ((1.0 - $f) * 255) | math round | into int
    match ($sector mod 6) {
        0 => { [255 $rise 0] }
        1 => { [$fall 255 0] }
        2 => { [0 255 $rise] }
        3 => { [0 $fall 255] }
        4 => { [$rise 0 255] }
        _ => { [255 0 $fall] }
    }
}

# Linearly interpolate between two RGB colors
def lerp-rgb [c1: list<int> c2: list<int> t: float]: nothing -> list<int> {
    [0 1 2] | each {|i|
        let a = $c1 | get $i | into float
        let b = $c2 | get $i | into float
        ($a + ($b - $a) * $t) | math round | into int
    }
}

# Color each character per-column with a given RGB-from-position function
def color-horizontal [lines: list<string> rgb_fn: closure]: nothing -> string {
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
def color-vertical [lines: list<string> rgb_fn: closure]: nothing -> string {
    let reset = (ansi reset)
    let n = $lines | length
    $lines | enumerate | each {|e|
        let t = if $n <= 1 { 0.0 } else { ($e.index | into float) / (($n - 1) | into float) }
        let rgb = do $rgb_fn $t
        $"(fg $rgb)($e.item)($reset)"
    } | str join (char nl)
}

# Resolve a gradient spec to {start: list<int>, end: list<int>}
def resolve-gradient [spec: string]: nothing -> record {
    if $spec in ($GRADIENT_PRESETS | columns) {
        $GRADIENT_PRESETS | get $spec
    } else {
        let parts = $spec | split row ':'
        {start: (resolve-color ($parts | first)) end: (resolve-color ($parts | last))}
    }
}

# Apply color to FIGlet text
#
# Spec values:
#   "red"        — solid named color
#   "#ff6600"    — solid hex color
#   "rainbow"    — rainbow gradient
#   "g-sunset"   — named gradient preset (g-sunset, g-ocean, g-fire, g-ice, g-neon, g-pastel, g-gold, g-matrix)
#   "red:blue"   — gradient between two colors
#
# With --reverse, two-color gradients traverse the long arc of the hue circle
# instead of the short path. For rainbow, it reverses the cycle direction.
export def colorize [
    spec: string # Color spec
    --direction: string # horizontal (default) or vertical
    --reverse (-r) # Long arc around the hue circle (gradients) or reverse (rainbow)
]: string -> string {
    let text = $in
    let dir = $direction | default "horizontal"
    let lines = $text | lines

    if $spec == "rainbow" {
        let fn = if $reverse { {|t| rainbow-rgb (1.0 - $t) } } else { {|t| rainbow-rgb $t } }
        if $dir == "vertical" {
            color-vertical $lines $fn
        } else {
            color-horizontal $lines $fn
        }
    } else if ($spec in ($GRADIENT_PRESETS | columns)) or ($spec | str contains ':') {
        let g = resolve-gradient $spec
        if $reverse {
            # Long arc — interpolate through HSL hue circle
            let hsl1 = rgb-to-hsl $g.start
            let hsl2 = rgb-to-hsl $g.end
            let fn = {|t|
                let h = hue-long-arc $hsl1.h $hsl2.h $t
                let s = $hsl1.s + ($hsl2.s - $hsl1.s) * $t
                let l = $hsl1.l + ($hsl2.l - $hsl1.l) * $t
                hsl-to-rgb $h $s $l
            }
            if $dir == "vertical" {
                color-vertical $lines $fn
            } else {
                color-horizontal $lines $fn
            }
        } else {
            # Short path — RGB interpolation
            if $dir == "vertical" {
                color-vertical $lines {|t| lerp-rgb $g.start $g.end $t }
            } else {
                $text | ansi gradient --fgstart ($g.start | rgb-to-hex) --fgend ($g.end | rgb-to-hex)
            }
        }
    } else {
        # Solid color
        let esc = fg (resolve-color $spec)
        let reset = (ansi reset)
        $lines | each {|line| $"($esc)($line)($reset)" } | str join (char nl)
    }
}
