module modules.services.context7_submit_dialog;

import context7.submit;
import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import modules.infra.logging : logInfo, logWarning;
import std.algorithm : endsWith, startsWith;
import std.process : environment, execute;
import std.string : indexOf, strip;

/// Ask for a documentation URL and send it to the Context7 index.
void showContext7SubmitDialog(Window parentWindow, string repoRoot)
{
    logInfo("Opening Context7 submit for " ~ repoRoot);
    auto dlg = new Dialog(UIString.fromRaw("Submit docs to Context7"d), parentWindow,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(720).minHeight(420);

    auto content = new VerticalLayout();
    content.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(12);

    auto heading = new TextWidget(null, "Submit docs to Context7"d);
    heading.fontSize(16).fontWeight(700).margins(Rect(0, 0, 0, 8));
    content.addChild(heading);

    auto note = new TextWidget(null,
        "This sends a source URL to the Context7 index. It does not install anything on this machine.\n"
        ~ "For a website, set the HTML documentation root. That root is often not the page the homepage links to."d);
    note.textColor(0xBBBBBB).margins(Rect(0, 0, 0, 8));
    content.addChild(note);

    content.addChild(new TextWidget(null, "Source URL"d));
    auto urlEdit = new EditLine("ctx7SubmitUrl", toUI(originHttps(repoRoot)));
    urlEdit.layoutWidth(FILL_PARENT);
    content.addChild(urlEdit);

    content.addChild(new TextWidget(null, "Website documentation root (optional)"d));
    auto baseEdit = new EditLine("ctx7SubmitBase", ""d);
    baseEdit.layoutWidth(FILL_PARENT).margins(Rect(0, 4, 0, 8));
    content.addChild(baseEdit);

    content.addChild(new TextWidget(null, "Context7 API key"d));
    auto keyEnv = environment.get("CONTEXT7_API_KEY", "");
    auto keyEdit = new EditLine("ctx7SubmitKey", toUI(keyEnv));
    keyEdit.layoutWidth(FILL_PARENT).margins(Rect(0, 4, 0, 8));
    content.addChild(keyEdit);

    auto status = new TextWidget(null, ""d);
    status.textColor(0xCCCCCC).margins(Rect(0, 8, 0, 0));
    content.addChild(status);

    auto buttons = new HorizontalLayout();
    buttons.layoutWidth(FILL_PARENT).margins(Rect(0, 12, 0, 0));
    auto submitBtn = new Button(null, "Submit"d);
    submitBtn.click = delegate(Widget w) {
        auto url = fromUI(urlEdit.text).strip;
        auto websiteBase = fromUI(baseEdit.text).strip;
        auto apiKey = fromUI(keyEdit.text).strip;
        if (url.length == 0)
        {
            status.text = "A source URL is required."d;
            return true;
        }
        if (apiKey.length == 0)
        {
            status.text = "Set CONTEXT7_API_KEY or type a key. It is not saved."d;
            return true;
        }
        status.text = "Submitting…"d;
        SubmitOptions options;
        if (websiteBase.length)
            options.websiteBaseUrl = websiteBase;
        SubmitResult result;
        try
        {
            result = submitSource(SubmitRequest(url, null, options, apiKey));
        }
        catch (Exception e)
        {
            logWarning("Context7 submit failed: " ~ e.msg);
            status.text = toUI(e.msg);
            return true;
        }
        if (result.ok)
        {
            auto line = result.message;
            if (result.libraryName.length)
                line ~= " " ~ result.libraryName;
            logInfo("Context7 submit: " ~ line);
            status.text = toUI(line);
        }
        else
        {
            logWarning("Context7 submit: " ~ result.message);
            status.text = toUI(result.message);
        }
        return true;
    };
    buttons.addChild(submitBtn);
    auto closeBtn = new Button(null, "Close"d);
    closeBtn.click = delegate(Widget w) { dlg.close(null); return true; };
    buttons.addChild(closeBtn);
    content.addChild(buttons);

    dlg.addChild(content);
    dlg.show();
}

private dstring toUI(string s)
{
    import std.conv : to;
    return to!dstring(s);
}

private string fromUI(dstring s)
{
    import std.conv : to;
    return to!string(s);
}

private string originHttps(string repoRoot)
{
    if (repoRoot.length == 0)
        return "";
    auto res = execute(["git", "-C", repoRoot, "remote", "get-url", "origin"]);
    if (res.status != 0)
        return "";
    return httpsRemote(res.output.strip);
}

private string httpsRemote(string raw)
{
    auto s = raw.strip;
    if (s.endsWith(".git"))
        s = s[0 .. $ - 4];
    if (s.startsWith("https://") || s.startsWith("http://"))
        return s;
    if (s.startsWith("git@"))
    {
        auto colon = s.indexOf(":");
        if (colon > 4)
            return "https://" ~ s[4 .. colon] ~ "/" ~ s[colon + 1 .. $];
    }
    if (s.startsWith("ssh://git@"))
    {
        auto rest = s["ssh://git@".length .. $];
        auto slash = rest.indexOf("/");
        if (slash > 0)
            return "https://" ~ rest;
    }
    return s;
}
