module modules.content_create.ecosystem_tags;

import modules.project_recognizer.recognizer;
import modules.project_recognizer.profiles_dir;
import std.algorithm : canFind, sort, uniq;
import std.array : array;
import std.file : exists;
import std.path : buildPath;
import std.string : toLower;

/// Stable vocabulary for Create… filter chips.
enum knownEcosystemTags = [
    "general", "js", "jvm", "java", "dotnet", "python", "rust", "go", "d", "cpp",
    "docs", "devops", "data"
];

string[] uniqueSorted(string[] tags)
{
    if (tags.length == 0)
        return tags;
    auto copy = tags.dup;
    copy.sort();
    return copy.uniq().array;
}

string[] tagsForStackName(string stackName)
{
    auto s = stackName.toLower();
    if (s.length == 0)
        return null;
    if (s.canFind("node") || s.canFind("react") || s.canFind("next") || s.canFind("vue")
            || s.canFind("npm") || s.canFind("pnpm") || s.canFind("typescript") || s == "js"
            || s.canFind("javascript") || s.canFind("bun"))
        return ["js"];
    if (s.canFind("python") || s.canFind("django") || s.canFind("flask") || s.canFind("fastapi"))
        return ["python"];
    if (s.canFind("java") || s.canFind("spring") || s.canFind("maven") || s.canFind("gradle")
            || s.canFind("kotlin"))
        return ["jvm", "java"];
    if (s.canFind("dotnet") || s.canFind(".net") || s.canFind("csharp") || s.canFind("c#"))
        return ["dotnet"];
    if (s.canFind("rust") || s.canFind("cargo"))
        return ["rust"];
    if (s == "go" || s.canFind("golang"))
        return ["go"];
    if (s == "d" || s.canFind("dlang") || s.canFind("dub"))
        return ["d"];
    if (s.canFind("c++") || s.canFind("cpp") || s.canFind("cmake"))
        return ["cpp"];
    if (s.canFind("docker") || s.canFind("kubernetes") || s.canFind("terraform")
            || s.canFind("opentofu") || s.canFind("github actions"))
        return ["devops"];
    if (s.canFind("docs") || s.canFind("antora") || s.canFind("sphinx") || s.canFind("mkdocs"))
        return ["docs"];
    return null;
}

string[] inferTagsFromFiles(string repoPath)
{
    string[] tags;
    if (repoPath.length == 0 || !exists(repoPath))
        return tags;

    void hit(string tag)
    {
        if (!tags.canFind(tag))
            tags ~= tag;
    }

    if (exists(buildPath(repoPath, "package.json")) || exists(buildPath(repoPath, "pnpm-lock.yaml"))
            || exists(buildPath(repoPath, "bun.lockb")) || exists(buildPath(repoPath, "tsconfig.json")))
        hit("js");
    if (exists(buildPath(repoPath, "Cargo.toml")))
        hit("rust");
    if (exists(buildPath(repoPath, "go.mod")))
        hit("go");
    if (exists(buildPath(repoPath, "dub.json")) || exists(buildPath(repoPath, "dub.sdl")))
        hit("d");
    if (exists(buildPath(repoPath, "pyproject.toml")) || exists(buildPath(repoPath, "requirements.txt"))
            || exists(buildPath(repoPath, "setup.py")))
        hit("python");
    if (exists(buildPath(repoPath, "pom.xml")) || exists(buildPath(repoPath, "build.gradle"))
            || exists(buildPath(repoPath, "build.gradle.kts")))
    {
        hit("jvm");
        hit("java");
    }
    if (exists(buildPath(repoPath, "CMakeLists.txt")) || exists(buildPath(repoPath, "meson.build")))
        hit("cpp");
    if (exists(buildPath(repoPath, "global.json")) || exists(buildPath(repoPath, "Directory.Build.props")))
        hit("dotnet");
    if (exists(buildPath(repoPath, "antora.yml")) || exists(buildPath(repoPath, "docs", "antora.yml")))
        hit("docs");
    if (exists(buildPath(repoPath, "docker-compose.yml")) || exists(buildPath(repoPath, "Dockerfile"))
            || exists(buildPath(repoPath, ".github", "workflows")))
        hit("devops");

    return tags;
}

string[] inferEcosystemTags(string repoPath, string[] stackNames = null)
{
    string[] tags = ["general"];
    void addAll(string[] more)
    {
        foreach (t; more)
            if (t.length && !tags.canFind(t))
                tags ~= t;
    }

    if (stackNames.length)
    {
        foreach (name; stackNames)
            addAll(tagsForStackName(name));
    }

    addAll(inferTagsFromFiles(repoPath));

    try
    {
        if (repoPath.length && exists(repoPath))
        {
            ViewOptions recogOpts;
            ProjectRecognizer recognizer;
            auto fromDub = findProjectMapStacksDir();
            if (fromDub.length)
                recognizer = ProjectRecognizer.fromProfilesDir(fromDub, recogOpts);
            if (recognizer is null)
                recognizer = new ProjectRecognizer(
                    [RecognitionRule("Generic", "General project", "", [], [], [], [], [])], recogOpts);
            auto scan = recognizer.recognize(repoPath, true);
            foreach (s; scan.techStacks)
                addAll(tagsForStackName(s.name));
        }
    }
    catch (Exception)
    {
    }

    return uniqueSorted(tags);
}

struct InferredTags
{
    string[] tags;
    string hint; /// inferred | default | cli
}

InferredTags resolveInitialTags(string repoPath, string[] cliTags)
{
    InferredTags r;
    if (cliTags.length)
    {
        r.tags = uniqueSorted(cliTags.dup);
        if (!r.tags.canFind("general"))
            r.tags = "general" ~ r.tags;
        r.hint = "cli";
        return r;
    }
    r.tags = inferEcosystemTags(repoPath);
    r.hint = (r.tags.length == 1 && r.tags[0] == "general") ? "default" : "inferred";
    return r;
}
