#!/bin/bash

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
    local INODE_NUM=${FILE_PATH} # $(debugfs -R "ncheck ${FILE_PATH}" ${DRIVE} 2>/dev/null | tail -n 1 | awk '{print $1}')

    if [ -z "${INODE_NUM}" ]; then
        echo "Error: File not found."
        exit 1
    fi

    if [ ! -z "${ATIME}" ]; then
        if [ -z "${ATIME_EXTRA}" ]; then
            ATIME_EXTRA=$(generate_random_extra)
        fi
        debugfs -w -R "set_inode_field ${INODE_NUM} i_atime ${ATIME}" ${DRIVE}
        debugfs -w -R "set_inode_field ${INODE_NUM} i_atime_extra ${ATIME_EXTRA}" ${DRIVE}
        echo "Set i_atime to ${ATIME} with extra ${ATIME_EXTRA}"
    fi

    if [ ! -z "${CTIME}" ]; then
        if [ -z "${CTIME_EXTRA}" ]; then
            CTIME_EXTRA=$(generate_random_extra)
        fi
        debugfs -w -R "set_inode_field ${INODE_NUM} i_ctime ${CTIME}" ${DRIVE}
        debugfs -w -R "set_inode_field ${INODE_NUM} i_ctime_extra ${CTIME_EXTRA}" ${DRIVE}
        echo "Set i_ctime to ${CTIME} with extra ${CTIME_EXTRA}"
    fi

    if [ ! -z "${CRTIME}" ]; then
        if [ -z "${CRTIME_EXTRA}" ]; then
            CRTIME_EXTRA=$(generate_random_extra)
        fi
        debugfs -w -R "set_inode_field ${INODE_NUM} i_crtime ${CRTIME}" ${DRIVE}
        debugfs -w -R "set_inode_field ${INODE_NUM} i_crtime_extra ${CRTIME_EXTRA}" ${DRIVE}
        echo "Set i_crtime to ${CRTIME} with extra ${CRTIME_EXTRA}"
    fi

    if [ ! -z "${MTIME}" ]; then
        if [ -z "${MTIME_EXTRA}" ]; then
            MTIME_EXTRA=$(generate_random_extra)
        fi
        debugfs -w -R "set_inode_field ${INODE_NUM} i_mtime ${MTIME}" ${DRIVE}
        debugfs -w -R "set_inode_field ${INODE_NUM} i_mtime_extra ${MTIME_EXTRA}" ${DRIVE}
        echo "Set i_mtime to ${MTIME} with extra ${MTIME_EXTRA}"
    fi
}

# Main script
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
			printf "${ATIME_PARSED}"
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
            exit 1
            ;;
    esac
done

if [ -z "${DRIVE}" ] || [ -z "${FILE_PATH}" ]; then
    echo "Error: Drive and file path are required."
    exit 1
fi

apply_changes ${DRIVE} ${FILE_PATH}

