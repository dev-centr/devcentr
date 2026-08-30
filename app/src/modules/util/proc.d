/// Subprocess helpers that survive interrupted syscalls.
///
/// On POSIX a SIGCHLD handler installed without SA_RESTART makes the pipe reads
/// inside std.process.execute/executeShell fail with EINTR ("Interrupted system
/// call"). Third-party libraries linked into the app install such a handler, so
/// every capturing subprocess call has to tolerate it. These wrappers keep the
/// signatures of their std.process counterparts, so call sites can pick them up
/// with a renamed import:
///
///     import modules.util.proc : execute = executeRetry;
module modules.util.proc;

import std.process : Config, execute_ = execute, executeShell_ = executeShell;
import std.exception : ErrnoException;
import std.typecons : Tuple;

private enum maxAttempts = 8;

alias ProcessResult = Tuple!(int, "status", string, "output");

/// std.process.execute that retries when the output pipe read is interrupted.
ProcessResult executeRetry(scope const(char[])[] args,
                           const string[string] env = null,
                           Config config = Config.none,
                           size_t maxOutput = size_t.max,
                           scope const(char)[] workDir = null) {
    foreach (attempt; 0 .. maxAttempts) {
        try
            return execute_(args, env, config, maxOutput, workDir);
        catch (ErrnoException e) {
            if (attempt + 1 == maxAttempts)
                return ProcessResult(-1, "");
        }
    }
    assert(0);
}

/// std.process.executeShell that retries when the output pipe read is interrupted.
ProcessResult executeShellRetry(scope const(char)[] command,
                                const string[string] env = null,
                                Config config = Config.none,
                                size_t maxOutput = size_t.max,
                                scope const(char)[] workDir = null,
                                string shellPath = null) {
    foreach (attempt; 0 .. maxAttempts) {
        try {
            if (shellPath is null)
                return executeShell_(command, env, config, maxOutput, workDir);
            return executeShell_(command, env, config, maxOutput, workDir, shellPath);
        } catch (ErrnoException e) {
            if (attempt + 1 == maxAttempts)
                return ProcessResult(-1, "");
        }
    }
    assert(0);
}
