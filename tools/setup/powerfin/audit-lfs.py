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


def inspect_file(path: pathlib.Path) -> tuple[str, int | None]:
    """Inspect checkout state and declared LFS object size, without fetching."""
    if not path.exists():
        return ("MISSING", None)
    if not path.is_file():
        return ("NOT_FILE", None)
    try:
        with path.open("rb") as stream:
            if stream.readline() != LFS_HEADER:
                return ("PRESENT", None)
            oid_line = stream.readline()
            size_line = stream.readline()
        if not oid_line.startswith(b"oid sha256:") or not size_line.startswith(b"size "):
            return ("POINTER", None)
        return ("POINTER", int(size_line[5:].strip()))
    except (OSError, ValueError):
        return ("UNREADABLE", None)


def human_bytes(value: int) -> str:
    size = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if size < 1024 or unit == "TiB":
            return f"{size:.1f} {unit}"
        size /= 1024
    raise AssertionError("unreachable")


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

    inspected = {name: inspect_file(sdk / name) for name in names}
    summary = collections.defaultdict(collections.Counter)
    payload_bytes = collections.Counter()
    for name, (state, size) in inspected.items():
        label = group(name)
        summary[label][state] += 1
        if state == "POINTER" and size is not None:
            payload_bytes[label] += size

    print(f"{'Group':<19} {'POINTER':>8} {'PRESENT':>8} {'MISSING':>8} {'OTHER':>7} {'Pointer bytes':>16}")
    for label in [x[0] for x in RELEVANT_GROUPS] + ["other"]:
        counts = summary[label]
        other = sum(v for k, v in counts.items() if k not in {"POINTER", "PRESENT", "MISSING"})
        print(
            f"{label:<19} {counts['POINTER']:>8} {counts['PRESENT']:>8} "
            f"{counts['MISSING']:>8} {other:>7} {human_bytes(payload_bytes[label]):>16}"
        )
    print(f"Total logical bytes in materialization-pending pointers: {human_bytes(sum(payload_bytes.values()))}")

    print("\nKnown build inputs (state only; not a complete dependency closure):")
    candidates = set(CRITICAL_FILES)
    candidates.update(n for n in names if n.startswith("rkbin/RKBOOT/") and "RK3506" in n)
    candidates.update(n for n in names if n.startswith("rkbin/RKTRUST/") and "RK3506" in n)
    # Keep toolchain report short: identify the actual compiler entry points only.
    candidates.update(n for n in names if n.startswith("prebuilts/gcc/") and n.endswith("/arm-none-linux-gnueabihf-gcc"))
    for n in sorted(candidates):
        state, size = inspected.get(n, inspect_file(sdk / n))
        size_label = human_bytes(size) if size is not None else "-"
        print(f"  {state:<9} {size_label:>11} {n}")

    print("\\nNOTE: POINTER means the working tree contains a Git LFS pointer, not the binary.")
    print("Pointer bytes are declared uncompressed logical payload sizes, not network transfer estimates.")
    print("No files were downloaded or changed. A complete image build needs additional validation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
