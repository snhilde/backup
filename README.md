# backup
Simple script for incremental backups

## Introduction
This script will perform an incremental backup depending on when the last
backup was performed. If there has been no backup this month, it will back up
everything. Otherwise, it will check when the last backup happened and only
save # the files that have changed since then. It will back up everything in
the user's home directory (excluding the # directories listed in IGNORE_DIRS
below) and will also back up /etc every month. # The only argument to the
script is the directory of where the archive should be stored. # To recreate a
backup's snapshot at a specific time, incrementally extract each archive from
the largest time (monthly # level) down to the desired level.

## Caveat
Please note that this is not meant to be a universal backup script. It's a
working product, not a full-featured system. Some work will need to be taken to
localize this to your particular system.

## Settings
You will want to change these settings for your system:
* `LOG_FILE` - file to log backup process
* `INFO_DIR` - directory where small, informational files will be stored
* `IGNORE_DIRS` - directories to **not** include in backup.
