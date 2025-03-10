# File: _device_fixture.bash
# Purpose: Provides functions to create and teardown a loopback device as a LUKS container.

declare -gA DEVCONFIG  # Declare the array but don't initialize it here

_initialize_DEVCONFIG() {
    DEVCONFIG[TEST_DEVICE]=""  # Passed to container as env var in _run-in-docker.bash
    DEVCONFIG[LUKS_PW]="password"
    DEVCONFIG[LUKS_LABEL]="TEST_LUKS"
    DEVCONFIG[MAPPED_DEVICE]=""  # Set by setup_luks(): /dev/mapper/LUKS_LABEL
    DEVCONFIG[VG_NAME]="vgtest"
    DEVCONFIG[LV_NAME]="lvtest"
    DEVCONFIG[MAPPED_LVM]=""  # Set by setup_lvm(): /dev/mapper/VG_NAME-LV_NAME
    DEVCONFIG[FS_TYPE]="btrfs"
    DEVCONFIG[MOUNT_POINT]="/mnt/target"
    DEVCONFIG[REG_FILE]="$(mktemp /tmp/device_fixture_registry-XXXXXX.log)"
}

_initialize_DEVCONFIG

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

    # Store password in a temporary file to avoid using a pipe
    echo -n "${DEVCONFIG[LUKS_PW]}" > /tmp/luks-pw.tmp

    cryptsetup luksFormat \
        --type luks2 -s 256 -h sha512 \
        --label "${DEVCONFIG[LUKS_LABEL]}" \
        --batch-mode "${DEVCONFIG[TEST_DEVICE]}" < /tmp/luks-pw.tmp || return 1

    rm -f /tmp/luks-pw.tmp

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
    # shellcheck disable=SC2129
    echo "LVM_PV ${DEVCONFIG[MAPPED_DEVICE]}" >> "${DEVCONFIG[REG_FILE]}"
    echo "LVM_VG ${DEVCONFIG[VG_NAME]}" >> "${DEVCONFIG[REG_FILE]}"
    echo "LVM_LV ${DEVCONFIG[MAPPED_LVM]}" >> "${DEVCONFIG[REG_FILE]}"

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
                        echo "Unmounting $value and wiping filesystem signatures..." >&2
                        mount -o remount,ro "$value" 2>/dev/null
                        if fuser -m "$value" >/dev/null 2>&1; then
                            echo "Killing processes using $value..." >&2
                            fuser -km "$value"
                            sleep 1  # Give processes time to terminate
                        else
                            echo "No blocking processes on $value" >&2
                        fi
                        umount -l "$value" || echo "Failed to unmount $value" >&2
                        attempts_remaining=4

                        while mountpoint -q "$value"; do
                            echo "Waiting for $value to unmount... (Attempts remaining: $attempts_remaining)" >&2
                            sleep 0.5

                            (( attempts_remaining-- ))

                            if (( attempts_remaining <= 0 )); then
                                echo "ERROR: Timeout waiting for $value to unmount." >&2
                                return 1
                            fi
                        done
                        rm -rf "$value" || echo "Failed to remove mount point $value" >&2
                        wipefs -a "${DEVCONFIG[MAPPED_LVM]}" || echo "Failed to wipe filesystem signatures on $value" >&2

                        udevadm settle
                        echo "Finished unmounting $value and wiping filesystem signatures" >&2
                        ;;
                    LVM_LV)
                        echo "Deactivating and removing logical volume $value..." >&2
                        lvchange -an "$value" || echo "Failed to deactivate $value" >&2
                        lvremove -f "$value" || echo "Failed to remove $value" >&2
                        while lvs "$value" &>/dev/null; do
                            echo "Waiting for logical volume $value to be removed..." >&2
                            sleep 0.5
                        done

                        # Ensure device-mapper entry is fully removed
                        echo "Removing device-mapper entry for ${DEVCONFIG[MAPPED_LVM]}..." >&2
                        dmsetup remove "${DEVCONFIG[MAPPED_LVM]}" || echo "Failed to remove device-mapper entry" >&2

                        # Wait until the device is no longer listed
                        while dmsetup info "${DEVCONFIG[MAPPED_LVM]}" &>/dev/null; do
                            echo "Waiting for dmsetup to fully remove ${DEVCONFIG[MAPPED_LVM]}..." >&2
                            sleep 0.5
                        done

                        sync && udevadm settle
                        echo "Finished deactivating and removing logical volume $value" >&2
                        ;;
                    LVM_VG)
                        echo "Deactivating and removing volume group $value..." >&2
                        vgchange -an "$value" || echo "Failed to deactivate $value" >&2
                        vgremove -f "$value" || echo "Failed to remove $value" >&2
                        while vgs "$value" &>/dev/null; do
                            echo "Waiting for volume group $value to be removed..." >&2
                            sleep 0.5
                        done
                        udevadm settle
                        echo "Finished deactivating and removing volume group $value" >&2
                        ;;

                    LVM_PV)
                        echo "Wiping and removing physical volume $value..." >&2
                        pvremove -ff -y "$value" || echo "Failed to remove $value" >&2
                        wipefs -a "$value" || echo "Failed to wipe filesystem signatures on $value" >&2
                        while pvs "$value" &>/dev/null; do
                            echo "Waiting for physical volume $value to be removed..." >&2
                            sleep 0.5
                        done
                        udevadm settle
                        echo "Finished wiping and removing physical volume $value" >&2
                        ;;
                    LUKS)
                        echo "Closing LUKS container $value..." >&2

                        timeout=10
                        while ! cryptsetup close "$value" && (( timeout-- > 0 )); do
                            echo "Waiting for LUKS container $value to close..." >&2
                            sleep 0.5
                        done
                        if (( timeout == 0 )); then
                            echo "ERROR: Timeout while closing LUKS container $value" >&2
                            return 1
                        fi

                        # Overwrite the LUKS header to remove LUKS metadata
                        echo "Erasing LUKS header from $value..." >&2

                        cryptsetup erase "$value" || echo "Failed to erase LUKS metadata on $value" >&2

                        # Verify that the device is no longer a LUKS container
                        if cryptsetup isLuks "$value"; then
                            echo "ERROR: $value is still a LUKS container after wipe." >&2
                            return 1
                        else
                            echo "LUKS metadata successfully removed from $value." >&2
                        fi

                        echo "Finished closing LUKS container $value" >&2
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
                        echo "Ensuring test device is clean" >&2
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
