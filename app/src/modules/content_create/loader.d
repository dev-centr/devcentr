module modules.content_create.loader;

import modules.content_create.model;
import sdlang;
import std.algorithm : canFind;
import std.conv : to;
import std.file : exists, getcwd, readText, thisExePath;
import std.path : buildPath, dirName;
import std.string : strip, toLower;

private string tagStr(Tag t, string name)
{
    auto x = t.getTag(name);
    if (x is null || x.values.length == 0)
        return "";
    try
        return x.values[0].get!string;
    catch (Exception)
    {
        try
            return to!string(x.values[0].get!long);
        catch (Exception)
            return "";
    }
}

private string[] tagStrList(Tag t, string name)
{
    string[] result;
    foreach (child; t.tags)
    {
        if (child.name != name)
            continue;
        foreach (v; child.values)
        {
            try
                result ~= v.get!string;
            catch (Exception)
            {
                try
                    result ~= to!string(v.get!long);
                catch (Exception)
                {
                }
            }
        }
    }
    // also allow single ecosystem "a" "b" on one tag
    auto x = t.getTag(name);
    if (x !is null)
    {
        foreach (v; x.values)
        {
            string s;
            try
                s = v.get!string;
            catch (Exception)
            {
                try
                    s = to!string(v.get!long);
                catch (Exception)
                    continue;
            }
            if (s.length && !result.canFind(s))
                result ~= s;
        }
    }
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

private int tagInt(Tag t, string name, int defaultVal = 0)
{
    auto x = t.getTag(name);
    if (x is null || x.values.length == 0)
        return defaultVal;
    try
        return cast(int)x.values[0].get!long;
    catch (Exception)
    {
        try
            return to!int(x.values[0].get!string);
        catch (Exception)
            return defaultVal;
    }
}

string resolveContentTypesSdlPath()
{
    string fileName = "content-types.sdl";
    string[] candidates = [
        buildPath(getcwd(), "src", "modules", "content_create", fileName),
        buildPath(getcwd(), "app", "src", "modules", "content_create", fileName),
        buildPath(dirName(thisExePath()), "src", "modules", "content_create", fileName),
        buildPath(dirName(thisExePath()), fileName),
    ];
    foreach (c; candidates)
        if (exists(c))
            return c;
    return candidates[0];
}

/// Default ecosystems when SDL omits them (by type id, then classification).
string[] defaultEcosystemsFor(string typeId, string classificationId, string[] parentEco)
{
    string id = typeId.toLower();
    switch (id)
    {
    case "typescript", "javascript", "mdx", "toon":
        return ["general", "js"];
    case "java":
        return ["general", "jvm", "java"];
    case "csharp", "cs":
        return ["general", "dotnet"];
    case "python":
        return ["general", "python"];
    case "rust":
        return ["general", "rust"];
    case "go":
        return ["general", "go"];
    case "d":
        return ["general", "d"];
    case "c", "cpp":
        return ["general", "cpp"];
    case "openapi", "protobuf", "json-schema", "avro", "yaml", "dotenv":
        return ["general", "devops"];
    case "csv", "tsv", "jsonl":
        return ["general", "data"];
    case "centrmark", "asciidoc", "markdown", "djot", "rst", "orgmode", "typst":
        return ["general", "docs"];
    default:
        break;
    }
    if (parentEco.length)
        return parentEco.dup;
    switch (classificationId)
    {
    case "docs":
        return ["general", "docs"];
    case "data":
        return ["general", "data"];
    case "schema":
        return ["general", "devops"];
    case "code":
        return ["general"];
    default:
        return ["general"];
    }
}

private void applyEcosystems(ref ContentTypeNode n, string classificationId, string[] parentEco)
{
    if (n.ecosystems.length == 0)
        n.ecosystems = defaultEcosystemsFor(n.id, classificationId, parentEco);
    foreach (ref ch; n.children)
        applyEcosystems(ch, classificationId, n.ecosystems);
}

private ContentTypeNode parseType(Tag t)
{
    ContentTypeNode n;
    n.id = tagStr(t, "id");
    n.label = tagStr(t, "label");
    n.role = tagStr(t, "role");
    n.description = tagStr(t, "description");
    n.extension = tagStr(t, "extension");
    n.suggestedName = tagStr(t, "suggestedName");
    n.templateBody = tagStr(t, "template");
    n.inventedYear = tagInt(t, "inventedYear", 0);
    n.lastUpdated = tagStr(t, "lastUpdated");
    n.repoUrl = tagStr(t, "repo");
    if (n.repoUrl.length == 0)
        n.repoUrl = tagStr(t, "repoUrl");
    n.specUrl = tagStr(t, "spec");
    if (n.specUrl.length == 0)
        n.specUrl = tagStr(t, "specUrl");
    n.homepage = tagStr(t, "homepage");
    n.vitality = tagStr(t, "vitality");
    n.ecosystems = tagStrList(t, "ecosystem");
    bool hasCreatable = t.getTag("creatable") !is null;
    if (hasCreatable)
        n.creatable = tagBool(t, "creatable", true);
    else
        n.creatable = n.extension.length > 0;

    foreach (child; t.tags)
    {
        if (child.name == "type")
            n.children ~= parseType(child);
    }
    if (n.children.length > 0 && t.getTag("creatable") is null && n.extension.length == 0)
        n.creatable = false;
    if (n.vitality.length == 0)
        n.vitality = n.creatable ? "mature" : "reference";
    return n;
}

private ContentClassification parseClassification(Tag t)
{
    ContentClassification c;
    c.id = tagStr(t, "id");
    c.label = tagStr(t, "label");
    c.summary = tagStr(t, "summary");
    foreach (child; t.tags)
    {
        if (child.name == "type")
            c.types ~= parseType(child);
    }
    foreach (ref n; c.types)
        applyEcosystems(n, c.id, null);
    return c;
}

private LineageScope parseLineage(Tag t)
{
    LineageScope lin;
    lin.scope_ = tagStr(t, "scope");
    foreach (child; t.tags)
    {
        if (child.name != "edge")
            continue;
        LineageEdge e;
        e.fromId = tagStr(child, "from");
        e.toId = tagStr(child, "to");
        e.kind = tagStr(child, "kind");
        e.note = tagStr(child, "note");
        lin.edges ~= e;
    }
    return lin;
}

ContentTypesCatalog loadContentTypesCatalog(string path = "")
{
    ContentTypesCatalog cat;
    auto p = path.length == 0 ? resolveContentTypesSdlPath() : path;
    if (!exists(p))
        return cat;
    Tag root;
    try
        root = parseSource(readText(p), p);
    catch (Exception)
        return cat;

    auto ct = root.getTag("contentTypes");
    if (ct is null)
    {
        if (root.name == "contentTypes")
            ct = root;
        else
        {
            foreach (t; root.tags)
            {
                if (t.name == "contentTypes")
                {
                    ct = t;
                    break;
                }
            }
        }
    }
    if (ct is null)
        return cat;

    cat.version_ = tagInt(ct, "version", 1);
    foreach (child; ct.tags)
    {
        if (child.name == "classification")
            cat.classifications ~= parseClassification(child);
        else if (child.name == "lineage")
            cat.lineages ~= parseLineage(child);
    }
    return cat;
}
