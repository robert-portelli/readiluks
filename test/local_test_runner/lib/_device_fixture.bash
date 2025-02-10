# File: _device_fixture.bash
# Purpose: Provides functions to create and teardown a loopback device as a LUKS container.

declare -gA DEVCONFIG=(
    [IMG_SIZE]="1024M"
    [IMG_FILE]="" # set by create_device(): /tmp/device-XXXXXX.img
    [TEST_DEVICE]="" # set by create_device(): /dev/loopX
    [LUKS_PW]="password"
    [LUKS_LABEL]="TEST_LUKS"
    [MAPPED_DEVICE]="" # set by setup_luks(): /dev/mapper/LUKS_LABEL
    [VG_NAME]="vgtest"
    [LV_NAME]="lvtest"
    [MAPPED_LVM]="" # set by setup_lvm(): /dev/mapper/VG_NAME-LV_NAME
    [FS_TYPE]="btrfs"
    [MOUNT_POINT]="/mnt/target"
)

create_device() {
    local size="${1:-${DEVCONFIG[IMG_SIZE]}}"
    local img_file

    img_file="$(mktemp /tmp/device-XXXXXX.img)" || return 1
    DEVCONFIG[IMG_FILE]="$img_file"
    truncate -s "$size" "$img_file" || return 1

    losetup_output=$(losetup --show -f -P "${DEVCONFIG[IMG_FILE]}" 2>/dev/null)
    if [[ -z "$losetup_output" ]]; then
        rm -f "${DEVCONFIG[IMG_FILE]}"
        echo "Failed to create loop device for ${DEVCONFIG[IMG_FILE]}"
        return 1
    fi
    DEVCONFIG[TEST_DEVICE]="$losetup_output"

    echo "Created loop device: ${DEVCONFIG[TEST_DEVICE]} (backed by ${DEVCONFIG[IMG_FILE]})"
}

setup_luks() {
    echo "Setting up LUKS container on ${DEVCONFIG[TEST_DEVICE]}..."

    echo -n "${DEVCONFIG[LUKS_PW]}" | \
        cryptsetup luksFormat \
            --type luks2 -s 256 -h sha512 \
            --label "${DEVCONFIG[LUKS_LABEL]}" \
            --batch-mode \
            "${DEVCONFIG[TEST_DEVICE]}" || return 1

    echo -n "${DEVCONFIG[LUKS_PW]}" | \
        cryptsetup open "${DEVCONFIG[TEST_DEVICE]}" "${DEVCONFIG[LUKS_LABEL]}" || return 1

    DEVCONFIG[MAPPED_DEVICE]="/dev/mapper/${DEVCONFIG[LUKS_LABEL]}"

    echo "LUKS container created and opened at ${DEVCONFIG[MAPPED_DEVICE]}"
}

setup_lvm() {
    echo "Setting up LVM on ${DEVCONFIG[MAPPED_DEVICE]}..."

    # Create physical volume (PV)
    pvcreate "${DEVCONFIG[MAPPED_DEVICE]}" || { echo "Failed to create PV"; return 1; }

    # Create volume group (VG)
    vgcreate "${DEVCONFIG[VG_NAME]}" "${DEVCONFIG[MAPPED_DEVICE]}" || { echo "Failed to create VG"; return 1; }

    # Create logical volume (LV)
    lvcreate -l 100%FREE \
        -n "${DEVCONFIG[LV_NAME]}" \
        "${DEVCONFIG[VG_NAME]}" \
        --zero n || { echo "Failed to create LV"; return 1; }

    DEVCONFIG[MAPPED_LVM]="/dev/mapper/${DEVCONFIG[VG_NAME]}-${DEVCONFIG[LV_NAME]}"

    # Ensure volume group is active
    vgchange -ay "${DEVCONFIG[VG_NAME]}" || { echo "Failed to activate VG"; return 1; }

    # Explicitly activate the logical volume
    lvchange -ay "${DEVCONFIG[MAPPED_LVM]}" || { echo "Failed to activate LV"; return 1; }

    # Trigger udev to create device nodes
    udevadm trigger
    udevadm settle

    # Verify LV exists
    if [[ ! -e "${DEVCONFIG[MAPPED_LVM]}" ]]; then
        echo "Logical volume not found in /dev/mapper/, attempting to manually create device node..."

        # Get dynamic major/minor numbers
        dm_info=$(dmsetup info "${DEVCONFIG[VG_NAME]}-${DEVCONFIG[LV_NAME]}" | awk '/Major, minor:/ {print $3, $4}' | tr -d ',')
        if [[ -z "$dm_info" ]]; then
            echo "Failed to retrieve major/minor numbers for ${DEVCONFIG[MAPPED_LVM]}"
            return 1
        fi
        read -r major minor <<< "$dm_info"

        # Manually create the device node
        mknod "${DEVCONFIG[MAPPED_LVM]}" b "$major" "$minor"
    fi

    echo "LVM setup complete: ${DEVCONFIG[MAPPED_LVM]}"
}

