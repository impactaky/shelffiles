# Manage your dotfiles here

Put each program's configuration under `config/<program>/`, the same layout as
`~/.config`:

```bash
mkdir -p config/nvim
$EDITOR config/nvim/init.lua
```

Inside shelffiles, `XDG_CONFIG_HOME` is `config/`, so XDG-aware programs pick it
up ([why](how-it-works.md#xdg)). For programs that ignore XDG, point them at
`config/` from [user_env.sh](user-env.md).

`config/` is tracked by Git, so committing it is how you carry your settings.
