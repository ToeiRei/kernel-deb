#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.json"
SCRIPT_NAME="$(basename "$0")"

USE_LLVM=false
USE_RT=false
USE_VM=false
ADD_PATCHES=false
UPLOAD_PACKAGECLOUD=false
UPLOAD_NEXUS=false
PUBLISH_ONLY=false
KERNEL_VERSION=""
NTFY_URL=""
CLEAN_BUILD=false
SUFFIX=""

# === New Cross-Compile Variables ===
# If CROSS_COMPILE is empty, we assume a native build
ARCH="${ARCH:-x86}"  # Default to x86 if not set
CROSS_COMPILE="${CROSS_COMPILE:-}"

# Utils
fatal() {
    echo "[FATAL] $*" >&2
    log "$*" "FATAL"
    exit 1
}

# Define numerical values for log levels.
# Lower numbers imply less severity.
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

# Set a threshold to prevent ntfy from sending every log message.
# For instance, only notify if severity is WARN (2) or above.
DEFAULT_NOTIFY_LEVEL=${DEFAULT_NOTIFY_LEVEL:-1}

log() {
    local message="$1"
    local level="${2:-DEBUG}"  # Default to DEBUG if no level is provided
    local level_value=${LOG_LEVELS[$level]:-0}
    
    # Print log message to stdout with a level prefix
    echo "[$level] $message"
    
    # Only send an ntfy notification if the level meets or exceeds DEFAULT_NOTIFY_LEVEL
    if [[ -n "$NTFY_URL" && $level_value -ge $DEFAULT_NOTIFY_LEVEL ]]; then
        curl -sL -H "Title: ${SCRIPT_NAME:-Script}" -d "$message" "$NTFY_URL" >/dev/null || true
    fi
}

# Config loader
parse_config() {
    command -v jq >/dev/null || fatal "jq is required but not found in PATH"

    if [[ -f "$CONFIG_FILE" ]]; then
        BUILDPATH=$(jq -r '.buildpath' "$CONFIG_FILE")
        CONFIGDIR=$(jq -r '.configdir' "$CONFIG_FILE")
        RELEASEDIR=$(jq -r '.releasedir' "$CONFIG_FILE")
        PATCHDIR=$(jq -r '.patchdir' "$CONFIG_FILE")
        CCOPTS=$(jq -r '.ccopts // empty' "$CONFIG_FILE")
        HOMEPAGE=$(jq -r '.homepage // empty' "$CONFIG_FILE")
        MAINTAINER=$(jq -r '.maintainer // empty' "$CONFIG_FILE")
        WGETPARMS=$(jq -r '.wgetparms // "-q"' "$CONFIG_FILE")
        PACKAGECLOUD_DEB=$(jq -r '.packagecloud_deb // empty' "$CONFIG_FILE")
        PACKAGECLOUD_DEB2=$(jq -r '.packagecloud_deb2 // empty' "$CONFIG_FILE")
        NEXUS_USER=$(jq -r '.nexus_user // empty' "$CONFIG_FILE")
        NEXUS_PW=$(jq -r '.nexus_pass // empty' "$CONFIG_FILE")
        NEXUS_REPO=$(jq -r '.nexus_repo // empty' "$CONFIG_FILE")
        NTFY_URL=$(jq -r '.ntfy_url // empty' "$CONFIG_FILE")
        LLVM=$(jq -r '.llvm // false' "$CONFIG_FILE")
        LD=$(jq -r '.ld // empty' "$CONFIG_FILE")
        GH_TOKEN=$(jq -r '.gh_token // empty' "$CONFIG_FILE")
    else
        echo "[WARN] $CONFIG_FILE not found, using environment variables (CI mode)"

        BUILDPATH="${BUILDPATH:-/build}"
        CONFIGDIR="${CONFIGDIR:-/config}"
        RELEASEDIR="${RELEASEDIR:-/release}"
        PATCHDIR="${PATCHDIR:-/patches}"
        CCOPTS="${CCOPTS:-}"
        HOMEPAGE="${HOMEPAGE:-https://example.com}"
        MAINTAINER="${MAINTAINER:-GitHub Actions <gh@actions.local>}"
        WGETPARMS="${WGETPARMS:--q}"
        PACKAGECLOUD_DEB="${PACKAGECLOUD_DEB:-}"
        PACKAGECLOUD_DEB2="${PACKAGECLOUD_DEB2:-}"
        NEXUS_USER="${NEXUS_USER:-}"
        NEXUS_PW="${NEXUS_PW:-}"
        NEXUS_REPO="${NEXUS_REPO:-}"
        NTFY_URL="${NTFY_URL:-}"
        LLVM="${LLVM:-false}"
        LD="${LD:-}"
        GH_TOKEN="${GH_TOKEN:-}"
    fi
}

# Kernel version logic
detect_latest_kernel() {
    # Get releases JSON quietly
    local releases_json
    releases_json=$(curl -s https://www.kernel.org/releases.json) || {
        echo "Failed to fetch releases from kernel.org" >&2
        return 1
    }

    # Extract version with proper error handling
    local version
    #version=$(echo "$releases_json" | \
    #         jq -r '.releases[] | select(.moniker == "stable" and (.iseol == false or .iseol == null)) | .version' | \
    #         sort -V | tail -n1 | sed 's/^v//' 2>/dev/null)

    version=$(echo "$releases_json" | \
        jq -r '.releases[] | select((.moniker == "stable" or .moniker == "mainline") and (.iseol == false or .iseol == null)) | .version' | \
        sort -V | tail -n1 | sed 's/^v//' 2>/dev/null)

    # Validate version format
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Invalid version format detected" >&2
        return 1
    fi

    echo "$version"
}

