# backup
Simple script for daily automated backups

## Introduction
This script will perform incremental backups daily and upload the encrypted file to Google Drive. A base (level 0) backup occurs once a month, level 2 is weekly, and level 3 daily.

## Requirements
* [gupload](https://github.com/snhilde/gupload)

## Configuration
Some things to localize the script to your system:
1. If you are not using Arch Linux, you will need to change the two calls to pacman.
2. The script uses ~/.backup as the main repository for the lists and logs it creates. If you don't want to use that directory or don't like the tree structure within it, then you know how to change it.
3. Archives are encrypted with `gpg` before being uploaded. The script assumes your plain-text password is kept in ~/.backup/.info. You might want to configure this.

### Author
Hilde N.
