module modules.uniconfig.launch;

import std.file : exists;
import std.path : baseName, extension;
import std.process : execute, spawnProcess;
import std.string : toLower, strip;

/// True when `uniconfig` resolves on PATH.
bool uniConfigOnPath()
{
    try
    {
        version (Windows)
            auto r = execute(["where", "uniconfig"]);
        else
            auto r = execute(["which", "uniconfig"]);
        return r.status == 0 && r.output.strip.length > 0;
    }
    catch (Exception)
    {
        return false;
    }
}

bool looksLikeConfigFile(string path)
{
    auto ext = extension(path).toLower;
    switch (ext)
    {
    case ".json", ".json5", ".yml", ".yaml", ".toml", ".ini", ".cfg", ".sdl", ".tfvars", ".hcl":
        return true;
    default:
        auto b = baseName(path).toLower;
        return b == ".gitconfig" || b == ".editorconfig" || b == "dub.sdl" || b == "gitconfig";
    }
}

/// Spawn the standalone UniConfig Config Panel. Returns false if the binary is missing.
bool openWithUniConfig(string path)
{
    if (!exists(path) || !uniConfigOnPath())
        return false;
    try
    {
        spawnProcess(["uniconfig", path]);
        return true;
    }
    catch (Exception)
    {
        return false;
    }
}
