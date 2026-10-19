# Shelffiles

Shelffiles keeps your working environment, meaning command-line tools and their
configuration, inside one directory. You can carry that directory to any Linux
or macOS machine or container. Entering it does not modify the host or your
`$HOME`, and it works even where you have no root.

|                | Manages           | Where it lives                |
|----------------|-------------------|-------------------------------|
| home-manager   | packages + config | rewrites `$HOME`              |
| chezmoi / stow | config only       | links into `$HOME`            |
| **shelffiles** | packages + config | **only inside this checkout** |

## How it works (in three lines)

1. **Nix makes the environment independent of the host.**
2. **XDG paths confine config, cache and state to the checkout.**
3. **Nix's prebuilt `/nix/store` is rewritten to a same-length `/tmp/xxxxx`, so it runs on machines without `/nix`.**

More: [How it works](docs/how-it-works.md)

## What do you want to do?

**Get started**
- Try shelffiles on your machine → [Getting started](docs/start.md)

**Grow your environment**
- Add or remove packages → [Packages](docs/packages.md)
- Manage your dotfiles here → [Configuration](docs/config.md)
- Apply machine-specific settings → [Per-machine settings](docs/user-env.md)
- Keep your own fork and follow upstream → [Forking](docs/forking.md)

**Bring it somewhere else** → details in [Carrying shelffiles](docs/carry.md)

| Where you want to run                   | How                                                      |
|-----------------------------------------|----------------------------------------------------------|
| Linux or macOS where Nix can be installed | `./setup.sh`                                           |
| Linux without root or without Nix       | build on a Linux machine with Nix, then portable export  |
| Linux container on a macOS host         | build and export in a `nixos/nix` container              |

- Use it in a devcontainer without leaking it into the project → [Devcontainer](docs/devcontainer.md)

**Maintain**
- Run the tests → [Testing](docs/testing.md)

Reference: [Directory layout, variables and portable export](docs/reference.md)
