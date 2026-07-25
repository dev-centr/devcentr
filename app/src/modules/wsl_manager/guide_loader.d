module modules.wsl_manager.guide_loader;

import sdlang;
import modules.wsl_manager.model;
import std.file : exists, thisExePath, getcwd;
import std.path : buildPath, dirName;

private string tagStr(Tag t, string name)
{
    auto x = t.getTag(name);
    if (x is null || x.values.length == 0)
        return "";
    return x.values[0].get!string;
}

DistroGuide loadDistroGuideFromSdl(string path)
{
    DistroGuide g;
    if (!exists(path))
        return builtinGuide();
    auto root = parseFile(path);
    auto guideTag = root.getTag("guide");
    if (guideTag is null)
        return builtinGuide();

    g.docsComparisonUrl = tagStr(guideTag, "docsComparisonUrl");
    g.docsSetupUrl = tagStr(guideTag, "docsSetupUrl");
    g.wslSettingsDocsUrl = tagStr(guideTag, "wslSettingsDocsUrl");
    g.microsoftWslDocsUrl = tagStr(guideTag, "microsoftWslDocsUrl");
    g.intro = tagStr(guideTag, "intro");

    foreach (dtag; guideTag.tags)
    {
        if (dtag.name != "distro")
            continue;
        DistroGuideEntry e;
        e.id = tagStr(dtag, "id");
        e.title = tagStr(dtag, "title");
        e.role = tagStr(dtag, "role");
        e.summary = tagStr(dtag, "summary");
        e.preferWhen = tagStr(dtag, "preferWhen");
        e.avoidWhen = tagStr(dtag, "avoidWhen");
        foreach (m; dtag.tags)
        {
            if (m.name == "match" && m.values.length > 0)
                e.matchTokens ~= m.values[0].get!string;
        }
        g.distros ~= e;
    }
    if (g.distros.length == 0)
        return builtinGuide();
    return g;
}

string bundledGuideSdlPath()
{
    string p = buildPath(getcwd(), "src", "modules", "wsl_manager", "distro-guide.sdl");
    if (exists(p))
        return p;
    return buildPath(dirName(thisExePath()), "distro-guide.sdl");
}

/// Fallback if SDL missing (keeps UI usable).
DistroGuide builtinGuide()
{
    DistroGuide g;
    g.docsComparisonUrl = "https://docs.devcentr.org/general-knowledge/latest/explanation/infrastructure/wsl-distro-comparison.html";
    g.docsSetupUrl = "https://docs.devcentr.org/general-knowledge/latest/how-to/wsl-setup.html";
    g.wslSettingsDocsUrl = "https://learn.microsoft.com/windows/wsl/wsl-config";
    g.microsoftWslDocsUrl = "https://learn.microsoft.com/windows/wsl/";
    g.intro = "Pick a default distro for bare wsl. Ubuntu LTS is the merit-based default; never default docker-desktop or podman-machine.";
    g.distros = [
        DistroGuideEntry("ubuntu", ["ubuntu"], "Ubuntu LTS", "Ideal system default",
            "Real Ubuntu LTS for the release you installed. Stable baseline with security backports—not rolling newest Ubuntu.",
            "Daily shell and docs/CI match.", "Bleeding-edge system libs without a second distro."),
        DistroGuideEntry("tumbleweed", ["tumbleweed", "opensuse"], "openSUSE Tumbleweed", "Ideal rolling workshop",
            "Curated rolling with strong packaging.", "Fresh packages.", "Max docs overlap as default."),
        DistroGuideEntry("arch", ["arch"], "Arch Linux", "Enthusiast / experiment",
            "Rolling + AUR; you maintain it.", "Experiments.", "Boring shared default."),
        DistroGuideEntry("alma", ["alma", "rocky", "rhel"], "AlmaLinux / RHEL clones", "Prod-parity specialty",
            "Match RHEL-shaped production.", "Enterprise CI parity.", "General personal default."),
        DistroGuideEntry("managed", ["docker-desktop", "podman-machine"], "Engine-managed (Docker / Podman)", "Never set as default",
            "Helper distros for container engines.", "Leave for the engine.", "Daily default shell."),
        DistroGuideEntry("other", ["*"], "Other distro", "Named specialist",
            "Use on purpose; keep a clear default.", "Specific required image.", "Replacing Ubuntu without need."),
    ];
    return g;
}