# Args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --llm|--llvm) USE_LLVM=true ;;
            --rt) USE_RT=true ;;
            --vm) USE_VM=true ;;
            --add-patches) ADD_PATCHES=true ;;
            --upload-nexus) UPLOAD_NEXUS=true ;;
            --upload-pkgcloud|--upload-packagecloud) UPLOAD_PACKAGECLOUD=true ;;
            --publish) PUBLISH_ONLY=true ;;
	    --menuconfig) MENUCONFIG=true ;;
            --arch)
                shift
                [[ $# -eq 0 ]] && fatal "--arch requires an argument"
                ARCH="$1"
                ;;
            --cross-compile)
                shift
                [[ $# -eq 0 ]] && fatal "--cross-compile requires an argument"
                CROSS_COMPILE="$1"
                ;;
            -h|--help) usage ;;
            [0-9]*.[0-9]*.[0-9]*) KERNEL_VERSION="$1" ;;
            --clean|--cleanup) CLEAN_BUILD=true ;;
            --suffix)
                shift
                [[ $# -eq 0 ]] && fatal "--suffix requires an argument"
                SUFFIX="$1"
                ;;
            *) fatal "Unknown option: $1" ;;
        esac
        shift
    done
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [version] [options]
Options:
  --clean                        Cleans the build directory
  --llvm                         Use LLVM/clang toolchain
  --rt                           Apply RT patches
  --vm                           Build a stripped-down VM kernel
  --add-patches                  Apply patches from configured patchdir
  --upload-nexus                 Upload built packages to Nexus
  --upload-pkgcloud              Upload packages to Packagecloud
  --publish                      Only publish release to GitHub (no build)
  --menuconfig                   Runs make menuconfig on a config
  --arch <arch>                  Set target architecture (e.g. x86_64, arm64)
  --cross-compile <prefix>       Set cross-compiler prefix (e.g. aarch64-linux-gnu-)
  --suffix <str>                 Set custom localversion suffix
  -h, --help                     Show this help

Examples:
  $SCRIPT_NAME                    # Builds latest vanilla kernel
  $SCRIPT_NAME 6.9.3 --vm         # Builds stripped kernel for 6.9.3
  $SCRIPT_NAME 6.9.3 --arch arm64 --cross-compile aarch64-linux-gnu- --suffix test
  $SCRIPT_NAME 6.9.3 --publish    # Only publish GitHub release
EOF
    exit 0
}

config_diff() {
    # Determine the configuration variant based on flags
    local config_variant="vanilla"
    if [[ "$USE_VM" == true ]]; then
        config_variant="vm"
    elif [[ "$USE_RT" == true ]]; then
        config_variant="rt"
    fi

    # Define the baseline and active config file paths
    local config_source="${CONFIGDIR}/${config_variant}.config"
    local active_config="${SOURCEDIR}/.config"

    # Validate that the necessary config files exist
    [[ ! -f "$config_source" ]] && fatal "Missing baseline kernel config: $config_source"
    [[ ! -f "$active_config" ]] && fatal "Missing active kernel config: $active_config"

    # Ensure that the diffconfig tool exists and is executable
    if [[ ! -x "${SOURCEDIR}/scripts/diffconfig" ]]; then
        fatal "diffconfig tool not found or not executable at ${SOURCEDIR}/scripts/diffconfig"
    fi

    # Ensure the release directory exists
    mkdir -p "$RELEASEDIR"

    log "Generating kernel config differences for '$config_variant'..."
    "${SOURCEDIR}/scripts/diffconfig" "$config_source" "$active_config" > "$RELEASEDIR/config_changes-${config_variant}.diff"
    log "Config changes stored at $RELEASEDIR/config_changes-${config_variant}.diff"

    # Enhance the diff output with markdown formatting for GitHub release notes
    enrich_diff_markdown "$RELEASEDIR/config_changes-${config_variant}.diff" > "$RELEASEDIR/config_changes-${config_variant}-enriched.md"
    log "Enriched config changes stored at $RELEASEDIR/config_changes-${config_variant}-enriched.md"
}


