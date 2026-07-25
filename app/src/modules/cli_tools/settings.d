module modules.cli_tools.settings;

import std.file : exists, readText, write, mkdirRecurse;
import std.path : buildPath, dirName;
import std.json : JSONValue, parseJSON, JSONType;
import modules.cli_tools.cache : CliToolsCatalogCache;

struct CliToolsSettings {
    string definitionsRepoUrl = CliToolsCatalogCache.defaults.repoUrl;
    bool preferImmutable = true;
}

CliToolsSettings loadCliToolsSettings(string dataRoot) {
    auto path = buildPath(dataRoot, "cli-tools-settings.json");
    CliToolsSettings s;
    if (!exists(path))
        return s;
    try {
        auto j = parseJSON(readText(path));
        if ("definitionsRepoUrl" in j && j["definitionsRepoUrl"].type == JSONType.string)
            s.definitionsRepoUrl = j["definitionsRepoUrl"].str;
        if ("preferImmutable" in j) {
            if (j["preferImmutable"].type == JSONType.true_) s.preferImmutable = true;
            if (j["preferImmutable"].type == JSONType.false_) s.preferImmutable = false;
        }
    } catch (Exception) { }
    return s;
}

void saveCliToolsSettings(string dataRoot, CliToolsSettings s) {
    auto path = buildPath(dataRoot, "cli-tools-settings.json");
    auto dir = dirName(path);
    if (!exists(dir))
        mkdirRecurse(dir);
    JSONValue j;
    j["definitionsRepoUrl"] = JSONValue(s.definitionsRepoUrl);
    j["preferImmutable"] = JSONValue(s.preferImmutable);
    write(path, j.toPrettyString());
}
