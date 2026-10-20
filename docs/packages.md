# Add or remove packages

1. Edit `packages.nix`:
   ```nix
   pkgs: with pkgs; [
     git
     ripgrep
     neovim   # added
   ]
   ```
2. Rebuild:
   ```bash
   nix build
   ```

The new tool is available immediately, also in shells that are already inside
shelffiles, because `PATH` contains `result/bin` and `result` now points at the
new build ([why](how-it-works.md#nix)).

If you use a [portable export](carry.md#portable), run
`./utils/create_portable.sh` again after the rebuild. It copies only the
packages that changed.

Packages come from stable nixpkgs. Prefix `unstable.` for a newer version:

```nix
pkgs: with pkgs; [
  git
  unstable.neovim
]
```

To find package names, use <https://search.nixos.org/packages> or
`nix search nixpkgs <name>`.

> `packages.nix` must be tracked by Git (`git add packages.nix`). A flake build
> ignores untracked files and fails with "packages.nix does not exist".
