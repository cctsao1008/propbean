#!/usr/bin/env python3
"""Read-only inventory of PowerFin SDK root LFS objects and known build inputs.

This is a triage tool, not a declaration that a complete image build is ready.
"""

import argparse
import collections
import pathlib
import subprocess
import sys

LFS_HEADER = b"version https://git-lfs.github.com/spec/v1\n"
RELEVANT_GROUPS = (
    ("rkbin", "rkbin/"),
    ("prebuilt-gcc", "prebuilts/gcc/"),
    ("packaging-tools", "tools/linux/Linux_Pack_Firmware/"),
    ("signing-tools", "tools/linux/rk_sign_tool/"),
)
CRITICAL_FILES = (
    "tools/linux/Linux_Pack_Firmware/rockdev/afptool",
    "tools/linux/Linux_Pack_Firmware/rockdev/rkImageMaker",
)


def git(sdk: pathlib.Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(sdk), *args],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    return result.stdout.strip()


def status(path: pathlib.Path) -> str:
    if not path.exists():
        return "MISSING"
    if not path.is_file():
        return "NOT_FILE"
    try:
        with path.open("rb") as stream:
            return "POINTER" if stream.read(len(LFS_HEADER)) == LFS_HEADER else "PRESENT"
    except OSError:
        return "UNREADABLE"


def group(path: str) -> str:
    for label, prefix in RELEVANT_GROUPS:
        if path.startswith(prefix):
            return label
    return "other"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sdk", type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parents[3] / "third_party/powerfin-sdk",
        help="PowerFin SDK root (default: PropBean third_party/powerfin-sdk)",
    )
    args = parser.parse_args()
    sdk = args.sdk.resolve()
    if not (sdk / ".git").exists():
        print(f"ERROR: not a Git SDK root: {sdk}", file=sys.stderr)
        return 2

    try:
        names = git(sdk, "lfs", "ls-files", "--name-only").splitlines()
        sha = git(sdk, "rev-parse", "HEAD")
    except (subprocess.CalledProcessError, OSError) as exc:
        print(f"ERROR: cannot inventory Git LFS: {exc}", file=sys.stderr)
        return 2

    print("PowerFin SDK root LFS inventory (read-only)")
    print(f"SDK: {sdk}")
    print(f"HEAD: {sha}")
    print(f"LFS tracked paths: {len(names)}")
    print()

    summary = collections.defaultdict(collections.Counter)
    for name in names:
        summary[group(name)][status(sdk / name)] += 1

    print(f"{'Group':<19} {'POINTER':>8} {'PRESENT':>8} {'MISSING':>8} {'OTHER':>7}")
    for label in [x[0] for x in RELEVANT_GROUPS] + ["other"]:
        s = summary[label]
        other = sum(v for k, v in s.items() if k not in {"POINTER", "PRESENT", "MISSING"})
        print(f"{label:<19} {s['POINTER']:>8} {s['PRESENT']:>8} {s['MISSING']:>8} {other:>7}")

    print("\nKnown build inputs (state only; not a complete dependency closure):")
    candidates = set(CRITICAL_FILES)
    candidates.update(n for n in names if n.startswith("rkbin/RKBOOT/") and "RK3506" in n)
    candidates.update(n for n in names if n.startswith("rkbin/RKTRUST/") and "RK3506" in n)
    # Keep toolchain report short: identify the actual compiler entry points only.
    candidates.update(n for n in names if n.startswith("prebuilts/gcc/") and n.endswith("/arm-none-linux-gnueabihf-gcc"))
    for n in sorted(candidates):
        print(f"  {status(sdk / n):<9} {n}")

    print("\nNOTE: POINTER means the working tree contains a Git LFS pointer, not the binary.")
    print("No files were downloaded or changed. A complete image build needs additional validation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
