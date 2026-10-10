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

# The manifest's Buildroot project creates a top-level envsetup.sh linkfile.
# It is owned by Android repo rather than the SDK root Git index.
pb_sdk_root_changes() {
    local entries line target
    entries="$(git -C "${PB_SDK_ROOT}" status --porcelain=v1 --untracked-files=normal)" || return 1

    while IFS= read -r line; do
        [[ -n "${line}" ]] || continue

        if [[ "${line}" == '?? envsetup.sh' && -L "${PB_SDK_ROOT}/envsetup.sh" ]]; then
            # Compare the literal link emitted by repo. The manifest currently
            # targets buildroot/build/envsetup.sh, which is absent upstream;
            # readlink -f would fail and misclassify the whole checkout.
            target="$(readlink -- "${PB_SDK_ROOT}/envsetup.sh")" || return 1
            if [[ "${target}" == 'buildroot/build/envsetup.sh' ]]; then
                continue
            fi
        fi

        printf '%s\n' "${line}"
    done <<< "${entries}"
}

# Report paths of modified manifest-managed Git projects; unlike "repo status",
# this emits nothing for clean workspaces.
pb_repo_project_changes() {
    local repo_cmd
    repo_cmd="$(pb_repo_cmd)" || return 1
    [[ -d "${PB_SDK_ROOT}/.repo" ]] || return 1

    (
        cd "${PB_SDK_ROOT}" || exit 1
        "${repo_cmd}" forall -c '
            changes="$(git status --porcelain=v1 --untracked-files=normal)" || exit 1
            test -z "$changes" || printf "%s\n" "$REPO_PATH"
        '
    )
}

# Return success (0) if the workspace is dirty or cannot be checked safely.
pb_sdk_is_dirty() {
    [[ -d "${PB_SDK_ROOT}/.git" ]] || return 0

    local changes
    changes="$(pb_sdk_root_changes)" || return 0
    [[ -z "${changes}" ]] || return 0

    if [[ -d "${PB_SDK_ROOT}/.repo" ]]; then
        changes="$(pb_repo_project_changes)" || return 0
        [[ -z "${changes}" ]] || return 0
    fi

    return 1
}
