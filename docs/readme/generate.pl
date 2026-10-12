#!/usr/bin/env perl
#
# Draws the README artwork for Nixdatifier.
#
#   perl docs/readme/generate.pl
#
# These are crisp, pixel-perfect illustrations of the real Nixdatifier UI.
# Rendered in SVG so they stay sharp at any zoom level, scale effortlessly,
# and diff cleanly in git.
#

use strict;
use warnings;
use File::Basename qw(dirname);
use MIME::Base64 qw(encode_base64);

my $DIR = dirname($0);
my $ICON_PNG = do {
    my $path = -f "$DIR/../../package/icon-emblem.png" ? "$DIR/../../package/icon-emblem.png"
             : -f "$DIR/../../package/icon.png" ? "$DIR/../../package/icon.png"
             : "$DIR/../../package/icon-emblem.png";
    my $tmp = "/tmp/nixdatifier-emblem-128.png";
    if (system("magick", $path, "-resize", "128x128", $tmp) == 0 && -f $tmp) {
        open my $fh, '<:raw', $tmp or die "$tmp: $!";
        local $/;
        my $b64 = encode_base64(<$fh>, '');
        close $fh;
        unlink $tmp;
        'data:image/png;base64,' . $b64;
    } else {
        open my $fh, '<:raw', $path or die "$path: $!";
        local $/;
        my $b64 = encode_base64(<$fh>, '');
        close $fh;
        'data:image/png;base64,' . $b64;
    }
};

# ── palette (matches UI Theme: system dark base + NixOS blue accents) ─────────
my %C = (
    bg_top      => '#161d28',
    bg_bot      => '#0f141d',
    surface     => '#1b2330',
    surface_alt => '#222c3c',
    surface_dim => '#121822',
    card_bg     => 'rgba(255,255,255,0.025)',
    card_border => 'rgba(255,255,255,0.07)',
    text        => '#e6ecf5',
    dim         => '#939fb2',
    muted       => '#939fb2',   # Theme.muted
    faint       => '#627084',
    line        => 'rgba(255,255,255,0.07)',
    edge        => 'rgba(145,188,255,0.18)',
    sheen       => 'rgba(255,255,255,0.14)',
    accent      => '#91bcff',   # Theme highlightColor
    accent_dim  => '#5277c3',   # NixOS blue
    onaccent    => '#131923',
    positive    => '#6ee7b7',   # Green (Booted / additions / OK)
    negative    => '#fb858f',   # Red (Deletions / errors)
    changed     => '#f2cc70',   # Amber/Gold (Next boot / updates / reclaimable)
);

my $UI   = 'system-ui,-apple-system,Segoe UI,Noto Sans,sans-serif';
my $MONO = 'ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace';

# ── glyphs (viewBox 0 0 24 24) ────────────────────────────────────────────────
my %FILL = (
    generation    => 'M12 2a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3ZM4.5 7a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3Zm15 0a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3ZM3 14h4v2H3zm7 0h4v2h-4zm7 0h4v2h-4ZM8 19h8v2H8z',
    boot          => 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2Zm0 2c1.5 0 2.9.42 4.1 1.14L4.14 16.1A8 8 0 0 1 12 4Zm0 16c-1.5 0-2.9-.42-4.1-1.14L19.86 7.9A8 8 0 0 1 12 20Z',
    activate      => 'M8 5v14l11-7L8 5Z',
    nextboot      => 'M17 12l-5-5v3H6v4h6v3l5-5ZM4 6h2v12H4z',
    delete        => 'M9 3v1H4v2h16V4h-5V3H9Zm-2 5 1 11h8l1-11H7Zm3 2h2v7h-2V10Zm4 0h-2v7h2V10Z',
    copy          => 'M16 1H4a2 2 0 0 0-2 2v14h2V3h12V1Zm3 4H8a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2Zm0 16H8V7h11v14Z',
    check         => 'M9 16.2 4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2Z',
    chevron_down  => 'M7 10l5 5 5-5H7Z',
    chevron_up    => 'M7 14l5-5 5 5H7Z',
    chevron_right => 'M10 7l5 5-5 5V7Z',
    hash          => 'M5 9h14v2H5zm0 4h14v2H5zM9 3h2v18H9zm4 0h2v18h-2z',
    package_added => 'M11 2 3 7l8 5 8-5-8-5ZM3 9v6l8 5 8-5V9l-8 5-8-5Zm9 3-4-2.5v5l4 2.5 4-2.5v-5L12 12Z',
    refresh       => 'M17.65 6.35A7.95 7.95 0 0 0 12 4a8 8 0 1 0 8 8h-2a6 6 0 1 1-1.76-4.24L14 10h6V4l-2.35 2.35Z',
    secrets       => 'M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2ZM9 6a3 3 0 1 1 6 0v2H9V6Zm3 9a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3Z',
    timeline      => 'M4 4h2v16H4zm4 2h12v2H8zm0 5h12v2H8zm0 5h8v2H8z',
    warning       => 'M12 3 1 21h22L12 3Zm0 6v5m0 3v1',
    more          => 'M6 12a2 2 0 1 1-4 0 2 2 0 0 1 4 0Zm8 0a2 2 0 1 1-4 0 2 2 0 0 1 4 0Zm8 0a2 2 0 1 1-4 0 2 2 0 0 1 4 0Z',
);

my %STROKE = (
    clock      => { d => 'M12 6v6l4 2', w => 1.8, circle => [12, 12, 9] },
    disk       => { d => 'M3 14h18M16 17h2', w => 1.8, rect => [3, 4, 18, 16, 3] },
    external   => { d => 'M14 3h7v7M21 3l-11 11m-1-9H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4', w => 1.8 },
    go_up_right => { d => 'M7 17 17 7M9 7h8v8', w => 2.0 },
    folder     => { d => 'M3 7V4h7l3 3h8v13H3Z', w => 1.8 },
    grid       => { d => '', w => 1.8, rects => [[3,3,6,6,1],[15,3,6,6,1],[3,15,6,6,1],[15,15,6,6,1]] },
    history    => { d => 'M3 4v5h5M3.5 9a9 9 0 1 1 0 7M12 7v5l3 2', w => 1.8 },
    info       => { d => 'M12 11v6m0-10v.2', w => 1.8, circle => [12, 12, 9] },
    monitor    => { d => 'M12 17v4m-5 0h10', w => 1.8, rect => [2, 3, 20, 14, 2] },
    box        => { d => 'm12 3 9 5v9l-9 5-9-5V8Zm0 10v9M3 8l9 5 9-5M8 5l9 5', w => 1.7 },
    compare    => { d => 'M6 7v12m12-2V5M9 16l-3 3-3-3M15 8l3-3 3 3', w => 1.8, circles => [[6, 5, 2],[18, 19, 2]] },
    updates    => { d => 'M12 3v12m-5-5 5 5 5-5M4 16v4h16v-4', w => 1.8 },
    pin        => { d => 'm8 3 8 0-1 6 3 3v2H6v-2l3-3-1-6ZM12 14v7', w => 1.8 },
    search     => { d => 'm15 15 6 6', w => 1.8, circle => [10, 10, 6] },
    settings   => { d => 'm9 3-.7 2.2-2 .9L4 5.8 2 9l1.7 1.8v2.4L2 15l2 3.2 2.3-.3 2 .9L9 21h4l.7-2.2 2-.9 2.3.3 2-3.2-1.7-1.8v-2.4L20 9l-2-3.2-2.3.3-2-.9L13 3Z', w => 1.8, circle => [11, 12, 3] },
    terminal   => { d => 'm7 9 3 3-3 3m6 0h4', w => 1.8, rect => [3, 5, 18, 14, 3] },
    user       => { d => 'M4 21v-2a8 8 0 0 1 16 0v2', w => 1.8, circle => [12, 7, 4] },
    calendar   => { d => 'M3 10h18M8 3v4m8-4v4', w => 1.6, rect => [3, 5, 18, 16, 2] },
    back       => { d => 'm10 5-7 7 7 7M3 12h18', w => 1.8 },
    disclosure => { d => 'm6 9 6 6 6-6', w => 2.0 },
);

