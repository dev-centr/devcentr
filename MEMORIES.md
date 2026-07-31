# MEMORIES

Durable facts about this machine / environment for AI agents. Increment the usage counter when you rely on a fact.

## DUB / packages

* (1) `%LOCALAPPDATA%\dub\packages\local-overrides.json` was removed on 2026-07-26 (stale `repo-get` override). Prefer `dub add-local` over recreating that deprecated file.
* (1) `repo-get` is on the DUB registry (`~>0.2.1`, https://code.dlang.org/packages/repo-get). GitHub update webhook on `dlang-supplemental/repo-get` keeps it synced. Prefer registry over git pins in dependents (e.g. `equivalence-engine`).
* (1) `arsd-official` for Dev Center is **11.5.3** (matches dlangui). Do not `dub add-local` `.forks/arsd` as 10.9.10 — that reintroduces the version mismatch warning.
* (1) Intentional local package: `unit-threaded` 0.7.55 → `devcentr/unit-threaded` via `dub add-local`.
