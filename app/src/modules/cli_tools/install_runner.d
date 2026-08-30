module modules.cli_tools.install_runner;

import std.file : exists, mkdirRecurse, append;
import std.path : buildPath, dirName;
import std.datetime : Clock;
import modules.util.proc : execute = executeRetry;
import std.format : format;
import std.array : replace;
import modules.cli_tools.model;

struct InstallAuditResult {
    bool success;
    string auditLogPath;
    string output;
}

InstallAuditResult runInteractiveInstall(
    string dataRoot,
    string toolId,
    string toolName,
    const ref CliToolInstallMethod method,
    string verifyCommand
) {
    InstallAuditResult result;
    auto auditDir = buildPath(dataRoot, "install-audit");
    if (!exists(auditDir))
        mkdirRecurse(auditDir);

    auto stamp = Clock.currTime().toISOExtString().replace(":", "-").replace(".", "-");
    result.auditLogPath = buildPath(auditDir, format("%s_%s.log", toolId, stamp));

    string header = format(
        "tool=%s\nname=%s\ncontext=%s\nmutable=%s\ncommand=%s\nstarted=%s\n---\n",
        toolId, toolName, method.context,
        method.mutableInstall ? "yes" : "no",
        method.command,
        Clock.currTime().toISOExtString()
    );
    if (method.auditNote.length)
        header ~= "note=" ~ method.auditNote ~ "\n";

    append(result.auditLogPath, header);

    version (Windows) {
        auto r = execute(["cmd", "/c", method.command]);
        result.output = r.output;
        append(result.auditLogPath, result.output ~ "\n");
        result.success = r.status == 0;
    } else {
        auto r = execute(["sh", "-c", method.command]);
        result.output = r.output;
        append(result.auditLogPath, result.output ~ "\n");
        result.success = r.status == 0;
    }

    if (result.success && verifyCommand.length > 0) {
        version (Windows) {
            auto vr = execute(["cmd", "/c", verifyCommand]);
            if (vr.status != 0) {
                append(result.auditLogPath, "verify failed: " ~ verifyCommand ~ "\n");
                result.success = false;
            }
        } else {
            auto vr = execute(["sh", "-c", verifyCommand]);
            if (vr.status != 0) {
                append(result.auditLogPath, "verify failed: " ~ verifyCommand ~ "\n");
                result.success = false;
            }
        }
    }

    append(result.auditLogPath, format("finished=%s success=%s\n",
        Clock.currTime().toISOExtString(), result.success ? "yes" : "no"));
    return result;
}
