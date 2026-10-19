# Carrying shelffiles to another machine

Pick the row that matches where you want to run. Why there are several ways:
[How it works § 3](how-it-works.md#relocate).

| Where you want to run                     | Section                               |
|-------------------------------------------|---------------------------------------|
| Linux or macOS where Nix can be installed | [With Nix](#with-nix)                 |
| Linux without root or without Nix         | [Portable export](#portable)          |
| Linux container on a macOS host           | [Export in a container](#container)   |

<a id="with-nix"></a>

## With Nix

Same as [Getting started](start.md): clone, `./setup.sh`, enter.

<a id="portable"></a>

## Portable export

1. On a Linux machine with Nix, build normally:
   ```bash
   nix build
   ```
2. Export, choosing a prefix of the form `/tmp/` + 5 letters or digits:
   ```bash
   SHELFFILES_PORTABLE_PREFIX=/tmp/ab12c ./utils/create_portable.sh
   ```
   The prefix is saved in `config/shelffiles.conf`, so later runs need only
   `./utils/create_portable.sh`.
3. Copy or mount the whole checkout on the target, and enter:
   ```bash
   ./portable/entrypoint/zsh     # or bash, fish
   ```

Limits:

- Linux only, and the target must have the same CPU architecture.
- The copy is for running tools, not for Nix operations such as `nix build`.
- If `/tmp/ab12c` already exists on the target as something else, the
  entrypoint stops with exit status 73. Remove it, or export with another prefix.

Details: [Reference § Portable export](reference.md#portable).

<a id="container"></a>

## Export in a container

A container started from a macOS host runs Linux, so it needs a Linux build.
Build and export it in a `nixos/nix` container, from the checkout on the Mac:

```bash
docker run --rm -v "$PWD:$PWD" -w "$PWD" nixos/nix sh -c '
  git config --global --add safe.directory "$PWD" &&
  nix --extra-experimental-features "nix-command flakes" build &&
  SHELFFILES_PORTABLE_PREFIX=/tmp/ab12c \
    nix --extra-experimental-features "nix-command flakes" \
    shell nixpkgs#gnused -c utils/create_portable.sh'
```

- `safe.directory` lets Git in the container read a checkout owned by your user.
- `nix shell nixpkgs#gnused` supplies `sed`, which the `nixos/nix` image lacks.

Then mount the checkout into any Linux container and enter with
`portable/entrypoint/zsh`. See [Devcontainer](devcontainer.md) for a mount
example.

The container build replaces `result` with a Linux build. If you also use
shelffiles directly on the Mac, run `nix build` on the Mac again afterwards.
The export in `portable/` is not affected.
