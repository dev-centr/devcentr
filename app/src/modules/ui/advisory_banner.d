module modules.ui.advisory_banner;

import dlangui;
import modules.infra.ui : openUrlInBrowser;
import std.conv : to;

private enum Style {
    bg = 0x2A2420,
    muted = 0xAAAAAA,
    warn = 0xCC8866,
    accent = 0x007AFF,
}

/// Short top-of-page advisory with optional Learn more URL (Toolchain Management, etc.).
class AdvisoryBanner : VerticalLayout
{
    this(string message, string learnMoreUrl = null, bool warnTint = true)
    {
        super("advisoryBanner");
        layoutWidth(FILL_PARENT);
        padding(10);
        margins(Rect(0, 0, 0, 8));
        backgroundColor(Style.bg);

        auto row = new HorizontalLayout();
        row.layoutWidth(FILL_PARENT);

        auto text = new TextWidget(null, to!dstring(message));
        text.fontSize(10).textColor(warnTint ? Style.warn : Style.muted);
        text.layoutWidth(FILL_PARENT);
        row.addChild(text);

        if (learnMoreUrl.length > 0)
        {
            auto btn = new Button(null, "Learn more"d);
            btn.click = delegate(Widget w) {
                openUrlInBrowser(learnMoreUrl);
                return true;
            };
            row.addChild(btn);
        }

        addChild(row);
    }
}
