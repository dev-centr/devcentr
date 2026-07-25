module modules.ecosystems.loader;

import modules.ecosystems.model;
import sdlang;
import std.file : exists, getcwd, thisExePath;
import std.path : buildPath, dirName;
import std.string : strip;

private string tagStr(Tag t, string name)
{
    auto x = t.getTag(name);
    if (x is null || x.values.length == 0)
        return "";
    return x.values[0].get!string;
}

private string[] tagStrList(Tag t, string name)
{
    string[] result;
    auto x = t.getTag(name);
    if (x is null)
        return result;
    foreach (v; x.values)
        result ~= v.get!string;
    foreach (child; x.tags)
        if (child.values.length > 0)
            result ~= child.values[0].get!string;
    return result;
}

private bool tagBool(Tag t, string name, bool defaultValue)
{
    auto x = t.getTag(name);
    if (x is null || x.values.length == 0)
        return defaultValue;
    try
        return x.values[0].get!bool;
    catch (Exception)
    {
        auto s = x.values[0].get!string.strip();
        if (s == "true" || s == "1")
            return true;
        if (s == "false" || s == "0")
            return false;
        return defaultValue;
    }
}

private ControlPlaneStatus parseStatus(string s)
{
    switch (s.strip())
    {
    case "official":
        return ControlPlaneStatus.official;
    case "community":
        return ControlPlaneStatus.community;
    case "missing":
    default:
        return ControlPlaneStatus.missing;
    }
}

/// Load ecosystem definition from an SDL file. Root tag name should match `ecosystemId`.
EcosystemDefinition loadEcosystemFromSdl(string path, string ecosystemId)
{
    EcosystemDefinition def;
    def.id = ecosystemId;
    def.displayName = ecosystemId;
    def.controlPlane.advisory = true;

    if (!exists(path))
        return fallbackDefinition(ecosystemId);

    auto root = parseFile(path);
    auto eco = root.getTag(ecosystemId);
    if (eco is null)
        return fallbackDefinition(ecosystemId);

    if (ecosystemId == "flutter")
        def.displayName = "Flutter";
    else if (ecosystemId == "node")
        def.displayName = "Node.js";

    auto ucp = eco.getTag("unifiedControlPlane");
    if (ucp !is null)
    {
        def.controlPlane.status = parseStatus(tagStr(ucp, "status"));
        def.controlPlane.entrypoint = tagStr(ucp, "entrypoint");
        def.controlPlane.communityTools = tagStrList(ucp, "communityTools");
        def.controlPlane.advisory = tagBool(ucp, "advisory", true);
    }

    foreach (rt; eco.tags)
    {
        if (rt.name == "runtime")
        {
            EcosystemRuntime r;
            r.id = tagStr(rt, "id");
            r.name = tagStr(rt, "name");
            def.runtimes ~= r;
        }
        else if (rt.name == "packageManager")
        {
            EcosystemPackageManager p;
            p.id = tagStr(rt, "id");
            p.name = tagStr(rt, "name");
            def.packageManagers ~= p;
        }
        else if (rt.name == "framework")
        {
            EcosystemFramework f;
            f.id = tagStr(rt, "id");
            f.name = tagStr(rt, "name");
            def.frameworks ~= f;
        }
    }

    return def;
}

EcosystemDefinition fallbackDefinition(string ecosystemId)
{
    EcosystemDefinition def;
    def.id = ecosystemId;
    def.displayName = ecosystemId;
    def.controlPlane.status = ControlPlaneStatus.community;
    def.controlPlane.advisory = true;
    if (ecosystemId == "flutter")
    {
        def.displayName = "Flutter";
        def.controlPlane.communityTools = ["fvm", "puro", "mise"];
    }
    else if (ecosystemId == "node")
    {
        def.displayName = "Node.js";
        def.controlPlane.communityTools = ["fnm", "nvm", "mise"];
    }
    return def;
}

string bundledLanguageSdlPath(string ecosystemId)
{
    string p = buildPath(getcwd(), "src", "modules", "languages", ecosystemId ~ ".sdl");
    if (exists(p))
        return p;
    return buildPath(dirName(thisExePath()), "languages", ecosystemId ~ ".sdl");
}
