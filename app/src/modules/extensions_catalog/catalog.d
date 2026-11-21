/// Extensions catalog. Rules templates use the same entry fields as other kinds.
module modules.extensions_catalog.catalog;

import std.algorithm : canFind;
import std.file : exists, mkdirRecurse, readText, write;
import std.json : JSONType, JSONValue, parseJSON;
import std.path : buildNormalizedPath, buildPath, dirName;

struct ExtensionInstall
{
    /// URL or repo path. Same idea as DOCS_TEMPLATE. Not a copy of the rule body.
    string pointer;
}

struct ExtensionEntry
{
    string catalogId;
    string id;
    string name;
    string description;
    string repository;
    string repositoryOwner;
    string repositoryName;
    string manifestPath;
    /// JSON field `version`. `version` is a D keyword, so the member name differs.
    string releaseVersion;
    string type;
    string[] tags;
    ExtensionInstall install;
}

enum rulesTemplateType = "rules-template";
enum onlineStoreUrl = "https://devcentr.org/extensions?type=rules-template";

/// Docs template shipped as an installed template on first run.
ExtensionEntry docsDefaultEntry()
{
    ExtensionEntry e;
    e.catalogId = "dev-centr/agent-rules/docs-default";
    e.id = "docs-default";
    e.name = "Default documentation template";
    e.description = "Suggested default for an org's documentation preferences. An org records a pointer to this file as DOCS_TEMPLATE. Installing it stores that link, not a pasted copy of the rules.";
    e.repository = "https://github.com/dev-centr/agent-rules";
    e.repositoryOwner = "dev-centr";
    e.repositoryName = "agent-rules";
    e.manifestPath = "templates/docs-default.md";
    e.releaseVersion = "1";
    e.type = rulesTemplateType;
    e.tags = ["docs", "agent-rules", "default"];
    e.install.pointer = "https://github.com/dev-centr/agent-rules/blob/main/templates/docs-default.md";
    return e;
}

private string fieldStr(JSONValue item, string key)
{
    if ((key in item) is null)
        return "";
    auto v = item[key];
    if (v.type == JSONType.string)
        return v.str;
    return "";
}

ExtensionEntry entryFromJson(JSONValue item)
{
    ExtensionEntry e;
    e.catalogId = fieldStr(item, "catalogId");
    e.id = fieldStr(item, "id");
    e.name = fieldStr(item, "name");
    e.description = fieldStr(item, "description");
    e.repository = fieldStr(item, "repository");
    e.repositoryOwner = fieldStr(item, "repositoryOwner");
    e.repositoryName = fieldStr(item, "repositoryName");
    e.manifestPath = fieldStr(item, "manifestPath");
    e.releaseVersion = fieldStr(item, "version");
    e.type = fieldStr(item, "type");
    if ((("tags" in item) !is null) && item["tags"].type == JSONType.array)
    {
        foreach (t; item["tags"].array)
        {
            if (t.type == JSONType.string)
                e.tags ~= t.str;
        }
    }
    if (("install" in item) !is null && item["install"].type == JSONType.object)
        e.install.pointer = fieldStr(item["install"], "pointer");
    return e;
}

ExtensionEntry[] entriesFromCatalogJson(string jsonText)
{
    auto root = parseJSON(jsonText);
    JSONValue[] rows;
    if (root.type == JSONType.array)
        rows = root.array;
    else if (root.type == JSONType.object && ("entries" in root) !is null && root["entries"].type == JSONType.array)
        rows = root["entries"].array;
    else
        return [];
    ExtensionEntry[] list;
    foreach (item; rows)
    {
        if (item.type != JSONType.object)
            continue;
        auto e = entryFromJson(item);
        if (e.id.length == 0 || e.install.pointer.length == 0)
            continue;
        if (e.catalogId.length == 0)
            e.catalogId = e.id;
        list ~= e;
    }
    return list;
}

string catalogToJson(ExtensionEntry[] entries)
{
    JSONValue[] rows;
    foreach (e; entries)
    {
        JSONValue[] tagList;
        foreach (t; e.tags)
            tagList ~= JSONValue(t);
        JSONValue row;
        row["catalogId"] = e.catalogId;
        row["id"] = e.id;
        row["name"] = e.name;
        row["description"] = e.description;
        row["repository"] = e.repository;
        row["repositoryOwner"] = e.repositoryOwner;
        row["repositoryName"] = e.repositoryName;
        row["manifestPath"] = e.manifestPath;
        row["version"] = e.releaseVersion;
        row["type"] = e.type;
        row["tags"] = JSONValue(tagList);
        JSONValue install;
        install["pointer"] = e.install.pointer;
        row["install"] = install;
        rows ~= row;
    }
    JSONValue root = ["entries": JSONValue(rows)];
    return root.toPrettyString();
}

ExtensionEntry[] publishedCatalog()
{
    string[] candidates = [
        buildPath("catalog", "extensions.json"),
        buildPath("..", "catalog", "extensions.json"),
        buildPath("..", "..", "catalog", "extensions.json")
    ];
    foreach (c; candidates)
    {
        if (!exists(c))
            continue;
        try
        {
            auto parsed = entriesFromCatalogJson(readText(c));
            if (parsed.length)
                return parsed;
        }
        catch (Exception)
        {
        }
    }
    return [docsDefaultEntry()];
}