check_fs_tools() {
    local fs_tool
    case "${DEVCONFIG[FS_TYPE]}" in
        btrfs) fs_tool="btrfs-progs" ;;
        xfs) fs_tool="xfsprogs" ;;
        ext4) fs_tool="e2fsprogs" ;;
        *) echo "Unsupported filesystem: ${DEVCONFIG[FS_TYPE]}"; return 1 ;;
    esac

    if ! command -v mkfs."${DEVCONFIG[FS_TYPE]}" &>/dev/null; then
        echo "Missing required package: $fs_tool. Please install it inside the container."
        return 1
    fi
}

format_filesystem() {
    if [[ -z "${DEVCONFIG[MAPPED_LVM]}" ]]; then
        echo "Error: No LVM volume found. Cannot format filesystem."
        return 1
    fi

    echo "Formatting ${DEVCONFIG[MAPPED_LVM]} as ${DEVCONFIG[FS_TYPE]}..."
    mkfs."${DEVCONFIG[FS_TYPE]}" -f "${DEVCONFIG[MAPPED_LVM]}" || return 1

    mkdir -p "${DEVCONFIG[MOUNT_POINT]}"

    echo "Mounting ${DEVCONFIG[MAPPED_LVM]} to ${DEVCONFIG[MOUNT_POINT]}..."
    mount -t "${DEVCONFIG[FS_TYPE]}" "${DEVCONFIG[MAPPED_LVM]}" "${DEVCONFIG[MOUNT_POINT]}" || return 1
}

teardown_device() {
    # Unmount if mounted
    if findmnt -rn "${DEVCONFIG[MOUNT_POINT]}" &>/dev/null; then
        umount "${DEVCONFIG[MOUNT_POINT]}"
    fi

    # Deactivate LVM
    if vgs "${DEVCONFIG[VG_NAME]}" &>/dev/null; then
        if lvs "${DEVCONFIG[MAPPED_LVM]}" &>/dev/null; then
            lvchange -an "${DEVCONFIG[MAPPED_LVM]}"
        fi
        vgchange -an "${DEVCONFIG[VG_NAME]}"
    fi

    # Close LUKS
    if [[ -n "${DEVCONFIG[MAPPED_DEVICE]}" ]]; then
        cryptsetup close "${DEVCONFIG[LUKS_LABEL]}" 2>/dev/null
        DEVCONFIG[MAPPED_DEVICE]=""
    fi

    # Remove loop device and image
    if [[ -n "${DEVCONFIG[TEST_DEVICE]}" && -n "${DEVCONFIG[IMG_FILE]}" ]]; then
        losetup -d "${DEVCONFIG[TEST_DEVICE]}" 2>/dev/null
        rm -f "${DEVCONFIG[IMG_FILE]}"
        # Reset all device-related variables manually
        DEVCONFIG[MAPPED_LVM]=""
        DEVCONFIG[MAPPED_DEVICE]=""
        DEVCONFIG[TEST_DEVICE]=""
        DEVCONFIG[IMG_FILE]=""
        echo "Cleaned up loop device and image file."
    fi
}
