# ext4-file-timestamp-modifier
This simple sctript might help you to modify cr/c/m/a|time of any file in ext4 filesystem


# Usage
## Options:

- `--drive, -d DRIVE`
  Specify the drive to use (e.g., /dev/sda1).
  If drive is not provided, program can create temporary one by itself

- `--file, -f FILE_PATH`
  Specify the file path for which to modify timestamps.

- `--atime, -a TIMESTAMP`
  Set the access time (atime) for the file.
  Format: `YYYY-MM-DD HH:MM:SS.SSSSSSSSS`

- `--ctime, -c TIMESTAMP`
  Set the inode change time (ctime) for the file.
  Format: `YYYY-MM-DD HH:MM:SS.SSSSSSSSS`

- `--crtime, -b TIMESTAMP`
  Set the creation time (crtime) for the file.
  Format: `YYYY-MM-DD HH:MM:SS.SSSSSSSSS`

- `--mtime, -m TIMESTAMP`
  Set the data modification time (mtime) for the file.
  Format: `YYYY-MM-DD HH:MM:SS.SSSSSSSSS`

- `--Atime, -A TIMESTAMP`
  Set the access time (atime) using a timestamp with nanoseconds.
  Format: `YYYY-MM-DD HH:MM:SS.SSSSSSSSS +OFFSET`

- `--Ctime, -C TIMESTAMP`
  Set the inode change time (ctime) using a timestamp with nanoseconds.
  Format: `YYYY-MM-DD HH:MM:SS.SSSSSSSSS +OFFSET`

- `--CRtime, -B TIMESTAMP`
  Set the creation time (crtime) using a timestamp with nanoseconds.
  Format: `YYYY-MM-DD HH:MM:SS.SSSSSSSSS +OFFSET`

- `--Mtime, -M TIMESTAMP`
  Set the data modification time (mtime) using a timestamp with nanoseconds.
  Format: `YYYY-MM-DD HH:MM:SS.SSSSSSSSS +OFFSET`

- `--sync-crtime, -s`
  Synchronize creation time (crtime) with inode change time (ctime) if ctime is not set.

- `-h, --help`
  Display this help message and exit.

## Examples:

- `./time-edit.sh --drive /dev/sda1 --file /path/to/file --atime '2024-08-09 08:22:37.404791996' --mtime '2024-08-09 08:22:37.404791996'`

- `./time-edit.sh -d /dev/sda1 -f /path/to/file -a '0x66b5a79d' -M '2024-08-09 08:22:37.404791996 +0300'`

- `./time-edit.sh -d ./fake-usb.img -f /file.ext -B '2024-07-28 13:06:21.826639092' -M '2024-08-01 23:53:37.093976012' -A '2024-08-02 00:01:43.109820394' -s`

- `./time-edit.sh -f /some.file -B '2024-07-28 13:06:21.826639092' -M '2024-08-01 23:53:37.093976012' -A '2024-08-02 00:01:43.109820394' -s`

## Warning:

- Drive should be unmounted before this script is executed. Also, it is possible to run it on filesystem images.
- You can use the following commands to create a virtual USB:
  - `$ fallocate -l <size of virtual drive>M fake-usb.img`
  - `$ mkfs -t ext4 fake-usb.img`

- Do not forget to run `sudo chmod -R 0777 ./time-edit.sh` before you run this program.
