# /bin/bash


# These are the directories that will be backed up:
SYNCTHESE="/boot /etc /home /opt /root /usr"

# This will be the name of the backup:
DIRNAME="$(date +%s)"


function usage {
	cat <<\EOF
Arguments:
	-c: Encrypted drive to open and use (Required if '-d' is not specified)
	-d: Base directory where all backups are stored (Required if '-c' is not specified)
	-h: This help screen
	-v: Verbose mode

Return values:
	0: Backup completed successfully
	1: Error encountered during backup
	2: Invalid arguments
EOF
}

# This puts the backups into a working state if any error is encountered.
function die {
	if [ -d ${SYNCDIR}/${DIRNAME} ]; then
		echo "Error encountered, rolling back progress..."
		rm -rf ${SYNCDIR}/${DIRNAME}
	else
		echo "Error encountered"
	fi

	echo "Exiting"
	exit 1
}

# This sets up the backup structure.
function init {
	# Figure out where we're going to back up to.
	if [ -n "${CRYPT}" ]; then
		# We need to backup to an encrypted drive.
		CRYPTNAME="backup-${RANDOM}"
		cryptsetup open ${CRYPT} ${CRYPTNAME} || die
		mount /dev/mapper/${CRYPTNAME} /mnt || die
		SYNCTO="/mnt"
	else
		# Make sure we were passed a base directory.
		if [ -z "${SYNCTO}" ] || [ ! -d "${SYNCTO}" ]; then
			echo "Missing base directory ('-d')"
			echo ""
			usage
			exit 2
		fi
	fi

	# Go to the main directory where all the backups are stored.
	if [ "$(basename ${SYNCTO})" == "backups" ]; then
		SYNCDIR="${SYNCTO}"
	else
		SYNCDIR="${SYNCTO}/backups"
		if [ ! -d ${SYNCDIR} ]; then
			mkdir ${SYNCDIR} || die
		fi
	fi

	cd ${SYNCDIR} || die
}

# This creates a duplicate of the latest backup by mirroring the directory structure and hard
# linking all files.
function mirror_backup {
	# If we have a previous backup, then we'll make an identical mirror of it for later syncing.
	if [ -L latest ]; then
		echo "Mirroring latest backup..."

		# Because we are preserving links with the -a switch, we have to follow the latest link
		# first before creating the mirror.
		cp -al ${VERBOSE} $(readlink latest) ${DIRNAME} || die
		sync

		echo "Mirror complete"
	fi
}

# This syncs the chosen directories with the latest backup, creating a snapshot of the current
# system.
function perform_backup {
	echo "Performing backup on these directories: ${SYNCTHESE}"

	# If Verbose mode is enabled, then we'll show all of rsync's output. Otherwise, we'll only show
	# the last 2 lines, which detail the size of the archive and how much was actually backed up.
	if [ -n ${VERBOSE} ]; then
		rsync --archive --hard-links --delete --verbose ${SYNCTHESE} ${DIRNAME} || die
	else
		rsync --archive --hard-links --delete --verbose ${SYNCTHESE} ${DIRNAME} | tail -n 2 || die
	fi
	sync

	if [ -L latest ]; then
		rm latest
	fi
	ln -s ${DIRNAME} latest

	echo "Backup complete"
}

# Currently, this only closes out the encrypted drive, if one was used.
function deinit {
	if [ -n "${CRYPTNAME}" ]; then
		umount /mnt && cryptsetup close ${CRYPTNAME}

		if [ "${?}" == "0" ]; then
			echo "Crypt drive closed successfully"
		else
			echo "Error closing crypt drive"
		fi
	fi
}


while getopts "c:d:hv" opt; do
	case ${opt} in
		c)
			if [ -n "${SYNCTO}" ]; then
				echo "Cannot specify both '-c' and '-d' arguments"
				usage
				exit 2
			fi

			CRYPT=${OPTARG}
			;;
		d)
			if [ -n "${CRYPT}" ]; then
				echo "Cannot specify both '-c' and '-d' arguments"
				usage
				exit 2
			fi

			SYNCTO=${OPTARG}
			;;
		h)
			usage
			exit
			;;
		v)
			VERBOSE="--verbose"
			;;
		*)
			echo "Invalid argument: ${opt}"
			usage
			exit 2
			;;
	esac
done


init
mirror_backup
perform_backup
deinit
