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
	echo "Error encountered, rolling back progress..."

	if [ -d ${SYNCDIR}/${DIRNAME} ]; then
		rm -rf ${SYNCDIR}/${DIRNAME}
	fi

	echo "Exiting"
	exit 1
}

function init {
	# Make sure we were passed the correct arguments.
	if [ -z "${SYNCTO}" ] || [ ! -d "${SYNCTO}" ]; then
		echo "Missing base directory ('-d')"
		echo ""
		usage
		exit 2
	fi

	# Go to the main directory where all the backups are stored.
	SYNCDIR="${SYNCTO}/backups"
	if [ ! -d ${SYNCDIR} ]; then
		mkdir ${SYNCDIR} || die
	fi
	cd ${SYNCDIR} || die
}

function mirror_backup {
	# If we have a previous backup, then we'll make an identical mirror of it and sync it with the
	# current system.
	if [ -d latest ]; then
		echo "Mirroring latest backup..."

		cp -al ${VERBOSE} $(readlink latest) ${DIRNAME} || die
		sync

		echo "Mirror complete"
	fi
}

function perform_backup {
	echo "Performing backup on these directories: ${SYNCFROM}"

	rsync -ah --delete ${VERBOSE} ${SYNCFROM} ${DIRNAME} || die
	sync
	rm latest
	ln -s ${DIRNAME} latest

	echo "Backup complete"
}


while getopts "c:d:hv" opt; do
	case ${opt} in
		c)
			echo "todo"
			;;
		d)
			SYNCTO=${OPTARG}
			;;
		h)
			usage
			exit
			;;
		v)
			VERBOSE="-v"
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
