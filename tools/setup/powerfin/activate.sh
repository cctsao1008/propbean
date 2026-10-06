#!/usr/bin/env bash

# This script intentionally affects only the current shell and therefore must be sourced.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'This script must be sourced:\n  source ./tools/setup/powerfin/activate.sh\n' >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

pb_require_linux

export POWERFIN_SDK_ROOT="${PB_SDK_ROOT}"
export PATH="${PB_TOOLS_BIN}:${PB_PYTHON2_PREFIX}/bin:${PATH}"

printf 'PropBean PowerFin environment active\n'
printf '  POWERFIN_SDK_ROOT=%s\n' "${POWERFIN_SDK_ROOT}"
printf '  repo=%s\n' "$(command -v repo 2>/dev/null || true)"
printf '  python2=%s\n' "$(command -v python2 2>/dev/null || true)"
