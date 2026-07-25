module modules.appearance.fonts;

import dlangui;
import dlangui.graphics.fonts : FontFamily;
import modules.appearance.settings;

/// Apply the user's preferred code font (Cascadia Mono or JetBrains Mono) to a widget.
void applyCodeFont(Widget w)
{
    if (w is null)
        return;
    auto s = loadAppearanceSettings();
    w.fontFamily(FontFamily.MonoSpace);
    w.fontFace(codeFontFaceList(s.codeFontFace));
}

/// Current primary face name (for labels / dialogs).
string currentCodeFontFace()
{
    return loadAppearanceSettings().codeFontFace;
}