enrich_diff_markdown() {
    local diff_file=$1
    # Validate input
    if [[ ! -f "$diff_file" ]]; then
        echo "* Diff file not found: $diff_file" >&2
        return 1
    fi
    if [[ ! -s "$diff_file" ]]; then
        echo "* No configuration changes detected"
        return 0
    fi

    local pahole_patterns="PAHOLE|BTF|DEBUG_INFO"
    local version_patterns="VERSION|RELEASE|GCC|CLANG|RUSTC|LLVM"
    local important_patterns="KVM|SECURITY|SELINUX|APPARMOR|MODULE|DRM|NET|SCHED|PCI|USB|VIRTIO|MEMORY|CPU|ACPI|EFI"
    local driver_patterns="_DRIVER|_HCD|_UDC|_HID|_INPUT|_TOUCHSCREEN|_WATCHDOG|_PHY|_GPIO"

    local added removed changed pahole_changes version_changes important_changes driver_changes
    added=$(grep -E '^\+[^+]' "$diff_file" | grep -vE "$version_patterns" || true)
    removed=$(grep -E '^\-[^-]' "$diff_file" | grep -vE "$version_patterns" || true)
    changed=$(grep -E '^[+-][^+-]' "$diff_file" | grep -vE "$version_patterns" | \
              awk -F'=' '{print $1}' | sed 's/^[+-]//' | sort | uniq -c | awk '$1==2{print $2}' || true)

    pahole_changes=$(grep -E "$pahole_patterns" "$diff_file" || true)
    version_changes=$(grep -E "$version_patterns" "$diff_file" || true)
    important_changes=$(grep -E "$important_patterns" "$diff_file" || true)
    driver_changes=$(grep -E "$driver_patterns" "$diff_file" || true)

    local added_count removed_count changed_count pahole_count version_count important_count driver_count total_changes
    added_count=$(echo "$added" | grep -c '[^[:space:]]' || true)
    removed_count=$(echo "$removed" | grep -c '[^[:space:]]' || true)
    changed_count=$(echo "$changed" | grep -c '[^[:space:]]' || true)
    pahole_count=$(echo "$pahole_changes" | grep -c '[^[:space:]]' || true)
    version_count=$(echo "$version_changes" | grep -c '[^[:space:]]' || true)
    important_count=$(echo "$important_changes" | grep -c '[^[:space:]]' || true)
    driver_count=$(echo "$driver_changes" | grep -c '[^[:space:]]' || true)
    total_changes=$(wc -l < "$diff_file")

    local is_major_jump=0
    [[ $total_changes -gt 500 ]] && is_major_jump=1

    echo ""
    echo "### Configuration Changes Analysis"
    echo ""
    echo "* **Total changes:** ${total_changes}"
    echo "  - (+) ${added_count} added"
    echo "  - (-) ${removed_count} removed"
    echo "  - (~) ${changed_count} changed"
    [[ $pahole_count -gt 0 ]] && echo "  - (⚙) ${pahole_count} debug/format changes"
    [[ $important_count -gt 0 ]] && echo "  - (⚠) ${important_count} subsystem changes"
    [[ $driver_count -gt 0 ]] && echo "  - (🚗) ${driver_count} driver changes"

    [[ $is_major_jump -eq 1 ]] && {
        echo ""
        echo "> **Major Version Jump Detected**  "
        echo "> This appears to be a significant version upgrade. Focus on subsystem changes below."
    }

    [[ $pahole_count -gt 0 ]] && {
        echo ""
        echo "#### Debug/Format Changes"
        echo ""
        while IFS= read -r line; do
            [[ "$line" == +* ]] && echo "* [+] ${line:1}"
            [[ "$line" == -* ]] && echo "* [-] ${line:1}"
        done <<< "$pahole_changes"
    }

    [[ $important_count -gt 0 ]] && {
        echo ""
        echo "#### Subsystem Changes"
        echo ""
        if [[ $important_count -gt 15 ]]; then
            echo "*Showing top 15 of ${important_count} changes*  "
            echo ""
            while IFS= read -r line; do
                [[ "$line" == +* ]] && echo "* [+] ${line:1}"
                [[ "$line" == -* ]] && echo "* [-] ${line:1}"
            done <<< "$(echo "$important_changes" | head -15)"
            echo ""
            echo "<details>"
            echo "<summary>Show all ${important_count} changes</summary>"
            echo ""
            while IFS= read -r line; do
                [[ "$line" == +* ]] && echo "* [+] ${line:1}"
                [[ "$line" == -* ]] && echo "* [-] ${line:1}"
            done <<< "$important_changes"
            echo "</details>"
        else
            while IFS= read -r line; do
                [[ "$line" == +* ]] && echo "* [+] ${line:1}"
                [[ "$line" == -* ]] && echo "* [-] ${line:1}"
            done <<< "$important_changes"
        fi
    }

    [[ $driver_count -gt 0 ]] && {
        echo ""
        echo "#### Driver Changes"
        echo ""
        echo "*${driver_count} driver-related changes detected*  "
        echo ""
        echo "<details>"
        echo "<summary>Driver change details</summary>"
        echo ""
        while IFS= read -r line; do
            [[ "$line" == +* ]] && echo "* [+] ${line:1}"
            [[ "$line" == -* ]] && echo "* [-] ${line:1}"
        done <<< "$driver_changes"
        echo "</details>"
    }

    [[ $changed_count -gt 0 ]] && {
        echo ""
        echo "#### Changed Option Values"
        echo ""
        for opt in $changed; do
            local old_val new_val
            old_val=$(grep -E "^-${opt}=" "$diff_file" | head -1 | cut -d= -f2- || true)
            new_val=$(grep -E "^\+${opt}=" "$diff_file" | head -1 | cut -d= -f2- || true)
            [[ -z "$old_val" ]] && old_val="(not set)"
            [[ -z "$new_val" ]] && new_val="(not set)"
            echo "* [~] ${opt}=${old_val} → ${new_val}"
        done
    }

    [[ $version_count -gt 0 ]] && {
        echo ""
        echo "#### Version/Trivial Changes"
        echo ""
        if [[ $version_count -gt 5 ]]; then
            echo "*Showing 3 of ${version_count} changes*  "
            echo ""
            while IFS= read -r line; do
                echo "* [↻] ${line:1}"
            done <<< "$(echo "$version_changes" | head -3)"
            echo ""
            echo "<details>"
            echo "<summary>Show all ${version_count} changes</summary>"
            echo ""
            while IFS= read -r line; do
                echo "* [↻] ${line:1}"
            done <<< "$version_changes"
            echo "</details>"
        else
            while IFS= read -r line; do
                echo "* [↻] ${line:1}"
            done <<< "$version_changes"
        fi
    }
}



