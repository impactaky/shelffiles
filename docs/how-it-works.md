# How it works

Shelffiles exists to let you carry one environment everywhere without touching
the host. Three ideas make that possible.

<a id="nix"></a>

## 1. Nix makes the environment independent of the host

Tools are built with Nix. A Nix package carries all of its dependencies under
`/nix/store` and does not use host libraries, so the same `packages.nix` gives
the same tools whatever the host distribution or version.

`nix build` collects every package in `packages.nix` into one environment and
points the `result` link at it. The entrypoint puts `result/bin` at the start of
`PATH`.

<a id="xdg"></a>

## 2. XDG paths confine everything to one directory

The XDG Base Directory variables (`XDG_CONFIG_HOME` and others) decide where
programs keep config, cache, data and state. The entrypoint points them into the
checkout (`config/`, `cache/`, `share/`, `state/`) before it starts your shell,
so XDG-aware programs never write outside it.

Programs that ignore XDG are pointed into the checkout from
[`user_env.sh`](user-env.md). When you leave the shell, nothing remains on the
host.

`cache/`, `share/` and `state/` are namespaced as `<path>_<uid>_<gid>`. One
checkout can therefore be mounted into a host and several containers at once
without collisions.

<a id="relocate"></a>

## 3. Keep Nix's prebuilt packages, rewrite `/nix/store` to a same-length path

Ideas 1 and 2 still need `/nix/store`, because Nix-built programs embed absolute
`/nix/store/...` paths. On a machine without root, or where Nix cannot be
installed, `/nix` cannot be created.

Nix can use a different store location, but then the official prebuilt packages
(the binary cache) no longer apply and everything must be rebuilt from source.

So shelffiles makes **a copy of the prebuilt files in which every `/nix/store`
string is replaced by a 10-character `/tmp/xxxxx`**. This is the portable
export, `utils/create_portable.sh`.

- **Why the same length:** if the string length does not change, nothing after it
  in a binary moves, so the files can be patched without rebuilding.
- **Why `/tmp`:** anyone can write there without root. At startup,
  `portable/entrypoint/*` creates a symlink `/tmp/xxxxx` →
  `<checkout>/portable/nix/store`, so the embedded paths lead into the checkout.

You keep Nix's prebuilt packages and can carry the checkout to Linux machines
that have no `/nix`.

### When Nix is available

On a machine where Nix can be installed, idea 3 is not needed: `./setup.sh`
installs Nix, which creates a real `/nix`.
