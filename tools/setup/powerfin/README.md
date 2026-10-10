# PowerFin development environment

This directory owns PropBean's reproducible host-side setup for the upstream PowerFin RK3506 SDK.

The implementation takes `cctsao1008/pibbi` as a structural reference only. PowerFin is a Linux/Buildroot multi-repository SDK, so this setup is intentionally Linux-first and follows the PowerFin project's own `repo` manifest rather than reproducing pibbi's Windows/HX6538 toolchain model.

## Host requirement

These scripts require a Linux shell. On a Windows development machine, use WSL bash; do not invoke `bootstrap.sh`, `activate.sh`, or `check-env.sh` directly from PowerShell.

From PowerShell:

```powershell
wsl
```

Then work from the WSL shell. A checkout under the Linux filesystem, such as `~/src/propbean`, is preferred over `/mnt/c/*` or `/mnt/d/*` because Buildroot performs many filesystem operations.

## Baseline sources

The initial environment follows two upstream sources:

1. `HumpbackLab/powerfin_sdk` bootstrap documentation for the SDK clone and `repo init/sync` flow.
2. The upstream `powerfin-build.yml` workflow for the current Ubuntu host package set and its Python 2.7.18 compatibility step.

The upstream CI currently runs on Ubuntu 24.04. The scripts are also designed for WSL Linux hosts and warn when PropBean lives under `/mnt/*`.

## Layout

```text
propbean/
├─ .tools/
│  └─ powerfin/
│     ├─ bin/repo
│     └─ python-2.7.18/
├─ .state/
│  └─ powerfin/
│     └─ powerfin-resolved.xml
├─ third_party/
│  └─ powerfin-sdk/
└─ tools/setup/powerfin/
   ├─ activate.sh
   ├─ bootstrap.sh
   ├─ check-env.sh
   ├─ common.sh
   └─ env.conf
```

`.tools/`, `.state/`, and the SDK checkout are local state and are ignored by PropBean Git.

## Bootstrap

Run as the normal development user, not through `sudo`:

```bash
./tools/setup/powerfin/bootstrap.sh
```

The bootstrap invokes `sudo` only for Debian/Ubuntu package installation. It otherwise keeps generated files owned by the normal user.

The bootstrap:

1. installs the host packages used by the upstream PowerFin build workflow;
2. runs `git lfs install`;
3. installs the Android-style `repo` launcher under PropBean's local `.tools/` area;
4. downloads and SHA-256 verifies the Python 2.7.18 source archive, then builds it locally under `.tools/` to match the current upstream U-Boot CI compatibility path;
5. clones `HumpbackLab/powerfin_sdk` under `third_party/` with Git LFS smudging disabled;
6. initializes the official `HumpbackLab/manifest` `powerfin.xml`;
7. syncs the SDK component repositories;
8. writes an exact resolved manifest under `.state/`;
9. runs the non-destructive environment checker.

The SDK root tracks thousands of Git LFS objects. The bootstrap therefore does **not** download the full root LFS payload by default. This keeps environment bring-up separate from full image-build preparation.

The script does not modify `~/.bashrc` or permanently alter `PATH`.

The manifest's Buildroot project generates the top-level `envsetup.sh` linkfile. PropBean recognizes that exact link as normal workspace state, while still checking tracked source changes and other unexpected untracked files. A clean `repo status` message is not considered a modification.

### Known upstream Buildroot linkfile mismatch

At the inspected upstream revisions, `HumpbackLab/manifest:powerfin.xml` links `build/envsetup.sh` from the Buildroot project to the SDK root `envsetup.sh`, while `HumpbackLab/buildroot` stores `envsetup.sh` in its repository root. Android `repo` therefore creates a dangling symlink (`envsetup.sh -> buildroot/build/envsetup.sh`). PropBean treats that generated symlink as non-dirty SDK state **but warns separately that the link is broken**. Do not modify the SDK checkout just to hide the warning; track the upstream correction in [issue #2](https://github.com/cctsao1008/propbean/issues/2).

### Intentional SDK update

An existing workspace is left at its current revision by default. To intentionally fast-forward and re-sync it:

```bash
./tools/setup/powerfin/bootstrap.sh --update
```

The update is refused when the SDK root or any manifest-managed repository has local modifications. Bootstrap also refuses to continue if the SDK root looks dirty or incompletely checked out; for a disposable fresh workspace, remove `third_party/powerfin-sdk` and rerun the bootstrap rather than trying to repair thousands of missing files manually.

Other options:

```text
--skip-packages   use already-installed equivalent host dependencies
--skip-sync       initialize the workspace without downloading all manifest projects
--with-lfs        download the complete PowerFin SDK root Git LFS payload
--jobs N          override repo sync parallelism
```

Use `--with-lfs` only when preparing a complete official image build that needs the SDK root binary payload. The normal bootstrap path keeps LFS pointer files in place.

## Activate the current shell

```bash
source ./tools/setup/powerfin/activate.sh
```

`source` is a bash builtin. It will not work in PowerShell.

This adds only PropBean's local `repo` and Python 2 compatibility runtime to the current shell and defines:

```text
POWERFIN_SDK_ROOT=<propbean>/third_party/powerfin-sdk
```

Opening a new shell restores the normal environment.

## Validate

```bash
./tools/setup/powerfin/check-env.sh
```

The checker validates the Linux host, architecture, upstream Debian/Ubuntu package set, core tools, local `repo`, Python 2 compatibility runtime, SDK checkout, manifest workspace, expected kernel/Buildroot/U-Boot trees, working-tree cleanliness, and the locally recorded resolved manifest.

Missing required dependencies return a non-zero exit code. Workspace placement and local source changes are warnings rather than destructive actions.

## Dependency policy

PropBean does not pin or fork the SDK before the first hardware-validated baseline.

During bring-up, `bootstrap.sh` records the exact multi-repository state at:

```text
.state/powerfin/powerfin-resolved.xml
```

The equivalent manual operation is to run `repo manifest -r` inside `$POWERFIN_SDK_ROOT` and write the output outside the upstream SDK workspace.

After a clean official build and hardware smoke test pass, a validated manifest revision can become an explicit PropBean baseline. Any later upstream advance should then be treated as a deliberate dependency upgrade rather than an incidental `repo sync`.