release_to_github() {
    pushd "/gitrepo" >/dev/null || fatal "Cannot change directory to Git repo"
    
    # Step 1: Set the Git repository's directory as safe.
    git config --global --add safe.directory /gitrepo

    # Step 2: Set up GitHub authentication.
    command -v gh >/dev/null || fatal "GitHub CLI (gh) is required for release publishing"
    if [[ -z "$GH_TOKEN" ]]; then
        fatal "GitHub token (GH_TOKEN) is missing. Authentication will fail."
    fi
    export GH_TOKEN="${GH_TOKEN}"
    gh auth status || fatal "GitHub authentication failed"
    gh auth setup-git || fatal "GitHub authentication setup for git failed"

    # Step 3: Set up the MAINTAINER information.
    if [[ ! "$MAINTAINER" =~ .*\<.*@.*\> ]]; then
        fatal "Invalid MAINTAINER format: '$MAINTAINER'. Expected format: 'Name <email@example.com>'"
    fi
    MAINTAINER_NAME="${MAINTAINER%% <*}"  # Extract name
    MAINTAINER_EMAIL="${MAINTAINER##*<}"    # Extract email
    MAINTAINER_EMAIL="${MAINTAINER_EMAIL%>}"
    git config --global user.name "$MAINTAINER_NAME"
    git config --global user.email "$MAINTAINER_EMAIL"
    log "MAINTAINER is set to: ${MAINTAINER_NAME} <${MAINTAINER_EMAIL}>"

    # Step 4: Commit configuration files (or any local changes) to the repo.
    # Note: Adjust the files to commit as necessary.
    git add .
    git commit -m "$1" || log "No changes to commit"

    # Step 5: Create a tag if it doesn’t exist.
    local version="$1"
    if git rev-parse "$version" >/dev/null 2>&1; then
        log "Tag '$version' already exists. Skipping tag creation."
    else
        git tag "$version"
        git push --tags
    fi

    # Step 6: Push commits.
    git push

    # Step 7: Craft a release readme from the enriched changelogs.
    local release_notes="${HOME}/release.md"
    {
        echo "Kernel release: $version"
        echo ""
        echo "Includes:"
        echo "- linux-image"
        echo "- linux-headers"
        echo "- linux-libc-dev"
        echo ""
        echo "Variants:"
        if [[ -f "${RELEASEDIR}/config_changes-vanilla-enriched.md" ]]; then
            echo "- vanilla-kernel: full Debian-based config"
        fi

        if [[ -f "${RELEASEDIR}/config_changes-vm-enriched.md" ]]; then
            echo "- vm-kernel: minimal driver footprint for virtual machines"
        fi

        if [[ -f "${RELEASEDIR}/config_changes-rt-enriched.md" ]]; then
            echo "- rt-kernel: real-time configuration"
        fi
        echo ""
        echo "Source code is included as a ZIP archive (quilt format)"
        echo "Built with a mildly cursed Bash script."
        echo ""
        echo "PS: We’ve taken the liberty of summarizing the configuration diff—because transparency is our middle name."
    } > "$release_notes"

    # Loop over all expected config variants (even if a diff file is missing for some, that’s fine)
    for variant in vanilla vm rt; do
        local diff_file="${RELEASEDIR}/config_changes-${variant}-enriched.md"
        if [[ -f "$diff_file" && -s "$diff_file" ]]; then
            echo "" >> "$release_notes"
            echo "## ${variant} configuration changes" >> "$release_notes"
            echo "" >> "$release_notes"
            cat "$diff_file" >> "$release_notes"
        else
            log "No enriched config diff found for variant '$variant'; skipping."
        fi
    done

    # Step 8: Loop through all the release assets.
    mapfile -t assets < <(find "$RELEASEDIR" -type f \( -name "*${version}*.zip" -o -name "*${version}*.zip.sha256sum" \))
    if [[ ${#assets[@]} -eq 0 ]]; then
        fatal "No release assets found in $RELEASEDIR"
    fi
    log "Attaching the following assets to release: ${assets[*]}"

    # Step 9: Create a draft GitHub release with the release notes and assets.
    gh release create "$version" -t "Kernel release: $version" -F "$release_notes" "${assets[@]}"
    log "Release $version published to GitHub as a draft."
    popd >/dev/null
}


fetch_sources() {
    mkdir -p "$BUILDPATH" "$RELEASEDIR"
    local major_version="${KERNEL_VERSION%%.*}"
    local base_url="https://cdn.kernel.org/pub/linux/kernel/v${major_version}.x"
    local tarball="linux-${KERNEL_VERSION}.tar"
    local tar_ext=""
    local srcdir="${BUILDPATH}/linux-${KERNEL_VERSION}"

    log "Preparing to fetch kernel sources for version: ${KERNEL_VERSION}"

    # Check if an existing tarball is present
    for ext in xz zst; do
        if [[ -f "${BUILDPATH}/${tarball}.${ext}" ]]; then
            tar_ext="${ext}"
            log "Found existing tarball: ${tarball}.${tar_ext}"
            break
        fi
    done

    # If no tarball was found locally, attempt to download it
    if [[ -z "$tar_ext" ]]; then
        for ext in xz zst; do
            local full_url="${base_url}/${tarball}.${ext}"
            log "Attempting download: $full_url"
            if curl -fLs ${WGETPARMS} -o "${BUILDPATH}/${tarball}.${ext}" "$full_url"; then
                tar_ext="${ext}"
                log "Successfully downloaded: ${tarball}.${tar_ext}"
                break
            fi
        done
    fi

    # Abort if we could not get the tarball
    if [[ -z "$tar_ext" ]]; then
        fatal "Could not fetch kernel sources for ${KERNEL_VERSION} (tried .xz and .zst formats)"
    fi

    # Always clean the source directory to avoid using a patched or stale set of sources
    if [[ -d "$srcdir" ]]; then
        log "Removing existing source directory $srcdir to ensure a clean extraction."
        rm -rf "$srcdir"
    fi

    # Extract the tarball
    log "Extracting ${tarball}.${tar_ext} to ${BUILDPATH}"
    case "$tar_ext" in
        xz)  tar -xf "${BUILDPATH}/${tarball}.xz" -C "$BUILDPATH" ;;
        zst) tar --zstd -xf "${BUILDPATH}/${tarball}.zst" -C "$BUILDPATH" ;;
    esac

    export SOURCEDIR="$srcdir"
}


configure_kernel() {
    [[ -z "$SOURCEDIR" ]] && fatal "SOURCEDIR is not set"

    local config_variant="vanilla"
    [[ "$USE_VM" == true ]] && config_variant="vm"
    local config_source="${CONFIGDIR}/${config_variant}.config"

    [[ -f "$config_source" ]] || fatal "Missing kernel config: $config_source"

    log "Copying config from $config_source"
    cp "$config_source" "${SOURCEDIR}/.config"

    pushd "$SOURCEDIR" >/dev/null || fatal "Failed to enter source directory: $SOURCEDIR"

    # Build up the make options
    local make_opts=()

    if [[ "$USE_LLVM" == true || "${LLVM:-false}" == true ]]; then
        make_opts+=( "LLVM=1" "LLVM_IAS=1" )
    fi

    if [[ -n "${CCOPTS:-}" ]]; then
        make_opts+=( "CC=${CCOPTS}" "HOSTCC=${CCOPTS}" )
    fi

    if [[ -n "${LD:-}" ]]; then
        make_opts+=( "LD=${LD}" )
    fi

    make_opts+=("-j$(nproc)" "olddefconfig")
    log "Running make olddefconfig with options: ${make_opts[*]}"
    make ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "${make_opts[@]}"

    popd >/dev/null
}

prepare_source_tree() {
    # Ensure we have a valid config loaded
    parse_config

    # Fetch the sources if not already fetched
    fetch_sources

    # Select and copy a baseline configuration
    local config_variant="vanilla"
    [[ "$USE_VM" == true ]] && config_variant="vm"
    [[ "$USE_RT" == true ]] && config_variant="rt"

    local config_source="${CONFIGDIR}/${config_variant}.config"
    log "Copying baseline configuration from $config_source"
    cp "$config_source" "${SOURCEDIR}/.config"

    pushd "$SOURCEDIR" >/dev/null || fatal "Failed to enter source directory: $SOURCEDIR"

    # Apply optional adjustments based on build mode
    apply_llvm_tweaks
    apply_rt_tweaks
    disable_signing

    # Preconfigure the kernel; this applies any non-interactive changes
    # that you want even before interactive tweaking.
    configure_kernel

    popd >/dev/null
}

run_menuconfig() {
    [[ ! -t 0 ]] && fatal "Menuconfig requires interactive terminal"

    # Prepare the source tree in a consistent way with the rest of the build system.
    prepare_source_tree

    pushd "$SOURCEDIR" >/dev/null || fatal "Failed to enter source directory: $SOURCEDIR"

    # Launch interactive menuconfig
    log "Entering interactive menuconfig; adjust your kernel configuration and save changes when done."
    make menuconfig
    popd >/dev/null

    # Archive the final configuration for future reproducibility.
    archive_config

    log "Menuconfig complete. To build:"
    log "  $0 ${KERNEL_VERSION} \\"
    [[ "$USE_VM" == true ]] && log "    --vm \\"
    [[ "$USE_RT" == true ]] && log "    --rt \\"
    [[ "$USE_LLVM" == true ]] && log "    --llvm"
    exit 0
}

disable_signing() {
    [[ -z "$SOURCEDIR" ]] && fatal "SOURCEDIR not set; cannot disable signing"

    pushd "$SOURCEDIR" >/dev/null || fatal "Failed to enter source directory: $SOURCEDIR"
    log "Disabling kernel signing to avoid build failures due to missing keys"

    # Disable trusted keys & revocation keys. These disable any signing checks.
    if ! ./scripts/config --disable SYSTEM_TRUSTED_KEYS; then
        fatal "Failed to disable SYSTEM_TRUSTED_KEYS"
    fi
    if ! ./scripts/config --disable SYSTEM_REVOCATION_KEYS; then
        fatal "Failed to disable SYSTEM_REVOCATION_KEYS"
    fi
    if ! ./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""; then
        fatal "Failed to unset CONFIG_SYSTEM_TRUSTED_KEYS"
    fi

    popd >/dev/null
}

apply_patches() {
    if [[ "$ADD_PATCHES" != true ]]; then
        log "Patch application is disabled. Skipping."
        return
    fi

    [[ -z "$PATCHDIR" ]] && fatal "PATCHDIR is not set"
    [[ -d "$PATCHDIR" ]] || fatal "Patch directory does not exist: $PATCHDIR"

    shopt -s nullglob
    local patches=("$PATCHDIR"/*.patch)

    if [[ ${#patches[@]} -eq 0 ]]; then
        log "No patches to apply in $PATCHDIR"
        return
    fi

    pushd "$SOURCEDIR" >/dev/null || fatal "Failed to change to source directory: $SOURCEDIR"

    for patch in "${patches[@]}"; do
        log "Preparing to apply patch: $patch"

        # Optional dry-run check to see if patch is applicable
        if patch --dry-run -N -p1 < "$patch" > /dev/null 2>&1; then
            log "Dry-run successful, applying patch: $patch"
            patch -N -p1 < "$patch" || fatal "Failed to apply patch: $patch"
        else
            log "Patch $patch appears to have been already applied or is not applicable. Skipping."
        fi
    done

    popd >/dev/null
}

build_kernel() {
    [[ -z "$SOURCEDIR" ]] && fatal "SOURCEDIR not set for build"

    pushd "$SOURCEDIR" >/dev/null || fatal "Failed to enter source directory: $SOURCEDIR"

    # Build up the make parameters as an array.
    local make_params=()

    # Preserve compiler options; using eval helps split multiword commands properly.
    if [[ -n "${CCOPTS:-}" ]]; then
        eval "make_params+=(\"CC=${CCOPTS}\" \"HOSTCC=${CCOPTS}\")"
    fi

    # Set LLVM options if enabled.
    if [[ "$USE_LLVM" == true || "${LLVM:-false}" == true ]]; then
        make_params+=( "LLVM=1" "LLVM_IAS=1" )
    fi

    local jobs
    jobs=$(nproc)

    log "Building kernel with ${jobs} parallel jobs"
    log "Running: make -j${jobs} ${make_params[*]}"

    # Build the kernel
    make -j"${jobs}" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "${make_params[@]}" || fatal "Kernel build failed"

    # Build kernel modules
    log "Building kernel modules..."
    make -j"${jobs}" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "${make_params[@]}" modules || fatal "Kernel modules build failed"

    # Package kernel into a deb package; fallback LOCALVERSION to 'custom' if not provided.
    log "Packaging kernel with deb-pkg..."
    make -j"${jobs}" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "${make_params[@]}" bindeb-pkg LOCALVERSION=-${SUFFIX:-toeirei} || fatal "Kernel packaging failed"

    popd >/dev/null
}

metapackage() {
    # Ensure required variables are set
    [[ -z "${BUILDPATH:-}" ]] && fatal "BUILDPATH is not set"
    [[ -z "${KERNEL_VERSION:-}" ]] && fatal "KERNEL_VERSION is not set"

    # Normalize KERNEL_VERSION to always have three fields: major.minor.patch
    local normalized_version="$KERNEL_VERSION"
    if [[ "$KERNEL_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
        normalized_version="${KERNEL_VERSION}.0"
    fi

    # Determine build variant based on flags and compute the localversion suffix.
    local package_name=""
    local localversion=""

    if [[ "$USE_RT" == true ]]; then
        package_name="rt-kernel"
        localversion="-rt"
    elif [[ "$USE_VM" == true ]]; then
        package_name="vm-kernel"
        localversion="-vm"
    else
        package_name="vanilla-kernel"
        localversion=""
    fi

    # Append the base local version (e.g. "toeirei" by default, or whatever is set in SUFFIX)
    localversion+="-${SUFFIX:-toeirei}"

    log "Packaging kernel meta-package: ${package_name}"
    log "Computed localversion string: ${localversion}"
    log "Using kernel version: ${normalized_version}"

    # Set up the dependency list based on the normalized kernel version and variant
    local depends="linux-image-${normalized_version}${localversion},linux-headers-${normalized_version}${localversion},linux-libc-dev"

    # Create a package directory for the current build
    local pkg_dir="${BUILDPATH}/${package_name}"
    mkdir -p "$pkg_dir" || fatal "Failed to create package directory: $pkg_dir"

    local cfg_file="${pkg_dir}/${package_name}.cfg"
    log "Generating Debian meta-package config at: ${cfg_file}"

    # Generate the configuration file for the Debian meta-package
    cat <<EOF >"$cfg_file"
Section: kernel
Priority: optional
Homepage: ${HOMEPAGE:-http://example.com}
Standards-Version: ${normalized_version}

Package: ${package_name}
Version: ${normalized_version}${localversion}
Maintainer: ${MAINTAINER:-Your Name <email@example.com>}

Depends: ${depends}
Provides: kernel-image
Replaces: kernel-image
Conflicts: kernel-image
Architecture: amd64
Description: Meta-Package for the ${package_name} built on kernel version ${normalized_version}
EOF

    log "Assembling Debian meta-package using equivs-build"
    pushd "$pkg_dir" >/dev/null || fatal "Unable to change to package directory: $pkg_dir"
    if ! equivs-build "${cfg_file}"; then
        popd >/dev/null
        fatal "Failed to build Debian meta-package using equivs-build"
    fi
    popd >/dev/null

    log "Debian meta-package generated successfully: ${package_name} (version: ${normalized_version}${localversion})"
}






package_kernel() {
    # Recursively find all .deb files in BUILDPATH, including meta-packages in subdirectories.
    mapfile -t all_debs < <(find "$BUILDPATH" -type f -name '*.deb')

    # Ensure we found at least one .deb file.
    if [[ ${#all_debs[@]} -eq 0 ]]; then
        fatal "No .deb packages found in $BUILDPATH"
    fi

    # Filter out debug packages which typically contain "dbg" or "dbgsym" in their names.
    local debs=()
    for deb in "${all_debs[@]}"; do
        if [[ "$deb" == *dbg*.deb || "$deb" == *dbgsym*.deb ]]; then
            log "Skipping debug symbols package: $deb"
        else
            debs+=("$deb")
        fi
    done

    # Abort if, after filtering, no packages remain.
    if [[ ${#debs[@]} -eq 0 ]]; then
        fatal "No non-debug .deb packages found in $BUILDPATH"
    fi

    mkdir -p "$RELEASEDIR" || fatal "Failed to create release directory: $RELEASEDIR"

    # Determine build flavor.
    local flavor="vanilla"  # default flavor
    if [[ "$USE_RT" == true ]]; then
        flavor="rt"
    elif [[ "$USE_VM" == true ]]; then
        flavor="vm"
    fi

    # Append _llvm if LLVM is enabled.
    local llvm_tag=""
    if [[ "$USE_LLVM" == true || "${LLVM:-false}" == true ]]; then
        llvm_tag="_llvm"
    fi

    # Optional custom tag if defined.
    local custom_tag=""
	if [[ -n "${SUFFIX:-}" ]]; then
		custom_tag="_${SUFFIX}"
	else
		custom_tag="_toeirei"
	fi

    # Construct the zip name using your schema: <flavor>_<version>[_llvm][_<custom>].zip
    local zipname="${flavor}-kernel_${KERNEL_VERSION}${llvm_tag}${custom_tag}.zip"
    log "Packaging .deb files into $zipname"

    # Create a zip archive containing only the filtered .deb packages.
    zip -j "$RELEASEDIR/$zipname" "${debs[@]}" || fatal "Zip packaging failed"

    # Generate a SHA-256 checksum for the zip file.
    local checksum_file="$RELEASEDIR/${zipname}.sha256sum"
    sha256sum "$RELEASEDIR/$zipname" > "$checksum_file" || fatal "Checksum generation failed"
    log "Checksum generated at $checksum_file"
}


upload_kernel() {
    # If neither upload flag is enabled, simply return.
    [[ "$UPLOAD_PACKAGECLOUD" == false && "$UPLOAD_NEXUS" == false ]] && return

    # Gather all .deb files from BUILDPATH (non-recursively).
    mapfile -t debs < <(find "$BUILDPATH" -maxdepth 2 -type f -name '*.deb')
    if [[ ${#debs[@]} -eq 0 ]]; then
         fatal "No deb packages found in $BUILDPATH"
    fi

    if [[ "$UPLOAD_PACKAGECLOUD" == true ]]; then
        [[ -z "$PACKAGECLOUD_DEB" ]] && fatal "PACKAGECLOUD_DEB not set"
        log "Uploading to Packagecloud" "INFO"
        for pkg in "${debs[@]}"; do
            # Skip debug packages (they tend to be huge)
            if [[ "$pkg" == *dbg*.deb || "$pkg" == *dbgsym*.deb ]]; then
                log "Skipping debug package: $pkg for Packagecloud"
                continue
            fi

            # Attempt to push the package with retries
            local attempt success=0
            for attempt in {1..3}; do
                if package_cloud push "$PACKAGECLOUD_DEB" "$pkg"; then
                    log "Successfully uploaded $pkg to Packagecloud on attempt $attempt."
                    success=1
                    break
                else
                    log "Attempt $attempt failed for $pkg. Retrying in 2 seconds..." "WARN"
                    sleep 2
                fi
            done
            if [[ $success -ne 1 ]]; then
                log "Failed to upload $pkg to Packagecloud after 3 attempts. Skipping this package." "WARN"
            fi

            # Optional: If you have a second Packagecloud repository, push there too.
            if [[ -n "${PACKAGECLOUD_DEB2:-}" ]]; then
                success=0
                for attempt in {1..3}; do
                    if package_cloud push "$PACKAGECLOUD_DEB2" "$pkg"; then
                        log "Successfully uploaded $pkg to secondary Packagecloud repo on attempt $attempt."
                        success=1
                        break
                    else
                        log "Attempt $attempt to push $pkg to secondary Packagecloud repo failed. Retrying in 2 seconds..." "WARN"
                        sleep 2
                    fi
                done
                if [[ $success -ne 1 ]]; then
                    log "Failed to upload $pkg to secondary Packagecloud repo after 3 attempts." "WARN"
                fi
            fi
        done
    fi

    if [[ "$UPLOAD_NEXUS" == true ]]; then
         [[ -z "$NEXUS_USER" || -z "$NEXUS_PW" || -z "$NEXUS_REPO" ]] && fatal "Nexus credentials or repo not configured"
         log "Uploading to Nexus" "INFO"
         for pkg in "${debs[@]}"; do
			curl -u "${NEXUS_USER}:${NEXUS_PW}" -H "Content-Type: multipart/form-data" --data-binary "@${pkg}" "${NEXUS_REPO}"
         done
    fi
}

cleanup_artifacts() {
    log "Starting cleanup of build artifacts..."

    # Remove the extracted source directory.
    if [[ -n "${SOURCEDIR:-}" && -d "$SOURCEDIR" ]]; then
        log "Removing source directory: $SOURCEDIR"
        rm -rf "$SOURCEDIR" || log "Warning: Failed to remove $SOURCEDIR"
    fi

    # Optionally remove the downloaded tarball.
    #local tarball_path="$BUILDPATH/linux-${KERNEL_VERSION}.tar.xz"
    #if [[ -f "$tarball_path" ]]; then
    #    log "Removing tarball: $tarball_path"
    #    rm -f "$tarball_path" || log "Warning: Failed to remove $tarball_path"
    #fi

    # Remove built .deb packages and build metadata files.
    log "Removing generated .deb packages and build metadata from $BUILDPATH"
    find "$BUILDPATH" -maxdepth 1 -type f \( -name '*.deb' -or -name '*.buildinfo' -or -name '*.changes' \) -exec rm -f {} +

    # Remove extracted kernel directories (e.g. linux-6.14.6).
    for dir in "$BUILDPATH"/linux-*; do
        if [[ -d "$dir" ]]; then
            log "Removing extracted kernel directory: $dir"
            rm -rf "$dir" || log "Warning: Failed to remove directory $dir"
        fi
    done

    # Remove meta-package directories (e.g., vanilla-kernel, rt-kernel, vm-kernel).
    for meta_dir in "$BUILDPATH"/*kernel; do
        if [[ -d "$meta_dir" ]]; then
            log "Removing meta-package directory: $meta_dir"
            rm -rf "$meta_dir" || log "Warning: Could not remove meta-package directory $meta_dir"
        fi
    done

    log "Cleanup completed."
}


log_environment() {
    log $"Build Environment:
Kernel: ${KERNEL_VERSION} | CPUs: $(nproc) | Mem: $(free -h | awk '/Mem:/{print $2}')
Toolchain: $(gcc --version | head -n1) | CC: ${CCOPTS:-system default}
Options: LLVM=$USE_LLVM, RT=$USE_RT, VM=$USE_VM, PATCHES=$ADD_PATCHES, UPLOAD_NEXUS=$UPLOAD_NEXUS, UPLOAD_PACKAGECLOUD=$UPLOAD_PACKAGECLOUD" "INFO"
}

archive_config() {
    [[ -z "$SOURCEDIR" || -z "$CONFIGDIR" ]] && fatal "SOURCEDIR or CONFIGDIR not set"

    local flavor="vanilla"
    [[ "$USE_VM" == true ]] && flavor="vm"

    log "Archiving .config to ${CONFIGDIR}/${flavor}.config"
    cp "${SOURCEDIR}/.config" "${CONFIGDIR}/${flavor}.config"
}

apply_llvm_tweaks() {
    [[ "$USE_LLVM" != true ]] && return
    [[ -z "$SOURCEDIR" ]] && fatal "SOURCEDIR is not set"

    pushd "$SOURCEDIR" >/dev/null || fatal "Cannot enter $SOURCEDIR"
    log "Applying LLVM-specific kernel config tweaks (LTO enabled)"
    ./scripts/config --enable LTO_CLANG
    ./scripts/config --enable LTO_CLANG_THIN
    ./scripts/config --disable LTO_NONE
    popd >/dev/null
}

apply_rt_tweaks() {
    [[ "$USE_RT" != true ]] && return
    [[ -z "$SOURCEDIR" ]] && fatal "SOURCEDIR is not set"

    pushd "$SOURCEDIR" >/dev/null || fatal "Cannot enter $SOURCEDIR"
    log "Applying Real-Time kernel scheduler config tweaks"
    ./scripts/config --enable PREEMPT_RT
	./scripts/config --enable PREEMPT_LAZY
    ./scripts/config --set-val PREEMPT 3
    ./scripts/config --set-val SCHED_DEBUG 0
    popd >/dev/null
}

generate_source_package() {
    [[ -z "$SOURCEDIR" || -z "$KERNEL_VERSION" ]] && 
        fatal "Missing vars for source package generation"

    local suffix="${SUFFIX:-toeirei}"
    local package_name="vanilla-kernel"
    [[ "$USE_RT" == true ]] && package_name="rt-kernel"
    [[ "$USE_VM" == true ]] && package_name="vm-kernel"

    pushd "$SOURCEDIR/.." >/dev/null || fatal "Failed to enter source parent dir"

    # Create orig tarball (required for quilt format)
    log "Creating upstream tarball..."
    tar -czf "${package_name}_${KERNEL_VERSION}.orig.tar.gz" "$(basename "$SOURCEDIR")" || 
        fatal "Failed to create orig tarball"

    pushd "$(basename "$SOURCEDIR")" >/dev/null || fatal "Failed to enter source dir"

    # Set up minimal debian directory
    mkdir -p debian || fatal "Failed creating debian dir"
    cat > debian/control <<EOF
Source: ${package_name}
Section: kernel
Priority: optional
Maintainer: ${MAINTAINER:-"Kernel Builder <kernel@$(hostname)>"}
Build-Depends: debhelper-compat (= 13), bc, flex, bison, libssl-dev
Standards-Version: 4.6.2

Package: ${package_name}
Architecture: any
Description: Custom built Linux kernel ${KERNEL_VERSION}-${suffix}
 Built using a mildly cursed Bash script
EOF

    # Required packaging files
    echo "13" > debian/compat
    mkdir -p debian/source
    echo "3.0 (quilt)" > debian/source/format
    echo "1.0" > debian/source/local-options

    # Minimal changelog
    cat > debian/changelog <<EOF
${package_name} (${KERNEL_VERSION}-${suffix}) unstable; urgency=low

  * YOLO-built kernel package
  * Mildly cursed edition

 -- ${MAINTAINER:-"Kernel Builder <kernel@$(hostname)>"}  $(date -R)
EOF

    # Build the package
    log "Building source package..."
    dpkg-source -b . || fatal "dpkg-source failed"

    # Move artifacts
    mkdir -p "$RELEASEDIR"

    # Archive the source artifacts
    local archive_name="${package_name}_${KERNEL_VERSION}_${suffix}_source.zip"
    zip -j "$RELEASEDIR/$archive_name" ../${package_name}_${KERNEL_VERSION}* || fatal "Zip packaging failed"

    # SHA256 checksum
    local checksum_file="$RELEASEDIR/${archive_name}.sha256sum"
    sha256sum "$RELEASEDIR/$archive_name" > "$checksum_file" || fatal "Checksum generation failed"

    # Clean up raw source files
    rm -f ../${package_name}_${KERNEL_VERSION}*.dsc ../${package_name}_${KERNEL_VERSION}*.tar.*

    popd >/dev/null # source dir
    popd >/dev/null # source parent dir

    log "Source package archive created: $archive_name"
    log "Checksum generated at $checksum_file"
}


main() {
    # Capture the start time
    local start_time
    start_time=$(date +%s)

    parse_config
    parse_args "$@"

    # Handle version detection
    if [[ -z "$KERNEL_VERSION" ]]; then
        log "No version specified, detecting latest stable version..."
        if ! KERNEL_VERSION=$(detect_latest_kernel 2>/dev/null); then
            fatal "Could not determine latest kernel version"
        fi
        log "Detected latest stable version: $KERNEL_VERSION"
    fi

    # Command routing
    if [[ "${MENUCONFIG:-false}" == true ]]; then
        run_menuconfig
    elif [[ "$PUBLISH_ONLY" == true ]]; then
        release_to_github "$KERNEL_VERSION"
    elif [[ "$CLEAN_BUILD" == true ]]; then
        cleanup_artifacts
    else
        run_standard_build
    fi

    # Calculate and log build duration in HH:MM:SS format
    local end_time elapsed hours minutes seconds elapsed_formatted
    end_time=$(date +%s)
    elapsed=$(( end_time - start_time ))
    hours=$(( elapsed / 3600 ))
    minutes=$(( (elapsed % 3600) / 60 ))
    seconds=$(( elapsed % 60 ))
    elapsed_formatted=$(printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds")
    log "Build completed successfully in ${elapsed_formatted} (HH:MM:SS)." "INFO"

    exit 0
}

run_standard_build() {
    log "Starting build for Linux $KERNEL_VERSION"
    log_environment
    prepare_source_tree
    apply_patches
    generate_source_package
    build_kernel
    metapackage
    upload_kernel
    package_kernel
    config_diff
    archive_config
    cleanup_artifacts

}


main "$@"
