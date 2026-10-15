# Run the tests

The tests build a small environment from `test/packages.nix` in a `nixos/nix`
container, then run the bats tests in `test/test/`. They check that each shell
loads its config from `config/`, that `PATH` and the CA bundle are set, and how
portable export behaves, including failure and recovery.

```bash
docker build -f test/Dockerfile .
```

CI runs the same build on every pull request.
