/// Compile toolchain-advisor SDL catalog to JSON (for web bundle / validation).
module compile_catalog;

import std.file : write, exists;
import std.stdio;
import std.path : buildPath, dirName;
import modules.toolchain_advisor.sdl_parser;
import modules.toolchain_advisor.model;

int main(string[] args)
{
    string sdlPath = args.length > 1 ? args[1] : buildPath("..", "..", "toolchain-advisor", "catalog", "advisor.sdl");
    string outPath = args.length > 2 ? args[2] : buildPath(dirName(sdlPath), "advisor.json");

    if (!exists(sdlPath))
    {
        stderr.writeln("SDL not found: ", sdlPath);
        return 1;
    }

    auto catalog = loadAdvisorCatalogFromSdl(sdlPath);
    if (catalog.steps.length == 0)
    {
        stderr.writeln("No steps parsed from ", sdlPath);
        return 1;
    }

    write(outPath, advisorCatalogToJson(catalog));
    writeln("Wrote ", outPath, " (", catalog.steps.length, " steps, ", catalog.recommendations.length, " rules)");
    return 0;
}
