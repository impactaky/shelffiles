# Use it in a devcontainer without leaking it into the project

Mount the checkout into the container. To keep that line out of the project's
commits, use a Git filter that drops lines containing `shelffiles`.

1. Export the checkout, because the container has no `/nix`
   ([Portable export](carry.md#portable); on a Mac,
   [Export in a container](carry.md#container)).
2. Install the filter (from `example/config/git/`):
   ```
   # config/git/attributes
   devcontainer.json filter=devcontainer

   # config/git/config
   [filter "devcontainer"]
   smudge = cat
   clean = sed "/shelffiles/d"
   ```
3. Add the mount to `devcontainer.json`:
   ```jsonc
   "mounts": [
     "source=${localWorkspaceFolder}/shelffiles,target=/home/vscode/shelffiles,type=bind"
   ]
   ```
4. Inside the container, enter with `~/shelffiles/portable/entrypoint/zsh`.

The host and the container can share the same checkout safely
([why](how-it-works.md#xdg)).
