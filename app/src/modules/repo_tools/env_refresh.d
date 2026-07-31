module modules.repo_tools.env_refresh;

import std.array : replace;
import std.conv : to;
import std.digest : toHexString;
import std.digest.sha : sha1Of;
import std.file : exists, timeLastModified;
import std.path : buildPath;
import std.process : environment, execute;
import std.string : strip, toLower;

/// Interactive / worker shells the repo terminal can target.
enum TerminalShell
{
    nushell,
    powershell,
    cmd,
    bash,
    zsh,
    fish,
    sh
}

/// Resolved refresh action for the UI (preview + optional run).
struct EnvRefreshPlan
{
    TerminalShell shell;
    string shellLabel; /// Short label for chrome, e.g. "nushell"
    string command; /// Exact command to inject / run
    bool usesEnvRefreshCli; /// True when OpenShellOrg env-refresh is preferred
    string sourceNote; /// Why this recipe was chosen
}

bool commandOnPath(string name)
{
    if (name.length == 0)
        return false;
    version (Windows)
        enum probe = "where";
    else
        enum probe = "which";
    try
    {
        auto result = execute([probe, name]);
        return result.status == 0 && result.output.strip.length > 0;
    }
    catch (Exception)
    {
        return false;
    }
}

bool shellHostOnPath()
{
    return commandOnPath("shell-host");
}

bool envRefreshCliOnPath()
{
    return commandOnPath("env-refresh");
}

string terminalShellLabel(TerminalShell shell)
{
    final switch (shell)
    {
    case TerminalShell.nushell:
        return "nushell";
    case TerminalShell.powershell:
        return "powershell";
    case TerminalShell.cmd:
        return "cmd";
    case TerminalShell.bash:
        return "bash";
    case TerminalShell.zsh:
        return "zsh";
    case TerminalShell.fish:
        return "fish";
    case TerminalShell.sh:
        return "sh";
    }
}

private ptrdiff_t lastIndexOfChar(string s, char ch)
{
    foreach_reverse (i, c; s)
        if (c == ch)
            return cast(ptrdiff_t) i;
    return -1;
}

/// Parse persisted preference: auto | nushell | powershell | cmd | bash | zsh | fish | sh
TerminalShell resolveTerminalShell(string preference)
{
    auto pref = preference.strip.toLower;
    if (pref == "nushell" || pref == "nu")
        return TerminalShell.nushell;
    if (pref == "powershell" || pref == "pwsh")
        return TerminalShell.powershell;
    if (pref == "cmd")
        return TerminalShell.cmd;
    if (pref == "bash")
        return TerminalShell.bash;
    if (pref == "zsh")
        return TerminalShell.zsh;
    if (pref == "fish")
        return TerminalShell.fish;
    if (pref == "sh")
        return TerminalShell.sh;

    // auto
    if (commandOnPath("nu"))
        return TerminalShell.nushell;
    version (Windows)
    {
        if (commandOnPath("pwsh") || commandOnPath("powershell"))
            return TerminalShell.powershell;
        return TerminalShell.cmd;
    }
    else
    {
        auto shellEnv = environment.get("SHELL", "");
        auto base = shellEnv;
        auto slash = lastIndexOfChar(shellEnv, '/');
        if (slash >= 0 && slash + 1 < cast(ptrdiff_t) shellEnv.length)
            base = shellEnv[slash + 1 .. $];
        auto b = base.toLower;
        if (b == "zsh")
            return TerminalShell.zsh;
        if (b == "fish")
            return TerminalShell.fish;
        if (b == "bash")
            return TerminalShell.bash;
        if (b == "nu" || b == "nushell")
            return TerminalShell.nushell;
        return TerminalShell.sh;
    }
}

string builtinRefreshCommand(TerminalShell shell)
{
    final switch (shell)
    {
    case TerminalShell.nushell:
        version (Windows)
            return `$env.Path = ((^powershell -NoLogo -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')") | str trim)`;
        else
            return `exec nu -l`;
    case TerminalShell.powershell:
        return `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")`;
    case TerminalShell.cmd:
        return `for /f "tokens=*" %A in ('powershell -NoLogo -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"') do set "PATH=%A"`;
    case TerminalShell.bash:
    case TerminalShell.zsh:
        return `export PATH="$(/usr/bin/env -i HOME="$HOME" USER="$USER" /bin/bash --login -c 'printf %s "$PATH"' 2>/dev/null || printf %s "$PATH")"`;
    case TerminalShell.fish:
        return `set -gx PATH (string split : (bash --login -c 'echo $PATH'))`;
    case TerminalShell.sh:
        return `exec $SHELL -l`;
    }
}

EnvRefreshPlan planEnvRefresh(string shellPreference = "auto")
{
    EnvRefreshPlan plan;
    plan.shell = resolveTerminalShell(shellPreference);
    plan.shellLabel = terminalShellLabel(plan.shell);

    if (envRefreshCliOnPath())
    {
        plan.command = "env-refresh";
        plan.usesEnvRefreshCli = true;
        plan.sourceNote = "OpenShellOrg env-refresh on PATH";
        return plan;
    }

    plan.command = builtinRefreshCommand(plan.shell);
    plan.usesEnvRefreshCli = false;
    plan.sourceNote = "built-in " ~ plan.shellLabel ~ " recipe";
    return plan;
}

