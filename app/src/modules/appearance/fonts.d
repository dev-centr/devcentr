module modules.appearance.fonts;

import dlangui;
import dlangui.graphics.fonts : FontFamily, FontManager, FontWeight;
import modules.appearance.settings;
import std.algorithm : equal;
import std.uni : toLower;

enum string FONT_PREVIEW_PANGRAM =
    "0O 1lI 8B -- The quick brown fox jumps over the lazy dog.";

enum string FONT_PREVIEW_D_SAMPLE = q{
void main() {
    import std.stdio : writeln;
    const ids = ["cascadia", "jetbrains"]; // 0 vs O, 1 vs l
    foreach (id; ids)
        writeln("pin ", id);
}
};

/// Default editable preview text (pangram + D sample from font-lock spec).
string defaultFontPreviewText()
{
    import std.conv : to;
    return FONT_PREVIEW_PANGRAM ~ "\n\n" ~ to!string(FONT_PREVIEW_D_SAMPLE);
}

/// True when the OS reports the face by name (no fallback chain).
bool isCodeFontInstalled(string face)
{
    if (!isAllowedCodeFont(face))
        return false;

    auto faces = FontManager.instance.getFaces();
    if (faces !is null)
    {
        foreach (f; faces)
        {
            if (f.face.equal(face))
                return true;
        }
    }

    auto font = FontManager.instance.getFont(10, FontWeight.Normal, false, FontFamily.MonoSpace, face);
    return !font.isNull && font.face.toLower == face.toLower;
}

/// Apply the user's preferred code font (Cascadia Mono or JetBrains Mono) to a widget.
void applyCodeFont(Widget w)
{
    if (w is null)
        return;
    auto s = loadAppearanceSettings();
    w.fontFamily(FontFamily.MonoSpace);
    w.fontFace(codeFontFaceList(s.codeFontFace));
}

/// Preview pane: wear only the selected face (no silent Consolas fallback in the label).
void applyPreviewCodeFont(Widget w, string face)
{
    if (w is null)
        return;
    w.fontFamily(FontFamily.MonoSpace);
    w.fontFace(normalizeCodeFontFace(face));
}

/// Current primary face name (for labels / dialogs).
string currentCodeFontFace()
{
    return loadAppearanceSettings().codeFontFace;
}
