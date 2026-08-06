module modules.content_create.create;

import modules.content_create.model;
import modules.repo_tools.editor_detector : detectInstalledEditors, openPathWithEditor;
import std.file : exists, write;
import std.path : buildPath;
import std.string : format;

/// Resolve a non-colliding path under repoRoot.
string resolveCreatePath(string repoRoot, ContentTypeNode node)
{
    auto base = node.suggestedName.length ? node.suggestedName : node.id;
    auto ext = node.extension;
    auto path = buildPath(repoRoot, base ~ ext);
    if (!exists(path))
        return path;
    foreach (i; 2 .. 100)
    {
        auto alt = buildPath(repoRoot, format("%s-%s%s", base, i, ext));
        if (!exists(alt))
            return alt;
    }
    return buildPath(repoRoot, format("%s-new%s", base, ext));
}

/// Write stub file; optionally open in first detected editor. Returns path written.
string createContentStub(string repoRoot, ContentTypeNode node, out string error)
{
    error = "";
    if (!node.creatable || node.extension.length == 0)
    {
        error = "Selected type is not creatable.";
        return "";
    }
    if (repoRoot.length == 0 || !exists(repoRoot))
    {
        error = "Repository path is missing.";
        return "";
    }
    auto path = resolveCreatePath(repoRoot, node);
    try
    {
        auto body = node.templateBody;
        write(path, body);
    }
    catch (Exception e)
    {
        error = e.msg;
        return "";
    }
    auto editors = detectInstalledEditors();
    if (editors.length > 0)
        openPathWithEditor(editors[0], path);
    return path;
}
