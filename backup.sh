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
	echo ""
	echo "Return values:"
	echo -e "\t0: Backup completed successfully"
	echo -e "\t1: Error encountered during backup"
	echo -e "\t2: Invalid arguments"
}

function die {
	echo "Error encountered, reversing progress"
	rm -rf ${SYNCDIR}/${DIRNAME}
	echo "Exiting"
	exit 1
}

function init {
	# Make sure we were passed the correct arguments.
	if [ -z "${SYNCTO}" ] || [ ! -d "${SYNCTO}" ]; then
		echo "Missing base directory ('-d')"
		usage
		exit 2
	fi

	# This is the main directory for all the backups.
	SYNCDIR="${SYNCTO}/backups"

	# Set up our directories.
	if [ ! -d ${SYNCDIR} ]; then
		mkdir ${SYNCDIR}
	fi
	mkdir ${SYNCDIR}/${DIRNAME}
}

function mirror_backup {
	# If we have a previous backup, then we'll make an identical mirror of it and sync it with the
	# current system.
	if [ -d ${SYNCDIR}/latest ]; then
		echo "Mirroring latest backup..."

		cp -adl ${SYNCDIR}/latest ${SYNCDIR}/${DIRNAME} || die
		sync

		echo "Mirror complete"
	fi
}

function perform_backup {
	echo "Performing backup on these directories: ${SYNCFROM}"

	rsync -ahPv --delete ${SYNCFROM} ${SYNCDIR}/${DIRNAME} || die
	sync
	rm ${SYNCDIR}/latest
	ln -s ${SYNCDIR}/${DIRNAME} ${SYNCDIR}/latest

	echo "Backup complete"
}


while getopts "c:d:h" opt; do
	case ${opt} in
		c)
			echo "in progress"
			;;
		d)
			SYNCTO=${OPTARG}
			;;
		h)
			usage
			exit
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
