# Getting started

This takes you from nothing to a shell inside shelffiles, on a Linux or macOS
machine where you can install Nix. For other machines, see
[Carrying shelffiles](carry.md).

1. Clone and enter the checkout:
   ```bash
   git clone https://github.com/impactaky/shelffiles.git
   cd shelffiles
   ```
2. Create your package list from the example. The build reads only files that
   Git tracks, so add it:
   ```bash
   cp example/packages.nix packages.nix
   git add packages.nix
   ```
3. Install Nix if needed, and build:
   ```bash
   ./setup.sh
   ```
4. Enter:
   ```bash
   ./entrypoint/zsh     # or bash, fish
   ```

Check that you are inside:

```bash
echo $XDG_CONFIG_HOME   # → <checkout>/config
```

Type `exit` to leave. Nothing was written outside the checkout except `/nix`
([why](how-it-works.md#relocate)).

Next: [add your packages](packages.md).
