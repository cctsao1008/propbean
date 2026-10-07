# PropBean

PropBean is an integration workspace for embedded flight-computing work on the PowerFin RK3506 platform.

The project keeps three concerns separate:

- **PropBean-owned code and documentation** live in this repository.
- **ArduPilot** is tracked as a Git submodule from the `propbean` integration branch of `cctsao1008/ardupilot`.
- **PowerFin SDK** remains an Android `repo`-managed vendor workspace provisioned under `third_party/`.

## Repository layout

```text
propbean/
├─ external/
│  └─ ardupilot/              # pinned Git submodule
├─ firmware/                  # PropBean-owned target-side code
├─ hardware/                  # PropBean-owned hardware definitions/designs
├─ examples/                  # small, runnable reference examples
├─ tools/                     # host-side setup/build/validation tooling
├─ docs/                      # architecture and verified platform knowledge
└─ third_party/
   └─ powerfin-sdk/           # repo-managed vendor SDK workspace; Git ignored
```

## ArduPilot

Clone with the pinned ArduPilot revision:

```bash
git clone --recurse-submodules https://github.com/cctsao1008/propbean.git
```

For an existing clone:

```bash
git submodule update --init --recursive
```

The ArduPilot fork uses:

```text
master    = upstream tracking
propbean  = PropBean / PowerFin integration
```

PropBean always records an exact submodule commit SHA for reproducibility. The branch name describes the development lineage; it does not replace commit pinning.

## PowerFin development environment

The supported bring-up path is Linux or WSL Linux:

```bash
./tools/setup/powerfin/bootstrap.sh
source ./tools/setup/powerfin/activate.sh
./tools/setup/powerfin/check-env.sh
```

The bootstrap flow keeps the upstream PowerFin SDK under `third_party/`, installs project-local compatibility tools under `.tools/`, and records the resolved multi-repository manifest under `.state/`.

It does not vendor or convert the PowerFin SDK's `repo`-managed components into Git submodules.

See [tools/setup/powerfin/README.md](tools/setup/powerfin/README.md) for the environment policy and workflow.

## Project rules

- Keep upstream-derived projects in `external/` or the PowerFin SDK workspace; do not copy them into `firmware/`.
- Keep generated images, binaries, logs, and build output out of Git.
- Add directories only when they have a clear owner and a concrete use.
- Record verified board observations separately from assumptions or planned work.
