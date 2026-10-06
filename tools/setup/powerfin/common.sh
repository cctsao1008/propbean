#!/usr/bin/env bash

set -o pipefail

PB_SETUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PB_REPO_ROOT="$(cd -- "${PB_SETUP_DIR}/../../.." && pwd)"

# shellcheck source=env.conf
source "${PB_SETUP_DIR}/env.conf"

PB_TOOLS_ROOT="${PB_REPO_ROOT}/.tools/powerfin"
PB_TOOLS_BIN="${PB_TOOLS_ROOT}/bin"
PB_DOWNLOAD_ROOT="${PB_TOOLS_ROOT}/downloads"
PB_STATE_ROOT="${PB_REPO_ROOT}/.state/powerfin"
PB_SDK_ROOT="${PB_REPO_ROOT}/${POWERFIN_SDK_DIR}"
PB_PYTHON2_PREFIX="${PB_TOOLS_ROOT}/python-${PYTHON2_VERSION}"

pb_info() {
    printf '==> %s\n' "$*"
}

pb_warn() {
    printf 'WARN: %s\n' "$*" >&2
}

pb_die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

pb_is_wsl() {
    grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null
}

pb_repo_cmd() {
    if [[ -x "${PB_TOOLS_BIN}/repo" ]]; then
        printf '%s\n' "${PB_TOOLS_BIN}/repo"
        return 0
    fi

    command -v repo 2>/dev/null || return 1
}

pb_python2_cmd() {
    if [[ -x "${PB_PYTHON2_PREFIX}/bin/python2" ]]; then
        printf '%s\n' "${PB_PYTHON2_PREFIX}/bin/python2"
        return 0
    fi

    if command -v python2 >/dev/null 2>&1; then
        command -v python2
        return 0
    fi

    return 1
}

pb_require_linux() {
    [[ "$(uname -s)" == "Linux" ]] || pb_die "PowerFin/Buildroot setup requires Linux. Use a Linux host or WSL Linux."
}

pb_check_workspace_location() {
    if pb_is_wsl && [[ "${PB_REPO_ROOT}" == /mnt/* ]]; then
        pb_warn "PropBean is under ${PB_REPO_ROOT}. For large Buildroot SDK workspaces, prefer the WSL Linux filesystem (for example ~/src/propbean) rather than /mnt/*."
    fi
}

pb_sdk_is_dirty() {
    [[ -d "${PB_SDK_ROOT}/.git" ]] || return 1

    if [[ -n "$(git -C "${PB_SDK_ROOT}" status --porcelain)" ]]; then
        return 0
    fi

    local repo_cmd
    repo_cmd="$(pb_repo_cmd)" || return 1

    if [[ -d "${PB_SDK_ROOT}/.repo" ]]; then
        if ! (
            cd "${PB_SDK_ROOT}"
            "${repo_cmd}" forall -c 'test -z "$(git status --porcelain)"'
        ) >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}
