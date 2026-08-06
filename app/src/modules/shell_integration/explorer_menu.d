module modules.shell_integration.explorer_menu;

import std.array : join;
import std.file : thisExePath;
import std.process : executeShell;
import std.string : replace;

version (Windows)
{
    private string regQuote(string s)
    {
        return s.replace("\"", "\\\"");
    }

    private string cascadeRoot(string classKey)
    {
        return `HKCU\Software\Classes\` ~ classKey ~ `\shell\DevCentr`;
    }

    /// Install cascading DevCentr menu on Directory and Directory\Background.
    string installExplorerMenu()
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

            auto op = root ~ `\shell\03open`;
            run(`reg add "` ~ op ~ `" /ve /d "Open folder in DevCentr" /f`);
            run(`reg add "` ~ op ~ `\command" /ve /d "\"` ~ regQuote(exe)
                ~ `\" --mode=open --path=` ~ pathArg ~ `" /f`);
        }
        if (errors.length)
            return "Installed with warnings:\n" ~ errors.join("\n");
        return "Explorer DevCentr menu installed for folders (current user). Open a new Explorer window to see it.";
    }

    string uninstallExplorerMenu()
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
            return "Removed with messages:\n" ~ errors.join("\n");
        return "Explorer DevCentr menu removed.";
    }

    bool explorerMenuInstalled()
    {
        auto r = executeShell(`reg query "HKCU\Software\Classes\Directory\shell\DevCentr" /v MUIVerb`);
        return r.status == 0;
    }
}
else
{
    string installExplorerMenu()
    {
        return "Explorer integration is Windows-only.";
    }

    string uninstallExplorerMenu()
    {
        return "Explorer integration is Windows-only.";
    }

    bool explorerMenuInstalled()
    {
        return false;
    }
}
