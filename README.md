# PropBean

PropBean is a small, playful workspace for embedded flight-computing work.

The first target is the PowerFin RK3506 platform. PropBean owns its development tooling, validation, experiments, and project-specific code; upstream vendor SDKs remain external dependencies.

## PowerFin development environment

The supported bring-up path is Linux or WSL Linux. From a fresh clone:

```bash
./tools/setup/powerfin/bootstrap.sh
source ./tools/setup/powerfin/activate.sh
./tools/setup/powerfin/check-env.sh
```

The bootstrap flow keeps the upstream PowerFin SDK under `third_party/`, installs project-local compatibility tools under `.tools/`, and records the resolved multi-repository manifest under `.state/`.

It does not fork, vendor, or convert the upstream SDK into Git submodules.

See [tools/setup/powerfin/README.md](tools/setup/powerfin/README.md) for the environment policy and workflow.

## Repository direction

```text
propbean/
├─ docs/                      # durable architecture and platform notes
├─ experiments/               # bounded investigations and measurements
├─ platforms/                 # PropBean-owned platform-specific work
├─ third_party/               # external SDK workspaces; ignored by Git
└─ tools/
   └─ setup/
      └─ powerfin/            # reproducible PowerFin host environment
```

The repository starts with environment reproducibility before custom firmware or BSP changes.
