# File: _device_fixture.bash
# Purpose: Provides functions to create and teardown a loopback device as a LUKS container.

declare -gA DEVCONFIG=(
    [IMG_SIZE]="1024M"
    [IMG_FILE]=""  # set by create_device(): /tmp/device-XXXXXX.img
    [TEST_DEVICE]=""  # set by create_device(): /dev/loopX
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

create_device() {
    local size="${1:-${DEVCONFIG[IMG_SIZE]}}"
    local img_file

    img_file="$(mktemp /tmp/device-XXXXXX.img)" || return 1
    DEVCONFIG[IMG_FILE]="$img_file"
    truncate -s "$size" "$img_file" || return 1

    losetup_output=$(losetup --show -f -P "${DEVCONFIG[IMG_FILE]}" 2>/dev/null)
    if [[ -z "$losetup_output" ]]; then
        rm -f "${DEVCONFIG[IMG_FILE]}"
        echo "Failed to create loop device for ${DEVCONFIG[IMG_FILE]}" >&2
        return 1
    fi
    DEVCONFIG[TEST_DEVICE]="$losetup_output"

    # Append to the registry file
    echo "LOOPBACK ${DEVCONFIG[TEST_DEVICE]}" >> "${DEVCONFIG[REG_FILE]}"
    echo "IMAGE ${DEVCONFIG[IMG_FILE]}" >> "${DEVCONFIG[REG_FILE]}"

    echo "Created loop device: ${DEVCONFIG[TEST_DEVICE]} (backed by ${DEVCONFIG[IMG_FILE]})" >&2
}

setup_luks() {
    echo "Setting up LUKS container on ${DEVCONFIG[TEST_DEVICE]}..." >&2

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
    pvcreate "${DEVCONFIG[MAPPED_DEVICE]}"
    vgcreate "${DEVCONFIG[VG_NAME]}" "${DEVCONFIG[MAPPED_DEVICE]}"
    lvcreate -l 100%FREE -n "${DEVCONFIG[LV_NAME]}" "${DEVCONFIG[VG_NAME]}" --zero n

    DEVCONFIG[MAPPED_LVM]="/dev/mapper/${DEVCONFIG[VG_NAME]}-${DEVCONFIG[LV_NAME]}"

    vgchange -ay "${DEVCONFIG[VG_NAME]}"
    lvchange -ay "${DEVCONFIG[MAPPED_LVM]}"

    {
        echo "LVM_PV ${DEVCONFIG[MAPPED_DEVICE]}"
        echo "LVM_VG ${DEVCONFIG[VG_NAME]}"
        echo "LVM_LV ${DEVCONFIG[MAPPED_LVM]}"
    } >> "${DEVCONFIG[REG_FILE]}"

    echo "LVM setup complete: ${DEVCONFIG[MAPPED_LVM]}" >&2
}

format_filesystem() {
    if [[ -z "${DEVCONFIG[MAPPED_LVM]}" ]]; then
        echo "Error: No LVM volume found. Cannot format filesystem." >&2
        return 1
    fi

    echo "Formatting ${DEVCONFIG[MAPPED_LVM]} as ${DEVCONFIG[FS_TYPE]}..." >&2
    mkfs."${DEVCONFIG[FS_TYPE]}" -f "${DEVCONFIG[MAPPED_LVM]}" || return 1

    mkdir -p "${DEVCONFIG[MOUNT_POINT]}"

    mount -t "${DEVCONFIG[FS_TYPE]}" "${DEVCONFIG[MAPPED_LVM]}" "${DEVCONFIG[MOUNT_POINT]}" || return 1

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

    # Define teardown order
    local teardown_order=("MOUNT" "LVM_LV" "LVM_VG" "LVM_PV" "LUKS" "LOOPBACK" "IMAGE")

    # Iterate through the teardown order
    for type in "${teardown_order[@]}"; do
        if [[ -n "${REGFILE[$type]}" ]]; then
            # Example: REGFILE[LOOPBACK]="/dev/loop0 /dev/loop1"
            # This means we must iterate over multiple values for each key.
            for value in ${REGFILE[$type]}; do
                case "$type" in
                    MOUNT)
                        echo "Unmounting $value..." >&2
                        umount "$value" || echo "Failed to unmount $value" >&2
                        ;;
                    LVM_LV)
                        echo "Deactivating logical volume $value..." >&2
                        lvchange -an "$value" || echo "Failed to deactivate LV" >&2
                        lvremove -f "$value" || echo "Failed to remove LV" >&2
                        ;;
                    LVM_VG)
                        echo "Deactivating volume group $value..." >&2
                        vgchange -an "$value" || echo "Failed to deactivate VG" >&2
                        vgremove -f "$value" || echo "Failed to remove VG" >&2
                        ;;
                    LVM_PV)
                        echo "Removing physical volume $value..." >&2
                        pvremove -f "$value" || echo "Failed to remove PV" >&2
                        ;;
                    LUKS)
                        echo "Closing LUKS container $value..." >&2
                        cryptsetup close "$value" || echo "Failed to close LUKS container" >&2
                        ;;
                    LOOPBACK)
                        echo "Removing loop device $value..." >&2
                        losetup -d "$value" || echo "Failed to remove loop device" >&2
                        ;;
                    IMAGE)
                        echo "Deleting image file $value..." >&2
                        rm -f "$value" || echo "Failed to delete image file" >&2
                        ;;
                esac
            done
        fi
    done

    # Remove registry file after successful cleanup
    rm -f "${DEVCONFIG[REG_FILE]}"
    echo "Teardown complete." >&2
}
# Ensure teardown_device() runs when the script exits or gets interrupted
trap teardown_device EXIT INT TERM
