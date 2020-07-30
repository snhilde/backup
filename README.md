# backup
Script for creating filesystem snapshots.

## Introduction
To back up directories that the user does not have permission to or to back up to a directory where the user is not allowed to write, the script needs to be run with superuser permissions.

By default, it backs up these root directories: `/boot` `/etc` `/home` `/opt` `/root` `/usr`

## Options
* `-c` Encrypted drive to open and use (Required if `-d` is not specified)
* `-d` Base directory where all backups are stored (Required if `-c` is not specified)
* `-h` Usage screen

## Return Values
* `0` Backup completed successfully
* `1` Backup failed
* `2` Invalid argument passed
