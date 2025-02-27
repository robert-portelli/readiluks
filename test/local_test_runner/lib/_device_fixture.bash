# File: _device_fixture.bash
# Purpose: Provides functions to create and teardown a loopback device as a LUKS container.

declare -gA DEVCONFIG=(
    [TEST_DEVICE]=""  # passed to container as env var in _run-in-docker.bash
    [LUKS_PW]="password"
    [LUKS_LABEL]="TEST_LUKS"
    [MAPPED_DEVICE]=""  # set by setup_luks(): /dev/mapper/LUKS_LABEL
    [VG_NAME]="vgtest"
    [LV_NAME]="lvtest"
    [MAPPED_LVM]=""  # set by setup_lvm(): /dev/mapper/VG_NAME-LV_NAME
    [FS_TYPE]="btrfs"
    [MOUNT_POINT]="/mnt/target"
    [REG_FILE]="$(mktemp /tmp/device_fixture_registry-XXXXXX.log)"
)

register_test_device() {
    [[ -b "$TEST_DEVICE" ]] || {
        echo "ERROR: $TEST_DEVICE is not a block device" >&2
        return 1
    }
    DEVCONFIG[TEST_DEVICE]="$TEST_DEVICE"

    echo "LOOPBACK ${DEVCONFIG[TEST_DEVICE]}" >> "${DEVCONFIG[REG_FILE]}"
    echo "Found and registered loop device: ${DEVCONFIG[TEST_DEVICE]}" >&2
}


setup_luks() {
    [[ -b "${DEVCONFIG[TEST_DEVICE]}" ]] || {
        echo "ERROR: ${DEVCONFIG[TEST_DEVICE]} is not a valid block device." >&2
        return 1
    }

    if cryptsetup isLuks "${DEVCONFIG[TEST_DEVICE]}" 2>/dev/null; then
        echo "ERROR: ${DEVCONFIG[TEST_DEVICE]} is already a LUKS container." >&2
        return 1
    fi

    if cryptsetup status "${DEVCONFIG[LUKS_LABEL]}" &>/dev/null; then
        echo "ERROR: ${DEVCONFIG[LUKS_LABEL]} is already mapped at /dev/mapper/${DEVCONFIG[LUKS_LABEL]}" >&2
        return 1
    fi

    echo -n "${DEVCONFIG[LUKS_PW]}" | \
        cryptsetup luksFormat \
            --type luks2 -s 256 -h sha512 \
            --label "${DEVCONFIG[LUKS_LABEL]}" \
            --batch-mode \
            "${DEVCONFIG[TEST_DEVICE]}" || return 1

    echo -n "${DEVCONFIG[LUKS_PW]}" | \
        cryptsetup open "${DEVCONFIG[TEST_DEVICE]}" "${DEVCONFIG[LUKS_LABEL]}" || return 1

    DEVCONFIG[MAPPED_DEVICE]="/dev/mapper/${DEVCONFIG[LUKS_LABEL]}"

    echo "LUKS ${DEVCONFIG[MAPPED_DEVICE]}" >> "${DEVCONFIG[REG_FILE]}"
    echo "LUKS container created and opened at ${DEVCONFIG[MAPPED_DEVICE]}" >&2
}

setup_lvm() {
    # Validate that MAPPED_DEVICE is a valid block device
    [[  -b "${DEVCONFIG[MAPPED_DEVICE]}" ]] || {
        echo "ERROR: ${DEVCONFIG[MAPPED_DEVICE]} is not a valid block device." >&2
        return 1
    }

    # Check if the volume group already exists
    if vgs "${DEVCONFIG[VG_NAME]}" &>/dev/null; then
        echo "ERROR: Volume group ${DEVCONFIG[VG_NAME]} already exists." >&2
        return 1
    fi

    # Check if the logical volume already exists
    if lvs "${DEVCONFIG[MAPPED_LVM]}" &>/dev/null; then
        echo "ERROR: Logical volume ${DEVCONFIG[MAPPED_LVM]} already exists." >&2
        return 1
    fi

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

    # Append LVM information to the registry file
    {
        echo "LVM_PV ${DEVCONFIG[MAPPED_DEVICE]}"
        echo "LVM_VG ${DEVCONFIG[VG_NAME]}"
        echo "LVM_LV ${DEVCONFIG[MAPPED_LVM]}"
    } >> "${DEVCONFIG[REG_FILE]}"

    echo "LVM setup complete: ${DEVCONFIG[MAPPED_LVM]}"
}

format_filesystem() {
    if [[ -z "${DEVCONFIG[MAPPED_LVM]}" ]]; then
        echo "Error: No LVM volume found. Cannot format filesystem." >&2
        return 1
    fi

    # Redirect btrfs output to stderr to keep stdout clean for success message
    if ! mkfs."${DEVCONFIG[FS_TYPE]}" -f "${DEVCONFIG[MAPPED_LVM]}" &>/dev/null; then
        echo "Failed to format ${DEVCONFIG[MAPPED_LVM]} as ${DEVCONFIG[FS_TYPE]}" >&2
        return 1
    fi

    echo "Success: ${DEVCONFIG[MAPPED_LVM]} formatted as ${DEVCONFIG[FS_TYPE]}" >&2

    if ! mkdir -p "${DEVCONFIG[MOUNT_POINT]}"; then
        echo "Failed to create mountpoint: ${DEVCONFIG[MOUNT_POINT]}" >&2
        return 1
    fi

    echo "Success: mount point created at ${DEVCONFIG[MOUNT_POINT]}" >&2

    if ! mount -t "${DEVCONFIG[FS_TYPE]}" "${DEVCONFIG[MAPPED_LVM]}" "${DEVCONFIG[MOUNT_POINT]}"; then
        echo "Failed to mount ${DEVCONFIG[MAPPED_LVM]} at ${DEVCONFIG[MOUNT_POINT]}" >&2
        return 1
    fi

    echo "Success: ${DEVCONFIG[MOUNT_POINT]} mounted at ${DEVCONFIG[MAPPED_LVM]} as ${DEVCONFIG[FS_TYPE]}" >&2

    echo "MOUNT ${DEVCONFIG[MOUNT_POINT]}" >> "${DEVCONFIG[REG_FILE]}"
}


