# Reference

## Directory layout

| Path | What | Tracked |
|---|---|---|
| `flake.nix` | builds `packages.nix` (plus `cacert`) into one environment | yes |
| `packages.nix` | your package list | in your fork |
| `example/` | templates (`packages.nix`, `user_env.sh`, Git filter) | yes |
| `config/` | `XDG_CONFIG_HOME` | yes |
| `config/shelffiles.conf` | settings read on entry, such as the portable prefix | no¹ |
| `cache/`, `share/`, `state/` | XDG cache, data and state, namespaced per path, uid and gid | no |
| `user_env.sh` | per-machine settings, sourced on entry | no |
| `entrypoint/{bash,zsh,fish}` | enter the environment | yes |
| `entrypoint/env.sh` | environment setup shared by all entrypoints | yes |
| `portable/entrypoint/{bash,zsh,fish}` | enter the portable export | yes |
| `portable/nix/`, `portable/result` | the portable export | no |
| `setup.sh` | install Nix if needed, and build | yes |
| `utils/create_portable.sh` | create or update the portable export | yes |
| `result` | link to the built environment | no |
| `test/` | test environment and bats tests | yes |

¹ Not ignored by Git. Commit it only if the prefix should be the same on every
machine.

## Environment variables

| Variable | Set by | Meaning |
|---|---|---|
| `SHELFFILES` | entrypoint | absolute path of the checkout |
| `XDG_CONFIG_HOME` | entrypoint | `$SHELFFILES/config` |
| `XDG_CACHE_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME` | entrypoint | per path, uid and gid under the checkout |
| `PATH` | entrypoint | `result/bin` first; the portable entrypoint puts `portable/result/bin` before it |
| `SSL_CERT_FILE`, `NIX_SSL_CERT_FILE`, `SYSTEM_CERTIFICATE_PATH` | entrypoint | CA bundle from the build, unless already set to a non-empty value |
| `SHELFFILES_PORTABLE_PREFIX` | you | prefix for `utils/create_portable.sh` |

An ordinary entrypoint stops with exit status 1 if `result` is missing.

<a id="portable"></a>

## Portable export

### `utils/create_portable.sh [--force]`

Copies the closure of the existing `result` into `portable/nix/store`, replaces
every `/nix/store` in file contents and symlink targets with the prefix, and
points `portable/result` at the copy. It does not build, download, or write to
`/nix/store`.

Requirements: Linux, a `result` that resolves into `/nix/store`, `nix-store`
(on `PATH` or in `result/bin`), and common tools including `sed`, `grep` and
`find`.

### Prefix

- It must match `/tmp/[A-Za-z0-9]{5}`, which is 10 bytes, the same as
  `/nix/store`. There is no default.
- `SHELFFILES_PORTABLE_PREFIX` in the environment wins over
  `config/shelffiles.conf`, even when it is empty. An empty or invalid value
  fails; it never falls back.
- After a successful export, the prefix is saved in `config/shelffiles.conf` as
  a line marked `# managed by utils/create_portable.sh`. Other lines are kept.
  If saving fails, the export still succeeds with a warning.
- The prefix that was used is recorded in `portable/nix/runtime-prefix`.

### Updates

- With the same prefix, an export is incremental: store paths that are already
  copied are reused without a rescan, new paths are copied, and paths that are
  no longer needed are removed. The summary prints the counts.
- A different prefix, an incomplete earlier export, or `--force` rebuilds every
  path.
- Reused paths are not verified again. If you changed files under
  `portable/nix` by hand, run with `--force`.

### Failure and recovery

- Before `portable/result` is switched, any failure leaves the previous export
  usable.
- A full rebuild is prepared beside the active export and swapped in at the end.
  If the swap fails, the previous export is restored. An interrupted swap is
  recovered on the next run.
- Problems after the switch, such as failing to remove stale paths, are warnings.
  A later run retries them.

### `portable/entrypoint/{bash,zsh,fish}`

1. Loads the ordinary environment (`entrypoint/env.sh`).
2. Reads the prefix from `portable/nix/runtime-prefix`, ignoring the current
   environment and `config/shelffiles.conf`.
3. Creates the symlink `<prefix>` → `<checkout>/portable/nix/store`, or reuses
   it if it already points there.
4. Puts `portable/result/bin` at the start of `PATH`, points the CA variables at
   the exported bundle, and starts the shell.

| Situation | Result |
|---|---|
| `<prefix>` exists and is anything else | exit 73, nothing is changed |
| `portable/nix/store`, the metadata, or `portable/result` is missing or broken | exit 1 with a message |