# ── primitives ────────────────────────────────────────────────────────────────

sub esc {
    my $s = shift // '';
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
}

# Colours are written the way the QML writes them: Qt's #AARRGGBB (so values
# can be copied straight from the UI) or rgba(r,g,b,a). Browsers read 8-digit
# hex as #RRGGBBAA — "#04ffffff" becomes opaque cyan — and SVG 1.1 renderers
# (rsvg, Inkscape) understand neither, so always emit plain hex + *-opacity.
sub paint {
    my ($attr, $c) = @_;
    return '' unless defined $c;
    my ($hex, $alpha);
    if ($c =~ /^#([0-9a-f]{2})([0-9a-f]{6})$/i) {
        ($hex, $alpha) = ("#$2", hex($1) / 255);
    } elsif ($c =~ /^rgba\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)$/) {
        ($hex, $alpha) = (sprintf('#%02x%02x%02x', $1, $2, $3), $4);
    } else {
        return qq{ $attr="$c"};
    }
    my $o = qq{ $attr="$hex"};
    $o .= sprintf(' %s-opacity="%.3g"', $attr, $alpha) if $alpha < 1;
    return $o;
}

sub hline {
    my ($x1, $x2, $y, $col) = @_;
    return sprintf('<path d="M%.1f %.1f H%.1f"%s stroke-width="1"/>', $x1, $y, $x2, paint('stroke', $col // $C{line}));
}

sub glyph {
    my (%a) = @_;
    my ($n, $x, $y, $s, $col) = @a{qw(name x y size color)};
    $col //= '#ffffff';
    my $fill   = paint('fill', $col);
    my $stroke = paint('stroke', $col);
    my $k = sprintf('%.4f', ($s // 16) / 24);
    my $o = sprintf('<g transform="translate(%.2f,%.2f) scale(%s)">', $x, $y, $k);
    if (my $d = $FILL{$n}) {
        $o .= qq{<path d="$d"$fill/>};
    } elsif (my $st = $STROKE{$n}) {
        if ($st->{circle}) {
            my ($cx, $cy, $r) = @{$st->{circle}};
            $o .= qq{<circle cx="$cx" cy="$cy" r="$r" fill="none"$stroke stroke-width="$st->{w}"/>};
        }
        if ($st->{circles}) {
            for my $c (@{$st->{circles}}) {
                $o .= qq{<circle cx="$c->[0]" cy="$c->[1]" r="$c->[2]" fill="none"$stroke stroke-width="$st->{w}"/>};
            }
        }
        if ($st->{rect}) {
            my ($rx, $ry, $rw, $rh, $rr) = @{$st->{rect}};
            $o .= qq{<rect x="$rx" y="$ry" width="$rw" height="$rh" rx="$rr" fill="none"$stroke stroke-width="$st->{w}"/>};
        }
        if ($st->{rects}) {
            for my $r (@{$st->{rects}}) {
                $o .= qq{<rect x="$r->[0]" y="$r->[1]" width="$r->[2]" height="$r->[3]" rx="$r->[4]" fill="none"$stroke stroke-width="$st->{w}"/>};
            }
        }
        if ($st->{d}) {
            $o .= qq{<path d="$st->{d}" fill="none"$stroke stroke-width="$st->{w}" stroke-linecap="round" stroke-linejoin="round"/>};
        }
    }
    return $o . '</g>';
}

sub text {
    my (%a) = @_;
    my $anchor = $a{anchor} ? qq{ text-anchor="$a{anchor}"} : '';
    my $weight = $a{weight} ? qq{ font-weight="$a{weight}"} : '';
    my $family = $a{mono} ? $MONO : $UI;
    my $extra  = $a{extra} ? qq{ $a{extra}} : '';
    return sprintf(
        '<text x="%.1f" y="%.1f" font-family="%s" font-size="%.1f"%s%s%s%s>%s</text>',
        $a{x}, $a{y}, $family, $a{size}, paint('fill', $a{color} // '#ffffff'), $weight, $anchor, $extra, esc($a{t}));
}

# Greedy word wrap on an estimated glyph width (no font metrics available).
sub wrap {
    my ($s, $max_chars) = @_;
    my @lines = ('');
    for my $word (split ' ', $s) {
        my $try = $lines[-1] eq '' ? $word : "$lines[-1] $word";
        if (length($try) > $max_chars && $lines[-1] ne '') { push @lines, $word } else { $lines[-1] = $try }
    }
    return @lines;
}

sub rect {
    my (%a) = @_;
    my $rx     = defined $a{rx} ? qq{ rx="$a{rx}"} : '';
    my $stroke = $a{stroke} ? paint('stroke', $a{stroke}).' stroke-width="'.($a{sw} // 1).'"' : '';
    my $op     = defined $a{opacity} ? qq{ opacity="$a{opacity}"} : '';
    return sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f"%s%s%s%s/>',
        $a{x}, $a{y}, $a{w}, $a{h}, paint('fill', $a{fill} // 'none'), $rx, $op, $stroke);
}

sub circle {
    my (%a) = @_;
    my $op = defined $a{opacity} ? qq{ opacity="$a{opacity}"} : '';
    my $st = $a{stroke} ? paint('stroke', $a{stroke}).' stroke-width="'.($a{sw} // 1).'"' : '';
    return sprintf('<circle cx="%.1f" cy="%.1f" r="%.1f"%s%s%s/>', $a{cx}, $a{cy}, $a{r}, paint('fill', $a{fill}), $op, $st);
}

# Theme.wash(): the colour at a given alpha.
sub wash {
    my ($hex, $alpha) = @_;
    my ($r, $g, $b) = map { hex } $hex =~ /^#(..)(..)(..)$/;
    return "rgba($r,$g,$b,$alpha)";
}

# shared/ActionButton.qml: a primary button is a faint wash of its accent with
# an accent icon/label; a plain one is near-transparent with a muted icon.
# Returns (markup, width).
sub action_button {
    my (%a) = @_;
    my ($x, $y) = @a{qw(x y)};
    my $h       = $a{h} // 27;
    my $fs      = $a{size} // 10;
    my $label   = $a{label} // '';
    my $accent  = $a{accent} // $C{accent};
    my $primary = $a{primary};
    my $icon    = 13;
    my $content = ($a{glyph} ? $icon : 0) + ($a{glyph} && $label ne '' ? 6 : 0) + length($label) * $fs * 0.56;
    my $w       = $label eq '' ? $h : $content + 20;

    my $o = $a{disabled} ? '<g opacity="0.45">' : '<g>';
    $o .= rect(x => $x, y => $y, w => $w, h => $h, rx => 6,
               fill   => $primary ? wash($accent, 0.09) : '#04ffffff',
               stroke => $primary ? wash($accent, 0.24) : '#14ffffff');
    my $cx = $x + ($w - $content) / 2;
    if ($a{glyph}) {
        $o .= glyph(name => $a{glyph}, x => $cx, y => $y + ($h - $icon) / 2, size => $icon, color => $primary ? $accent : $C{muted});
        $cx += $icon + 6;
    }
    $o .= text(x => $cx, y => $y + $h / 2 + $fs * 0.36, size => $fs, weight => 500, color => $primary ? $accent : $C{text}, t => $label) if $label ne '';
    return ($o . '</g>', $w);
}

sub logo_image {
    my (%a) = @_;
    my ($cx, $cy, $r) = @a{qw(cx cy r)};
    my $d = $r * 2;
    return sprintf('<image href="%s" x="%.1f" y="%.1f" width="%.1f" height="%.1f" preserveAspectRatio="xMidYMid slice"/>',
        $ICON_PNG, $cx - $r, $cy - $r, $d, $d);
}

sub card {
    my ($w, $h) = @_;
    return join('',
        qq{<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">},
        qq{<stop offset="0%" stop-color="$C{bg_top}"/><stop offset="100%" stop-color="$C{bg_bot}"/>},
        qq{</linearGradient></defs>},
        rect(x => 0, y => 0, w => $w, h => $h, rx => 14, fill => 'url(#bg)'),
        rect(x => 0.5, y => 0.5, w => $w - 1, h => $h - 1, rx => 14, stroke => $C{edge}),
        hline(14, $w - 14, 1.5, $C{sheen}),
    );
}

sub diffstat {
    my (%a) = @_;
    my ($x, $y, $add, $del, $chg) = @a{qw(x y add del chg)};
    my $o = '';
    my $add_txt = "+$add";
    my $del_txt = "-$del";
    my $chg_txt = "~$chg";
    my $atw = length($add_txt) * 6.5;
    my $dtw = length($del_txt) * 6.5;
    my $ctw = length($chg_txt) * 6.5;

    $o .= text(x => $x, y => $y + 11.5, size => 9.5, weight => 600, mono => 1, color => $C{positive}, t => $add_txt);
    $o .= text(x => $x + $atw + 4, y => $y + 11.5, size => 9.5, weight => 600, mono => 1, color => $C{negative}, t => $del_txt);
    $o .= text(x => $x + $atw + 4 + $dtw + 4, y => $y + 11.5, size => 9.5, weight => 600, mono => 1, color => $C{changed}, t => $chg_txt);
    return ($o, $atw + 4 + $dtw + 4 + $ctw);
}

# ── shared header ─────────────────────────────────────────────────────────────
sub header {
    my (%a) = @_;
    my $w = $a{w} // 440;
    my $o = '';

    # Nixdatifier Flake Logo
    $o .= logo_image(cx => 37, cy => 35, r => 16);

    # Title
    $o .= text(x => 62, y => 31, size => 16, weight => 600, color => $C{text}, t => 'Nixdatifier');

    # Sub-header: #662 NixOS 26.05
    my $booted = $a{booted} // 662;
    my $active = $a{active} // 662;
    my $subX = 62;

    $o .= text(x => $subX, y => 45.5, size => 10, weight => 600, mono => 1, color => $C{positive}, t => "#$booted");
    $subX += length("#$booted") * 6.8 + 6;

    if ($active != $booted) {
        $o .= text(x => $subX, y => 45.5, size => 10, color => $C{muted}, t => '→');
        $subX += 12;
        $o .= text(x => $subX, y => 45.5, size => 10, weight => 600, mono => 1, color => $C{changed}, t => "#$active");
        $subX += length("#$active") * 6.8 + 6;
    }

    $o .= text(x => $subX, y => 45.5, size => 10, color => '#8fa0b7', t => 'NixOS 26.05');

    # Right side action buttons
    my @tools = (
        { icon => 'refresh', tip => 'Refresh' },
        { icon => 'pin', tip => 'Pin' },
        { icon => 'settings', tip => 'Configure' },
    );
    my $tx = $w - 21 - (scalar(@tools) * 25) - 20;
    for my $t (@tools) {
        $o .= glyph(name => $t->{icon}, x => $tx + 4, y => 24, size => 14, color => '#7286a3');
        $tx += 25;
    }
    # More button "⋯"
    $o .= text(x => $tx + 4, y => 36, size => 16, weight => 600, color => '#7286a3', t => '⋯');

    # System meta chips: Hostname, Uptime, Last activation (matching screenshot: muddyblack, Up 0h 14m, Switched 11 Sep, 12:16)
    my $my = 67;
    $o .= glyph(name => 'user', x => 21, y => $my - 2, size => 12, color => '#7286a3');
    $o .= text(x => 37, y => $my + 8.5, size => 10, color => '#a2b0c5', t => 'muddyblack');

    $o .= glyph(name => 'clock', x => 126, y => $my - 2, size => 12, color => '#7286a3');
    $o .= text(x => 142, y => $my + 8.5, size => 10, color => '#a2b0c5', t => 'Up 0h 14m');

    $o .= glyph(name => 'calendar', x => 226, y => $my - 2, size => 12, color => '#7286a3');
    $o .= text(x => 243, y => $my + 8.5, size => 9, color => '#8d9db4', t => 'Switched 11 Sep, 12:16');

    return $o;
}

# ── tabbar ────────────────────────────────────────────────────────────────────
my @TABS = (
    { id => 'timeline', icon => 'history', label => 'Generations', n => 0 },
    { id => 'updates',  icon => 'updates', label => 'Updates',     n => 5 },
    { id => 'diff',     icon => 'compare', label => 'Compare',     n => 0 },
    { id => 'tools',    icon => 'grid',    label => 'Tools',       n => 0 },
);

sub tabbar {
    my ($active, $w) = @_;
    my $o = '';
    my $ty = 90;
    my $x = 23;
    my $tw = ($w - 42) / @TABS - 10;   # equal slots, so the underline never leaves the bar

    for my $t (@TABS) {
        my $on = $t->{id} eq $active;
        my $col = $on ? $C{text} : $C{dim};

        $o .= glyph(name => $t->{icon}, x => $x, y => $ty + 2, size => 15, color => ($on ? $C{accent} : $col));
        $o .= text(x => $x + 20, y => $ty + 14, size => 11, weight => ($on ? 600 : 500), color => $col, t => $t->{label});

        if ($t->{n}) {
            my $nx = $x + 20 + length($t->{label}) * 6.4 + 4;
            $o .= rect(x => $nx, y => $ty + 2, w => 16, h => 14, rx => 7, fill => $C{accent});
            $o .= text(x => $nx + 8, y => $ty + 12.5, size => 9, weight => 700, color => $C{onaccent}, anchor => 'middle', t => $t->{n});
        }

        if ($on) {
            $o .= rect(x => $x - 2, y => $ty + 24, w => $tw, h => 2, rx => 1, fill => $C{accent});
        }

        $x += $tw + 10;
    }

    $o .= hline(21, $w - 21, $ty + 26.5);
    return $o;
}

# ── footer (Nix store disk usage & commands button) ───────────────────────────
sub footer {
    my ($w, $h, %a) = @_;
    my $y = $h - 21;
    my $o = '';

    # Storage icon & details
    $o .= glyph(name => 'disk', x => 21, y => $y - 9, size => 13, color => '#76869b');
    my $store_text = $a{text} // '115.0 GB store  ·  27.3 GB reclaimable';
    $o .= text(x => 39, y => $y + 2, size => 9.5, color => '#8f9db0', t => $store_text);

    # Commands button on right
    my $cmdX = $w - 118;
    $o .= rect(x => $cmdX, y => $y - 12, w => 97, h => 24, rx => 5, fill => 'rgba(255,255,255,0.03)', stroke => 'rgba(255,255,255,0.06)');
    $o .= glyph(name => 'terminal', x => $cmdX + 8, y => $y - 7, size => 13, color => $C{accent});
    $o .= text(x => $cmdX + 26, y => $y + 3.5, size => 10, weight => 500, color => $C{text}, t => 'Commands ›');

    # Separator above footer
    $o .= hline(0, $w, $h - 38);

    return $o;
}

sub write_svg {
    my ($name, $w, $h, $body) = @_;
    my $svg = qq{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" width="$w" height="$h">\n}
        . card($w, $h) . "\n" . $body . "\n</svg>\n";
    open my $fh, '>', "$DIR/$name" or die "$DIR/$name: $!";
    print $fh $svg;
    close $fh;
    printf "  %-22s %5d bytes\n", $name, length($svg);
}

# ── 1. TIMELINE TAB (Generations) ─────────────────────────────────────────────
{
    my $w = 440; my $h = 600;
    my $b = header(w => $w, booted => 662, active => 662);
    $b .= tabbar('timeline', $w);

    # Search bar
    my $sy = 126;
    $b .= rect(x => 21, y => $sy, w => $w - 42, h => 29, rx => 5, fill => 'rgba(255,255,255,0.025)', stroke => 'rgba(255,255,255,0.10)');
    $b .= glyph(name => 'search', x => 29, y => $sy + 7, size => 13, color => $C{muted});
    $b .= text(x => 49, y => $sy + 18, size => 9.5, color => $C{faint}, t => 'Search generations, packages, dates…');

    # Sub-header: SYSTEM HISTORY · 10 generations
    my $hy = 170;
    $b .= text(x => 21, y => $hy, size => 9, weight => 600, color => '#8491a4', extra => 'letter-spacing="1"', t => 'SYSTEM HISTORY');
    $b .= text(x => $w - 21, y => $hy, size => 9, color => $C{muted}, anchor => 'end', t => '10 generations');

    # Timeline rail (connecting line)
    # Starts at y=198 down to y=530 at x=28
    $b .= sprintf('<line x1="28" y1="198" x2="28" y2="530"%s stroke-width="2" stroke-linecap="round"/>', paint('stroke', $C{line}));

    # Traveling animated rail marker (as in real code!)
    $b .= qq{
    <g class="traveling-marker">
        <circle cx="28" cy="204" r="14" fill="$C{positive}" opacity="0.30">
            <animate attributeName="cy" values="204;450;450;204;204" keyTimes="0;0.38;0.46;0.84;1" dur="4.2s" repeatCount="indefinite" calcMode="spline" keySplines="0.45 0.05 0.55 0.95;0 0 1 1;0.45 0.05 0.55 0.95;0 0 1 1"/>
            <animate attributeName="fill" values="$C{positive};$C{changed};$C{changed};$C{positive};$C{positive}" keyTimes="0;0.38;0.46;0.84;1" dur="4.2s" repeatCount="indefinite"/>
            <animate attributeName="r" values="12;16;12;16;12" dur="2.1s" repeatCount="indefinite"/>
        </circle>
        <circle cx="28" cy="204" r="9" fill="$C{positive}" fill-opacity="0.12" stroke="$C{positive}" stroke-width="1.2" stroke-opacity="0.65">
            <animate attributeName="cy" values="204;450;450;204;204" keyTimes="0;0.38;0.46;0.84;1" dur="4.2s" repeatCount="indefinite" calcMode="spline" keySplines="0.45 0.05 0.55 0.95;0 0 1 1;0.45 0.05 0.55 0.95;0 0 1 1"/>
            <animate attributeName="fill" values="$C{positive};$C{changed};$C{changed};$C{positive};$C{positive}" keyTimes="0;0.38;0.46;0.84;1" dur="4.2s" repeatCount="indefinite"/>
            <animate attributeName="stroke" values="$C{positive};$C{changed};$C{changed};$C{positive};$C{positive}" keyTimes="0;0.38;0.46;0.84;1" dur="4.2s" repeatCount="indefinite"/>
        </circle>
        <circle cx="28" cy="204" r="4" fill="$C{positive}">
            <animate attributeName="cy" values="204;450;450;204;204" keyTimes="0;0.38;0.46;0.84;1" dur="4.2s" repeatCount="indefinite" calcMode="spline" keySplines="0.45 0.05 0.55 0.95;0 0 1 1;0.45 0.05 0.55 0.95;0 0 1 1"/>
            <animate attributeName="fill" values="$C{positive};$C{changed};$C{changed};$C{positive};$C{positive}" keyTimes="0;0.38;0.46;0.84;1" dur="4.2s" repeatCount="indefinite"/>
        </circle>
    </g>
    };

    # ── GENERATION #662 (BOOTED, EXPANDED) ────────────────────────────────────
    my $g1y = 186;
    # Rail node #662
    $b .= circle(cx => 28, cy => $g1y + 14, r => 4.5, fill => $C{positive});
    $b .= circle(cx => 28, cy => $g1y + 14, r => 9, fill => 'none', stroke => $C{positive}, opacity => 0.4);

    # Expanded card background
    $b .= rect(x => 42, y => $g1y, w => $w - 63, h => 248, rx => 10, fill => 'rgba(145,188,255,0.055)', stroke => 'rgba(145,188,255,0.20)');

    # Top row inside card: #662, Booted pill, Activate/Set boot/Delete, +0 -0 ~7, chevron
    my $cy1 = $g1y + 18;
    $b .= text(x => 54, y => $cy1, size => 12, weight => 600, color => $C{positive}, t => '#662');
    $b .= rect(x => 90, y => $cy1 - 11, w => 48, h => 17, rx => 4, fill => 'rgba(110,231,183,0.12)');
    $b .= text(x => 114, y => $cy1 + 1, size => 9, color => $C{positive}, anchor => 'middle', t => 'Booted');

    # Action buttons (GenerationDelegate.qml): all primary ActionButtons;
    # Delete is disabled on the booted generation.
    my $bx = 146;
    for my $btn (
        { label => 'Activate', glyph => 'activate', accent => $C{accent} },
        { label => 'Set boot', glyph => 'nextboot', accent => $C{changed} },
        { label => 'Delete',   glyph => 'delete',   accent => $C{negative}, disabled => 1 },
    ) {
        my ($mk, $bw) = action_button(x => $bx, y => $cy1 - 13, h => 25, size => 9, primary => 1, %$btn);
        $b .= $mk;
        $bx += $bw + 5;
    }

    # Chevron up
    $b .= glyph(name => 'chevron_up', x => $w - 42, y => $cy1 - 9, size => 15, color => $C{muted});

    # Date sub-row: Today, 12:16
    $b .= text(x => 54, y => $cy1 + 20, size => 10, color => $C{muted}, t => 'Today, 12:16');

    # Badges: CachyOS 7.2.3, NixOS 26.05 · 07 Sep
    my $bgy = $cy1 + 28;
    $b .= rect(x => 54, y => $bgy, w => 96, h => 19, rx => 4, fill => '#0991bcff', stroke => '#1491bcff');
    $b .= text(x => 62, y => $bgy + 13, size => 10, color => '#c7d6e8', t => 'CachyOS 7.2.3');

    $b .= rect(x => 156, y => $bgy, w => 134, h => 19, rx => 4, fill => '#0991bcff', stroke => '#1491bcff');
    $b .= text(x => 164, y => $bgy + 13, size => 10, color => '#c7d6e8', t => 'NixOS 26.05 · 07 Sep');

    # Closure size & vs. previous button
    my $csy = $bgy + 28;
    $b .= text(x => 54, y => $csy + 11, size => 9, color => $C{muted}, t => 'Closure size: 60.3 GB');
    $b .= rect(x => $w - 110, y => $csy - 2, w => 76, h => 19, rx => 4, fill => 'rgba(255,255,255,0.05)', stroke => $C{line});
    $b .= text(x => $w - 72, y => $csy + 11, size => 9, color => $C{text}, anchor => 'middle', t => 'vs. previous');

    # Package changes header: Package changes · 7 & Filter packages box
    my $pkhy = $csy + 24;
    $b .= text(x => 54, y => $pkhy + 13, size => 10, color => $C{muted}, t => 'Package changes · 7');
    $b .= rect(x => $w - 146, y => $pkhy, w => 112, h => 20, rx => 4, fill => 'rgba(255,255,255,0.03)', stroke => $C{line});
    $b .= text(x => $w - 138, y => $pkhy + 13, size => 9, color => $C{muted}, t => 'Filter packages…');

    # Filter pills: All 7, Added 0, Changed 7, Removed 0
    my $flty = $pkhy + 24;
    my @pills = (
        { label => 'All 7', act => 1, col => $C{accent} },
        { label => 'Added 0', act => 0, col => $C{positive} },
        { label => 'Changed 7', act => 0, col => $C{changed} },
        { label => 'Removed 0', act => 0, col => $C{negative} },
    );
    my $px = 54;
    for my $p (@pills) {
        my $pw = length($p->{label}) * 6.5 + 14;
        if ($p->{act}) {
            $b .= rect(x => $px, y => $flty, w => $pw, h => 19, rx => 4, fill => $C{accent});
            $b .= text(x => $px + $pw / 2, y => $flty + 12.5, size => 9, weight => 600, color => $C{onaccent}, anchor => 'middle', t => $p->{label});
        } else {
            $b .= rect(x => $px, y => $flty, w => $pw, h => 19, rx => 4, fill => 'none', stroke => $C{line});
            $b .= text(x => $px + $pw / 2, y => $flty + 12.5, size => 9, color => $p->{col}, anchor => 'middle', t => $p->{label});
        }
        $px += $pw + 6;
    }

    # Sample package rows inside expanded #662
    my @sample_pkgs = (
        { name => 'ai-usage-hyprland', ver => '2.1.2 → 2.3.0', size => '284.1 KB' },
        { name => 'ai-usage-widget',   ver => '1.4.0 → 1.5.0', size => '120.4 KB' },
        { name => 'gitpulse',          ver => '0.8.2 → 0.9.0', size => '540.2 KB' },
    );
    my $rwy = $flty + 25;
    for my $r (@sample_pkgs) {
        $b .= rect(x => 54, y => $rwy, w => $w - 85, h => 24, rx => 4, fill => 'rgba(255,255,255,0.02)');
        $b .= circle(cx => 64, cy => $rwy + 12, r => 6, fill => 'rgba(242,204,112,0.15)');
        $b .= text(x => 64, y => $rwy + 15, size => 9, weight => 700, color => $C{changed}, anchor => 'middle', t => '~');
        $b .= glyph(name => 'box', x => 75, y => $rwy + 5, size => 13, color => $C{changed});
        $b .= text(x => 93, y => $rwy + 15.5, size => 10, weight => 500, color => $C{text}, t => $r->{name});
        $b .= text(x => 260, y => $rwy + 15.5, size => 8.5, mono => 1, color => $C{muted}, t => $r->{ver});
        $b .= text(x => $w - 48, y => $rwy + 15.5, size => 9, mono => 1, color => $C{changed}, anchor => 'end', t => $r->{size});
        $b .= glyph(name => 'chevron_down', x => $w - 44, y => $rwy + 6, size => 12, color => $C{faint});
        $rwy += 27;
    }
    $b .= text(x => ($w - 21 + 42) / 2, y => $rwy + 12, size => 9, color => $C{accent}, anchor => 'middle', t => 'Show 4 more');

    # ── GENERATION #661 (COLLAPSED) ───────────────────────────────────────────
    my $g2y = 444;
    $b .= circle(cx => 28, cy => $g2y + 14, r => 4, fill => $C{dim});

    $b .= rect(x => 42, y => $g2y, w => $w - 63, h => 52, rx => 8, fill => $C{card_bg}, stroke => $C{card_border});
    $b .= text(x => 54, y => $g2y + 19, size => 12, weight => 600, color => $C{text}, t => '#661');

    # Counts: +50 -125 ~1
    my ($ds2_mk, $ds2_w) = diffstat(x => $w - 142, y => $g2y + 7, add => 50, del => 125, chg => 1);
    $b .= $ds2_mk;
    $b .= glyph(name => 'chevron_down', x => $w - 42, y => $g2y + 11, size => 15, color => $C{muted});

    $b .= text(x => 54, y => $g2y + 39, size => 10, color => $C{muted}, t => 'Today, 10:01');
    $b .= rect(x => 140, y => $g2y + 26, w => 82, h => 18, rx => 4, fill => '#0991bcff', stroke => '#1491bcff');
    $b .= text(x => 146, y => $g2y + 38.5, size => 9, color => '#c7d6e8', t => 'CachyOS 7.2.3');
    $b .= rect(x => 228, y => $g2y + 26, w => 116, h => 18, rx => 4, fill => '#0991bcff', stroke => '#1491bcff');
    $b .= text(x => 234, y => $g2y + 38.5, size => 9, color => '#c7d6e8', t => 'NixOS 26.05 · 07 Sep');

    # ── GENERATION #660 (COLLAPSED) ───────────────────────────────────────────
    my $g3y = 502;
    $b .= circle(cx => 28, cy => $g3y + 14, r => 4, fill => $C{dim});
    $b .= rect(x => 42, y => $g3y, w => $w - 63, h => 46, rx => 8, fill => $C{card_bg}, stroke => $C{card_border});
    $b .= text(x => 54, y => $g3y + 19, size => 12, weight => 600, color => $C{text}, t => '#660');
    my ($ds3_mk, $ds3_w) = diffstat(x => $w - 142, y => $g3y + 7, add => 0, del => 0, chg => 1);
    $b .= $ds3_mk;
    $b .= glyph(name => 'chevron_down', x => $w - 42, y => $g3y + 11, size => 15, color => $C{muted});
    $b .= text(x => 54, y => $g3y + 37, size => 10, color => $C{muted}, t => 'Yesterday, 22:48');

    $b .= footer($w, $h);
    write_svg('demo_timeline.svg', $w, $h, $b);
}

# ── 2. UPDATES TAB ────────────────────────────────────────────────────────────
{
    my $w = 440; my $h = 600;
    my $b = header(w => $w);
    $b .= tabbar('updates', $w);

    # Header bar: Flake updates, 5 inputs, Checked 15:48, Check button
    my $sy = 126;
    $b .= text(x => 21, y => $sy + 17, size => 12, weight => 600, color => $C{text}, t => 'Flake updates');
    $b .= text(x => 110, y => $sy + 17, size => 9.5, color => '#8e9eb3', t => '5 inputs');
    my ($chk, $chk_w) = action_button(x => 0, y => 0, h => 29, label => 'Check', glyph => 'refresh');
    my $chk_x = $w - 21 - $chk_w;
    $b .= qq{<g transform="translate($chk_x,}.($sy - 1).qq{)">$chk</g>};
    $b .= text(x => $chk_x - 8, y => $sy + 17, size => 9.5, color => '#7f8ba0', anchor => 'end', t => 'Checked 15:48');

    # Per-input buttons (UpdatesTab.qml): preview (purple, chevron when open),
    # "Update only <input>" (green), "Open source repository" (plain).
    my $abx = $w - 31 - (3 * 27 + 2 * 5);
    my $input_buttons = sub {
        my ($y, $opened) = @_;
        my $o = '';
        my $x = $abx;
        for my $btn (
            { glyph => $opened ? 'chevron_up' : 'compare', accent => '#b6a1e4', primary => 1 },
            { glyph => 'refresh',     accent => $C{positive}, primary => 1 },
            { glyph => 'go_up_right' },
        ) {
            my ($mk) = action_button(x => $x, y => $y, h => 27, %$btn);
            $o .= $mk;
            $x += 32;
        }
        return $o;
    };

    # Expanded Card: caelestia-shell (matching screenshot 2 & 3)
    my $i1y = 158;
    $b .= rect(x => 21, y => $i1y, w => $w - 42, h => 226, rx => 9, fill => '#03ffffff', stroke => '#0effffff');

    # Card header row
    $b .= rect(x => 31, y => $i1y + 10, w => 31, h => 31, rx => 8, fill => '#04ffffff', stroke => '#0effffff');
    $b .= glyph(name => 'box', x => 38, y => $i1y + 17, size => 16, color => '#93a5be');
    $b .= text(x => 72, y => $i1y + 24, size => 11, weight => 600, color => $C{text}, t => 'caelestia-shell');

    # Rev delta: 4e57199 -> d8ee1e8
    $b .= text(x => 72, y => $i1y + 37, size => 9, mono => 1, color => '#8293ab', t => '4e57199');
    $b .= text(x => 125, y => $i1y + 37, size => 9, color => '#8293ab', t => '→');
    $b .= text(x => 140, y => $i1y + 37, size => 9, mono => 1, color => $C{accent}, t => 'd8ee1e8');

    $b .= $input_buttons->($i1y + 12, 1);

    # Inner Package changes header & filter
    my $ipy = $i1y + 54;
    $b .= hline(31, $w - 31, $ipy);
    $ipy += 10;
    $b .= text(x => 31, y => $ipy + 13, size => 10, color => $C{muted}, t => 'Package changes · 16');
    $b .= rect(x => $w - 146, y => $ipy, w => 115, h => 20, rx => 4, fill => 'rgba(255,255,255,0.03)', stroke => $C{line});
    $b .= text(x => $w - 138, y => $ipy + 13, size => 9, color => $C{muted}, t => 'Filter packages…');

    # Filter pills inside card
    my $pky = $ipy + 24;
    $b .= rect(x => 31, y => $pky, w => 44, h => 19, rx => 4, fill => $C{accent});
    $b .= text(x => 53, y => $pky + 12.5, size => 9, weight => 600, color => $C{onaccent}, anchor => 'middle', t => 'All 16');

    $b .= rect(x => 81, y => $pky, w => 58, h => 19, rx => 4, fill => 'none', stroke => $C{line});
    $b .= text(x => 110, y => $pky + 12.5, size => 9, color => $C{positive}, anchor => 'middle', t => 'Added 16');

    $b .= rect(x => 145, y => $pky, w => 66, h => 19, rx => 4, fill => 'none', stroke => $C{line});
    $b .= text(x => 178, y => $pky + 12.5, size => 9, color => $C{changed}, anchor => 'middle', t => 'Changed 0');

    # Package rows inside preview
    my @up_pkgs = ('activate', 'activation-script', 'data.json', 'etc');
    my $ury = $pky + 25;
    for my $up (@up_pkgs) {
        $b .= rect(x => 31, y => $ury, w => $w - 62, h => 20, rx => 3, fill => 'rgba(255,255,255,0.015)');
        $b .= circle(cx => 40, cy => $ury + 10, r => 5, fill => 'rgba(110,231,183,0.15)');
        $b .= text(x => 40, y => $ury + 13, size => 9, weight => 700, color => $C{positive}, anchor => 'middle', t => '+');
        $b .= text(x => 52, y => $ury + 13.5, size => 9.5, weight => 500, color => $C{text}, t => $up);
        $ury += 22;
    }
    # Flat "Collapse preview" button closing the preview
    $b .= text(x => 37, y => $ury + 15, size => 10, weight => 500, color => $C{text}, t => 'Collapse preview');

    # Collapsed inputs
    my @collapsed = (
        { name => 'nix-cachyos-kernel', from => '0408d66', to => 'd4c06cf' },
        { name => 'sops-nix',           from => '03d09a0', to => 'eb1e967' },
        { name => 'nixpkgs',            from => 'd0107ad', to => '6497fba' },
    );
    my $iy = $i1y + 226 + 9;
    for my $in (@collapsed) {
        $b .= rect(x => 21, y => $iy, w => $w - 42, h => 48, rx => 9, fill => '#03ffffff', stroke => '#0effffff');
        $b .= rect(x => 31, y => $iy + 8, w => 31, h => 31, rx => 8, fill => '#04ffffff', stroke => '#0effffff');
        $b .= glyph(name => 'box', x => 38, y => $iy + 15, size => 16, color => '#93a5be');
        $b .= text(x => 72, y => $iy + 22, size => 11, weight => 600, color => $C{text}, t => $in->{name});
        $b .= text(x => 72, y => $iy + 35, size => 9, mono => 1, color => '#8293ab', t => $in->{from});
        $b .= text(x => 125, y => $iy + 35, size => 9, color => '#8293ab', t => '→');
        $b .= text(x => 140, y => $iy + 35, size => 9, mono => 1, color => $C{accent}, t => $in->{to});

        $b .= $input_buttons->($iy + 10, 0);
        $iy += 57;
    }

    $b .= footer($w, $h);
    write_svg('demo_updates.svg', $w, $h, $b);
}

# ── 3. DIFF TAB (Compare) ─────────────────────────────────────────────────────
{
    my $w = 440; my $h = 520;
    my $b = header(w => $w);
    $b .= tabbar('diff', $w);

    # Header & From / To Generation Pickers (matching DiffTab.qml)
    my $py = 126;
    $b .= text(x => 21, y => $py + 10, size => 9, color => $C{muted}, t => 'From');
    $b .= text(x => 197, y => $py + 10, size => 9, color => $C{muted}, t => 'To');

    # Gen A Selector dropdown (#661)
    $b .= rect(x => 21, y => $py + 16, w => 150, h => 32, rx => 6, fill => $C{surface}, stroke => $C{card_border});
    $b .= text(x => 33, y => $py + 36, size => 11, weight => 500, color => $C{text}, t => '#661');
    $b .= glyph(name => 'chevron_down', x => 149, y => $py + 25, size => 14, color => $C{muted});

    # Arrow
    $b .= text(x => 184, y => $py + 36.5, size => 13, color => $C{accent}, anchor => 'middle', t => '→');

    # Gen B Selector dropdown (#662 - Booted)
    $b .= rect(x => 197, y => $py + 16, w => 146, h => 32, rx => 6, fill => $C{surface}, stroke => $C{card_border});
    $b .= text(x => 209, y => $py + 36, size => 11, weight => 500, color => $C{text}, t => '#662 - Booted');
    $b .= glyph(name => 'chevron_down', x => 321, y => $py + 25, size => 14, color => $C{muted});

    # Compare button (primary blue)
    $b .= rect(x => 351, y => $py + 16, w => 68, h => 32, rx => 6, fill => $C{accent});
    $b .= text(x => 385, y => $py + 36, size => 10.5, weight => 600, color => $C{onaccent}, anchor => 'middle', t => 'Compare');

    # Package changes summary header
    my $ry = 186;
    $b .= text(x => 21, y => $ry + 13, size => 10, color => $C{muted}, t => 'Package changes · 7');
    $b .= rect(x => $w - 146, y => $ry, w => 125, h => 22, rx => 4, fill => 'rgba(255,255,255,0.03)', stroke => $C{line});
    $b .= text(x => $w - 138, y => $ry + 14, size => 9, color => $C{muted}, t => 'Filter packages…');

    # Filter pills: All 7, Added 0, Changed 7, Removed 0
    my $fly = $ry + 26;
    $b .= rect(x => 21, y => $fly, w => 44, h => 20, rx => 4, fill => $C{accent});
    $b .= text(x => 43, y => $fly + 13.5, size => 9, weight => 600, color => $C{onaccent}, anchor => 'middle', t => 'All 7');

    $b .= rect(x => 71, y => $fly, w => 56, h => 20, rx => 4, fill => 'none', stroke => $C{line});
    $b .= text(x => 99, y => $fly + 13.5, size => 9, color => $C{positive}, anchor => 'middle', t => 'Added 0');

    $b .= rect(x => 133, y => $fly, w => 68, h => 20, rx => 4, fill => 'none', stroke => $C{line});
    $b .= text(x => 167, y => $fly + 13.5, size => 9, color => $C{changed}, anchor => 'middle', t => 'Changed 7');

    $b .= rect(x => 207, y => $fly, w => 72, h => 20, rx => 4, fill => 'none', stroke => $C{line});
    $b .= text(x => 243, y => $fly + 13.5, size => 9, color => $C{negative}, anchor => 'middle', t => 'Removed 0');

    # Expanded Package Row: ai-usage-hyprland (matching screenshot 4 & 5)
    my $ey = $fly + 28;
    $b .= rect(x => 21, y => $ey, w => $w - 42, h => 128, rx => 6, fill => 'rgba(242,204,112,0.045)', stroke => 'none');
    # Glow bar on left
    $b .= rect(x => 21, y => $ey, w => 2.5, h => 128, rx => 1, fill => $C{changed});

    # Row compact top
    $b .= circle(cx => 33, cy => $ey + 16, r => 7, fill => 'rgba(242,204,112,0.15)');
    $b .= text(x => 33, y => $ey + 19.5, size => 10, weight => 700, color => $C{changed}, anchor => 'middle', t => '~');
    $b .= glyph(name => 'box', x => 45, y => $ey + 9, size => 14, color => $C{changed});
    $b .= text(x => 64, y => $ey + 19.5, size => 10.5, weight => 500, color => $C{text}, t => 'ai-usage-hyprland');
    $b .= text(x => 248, y => $ey + 19.5, size => 9, mono => 1, color => $C{muted}, t => '2.1.2 → 2.3.0');
    $b .= text(x => $w - 46, y => $ey + 19.5, size => 9, mono => 1, color => $C{changed}, anchor => 'end', t => '284.1 KB');
    $b .= glyph(name => 'chevron_up', x => $w - 40, y => $ey + 9, size => 13, color => $C{muted});

    # Detail panel inside package row
    my $diy = $ey + 38;
    $b .= text(x => 42, y => $diy + 10, size => 9.5, weight => 500, color => $C{text}, t => 'ai-usage-hyprland');

    # Version row
    $b .= text(x => 42, y => $diy + 27, size => 9, color => $C{muted}, t => 'Version');
    $b .= text(x => 110, y => $diy + 27, size => 9, mono => 1, weight => 600, color => $C{text}, t => '2.1.2  →  2.3.0');

    # Size delta row
    $b .= text(x => 42, y => $diy + 44, size => 9, color => $C{muted}, t => 'Size delta');
    $b .= text(x => 110, y => $diy + 44, size => 9, mono => 1, weight => 600, color => $C{changed}, t => '284.1 KB');

    # Store path row with copy button
    $b .= text(x => 42, y => $diy + 61, size => 9, color => $C{muted}, t => 'Store path');
    $b .= text(x => 110, y => $diy + 61, size => 9, mono => 1, color => $C{dim}, t => 'Resolving store path…');
    $b .= rect(x => 236, y => $diy + 50, w => 18, h => 16, rx => 3, fill => 'rgba(255,255,255,0.05)');
    $b .= glyph(name => 'copy', x => 239, y => $diy + 52, size => 12, color => $C{muted});

    # Nixpkgs search link row
    $b .= text(x => 42, y => $diy + 78, size => 9, color => $C{muted}, t => 'nixpkgs');
    $b .= text(x => 110, y => $diy + 78, size => 9, mono => 1, color => $C{accent}, t => 'github.com/NixOS/nixpkgs/search?q=ai-usage-hy…');
    $b .= glyph(name => 'external', x => 370, y => $diy + 69, size => 12, color => $C{accent});

    # Other package rows below
    my @other_pkgs = (
        { name => 'ai-usage-widget', ver => '1.4.0 → 1.5.0', size => '120.4 KB' },
        { name => 'gitpulse',        ver => '0.8.2 → 0.9.0', size => '540.2 KB' },
        { name => 'google-antigravity-cli', ver => '1.1.0 → 1.2.0', size => '1.8 MB' },
    );
    my $opy = $ey + 134;
    for my $op (@other_pkgs) {
        $b .= rect(x => 21, y => $opy, w => $w - 42, h => 28, rx => 4, fill => 'rgba(255,255,255,0.015)');
        $b .= circle(cx => 33, cy => $opy + 14, r => 7, fill => 'rgba(242,204,112,0.15)');
        $b .= text(x => 33, y => $opy + 17.5, size => 10, weight => 700, color => $C{changed}, anchor => 'middle', t => '~');
        $b .= glyph(name => 'box', x => 45, y => $opy + 7, size => 14, color => $C{changed});
        $b .= text(x => 64, y => $opy + 17.5, size => 10.5, weight => 500, color => $C{text}, t => $op->{name});
        $b .= text(x => 248, y => $opy + 17.5, size => 9, mono => 1, color => $C{muted}, t => $op->{ver});
        $b .= text(x => $w - 46, y => $opy + 17.5, size => 9, mono => 1, color => $C{changed}, anchor => 'end', t => $op->{size});
        $b .= glyph(name => 'chevron_down', x => $w - 40, y => $opy + 8, size => 13, color => $C{muted});
        $opy += 31;
    }

    $b .= footer($w, $h);
    write_svg('demo_diff.svg', $w, $h, $b);
}

# ── 4. TOOLS TAB ──────────────────────────────────────────────────────────────
{
    my $w = 440; my $h = 480;
    my $b = header(w => $w);
    $b .= tabbar('tools', $w);

    # Tool launch cards. FullView.qml lays them out in one row, but at this
    # 440px mockup width the labels and hints overflow, so draw them 2×2.
    my @tools = (
        { icon => 'secrets',  name => 'Secrets',         hint => 'Inspect deployed and source secrets.' },
        { icon => 'hash',     name => 'Hash calculator', hint => 'Hashes for URLs, files, and store paths.' },
        { icon => 'history',  name => 'Rebuild history', hint => 'Review past rebuild and update output.' },
        { icon => 'search',   name => 'Store usage',     hint => "See why a store path can't be collected." },
    );

    my $gap   = 10;
    my $cardW = ($w - 42 - $gap) / 2;
    my $cardH = 72;
    my $ty0   = 134;

    for my $i (0 .. $#tools) {
        my $t  = $tools[$i];
        my $tx = 21 + ($i % 2) * ($cardW + $gap);
        my $ty = $ty0 + int($i / 2) * ($cardH + $gap);
        $b .= rect(x => $tx, y => $ty, w => $cardW, h => $cardH, rx => 9, fill => '#03ffffff', stroke => '#10ffffff');
        $b .= glyph(name => $t->{icon}, x => $tx + 13, y => $ty + 14, size => 19, color => $C{accent});
        $b .= text(x => $tx + 42, y => $ty + 27, size => 11, weight => 600, color => $C{text}, t => $t->{name});

        my $ly = $ty + 44;
        for my $line (wrap($t->{hint}, 30)) {
            $b .= text(x => $tx + 42, y => $ly, size => 9, color => '#8fa0b7', t => $line);
            $ly += 13;
        }
    }

    # Nix store card (matching screenshot 6)
    my $sy = $ty0 + 2 * ($cardH + $gap) + 8;
    $b .= rect(x => 21, y => $sy, w => $w - 42, h => 112, rx => 9, fill => '#03ffffff', stroke => '#10ffffff');
    $b .= text(x => 34, y => $sy + 22, size => 10.5, weight => 600, color => $C{text}, t => 'Nix store');
    $b .= text(x => $w - 34, y => $sy + 22, size => 9.5, color => '#93a5bd', anchor => 'end', t => '115.0 GB');

    # Progress bar: Blue store bar with amber reclaimable portion on right
    my $pby = $sy + 36;
    $b .= rect(x => 34, y => $pby, w => $w - 68, h => 6, rx => 3, fill => '#0affffff');
    $b .= rect(x => 34, y => $pby, w => $w - 68, h => 6, rx => 3, fill => '#779ecc');
    # Reclaimable segment at right
    $b .= rect(x => $w - 34 - 88, y => $pby, w => 88, h => 6, rx => 3, fill => $C{changed});

    # Legend subrow
    my $ly = $sy + 58;
    $b .= text(x => 34, y => $ly + 10, size => 9, color => '#8fa0b7', t => '814.3 GB free');
    $b .= text(x => $w - 34, y => $ly + 10, size => 9, color => $C{changed}, anchor => 'end', t => '27.3 GB reclaimable');

    # Cleanup button
    my $cby = $sy + 78;
    $b .= rect(x => 34, y => $cby, w => 165, h => 22, rx => 5, fill => 'rgba(255,255,255,0.04)', stroke => $C{line});
    $b .= glyph(name => 'delete', x => 40, y => $cby + 3.5, size => 13, color => $C{negative});
    $b .= text(x => 60, y => $cby + 15, size => 9.5, color => $C{text}, t => 'Clean up old generations…');

    $b .= footer($w, $h);
    write_svg('demo_tools.svg', $w, $h, $b);
}

# ── 5. SECRETS OVERLAY ────────────────────────────────────────────────────────
{
    my $w = 440; my $h = 370;

    # Tools overlay header (FullView.qml lines 980-1015 & screenshot 7)
    my $b = '';
    # Back button "←"
    $b .= rect(x => 21, y => 20, w => 24, h => 24, rx => 4, fill => 'rgba(255,255,255,0.04)');
    $b .= glyph(name => 'back', x => 25, y => 24, size => 15, color => $C{muted});

    # Flake emblem icon
    $b .= logo_image(cx => 62, cy => 32, r => 12);

    # Header title: Secrets
    $b .= text(x => 82, y => 36.5, size => 14, weight => 600, color => $C{text}, t => 'Secrets');

    # Top line separator
    $b .= hline(0, $w, 55);

    # Body section header: green lock icon + SOPS / Agenix Secrets
    my $sy = 75;
    $b .= glyph(name => 'secrets', x => 21, y => $sy, size => 18, color => '#55cc55');
    $b .= text(x => 46, y => $sy + 15, size => 12, weight => 700, color => $C{text}, t => 'SOPS / Agenix Secrets');
    $b .= hline(21, $w - 21, $sy + 26);

    # DEPLOYED BLOCK (screenshot 7)
    my $dby = $sy + 38;
    $b .= text(x => 21, y => $dby + 12, size => 10, weight => 700, color => $C{text}, extra => 'opacity="0.7"', t => 'Deployed');
    $b .= rect(x => $w - 53, y => $dby, w => 32, h => 17, rx => 3, fill => 'rgba(85,204,85,0.15)', stroke => '#55cc55');
    $b .= text(x => $w - 37, y => $dby + 12, size => 8.5, weight => 700, color => '#55cc55', anchor => 'middle', t => 'OK');

    my @dep_rows = (
        ['Path:',          '/run/secrets'],
        ['Last modified:', '2026-09-11 15:38:27'],
        ['Freshness:',     'stale'],
        ['Secrets:',       '0 files'],
    );
    my $dry = $dby + 28;
    for my $r (@dep_rows) {
        $b .= text(x => 21, y => $dry, size => 9, color => $C{muted}, t => $r->[0]);
        my $col = $r->[0] eq 'Freshness:' ? $C{changed} : $C{text};
        $b .= text(x => 98, y => $dry, size => 9, mono => 1, color => $col, t => $r->[1]);
        $dry += 16;
    }

    # SOURCE ENCRYPTED BLOCK
    my $sby = $dry + 14;
    $b .= text(x => 21, y => $sby + 12, size => 10, weight => 700, color => $C{text}, extra => 'opacity="0.7"', t => 'Source');
    $b .= rect(x => $w - 53, y => $sby, w => 32, h => 17, rx => 3, fill => 'rgba(85,204,85,0.15)', stroke => '#55cc55');
    $b .= text(x => $w - 37, y => $sby + 12, size => 8.5, weight => 700, color => '#55cc55', anchor => 'middle', t => 'OK');

    my @src_rows = (
        ['Path:',          '/home/muddyblack/dotfiles/nixos/secrets/secrets.yaml'],
        ['Last modified:', '2026-09-11 15:24:18'],
        ['Encryption:',    'SOPS / age'],
        ['Size:',          '1.8 KB'],
    );
    my $sry = $sby + 28;
    for my $r (@src_rows) {
        $b .= text(x => 21, y => $sry, size => 9, color => $C{muted}, t => $r->[0]);
        $b .= text(x => 98, y => $sry, size => 9, mono => 1, color => $C{text}, t => $r->[1]);
        $sry += 16;
    }

    $b .= footer($w, $h);
    write_svg('demo_secrets.svg', $w, $h, $b);
}

# ── 6. COMMANDS DRAWER ────────────────────────────────────────────────────────
{
    my $w = 440; my $h = 340;

    # Dimmed background overlay
    my $b = rect(x => 0, y => 0, w => $w, h => $h, rx => 14, fill => '#0b0f16', opacity => 0.94);

    # Commands View header (CommandsView.qml lines 31-75 & screenshot 8)
    $b .= rect(x => 20, y => 18, w => 24, h => 24, rx => 4, fill => 'rgba(255,255,255,0.04)');
    $b .= glyph(name => 'back', x => 24, y => 22, size => 15, color => $C{muted});
    $b .= logo_image(cx => 62, cy => 30, r => 12);
    $b .= text(x => 82, y => 35, size => 14, weight => 600, color => $C{text}, t => 'Your commands');
    $b .= text(x => $w - 30, y => 34, size => 18, color => $C{muted}, t => '×');

    $b .= hline(0, $w, 50);

    # Subtitle
    $b .= text(x => 21, y => 74, size => 10.5, color => '#9bacc4', t => 'Quick access to your pinned terminal commands.');

    # Command buttons (as configured in screenshot 8)
    my @cmds = (
        { label => 'update', cmd => 'nix flake update' },
        { label => 'upnix',  cmd => 'upnix' },
    );

    my $cy = 92;
    for my $c (@cmds) {
        $b .= rect(x => 21, y => $cy, w => $w - 42, h => 56, rx => 6, fill => '#04ffffff', stroke => '#1cffffff');
        $b .= glyph(name => 'terminal', x => 33, y => $cy + 13, size => 13, color => '#9bacc4');
        $b .= text(x => 54, y => $cy + 24, size => 10, color => '#bbcbe1', t => $c->{label});
        $b .= text(x => 54, y => $cy + 42, size => 9, mono => 1, color => '#9bacc4', t => $c->{cmd});
        $cy += 65;
    }

    # Info explanation box
    $b .= rect(x => 21, y => $cy + 6, w => $w - 42, h => 46, rx => 7, fill => '#03ffffff', stroke => '#0dffffff');
    $b .= glyph(name => 'info', x => 33, y => $cy + 20, size => 14, color => '#8c9db5');
    $b .= text(x => 56, y => $cy + 33, size => 9, color => '#8c9db5', t => 'Commands run in your terminal, from your flake directory.');

    # Bottom Configure commands button
    $b .= rect(x => 21, y => $cy + 62, w => 165, h => 26, rx => 5, fill => 'none');
    $b .= glyph(name => 'settings', x => 24, y => $cy + 67, size => 13, color => $C{muted});
    $b .= text(x => 44, y => $cy + 78, size => 10, color => $C{text}, t => 'Configure commands…');

    write_svg('demo_commands.svg', $w, $h, $b);
}

# ── 7. PANEL PILL / TRAY ICON MOCKUP ──────────────────────────────────────────
{
    my $w = 210; my $h = 44;
    my $svg = qq{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" width="$w" height="$h">\n};
    $svg .= rect(x => 0, y => 0, w => $w, h => $h, rx => 10, fill => 'rgba(16,20,28,0.92)');
    $svg .= rect(x => 0.5, y => 0.5, w => $w - 1, h => $h - 1, rx => 10, stroke => $C{edge});

    # Left: desktop system tray icons
    for my $i (0 .. 1) {
        $svg .= circle(cx => 18 + $i * 22, cy => 22, r => 7, fill => '#ffffff', opacity => 0.12);
    }

    # Nixdatifier Pill: Flake + #662 + Badge (5 updates)
    my $pillX = 68;
    $svg .= rect(x => $pillX, y => 8, w => 72, h => 28, rx => 14, fill => 'rgba(145,188,255,0.12)', stroke => 'rgba(145,188,255,0.25)');
    $svg .= logo_image(cx => $pillX + 14, cy => 22, r => 10);
    $svg .= text(x => $pillX + 28, y => 26, size => 11, weight => 700, mono => 1, color => $C{text}, t => '#662');

    # Badge: 5 pending updates
    $svg .= circle(cx => $pillX + 66, cy => 12, r => 6.5, fill => $C{accent});
    $svg .= text(x => $pillX + 66, y => 15, size => 8.5, weight => 700, color => $C{onaccent}, anchor => 'middle', t => '5');

    # Clock on right
    $svg .= text(x => 176, y => 20, size => 10, mono => 1, color => $C{text}, anchor => 'middle', t => '12:16');
    $svg .= text(x => 176, y => 31, size => 7.5, mono => 1, color => $C{dim}, anchor => 'middle', t => 'Fri 11');
    $svg .= "\n</svg>\n";

    open my $fh, '>', "$DIR/panel.svg" or die $!;
    print $fh $svg;
    close $fh;
    printf "  %-22s %5d bytes\n", 'panel.svg', length($svg);
}

print "All demo visuals generated successfully.\n";
