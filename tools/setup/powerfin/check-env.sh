#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

FAILURES=0
WARNINGS=0

result() {
    local status="$1"
    local name="$2"
    local detail="${3:-}"

    case "${status}" in
        FAIL) FAILURES=$((FAILURES + 1)) ;;
        WARN) WARNINGS=$((WARNINGS + 1)) ;;
    esac

    if [[ -n "${detail}" ]]; then
        printf '[%s] %s: %s\n' "${status}" "${name}" "${detail}"
    else
        printf '[%s] %s\n' "${status}" "${name}"
    fi
}

check_command() {
    local command_name="$1"
    local label="${2:-$1}"

    if command -v "${command_name}" >/dev/null 2>&1; then
        result PASS "${label}" "$(command -v "${command_name}")"
    else
        result FAIL "${label}" "not found"
    fi
}

printf 'PropBean PowerFin development environment check\n\n'

if [[ "$(uname -s)" == "Linux" ]]; then
    result PASS "Host OS" "$(uname -sr)"
else
    result FAIL "Host OS" "PowerFin/Buildroot setup requires Linux"
fi

case "$(uname -m)" in
    x86_64|amd64)
        result PASS "Host architecture" "$(uname -m)"
        ;;
    *)
        result WARN "Host architecture" "$(uname -m); upstream PowerFin CI and bundled host toolchains are x86_64-oriented"
        ;;
esac

if pb_is_wsl; then
    result PASS "WSL" "detected"
    if [[ "${PB_REPO_ROOT}" == /mnt/* ]]; then
        result WARN "Workspace location" "${PB_REPO_ROOT}; prefer the WSL Linux filesystem for the large Buildroot workspace"
    else
        result PASS "Workspace location" "${PB_REPO_ROOT}"
    fi
else
    result PASS "Workspace location" "${PB_REPO_ROOT}"
fi

REQUIRED_PACKAGES=(
    bc
    bison
    build-essential
    ca-certificates
    cpio
    curl
    device-tree-compiler
    dosfstools
    expect
    fakeroot
    file
    flex
    git
    git-lfs
    jq
    libgmp-dev
    libmpc-dev
    libncurses-dev
    libsqlite3-dev
    libssl-dev
    lz4
    mtools
    ninja-build
    parted
    python3
    python3-pip
    python-is-python3
    rsync
    unzip
    wget
    xz-utils
    zstd
)

if command -v dpkg-query >/dev/null 2>&1; then
    missing_packages=()
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -q '^install ok installed$'; then
            missing_packages+=("${package}")
        fi
    done

    if [[ "${#missing_packages[@]}" -eq 0 ]]; then
        result PASS "Debian/Ubuntu packages" "all upstream build dependencies installed"
    else
        result FAIL "Debian/Ubuntu packages" "missing: ${missing_packages[*]}"
    fi
else
    result WARN "Package verification" "dpkg-query unavailable; checking executable dependencies only"
fi

for pair in     "git:Git"     "git-lfs:Git LFS"     "curl:curl"     "make:GNU Make"     "gcc:GCC"     "python3:Python 3"     "dtc:Device Tree Compiler"     "jq:jq"     "lz4:lz4"     "ninja:ninja"     "parted:parted"     "rsync:rsync"     "zstd:zstd"
do
    check_command "${pair%%:*}" "${pair#*:}"
done

if [[ -x "${PB_TOOLS_BIN}/repo" ]]; then
    repo_first_line="$("${PB_TOOLS_BIN}/repo" version 2>/dev/null | head -n 1)"
    result PASS "repo" "${repo_first_line:-${PB_TOOLS_BIN}/repo} [project-local]"
elif command -v repo >/dev/null 2>&1; then
    result WARN "repo" "$(command -v repo) [PATH fallback; bootstrap normally provisions a project-local copy]"
else
    result FAIL "repo" "not found; run bootstrap.sh"
fi

if [[ -x "${PB_PYTHON2_PREFIX}/bin/python2" ]]; then
    py2_version="$("${PB_PYTHON2_PREFIX}/bin/python2" --version 2>&1)"
    if [[ "${py2_version}" == "Python ${PYTHON2_VERSION}" ]]; then
        result PASS "Python 2 compatibility" "${py2_version} [project-local]"
    else
        result FAIL "Python 2 compatibility" "expected ${PYTHON2_VERSION}; detected ${py2_version}"
    fi
elif command -v python2 >/dev/null 2>&1; then
    result WARN "Python 2 compatibility" "$(python2 --version 2>&1) [PATH fallback]"
else
    result FAIL "Python 2 compatibility" "missing; current upstream PowerFin U-Boot CI uses Python ${PYTHON2_VERSION}"
fi

if [[ ! -d "${PB_SDK_ROOT}" ]]; then
    result FAIL "PowerFin SDK" "workspace not found: ${PB_SDK_ROOT}"
elif [[ ! -d "${PB_SDK_ROOT}/.git" ]]; then
    result FAIL "PowerFin SDK" "not a Git checkout: ${PB_SDK_ROOT}"
else
    sdk_head="$(git -C "${PB_SDK_ROOT}" rev-parse HEAD 2>/dev/null || true)"
    result PASS "PowerFin SDK" "${PB_SDK_ROOT}, HEAD ${sdk_head}"

    root_dirty="$(git -C "${PB_SDK_ROOT}" status --porcelain 2>/dev/null || true)"
    if [[ -n "${root_dirty}" ]]; then
        result WARN "SDK root working tree" "local modifications detected"
    else
        result PASS "SDK root working tree" "clean"
    fi

    if [[ -d "${PB_SDK_ROOT}/.repo" ]]; then
        result PASS "repo manifest workspace" "initialized"

        repo_cmd="$(pb_repo_cmd 2>/dev/null || true)"
        if [[ -n "${repo_cmd}" ]]; then
            repo_status="$(cd "${PB_SDK_ROOT}" && "${repo_cmd}" status 2>/dev/null || true)"
            if [[ -n "${repo_status}" ]]; then
                result WARN "Manifest project working trees" "local changes detected; run repo status in the SDK for details"
            else
                result PASS "Manifest project working trees" "clean"
            fi
        fi
    else
        result FAIL "repo manifest workspace" ".repo is missing; run bootstrap.sh"
    fi

    if [[ -d "${PB_SDK_ROOT}/kernel-6.1" && -d "${PB_SDK_ROOT}/buildroot" && -d "${PB_SDK_ROOT}/u-boot" ]]; then
        result PASS "SDK components" "kernel-6.1, buildroot, and u-boot present"
    else
        result FAIL "SDK components" "expected synced kernel-6.1/buildroot/u-boot trees are incomplete"
    fi
fi

if [[ -f "${PB_STATE_ROOT}/powerfin-resolved.xml" ]]; then
    if grep -q '192\.168\.10\.75' "${PB_STATE_ROOT}/powerfin-resolved.xml"; then
        result FAIL "Resolved manifest" "contains vendor intranet remote 192.168.10.75"
    else
        result PASS "Resolved manifest" "${PB_STATE_ROOT}/powerfin-resolved.xml"
    fi
else
    result WARN "Resolved manifest" "not recorded yet; bootstrap.sh records it after repo initialization"
fi

printf '\n'
if [[ "${FAILURES}" -gt 0 ]]; then
    printf 'Environment check failed: %d required check(s) failed; %d warning(s).\n' "${FAILURES}" "${WARNINGS}"
    exit 1
fi

if [[ "${WARNINGS}" -gt 0 ]]; then
    printf 'Environment check passed with %d warning(s).\n' "${WARNINGS}"
else
    printf 'Environment check passed.\n'
fi
