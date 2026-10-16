.pragma library

// Settings-only palette and metrics, Studio controls with Nixdatifier widget colours.
var panel = "#131923";
var panelTop = "#171f2c";
var panelBottom = "#111720";
var sunk = "#0e141e";
var line = "#10ffffff";
var line2 = "#1cffffff";
var text = "#e6ecf5";
var muted = "#939fb2";
var dim = "#77849a";
var brand = "#91bcff";
var brandInk = "#101b2c";
var sectionTitle = "#a9b8cc";
var card = "#04ffffff";
var hover = "#08ffffff";
var segPressed = "#294569";
var segPressedText = "#eeefeb";
var chipPressed = "#22344b";
var chipPressedBorder = "#5091bcff";
var switchOff = "#3a3e40";
var switchOnTop = "#a9cbff";
var switchOnBottom = "#71849b";
var knob = "#f3f5f5";
var rangeTrack = "#1affffff";
var rangeThumb = "#f4f6f6";
var outputText = "#d0dbea";
var fontFamily = "Inter";

var defaults = { panel: panel, panelTop: panelTop, panelBottom: panelBottom, sunk: sunk, line: line, line2: line2, text: text, muted: muted, dim: dim, brand: brand, brandInk: brandInk, sectionTitle: sectionTitle, card: card, hover: hover, segPressed: segPressed, segPressedText: segPressedText, chipPressed: chipPressed, chipPressedBorder: chipPressedBorder, switchOff: switchOff, switchOnTop: switchOnTop, switchOnBottom: switchOnBottom, knob: knob, rangeTrack: rangeTrack, rangeThumb: rangeThumb, outputText: outputText, fontFamily: fontFamily };

function mix(a, b, amount) {
    const x = Qt.color(a), y = Qt.color(b);
    return Qt.rgba(x.r + (y.r - x.r) * amount, x.g + (y.g - x.g) * amount, x.b + (y.b - x.b) * amount, 1);
}
function luminance(value) {
    const c = Qt.color(value);
    const linear = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
}
function contrast(a, b) {
    const x = luminance(a), y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}
function fromSettings(settings) {
    if (!settings) return defaults;
    const base = Qt.color(settings.bgColor || panel);
    const surface = Qt.rgba(base.r, base.g, base.b, 1);
    const accent = settings.accentColor || brand;
    const ink = contrast(surface, "#17202d") > contrast(surface, "#e6ecf5") ? "#17202d" : "#e6ecf5";
    const preferred = settings.useSystemTextColor ? ink : settings.customTextColor;
    const foreground = preferred && contrast(surface, preferred) >= 4.5 ? preferred : ink;
    const result = Object.assign({}, defaults);
    result.panel = surface;
    result.panelTop = mix(surface, foreground, 0.025);
    result.panelBottom = mix(surface, "#000000", 0.08);
    result.sunk = mix(surface, luminance(surface) > 0.45 ? "#ffffff" : "#000000", 0.22);
    result.text = foreground;
    result.muted = mix(surface, foreground, 0.64);
    result.dim = mix(surface, foreground, 0.52);
    result.sectionTitle = mix(surface, foreground, 0.75);
    result.outputText = foreground;
    result.brand = accent;
    result.brandInk = contrast(accent, "#101b2c") >= contrast(accent, "#ffffff") ? "#101b2c" : "#ffffff";
    result.segPressed = mix(surface, accent, 0.25);
    result.segPressedText = foreground;
    result.chipPressed = mix(surface, accent, 0.16);
    const c = Qt.color(accent);
    result.chipPressedBorder = Qt.rgba(c.r, c.g, c.b, 0.4);
    result.switchOnTop = accent;
    result.switchOnBottom = mix(accent, settings.timelineColor || accent, 0.35);
    const f = Qt.color(foreground);
    result.line = Qt.rgba(f.r, f.g, f.b, 0.08);
    result.line2 = Qt.rgba(f.r, f.g, f.b, 0.14);
    result.card = Qt.rgba(f.r, f.g, f.b, 0.025);
    result.hover = Qt.rgba(f.r, f.g, f.b, 0.05);
    result.rangeTrack = Qt.rgba(f.r, f.g, f.b, 0.14);
    result.switchOff = mix(surface, foreground, 0.2);
    return result;
}
