# Keep your own fork and follow upstream

Keep personal content in the files that upstream does not change, and merge
upstream freely:

| Personal                  | Shared with upstream                                     |
|---------------------------|----------------------------------------------------------|
| `packages.nix`            | `flake.nix`, `entrypoint/`, `portable/entrypoint/`, `setup.sh`, `utils/` |
| `config/` (your dotfiles) | `example/`, `test/`, `docs/`                             |
| `user_env.sh` (untracked) |                                                          |

Upstream ships only `example/packages.nix`, so the `packages.nix` that your fork
commits never conflicts.
