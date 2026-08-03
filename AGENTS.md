# Agent notes — devcentr

## DUB packages

- `repo-get` is on the DUB registry (`~>0.2.1`); GitHub webhook on `dlang-supplemental/repo-get` keeps it synced. Prefer registry over git pins in dependents.
- `arsd-official` for Dev Center is **11.5.3** (matches dlangui). Do not `dub add-local` `.forks/arsd` as 10.9.10.
- Intentional local package: `unit-threaded` 0.7.55 → `devcentr/unit-threaded` via `dub add-local`.
- Do not recreate deprecated `%LOCALAPPDATA%\dub\packages\local-overrides.json`; prefer `dub add-local`.