ExtensionEntry[] loadLocalCatalog(string catalogPath)
{
    if (!exists(catalogPath))
        return [];
    try
        return entriesFromCatalogJson(readText(catalogPath));
    catch (Exception)
        return [];
}

void saveLocalCatalog(string catalogPath, ExtensionEntry[] entries)
{
    string parent = dirName(catalogPath);
    if (parent.length && !exists(parent))
        mkdirRecurse(parent);
    write(catalogPath, catalogToJson(entries));
}

/// First run: the default docs template is already available.
ExtensionEntry[] loadOrSeed(string catalogPath)
{
    if (!exists(catalogPath))
    {
        ExtensionEntry[] seed = [docsDefaultEntry()];
        saveLocalCatalog(catalogPath, seed);
        return seed;
    }
    auto loaded = loadLocalCatalog(catalogPath);
    if (loaded.length == 0)
    {
        ExtensionEntry[] seed = [docsDefaultEntry()];
        saveLocalCatalog(catalogPath, seed);
        return seed;
    }
    return loaded;
}

bool catalogHas(ExtensionEntry[] entries, string catalogId)
{
    foreach (e; entries)
    {
        if (e.catalogId == catalogId || e.id == catalogId)
            return true;
    }
    return false;
}

/// Record a pointer. Does not write the template body.
bool installPointer(string catalogPath, ExtensionEntry entry, ref string message)
{
    if (entry.install.pointer.length == 0)
    {
        message = "This template has no install link.";
        return false;
    }
    if (entry.id.length == 0)
    {
        message = "This template has no id.";
        return false;
    }
    auto entries = exists(catalogPath) ? loadLocalCatalog(catalogPath) : [];
    if (catalogHas(entries, entry.catalogId.length ? entry.catalogId : entry.id))
    {
        message = "This template is already on this computer.";
        return false;
    }
    ExtensionEntry stored = entry;
    if (stored.catalogId.length == 0)
        stored.catalogId = stored.id;
    entries ~= stored;
    saveLocalCatalog(catalogPath, entries);
    message = "Saved the link. The template text stays in the repository.";
    return true;
}

string localTemplatePath(string codeRoot, ExtensionEntry e)
{
    if (codeRoot.length == 0 || e.repositoryOwner.length == 0 || e.repositoryName.length == 0 || e.manifestPath.length == 0)
        return "";
    return buildNormalizedPath(codeRoot, "github.com", e.repositoryOwner, e.repositoryName, e.manifestPath);
}

string readLocalTemplate(string codeRoot, ExtensionEntry e)
{
    string path = localTemplatePath(codeRoot, e);
    if (path.length == 0 || !exists(path))
        return "";
    try
        return readText(path);
    catch (Exception)
        return "";
}

ExtensionEntry[] filterEntries(ExtensionEntry[] entries, string typeFilter, string query)
{
    import std.uni : toLower;
    string q = query.toLower;
    string kind = typeFilter.toLower;
    ExtensionEntry[] out_;
    foreach (e; entries)
    {
        if (kind.length && kind != "all" && e.type.toLower != kind)
            continue;
        if (q.length)
        {
            string hay = (e.name ~ " " ~ e.description ~ " " ~ e.id ~ " " ~ e.repository ~ " " ~ e.catalogId).toLower;
            foreach (t; e.tags)
                hay ~= " " ~ t.toLower;
            if (!hay.canFind(q))
                continue;
        }
        out_ ~= e;
    }
    return out_;
}

unittest
{
    import std.file : rmdirRecurse, tempDir;
    import std.uuid : randomUUID;

    auto dir = buildPath(tempDir(), "devcentr-ext-" ~ randomUUID().toString());
    scope (exit)
    {
        if (exists(dir))
            rmdirRecurse(dir);
    }
    string path = buildPath(dir, "catalog.json");
    auto seeded = loadOrSeed(path);
    assert(seeded.length == 1);
    assert(seeded[0].id == "docs-default");
    assert(seeded[0].install.pointer.canFind("templates/docs-default.md"));
    string raw = readText(path);
    assert(raw.canFind("pointer"));
    assert(!raw.canFind(`"content"`));

    string msg;
    assert(!installPointer(path, docsDefaultEntry(), msg));
    assert(msg.canFind("already"));

    ExtensionEntry extra = docsDefaultEntry();
    extra.id = "other";
    extra.catalogId = "dev-centr/agent-rules/other";
    extra.name = "Other template";
    extra.install.pointer = "https://example.com/other.md";
    assert(installPointer(path, extra, msg));
    auto again = loadLocalCatalog(path);
    assert(again.length == 2);
    assert(again[1].install.pointer == "https://example.com/other.md");
    assert(!readText(path).canFind("Diátaxis"));

    auto found = filterEntries(again, rulesTemplateType, "other");
    assert(found.length == 1);
    assert(filterEntries(again, "ui-module", "").length == 0);
    assert(filterEntries(again, "all", "no-such-template").length == 0);
}
