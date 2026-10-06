# External source workspaces

This directory is reserved for upstream SDK/source checkouts provisioned by PropBean tooling.

The initial PowerFin environment uses:

```text
third_party/powerfin-sdk/
```

That directory is intentionally ignored by PropBean Git. The PowerFin SDK remains an upstream multi-repository workspace managed by its own `repo` manifest; it is not vendored, forked, or represented as a PropBean Git submodule.

Use `tools/setup/powerfin/bootstrap.sh` to create or update the managed workspace.