teardown_device() {
    if [[ ! -f "${DEVCONFIG[REG_FILE]}" ]]; then
        return 0
    fi

    echo "Starting explicit teardown of device fixture..." >&2

    # Declare an associative array to store registered resources
    declare -A REGFILE

    # Populate REGFILE from the registry file
    while read -r type value; do
        REGFILE[$type]+="$value "  # Append values for multi-entry keys
    done < "${DEVCONFIG[REG_FILE]}"

    # Define teardown order (adjusted for proper dependencies)
    local teardown_order=("MOUNT" "LVM_LV" "LVM_VG" "LVM_PV" "LUKS" "LOOPBACK")

    # Iterate through the teardown order
    for type in "${teardown_order[@]}"; do
        if [[ -n "${REGFILE[$type]}" ]]; then
            for value in ${REGFILE[$type]}; do
                case "$type" in
                    MOUNT)
                        echo "Unmounting $value..." >&2
                        fuser -km "$value" || echo "No blocking processes on $value" >&2
                        umount -l "$value" || echo "Failed to unmount $value" >&2
                        while mountpoint -q "$value"; do
                            echo "Waiting for $value to unmount..." >&2
                            sleep 0.5
                        done
                        rm -rf "$value" || echo "Failed to remove mount point $value" >&2
                        udevadm settle
                        ;;                    LVM_LV)
                        echo "Deactivating and removing logical volume $value..." >&2
                        lvchange -an "$value" || echo "Failed to deactivate LV" >&2
                        lvremove -f "$value" || echo "Failed to remove LV" >&2
                        while lvs "$value" &>/dev/null; do
                            echo "Waiting for logical volume $value to be removed..." >&2
                            sleep 0.5
                        done
                        udevadm settle
                        ;;
                    LVM_VG)
                        echo "Deactivating and removing volume group $value..." >&2
                        vgchange -an "$value" || echo "Failed to deactivate VG" >&2
                        vgremove -f "$value" || echo "Failed to remove VG" >&2
                        while vgs "$value" &>/dev/null; do
                            echo "Waiting for volume group $value to be removed..." >&2
                            sleep 0.5
                        done
                        udevadm settle
                        ;;
                    LVM_PV)
                        echo "Wiping and removing physical volume $value..." >&2
                        pvremove -ff -y "$value" || echo "Failed to remove PV" >&2
                        wipefs -a "$value" || echo "Failed to wipe filesystem signatures on $value" >&2
                        while pvs "$value" &>/dev/null; do
                            echo "Waiting for physical volume $value to be removed..." >&2
                            sleep 0.5
                        done
                        udevadm settle
                        ;;
                    LUKS)
                        echo "Closing LUKS container $value..." >&2

                        # Close the LUKS container with a retry loop
                        while ! cryptsetup close "$value"; do
                            echo "Waiting for LUKS container $value to close..." >&2
                            sleep 0.5
                        done
                        udevadm settle

                        # Overwrite the LUKS header to remove LUKS metadata
                        echo "Wiping LUKS header on ${DEVCONFIG[TEST_DEVICE]}..." >&2
                        dd if=/dev/zero of="${DEVCONFIG[TEST_DEVICE]}" bs=1M count=10 status=none || {
                            echo "Failed to wipe LUKS header on ${DEVCONFIG[TEST_DEVICE]}" >&2
                        }

                        # Verify that the device is no longer a LUKS container
                        if cryptsetup isLuks "${DEVCONFIG[TEST_DEVICE]}"; then
                            echo "ERROR: ${DEVCONFIG[TEST_DEVICE]} is still a LUKS container after wipe." >&2
                            return 1
                        else
                            echo "LUKS metadata successfully removed from ${DEVCONFIG[TEST_DEVICE]}." >&2
                        fi

                        sync && sleep 1
                        ;;
                    LOOPBACK)
                        echo "Resetting loop device $value..." >&2

                        # Since all mounts and mappings should already be removed,
                        # we only need to reset the device

                        # Ensure there are no lingering filesystem signatures
                        echo "Wiping filesystem signatures on $value..." >&2
                        wipefs -a "$value" || echo "Failed to wipe filesystem signatures on $value" >&2

                        # Zero out the first 10 MB to clear potential remnants
                        echo "Zeroing out the start of $value..." >&2
                        dd if=/dev/zero of="$value" bs=1M count=10 status=none || echo "Failed to zero out loopback device" >&2

                        sync
                        udevadm settle

                        # Final validation that the device is "clean"
                        if blkid "$value" &>/dev/null || cryptsetup isLuks "$value"; then
                            echo "ERROR: $value still contains data or LUKS metadata after reset." >&2
                            return 1
                        fi

                        echo "Loopback device $value reset to initial state." >&2
                        ;;

                esac
            done
        fi
    done

    # Remove registry file after successful cleanup
    rm -f "${DEVCONFIG[REG_FILE]}"
    echo "Teardown complete." >&2
}

print_devconfig() {
    for key in "${!DEVCONFIG[@]}"; do
        echo "$key=${DEVCONFIG[$key]}"
    done
}

# Ensure teardown_device() runs when the script exits or gets interrupted
#trap teardown_device EXIT INT TERM
