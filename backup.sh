# /bin/bash


# These are the directories that will be backed up:
SYNCFROM="/boot /etc /home /opt /root /usr"

# This will be the name of the backup:
DIRNAME="$(date +%s)"


function usage {
	echo "Arguments:"
	echo -e "\t-c: Encrypted drive to open and use (Required if '-d' is not specified)"
	echo -e "\t-d: Base directory where all backups are stored (Required if '-c' is not specified)"
	echo -e "\t-h: This help screen"
	echo -e "\t-v: Verbose mode"
	echo ""
	echo "Return values:"
	echo -e "\t0: Backup completed successfully"
	echo -e "\t1: Error encountered during backup"
	echo -e "\t2: Invalid arguments"
}

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

function init {
	if [ -n "${CRYPT}" ]; then
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

function mirror_backup {
	# If we have a previous backup, then we'll make an identical mirror of it for later syncing.
	if [ -d latest ]; then
		echo "Mirroring latest backup..."

		# Because we are preserving links with the -a switch, we have to follow the latest link
		# first before creating the mirror.
		cp -al ${VERBOSE} $(readlink latest) ${DIRNAME} || die
		sync

		echo "Mirror complete"
	fi
}

function perform_backup {
	echo "Performing backup on these directories: ${SYNCFROM}"

	rsync --archive --hard-links --delete ${VERBOSE} ${SYNCFROM} ${DIRNAME} || die
	sync

	if [ -f latest ]; then
		rm latest
	fi
	ln -s ${DIRNAME} latest

	echo "Backup complete"
}

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
