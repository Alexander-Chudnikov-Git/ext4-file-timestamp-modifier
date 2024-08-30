#!/bin/bash

# Function to prompt for confirmation
confirm() {
    read -r -p "$1 (y/n): " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

# Function to handle cleanup and exit
cleanup() {
    local EXIT_CODE="${1:-1}"

    if [ "$EXIT_CODE" -lt 0 ] || [ "$EXIT_CODE" -gt 255 ] 2>/dev/null; then
        echo "Invalid exit code: ${EXIT_CODE}."
        exit 1
    fi

    if [ "${AUTO_FAKE_DRIVE}" = true ]; then
        if [ -n "${AUTO_FAKE_DRIVE_LOCATION}" ]; then
            if [[ "${AUTO_FAKE_DRIVE_LOCATION}" == /tmp/* ]]; then
                echo "Cleaning up temporary drive location..."
                rm -rf "${AUTO_FAKE_DRIVE_LOCATION}"
            fi
        fi
    fi

    exit "${EXIT_CODE}"
}

# Function to get the file size in megabytes
get_file_size_in_mb() {
    local FILE_PATH_LOCAL="$1"
    local FILE_SIZE_LOCAL

    if [ -z "${FILE_PATH_LOCAL}" ]; then
        echo "Error: File is required."
        return 1
    fi

    if [ ! -f "${FILE_PATH_LOCAL}" ]; then
        echo "Error: File does not exist."
        return 1
    fi

    FILE_SIZE_LOCAL=$(stat -c%s "${FILE_PATH_LOCAL}")
    echo "$((FILE_SIZE_LOCAL / 1024 / 1024))"
}

# Function to create a fake drive
create_fake_drive() {
    local DRIVE_SIZE_LOCAL="$1"
    local DRIVE_FILE_LOCAL="$2"

    if [ -z "${DRIVE_FILE_LOCAL}" ]; then
        echo "Error: File is required."
        cleanup 1
    fi

    if [ -z "${DRIVE_SIZE_LOCAL}" ]; then
        echo "Error: Size is required."
        cleanup 1
    else
        if ! [[ "${DRIVE_SIZE_LOCAL}" =~ ^[0-9]+$ ]]; then
            echo "Error: Invalid size provided."
            cleanup 1
        fi
    fi

    # Just making sure thet there is enough space to copy file
    DRIVE_SIZE_LOCAL=$((DRIVE_SIZE_LOCAL + 1))

    echo "Creating a fake drive..."
    fallocate -l "${DRIVE_SIZE_LOCAL}M" "${DRIVE_FILE_LOCAL}" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create fake drive."
        cleanup 1
    fi

    local FILE_SIZE=$(stat -c%s "${DRIVE_FILE_LOCAL}")
    local EXPECTED_SIZE=$((DRIVE_SIZE_LOCAL * 1024 * 1024))

    if [ "${FILE_SIZE}" -ne "${EXPECTED_SIZE}" ]; then
        echo "Error: The file size does not match the expected size."
        cleanup 1
    fi

    mkfs -t ext4 "${DRIVE_FILE_LOCAL}" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to format fake drive."
        cleanup 1
    fi

    echo "Fake drive created: ${DRIVE_FILE_LOCAL}"
}

# Function to copy file to the drive
copy_file_to_drive() {
    local FILE_PATH_LOCAL="$1"
    local DRIVE_FILE_LOCAL="$2"

    local DEST_PATH="./$(basename "$FILE_PATH_LOCAL")"

    echo "Copying ${FILE_PATH_LOCAL} to ${DRIVE_FILE_LOCAL}..."

    debugfs -w -R "write $FILE_PATH_LOCAL $DEST_PATH" "$DRIVE_FILE_LOCAL" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy file to drive."
        cleanup 1
    fi

    echo "File copied and drive unmounted successfully."
}

# Function to copy file from drive to the original place
copy_drive_to_file() {
    local FILE_PATH_LOCAL="$1"
    local DRIVE_FILE_LOCAL="$2"
    local ORIGINAL_FILE_PATH_LOCAL="$3"
    local MOUNT_POINT="$4"

    if [[ ! -f "$DRIVE_FILE_LOCAL" ]]; then
        echo "Error: Image file '$DRIVE_FILE_LOCAL' does not exist."
        cleanup 1
    fi

    local LOOP_DEVICE=$(udisksctl loop-setup -f "$DRIVE_FILE_LOCAL" | awk '{print substr($NF, 1, length($NF)-1)}')
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to set up loop device for '$DRIVE_FILE_LOCAL'."
        cleanup 1
    fi

    local MOUNT_POINT=$(udisksctl mount -b "$LOOP_DEVICE" | awk '{print $NF}')
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to mount '$LOOP_DEVICE'."
        udisksctl loop-delete -b "$LOOP_DEVICE" 2>/dev/null
        cleanup 1
    fi

    echo "Mounted $LOOP_DEVICE at $MOUNT_POINT"

    if [[ ! -f "$MOUNT_POINT/$FILE_PATH_LOCAL" ]]; then
        echo "Error: File '$FILE_PATH_LOCAL' does not exist in mounted image."
        udisksctl unmount -b "$LOOP_DEVICE" 2>/dev/null
        udisksctl loop-delete -b "$LOOP_DEVICE" 2>/dev/null
        cleanup 1
    fi

    cp --preserve=timestamps "$MOUNT_POINT/$FILE_PATH_LOCAL" "$ORIGINAL_FILE_PATH_LOCAL" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "File '$FILE_PATH_LOCAL' has been copied from '$DRIVE_FILE_LOCAL' to '$ORIGINAL_FILE_PATH_LOCAL'."
    else
        echo "Error: Failed to copy '$FILE_PATH_LOCAL' from '$DRIVE_FILE_LOCAL'."
    fi

    udisksctl unmount -b "$LOOP_DEVICE" 2>/dev/null
    udisksctl loop-delete -b "$LOOP_DEVICE" 2>/dev/null
}

# Display help information
display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --drive, -d DRIVE           Specify the drive to use (e.g., /dev/sda1)."
    echo "  --file, -f FILE_PATH        Specify the file path for which to modify timestamps."
    echo "  --atime, -a TIMESTAMP       Set the access time (atime) for the file."
    echo "                              Format: YYYY-MM-DD HH:MM:SS.SSSSSSSSS"
    echo "  --ctime, -c TIMESTAMP       Set the inode change time (ctime) for the file."
    echo "                              Format: YYYY-MM-DD HH:MM:SS.SSSSSSSSS"
    echo "  --crtime, -b TIMESTAMP      Set the creation time (crtime) for the file."
    echo "                              Format: YYYY-MM-DD HH:MM:SS.SSSSSSSSS"
    echo "  --mtime, -m TIMESTAMP       Set the data modification time (mtime) for the file."
    echo "                              Format: YYYY-MM-DD HH:MM:SS.SSSSSSSSS"
    echo "  --Atime, -A TIMESTAMP       Set the access time (atime) using a timestamp with nanoseconds."
    echo "                              Format: YYYY-MM-DD HH:MM:SS.SSSSSSSSS +OFFSET"
    echo "  --Ctime, -C TIMESTAMP       Set the inode change time (ctime) using a timestamp with nanoseconds."
    echo "                              Format: YYYY-MM-DD HH:MM:SS.SSSSSSSSS +OFFSET"
    echo "  --CRtime, -B TIMESTAMP      Set the creation time (crtime) using a timestamp with nanoseconds."
    echo "                              Format: YYYY-MM-DD HH:MM:SS.SSSSSSSSS +OFFSET"
    echo "  --Mtime, -M TIMESTAMP       Set the data modification time (mtime) using a timestamp with nanoseconds."
    echo "                              Format: YYYY-MM-DD HH:MM:SS.SSSSSSSSS +OFFSET"
    echo "  --sync-crtime, -s           Synchronize creation time (crtime) with inode change time (ctime) if ctime is not set."
    echo "  -h, --help                  Display this help message and exit."
    echo
    echo "Examples:"
    echo "  $0 --drive /dev/sda1 --file /path/to/file --atime '2024-08-09 08:22:37.404791996' --mtime '2024-08-09 08:22:37.404791996'"
    echo "  $0 -d /dev/sda1 -f /path/to/file -A '2024-08-09 08:22:37.404791996 +0300' -M '2024-08-09 08:22:37.404791996 +0300'"
    echo "  $0 -d ./fake-usb.img -f /file.ext -B '2024-07-28 13:06:21.826639092' -M '2024-08-01 23:53:37.093976012' -A '2024-08-02 00:01:43.109820394' -s"
    echo
    echo "Warning:"
    echo "  Drive should be unmounted before this script is executed. Also it is possible to run it on filesystem images."
    echo "  You can use following commands in order to create virtual usb:"
    echo "    $ fallocate -l <size of virtual drive>M fake-usb.img "
    echo "    $ mkfs -t ext4 fake-usb.img"
}

# Function to convert timestamp to the required format
convert_to_ext4_time() {
    local TIMESTAMP=$1

    local UNIX_TIMESTAMP=$(date -d "$TIMESTAMP" +%s)
    local NANOSECONDS=$(date -d "$TIMESTAMP" +%N)

    local NANOSECONDS_30BIT=$(echo "$NANOSECONDS" | bc)
    NANOSECONDS_30BIT=$(echo "$NANOSECONDS_30BIT % (2^30)" | bc)

    local SECONDS_34BITS=$((UNIX_TIMESTAMP % (2**34)))

    local COMBINED_64BIT=$(( (SECONDS_34BITS) | (NANOSECONDS_30BIT << 34) ))
    local HIGH_32BIT=$(( (COMBINED_64BIT >> 32) & 0xFFFFFFFF ))
    local LOW_32BIT=$(( COMBINED_64BIT & 0xFFFFFFFF ))

    printf "0x%08x 0x%08x\n" "$LOW_32BIT" "$HIGH_32BIT"
}

# Function to generate a random 32-bit unsigned integer
generate_random_extra() {
    echo "0x00000000" # temporary, trying to figure out how to make it work
}

# Function to parse the input timestamp and set the nanoseconds
parse_timestamp() {
    local TIMESTAMP=$1
    local EXT4_EPOCH=$(convert_to_ext4_time "${TIMESTAMP}")
    local SECONDS=$(echo ${EXT4_EPOCH} | cut -d' ' -f1)
    local NANOSECONDS=$(echo ${EXT4_EPOCH} | cut -d' ' -f2)

    echo "${SECONDS} ${NANOSECONDS}"
}

# Function to apply the changes using debugfs
apply_changes() {
    local DRIVE=$1
    local FILE_PATH=$2
    local INODE_NUM=${FILE_PATH} # $(debugfs -R "stat $FILE_PATH" ${DRIVE} | grep "Inode:" | awk '{print $2}')

    if [ -z "${INODE_NUM}" ]; then
        echo "Error: File not found."
        cleanup 1
    fi

    if [ ! -z "${ATIME}" ]; then
        if [ -z "${ATIME_EXTRA}" ]; then
            ATIME_EXTRA=$(generate_random_extra)
        fi
        debugfs -w -R "set_inode_field ${INODE_NUM} i_atime ${ATIME}" ${DRIVE} 2>/dev/null
        debugfs -w -R "set_inode_field ${INODE_NUM} i_atime_extra ${ATIME_EXTRA}" ${DRIVE} 2>/dev/null
        echo "Set i_atime to ${ATIME} with extra ${ATIME_EXTRA}"
    fi

    if [ ! -z "${CTIME}" ]; then
        if [ -z "${CTIME_EXTRA}" ]; then
            CTIME_EXTRA=$(generate_random_extra)
        fi
        debugfs -w -R "set_inode_field ${INODE_NUM} i_ctime ${CTIME}" ${DRIVE} 2>/dev/null
        debugfs -w -R "set_inode_field ${INODE_NUM} i_ctime_extra ${CTIME_EXTRA}" ${DRIVE} 2>/dev/null
        echo "Set i_ctime to ${CTIME} with extra ${CTIME_EXTRA}"
    fi

    if [ ! -z "${CRTIME}" ]; then
        if [ -z "${CRTIME_EXTRA}" ]; then
            CRTIME_EXTRA=$(generate_random_extra)
        fi
        debugfs -w -R "set_inode_field ${INODE_NUM} i_crtime ${CRTIME}" ${DRIVE} 2>/dev/null
        debugfs -w -R "set_inode_field ${INODE_NUM} i_crtime_extra ${CRTIME_EXTRA}" ${DRIVE} 2>/dev/null
        echo "Set i_crtime to ${CRTIME} with extra ${CRTIME_EXTRA}"
    fi

    if [ ! -z "${MTIME}" ]; then
        if [ -z "${MTIME_EXTRA}" ]; then
            MTIME_EXTRA=$(generate_random_extra)
        fi
        debugfs -w -R "set_inode_field ${INODE_NUM} i_mtime ${MTIME}" ${DRIVE} 2>/dev/null
        debugfs -w -R "set_inode_field ${INODE_NUM} i_mtime_extra ${MTIME_EXTRA}" ${DRIVE} 2>/dev/null
        echo "Set i_mtime to ${MTIME} with extra ${MTIME_EXTRA}"
    fi
}

# Main script
main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                display_help
                exit 0
                shift
                ;;
            --drive|-d)
                DRIVE="$2"
                shift
                shift
                ;;
            --file|-f)
                FILE_PATH="$2"
                shift
                shift
                ;;
            --atime|-a)
                ATIME="$2"
                shift
                shift
                ;;
            --ctime|-c)
                CTIME="$2"
                shift
                shift
                ;;
            --crtime|-b)
                CRTIME="$2"
                shift
                shift
                ;;
            --mtime|-m)
                MTIME="$2"
                shift
                shift
                ;;
            --Atime|-A)
                ATIME_PARSED=$(parse_timestamp "$2")
                ATIME=$(echo ${ATIME_PARSED} | cut -d' ' -f1)
                ATIME_EXTRA=$(echo ${ATIME_PARSED} | cut -d' ' -f2)
                shift
                shift
                ;;
            --Ctime|-C)
                CTIME_PARSED=$(parse_timestamp "$2")
                CTIME=$(echo ${CTIME_PARSED} | cut -d' ' -f1)
                CTIME_EXTRA=$(echo ${CTIME_PARSED} | cut -d' ' -f2)
                shift
                shift
                ;;
            --CRtime|-B)
                CRTIME_PARSED=$(parse_timestamp "$2")
                CRTIME=$(echo ${CRTIME_PARSED} | cut -d' ' -f1)
                CRTIME_EXTRA=$(echo ${CRTIME_PARSED} | cut -d' ' -f2)
                shift
                shift
                ;;
            --Mtime|-M)
                MTIME_PARSED=$(parse_timestamp "$2")
                MTIME=$(echo ${MTIME_PARSED} | cut -d' ' -f1)
                MTIME_EXTRA=$(echo ${MTIME_PARSED} | cut -d' ' -f2)
                shift
                shift
                ;;
            --sync-crtime|-s)
                if [ -z "${CTIME}" ]; then
                    CTIME="${CRTIME}"
                    CTIME_EXTRA="${CRTIME_EXTRA}"
                fi
                shift
                ;;
            *)
                echo "Unknown option: $1"
                cleanup 1
                ;;
        esac
    done

    if [ -z "${DRIVE}" ]; then
        if confirm "Drive is not provided, do you whant to create it?"; then
            AUTO_FAKE_DRIVE=true
            AUTO_FAKE_DRIVE_LOCATION="$(mktemp -d)"
            DRIVE="${AUTO_FAKE_DRIVE_LOCATION}/fake-usb.img"

            FILE_SIZE_MB=$(get_file_size_in_mb "${FILE_PATH}")
            if [ $? -ne 0 ]; then
                echo "${FILE_SIZE_MB}"
                cleanup 1
            fi

            create_fake_drive "${FILE_SIZE_MB}" "${DRIVE}"

            copy_file_to_drive "${FILE_PATH}" "${DRIVE}"

            ORIGINAL_FILE_PATH="${FILE_PATH}"
            FILE_PATH="$(basename "$FILE_PATH")"

            #debugfs -R "ls /" "$DRIVE"
        else
            echo "Error: Drive is required."
            cleanup 1
        fi
    fi

    if [ -z "${FILE_PATH}" ]; then
        echo "Error: File path is required."
        cleanup 1
    fi

    apply_changes ${DRIVE} ${FILE_PATH}

    if [ ! -z "${ORIGINAL_FILE_PATH}" ]; then
        copy_drive_to_file "${FILE_PATH}" "${DRIVE}" "${ORIGINAL_FILE_PATH}"
    fi

    cleanup 0
}

main "$@"
