#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

UPDATE_SDK=0
SKIP_PACKAGES=0
SKIP_SYNC=0
WITH_LFS=0
SYNC_JOBS="${POWERFIN_SYNC_JOBS}"

usage() {
    cat <<'EOF'
Usage: ./tools/setup/powerfin/bootstrap.sh [options]

Options:
  --update          Fast-forward the SDK root and re-sync manifest projects.
  --skip-packages   Do not install Debian/Ubuntu host packages.
  --skip-sync       Clone/init as needed but do not run repo sync.
  --with-lfs        Download the full PowerFin SDK root Git LFS payload.
  --jobs N          Override repo sync job count.
  -h, --help        Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --update)
            UPDATE_SDK=1
            shift
            ;;
        --skip-packages)
            SKIP_PACKAGES=1
            shift
            ;;
        --skip-sync)
            SKIP_SYNC=1
            shift
            ;;
        --with-lfs)
            WITH_LFS=1
            shift
            ;;
        --jobs)
            [[ $# -ge 2 ]] || pb_die "--jobs requires a value"
            SYNC_JOBS="$2"
            [[ "${SYNC_JOBS}" =~ ^[1-9][0-9]*$ ]] || pb_die "--jobs must be a positive integer"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            pb_die "Unknown option: $1"
            ;;
    esac
done

pb_require_linux
pb_check_workspace_location

if [[ "${EUID}" -eq 0 ]]; then
    pb_die "Do not run the bootstrap as root or with sudo. Run it as your normal user; it invokes sudo only for apt packages."
fi

mkdir -p "${PB_TOOLS_BIN}" "${PB_DOWNLOAD_ROOT}" "${PB_STATE_ROOT}" "$(dirname "${PB_SDK_ROOT}")"

HOST_PACKAGES=(
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

if [[ "${SKIP_PACKAGES}" -eq 0 ]]; then
    command -v apt-get >/dev/null 2>&1 || pb_die "apt-get was not found. Use --skip-packages only after installing equivalent dependencies yourself."
    command -v sudo >/dev/null 2>&1 || pb_die "sudo is required to install host packages. Install dependencies manually and rerun with --skip-packages."

    pb_info "Install PowerFin host dependencies"
    sudo apt-get update
    sudo apt-get install --yes --no-install-recommends "${HOST_PACKAGES[@]}"
else
    pb_info "Skip host package installation"
fi

command -v git >/dev/null 2>&1 || pb_die "git is required"
command -v curl >/dev/null 2>&1 || pb_die "curl is required"
command -v sha256sum >/dev/null 2>&1 || pb_die "sha256sum is required"

pb_info "Initialize Git LFS"
git lfs install >/dev/null

pb_info "Provision repository-local repo launcher"
REPO_BIN="${PB_TOOLS_BIN}/repo"
if [[ ! -x "${REPO_BIN}" ]]; then
    curl --fail --location         "https://storage.googleapis.com/git-repo-downloads/repo"         --output "${REPO_BIN}"
    chmod +x "${REPO_BIN}"
else
    printf 'Already present: %s\n' "${REPO_BIN}"
fi
"${REPO_BIN}" version | head -n 1

pb_info "Provision Python ${PYTHON2_VERSION} compatibility runtime"
PYTHON2_BIN="${PB_PYTHON2_PREFIX}/bin/python2"
if [[ ! -x "${PYTHON2_BIN}" ]]; then
    PYTHON2_ARCHIVE="${PB_DOWNLOAD_ROOT}/Python-${PYTHON2_VERSION}.tgz"
    PYTHON2_SOURCE="${PB_TOOLS_ROOT}/Python-${PYTHON2_VERSION}"

    if [[ ! -f "${PYTHON2_ARCHIVE}" ]]; then
        curl --fail --location "${PYTHON2_URL}" --output "${PYTHON2_ARCHIVE}"
    else
        printf 'Using cached download: %s\n' "${PYTHON2_ARCHIVE}"
    fi

    actual_sha256="$(sha256sum "${PYTHON2_ARCHIVE}" | awk '{print $1}')"
    if [[ "${actual_sha256}" != "${PYTHON2_SHA256}" ]]; then
        rm -f "${PYTHON2_ARCHIVE}"
        pb_die "Python ${PYTHON2_VERSION} archive SHA-256 mismatch. Expected ${PYTHON2_SHA256}, got ${actual_sha256}."
    fi

    rm -rf "${PYTHON2_SOURCE}"
    tar -C "${PB_TOOLS_ROOT}" -xzf "${PYTHON2_ARCHIVE}"

    (
        cd "${PYTHON2_SOURCE}"
        ./configure --prefix="${PB_PYTHON2_PREFIX}" --without-ensurepip
        make --jobs="$(nproc)"
        make install
    )

    rm -rf "${PYTHON2_SOURCE}"
else
    printf 'Already present: %s\n' "${PB_PYTHON2_PREFIX}"
fi

"${PYTHON2_BIN}" --version 2>&1 | grep -F "Python ${PYTHON2_VERSION}" >/dev/null ||
    pb_die "Unexpected Python 2 runtime at ${PYTHON2_BIN}"

export PATH="${PB_TOOLS_BIN}:${PB_PYTHON2_PREFIX}/bin:${PATH}"

pb_info "Provision official PowerFin SDK workspace"
NEW_SDK=0
if [[ ! -d "${PB_SDK_ROOT}" ]]; then
    GIT_LFS_SKIP_SMUDGE=1 git clone "${POWERFIN_SDK_URL}" "${PB_SDK_ROOT}"
    NEW_SDK=1
elif [[ ! -d "${PB_SDK_ROOT}/.git" ]]; then
    pb_die "SDK path exists but is not a Git checkout: ${PB_SDK_ROOT}"
else
    printf 'Already present: %s\n' "${PB_SDK_ROOT}"
fi

if pb_sdk_is_dirty; then
    pb_die "PowerFin SDK workspace has local changes or an incomplete checkout. Repair or remove ${PB_SDK_ROOT} before continuing."
fi

if [[ "${UPDATE_SDK}" -eq 1 ]]; then
    pb_info "Fast-forward PowerFin SDK root"
    git -C "${PB_SDK_ROOT}" pull --ff-only
fi

if [[ "${WITH_LFS}" -eq 1 ]]; then
    pb_info "Download full PowerFin SDK root Git LFS payload"
    git -C "${PB_SDK_ROOT}" lfs pull
else
    pb_info "Skip full PowerFin SDK root Git LFS payload; use --with-lfs when preparing a complete image build"
fi

if [[ ! -d "${PB_SDK_ROOT}/.repo" ]]; then
    pb_info "Initialize upstream PowerFin repo manifest"
    (
        cd "${PB_SDK_ROOT}"
        "${REPO_BIN}" init             --manifest-url="${POWERFIN_MANIFEST_URL}"             --manifest-branch="${POWERFIN_MANIFEST_BRANCH}"             --manifest-name="${POWERFIN_MANIFEST_NAME}"             --depth="${POWERFIN_REPO_DEPTH}"
    )
fi

if [[ "${SKIP_SYNC}" -eq 0 ]] && { [[ "${NEW_SDK}" -eq 1 ]] || [[ "${UPDATE_SDK}" -eq 1 ]] || [[ ! -d "${PB_SDK_ROOT}/kernel-6.1" ]]; }; then
    pb_info "Synchronize upstream PowerFin component repositories"
    (
        cd "${PB_SDK_ROOT}"
        "${REPO_BIN}" sync             --current-branch             --jobs="${SYNC_JOBS}"             --fail-fast             --no-tags
    )
elif [[ "${SKIP_SYNC}" -eq 1 ]]; then
    pb_info "Skip repo sync"
else
    pb_info "Existing SDK workspace retained without re-sync; use --update to advance it"
fi

if [[ -d "${PB_SDK_ROOT}/.repo" ]]; then
    pb_info "Record exact resolved manifest"
    (
        cd "${PB_SDK_ROOT}"
        "${REPO_BIN}" manifest -r -o "${PB_STATE_ROOT}/powerfin-resolved.xml"
    )

    if grep -q '192\.168\.10\.75' "${PB_STATE_ROOT}/powerfin-resolved.xml"; then
        pb_die "Resolved manifest still contains the vendor intranet remote 192.168.10.75"
    fi
fi

pb_info "Validate PowerFin development environment"
"${SCRIPT_DIR}/check-env.sh"

cat <<EOF

Bootstrap complete.

Activate the PropBean PowerFin shell environment with:
  source ./tools/setup/powerfin/activate.sh

SDK workspace:
  ${PB_SDK_ROOT}

Resolved manifest:
  ${PB_STATE_ROOT}/powerfin-resolved.xml
EOF
