# Apply machine-specific settings

`user_env.sh` at the checkout root is sourced every time you enter. Git ignores
it, so it is the place for settings that differ per machine or must not be
committed.

```bash
cp example/user_env.sh user_env.sh
```

Typical uses:

- point programs that ignore XDG into the checkout
  (`export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"`)
- machine-local proxies, tokens, or `PATH` additions such as your own scripts