/// argv for running a user command in the session shell (cwd set by pipeProcess workDir).
string[] shellInvokeArgs(TerminalShell shell, string command)
{
    final switch (shell)
    {
    case TerminalShell.nushell:
        return ["nu", "-c", command];
    case TerminalShell.powershell:
        if (commandOnPath("pwsh"))
            return ["pwsh", "-NoLogo", "-NoProfile", "-Command", command];
        return ["powershell", "-NoLogo", "-NoProfile", "-Command", command];
    case TerminalShell.cmd:
        return ["cmd", "/C", command];
    case TerminalShell.bash:
        return ["bash", "-lc", command];
    case TerminalShell.zsh:
        return ["zsh", "-lc", command];
    case TerminalShell.fish:
        return ["fish", "-lc", command];
    case TerminalShell.sh:
        return ["sh", "-lc", command];
    }
}

/// Fingerprint of OS-stored PATH (and a few peers) for drift detection.
string osEnvFingerprint()
{
    version (Windows)
    {
        try
        {
            auto r = execute([
                "powershell", "-NoLogo", "-NoProfile", "-Command",
                "[Environment]::GetEnvironmentVariable('Path','Machine') + '|' + " ~
                "[Environment]::GetEnvironmentVariable('Path','User') + '|' + " ~
                "[Environment]::GetEnvironmentVariable('PATHEXT','Machine') + '|' + " ~
                "[Environment]::GetEnvironmentVariable('PATHEXT','User')"
            ]);
            if (r.status == 0)
                return toHexString(sha1Of(r.output.strip)).idup;
        }
        catch (Exception) { }
        return toHexString(sha1Of(environment.get("PATH", "") ~ "|" ~ environment.get("Path", ""))).idup;
    }
    else
    {
        string blob = environment.get("PATH", "");
        foreach (p; [
                "/etc/paths",
                "/etc/environment",
                buildPath(environment.get("HOME", ""), ".profile"),
                buildPath(environment.get("HOME", ""), ".zprofile"),
                buildPath(environment.get("HOME", ""), ".bash_profile"),
                buildPath(environment.get("HOME", ""), ".config/nushell/env.nu"),
            ])
        {
            if (exists(p))
            {
                try
                    blob ~= "|" ~ p ~ "=" ~ to!string(timeLastModified(p).stdTime);
                catch (Exception) { }
            }
        }
        return toHexString(sha1Of(blob)).idup;
    }
}

/// External terminal launcher argv. Prefer OpenShellOrg shell-host when present.
string[] externalTerminalArgs(string repoRoot, string shellPreference = "auto")
{
    auto shell = resolveTerminalShell(shellPreference);
    if (shellHostOnPath())
    {
        version (Windows)
            return ["cmd", "/c", "start", "\"\"", "shell-host", "--cwd", repoRoot];
        else
            return ["shell-host", "--cwd", repoRoot];
    }

    version (Windows)
    {
        final switch (shell)
        {
        case TerminalShell.nushell:
            return ["cmd", "/c", "start", "\"\"", "nu", "-c",
                "cd '" ~ repoRoot.replace("'", "''") ~ "'; exec nu"];
        case TerminalShell.powershell:
            auto ps = commandOnPath("pwsh") ? "pwsh" : "powershell";
            return ["cmd", "/c", "start", "\"\"", ps, "-NoExit", "-Command",
                "Set-Location \"" ~ repoRoot ~ "\""];
        case TerminalShell.cmd:
            return ["cmd", "/c", "start", "\"\"", "cmd", "/K", "cd /d \"" ~ repoRoot ~ "\""];
        case TerminalShell.bash:
        case TerminalShell.zsh:
        case TerminalShell.fish:
        case TerminalShell.sh:
            auto ps = commandOnPath("pwsh") ? "pwsh" : "powershell";
            return ["cmd", "/c", "start", "\"\"", ps, "-NoExit", "-Command",
                "Set-Location \"" ~ repoRoot ~ "\""];
        }
    }
    else
    {
        final switch (shell)
        {
        case TerminalShell.nushell:
            return ["sh", "-lc", "cd \"" ~ repoRoot ~ "\"; exec nu -l"];
        case TerminalShell.powershell:
            return ["sh", "-lc", "cd \"" ~ repoRoot ~ "\"; exec pwsh -NoExit"];
        case TerminalShell.cmd:
            return ["sh", "-lc", "cd \"" ~ repoRoot ~ "\"; exec $SHELL -l"];
        case TerminalShell.bash:
            return ["sh", "-lc", "cd \"" ~ repoRoot ~ "\"; exec bash -l"];
        case TerminalShell.zsh:
            return ["sh", "-lc", "cd \"" ~ repoRoot ~ "\"; exec zsh -l"];
        case TerminalShell.fish:
            return ["sh", "-lc", "cd \"" ~ repoRoot ~ "\"; exec fish -l"];
        case TerminalShell.sh:
            return ["sh", "-lc", "cd \"" ~ repoRoot ~ "\"; exec $SHELL -l"];
        }
    }
}
