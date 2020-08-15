![Maintenance Badge](https://img.shields.io/badge/Maintained-yes-success)
![Version Badge](https://img.shields.io/badge/Version-2.0-informational)
![Bash Badge](https://img.shields.io/badge/Made_with-Bash-darkblue)

# backup
Script for creating filesystem snapshots.


## Introduction
This script creates snapshots of the desired directories. When it is run, it mirrors the most recent backup and syncs any changes made since then. This allows you to see the system as it was in that moment of time. To minimize space used, the script mirrors with hard links.

By default, the script backs up these root directories: `/boot` `/etc` `/home` `/opt` `/root` `/usr`

**Note**: To back up directories that the user does not have permission to or to back up to a directory where the user is not allowed to write, the script needs to be run with superuser permissions.


## Options
* `-c` Encrypted drive to open and use (Required if `-d` is not specified)
* `-d` Base directory where all backups are stored (Required if `-c` is not specified)
* `-h` Usage screen
* `-v` Verbose mode


## Return Values
* `0` Backup completed successfully
* `1` Backup failed
* `2` Invalid argument passed


## Requisites
For general usage:
* `rsync`

If using an encrypted drive:
* `crypt`
