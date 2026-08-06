module modules.shell_integration.classic_registry;

version (Windows):

import std.array : join;
import std.file : thisExePath;
import std.process : executeShell;
import std.string : replace;

private string regQuote(string s)
{
    return s.replace("\"", "\\\"");
}

private string cascadeRoot(string classKey)
{
    return `HKCU\Software\Classes\` ~ classKey ~ `\shell\DevCentr`;
}

/// Classic cascading DevCentr menu (Win10 / Show more options).
string installClassicExplorerMenu()
{
    auto exe = thisExePath();
    string[] classKeys = [`Directory`, `Directory\Background`];
    string[] errors;
    foreach (ck; classKeys)
    {
        auto root = cascadeRoot(ck);
        auto pathArg = `"%V"`;

        void run(string cmd)
        {
            auto r = executeShell(cmd);
            if (r.status != 0)
                errors ~= cmd ~ " → " ~ r.output;
        }

        run(`reg add "` ~ root ~ `" /v MUIVerb /d "DevCentr" /f`);
        run(`reg add "` ~ root ~ `" /v SubCommands /d "" /f`);
        run(`reg add "` ~ root ~ `" /v Icon /d "` ~ regQuote(exe) ~ `" /f`);

        auto nf = root ~ `\shell\01newfile`;
        run(`reg add "` ~ nf ~ `" /ve /d "New File…" /f`);
        run(`reg add "` ~ nf ~ `\command" /ve /d "\"` ~ regQuote(exe)
            ~ `\" --mode=new-file --path=` ~ pathArg ~ `" /f`);

        auto np = root ~ `\shell\02newproject`;
        run(`reg add "` ~ np ~ `" /ve /d "New Project…" /f`);
        run(`reg add "` ~ np ~ `\command" /ve /d "\"` ~ regQuote(exe)
            ~ `\" --mode=new-project --path=` ~ pathArg ~ `" /f`);

        auto ni = root ~ `\shell\03newinstaller`;
        run(`reg add "` ~ ni ~ `" /ve /d "New Installer Project…" /f`);
        run(`reg add "` ~ ni ~ `\command" /ve /d "\"` ~ regQuote(exe)
            ~ `\" --mode=new-installer --path=` ~ pathArg ~ `" /f`);

        auto ip = root ~ `\shell\04inplacepath`;
        run(`reg add "` ~ ip ~ `" /ve /d "Install in-place (add to PATH)" /f`);
        run(`reg add "` ~ ip ~ `\command" /ve /d "\"` ~ regQuote(exe)
            ~ `\" --mode=inplace-path --path=` ~ pathArg ~ `" /f`);

        auto op = root ~ `\shell\05open`;
        run(`reg add "` ~ op ~ `" /ve /d "Open folder in DevCentr" /f`);
        run(`reg add "` ~ op ~ `\command" /ve /d "\"` ~ regQuote(exe)
            ~ `\" --mode=open --path=` ~ pathArg ~ `" /f`);
    }
    if (errors.length)
        return "Classic menu installed with warnings:\n" ~ errors.join("\n");
    return "Classic Explorer cascading menu installed (current user).";
}

string uninstallClassicExplorerMenu()
{
    string[] errors;
    foreach (ck; [`Directory`, `Directory\Background`])
    {
        auto root = cascadeRoot(ck);
        auto r = executeShell(`reg delete "` ~ root ~ `" /f`);
        if (r.status != 0 && r.output.length)
            errors ~= r.output;
    }
    if (errors.length)
        return "Classic removal messages:\n" ~ errors.join("\n");
    return "Classic Explorer menu removed.";
}

bool classicExplorerMenuInstalled()
{
    auto r = executeShell(`reg query "HKCU\Software\Classes\Directory\shell\DevCentr" /v MUIVerb`);
    return r.status == 0;
}
