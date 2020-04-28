# /bin/bash
# Thank you, Paul Whipp (paulwhippconsulting.com/)


# Note: This is not meant to be a universal backup script. Some work will need to be taken to localize this to a
# particular system.

# This script will perform an incremental backup depending on when the last backup was performed. If there has been no
# backup this month, it will back up everything. Otherwise, it will check when the last backup happened and only save
# the files that have changed since then. It will back up everything in the user's home directory (excluding the
# directories listed in IGNORE_DIRS below) and will also back up /etc every month.
# The only argument to the script is the directory of where the archive should be stored.
# To recreate a backup's snapshot at a specific time, incrementally extract each archive from the largest time (monthly
# level) down to the desired level.

# Customize the settings below for your environment.
# File where backup process will be logged:
LOG_FILE=~/.logs/backup.log
# Directory where archive lists and other informational files will be stored:
INFO_DIR=~/.backup
# Directories to not back up (under the home directory):
IGNORE_DIRS=".cache .ignore"


# Write the provided message to a log file and/or stdout.
# arg 1: message to write.
# arg 2: file to write to (or master log file, if no file specified)
function log {
	# Figure out which file to write to. If a file was specified, use that. Otherwise, use the script's master log file
	# (if specified).
	if [ ${#} -ge 2 ]; then
		local lfile=${2}
	elif [ -n "${LOG_FILE}" ]; then
		local lfile=${LOG_FILE}
	else
		local lfile=
	fi

	if [ ${#} -ge 1 ]; then
		# If the script is being run from the command line, log this line to stdout.
		if [ ${WINDOWID} ]; then
			echo -e "${1}"
		fi
		
		# If a log file was specified, add the line to it.
		if [ -n "${lfile}" ]; then
			echo -e "${1}" >> ${lfile}
		fi
	fi
}

# We'll do a few things to initialize the backup:
# 1. Get the start time.
# 2. Set some environment variables for the backup.
# 3. Make sure we have all the directories we need. 
function init {
	START_TS="$(date +%s)"

	YEAR="$(date +%Y)"
	MONTH="${YEAR}-$(date +%m)"
	WEEK="${MONTH}-$(date +%W)"
	DAY="${WEEK}-$(date +%d)"
	HOUR="${DAY}-$(date +%H)"
	MINUTE="${HOUR}-$(date +%M)"

	LIST_DIR=${INFO_DIR}/lists
	LOG_DIR=${INFO_DIR}/logs
	PROGRAM_DIR=${INFO_DIR}/programs
	ENV_DIR=${INFO_DIR}/env

	mkdir --parents ${INFO_DIR}
	mkdir --parents ${LIST_DIR}
	mkdir --parents ${LOG_DIR}
	mkdir --parents ${PROGRAM_DIR}
	mkdir --parents ${ENV_DIR}

	log "-- $(date) (${START_TS}) --"
}

# Determine what level of backup we need to perform.
function get_level {
	if [ -e ${INFO_DIR}/last ]; then
		LAST="$(cat ${INFO_DIR}/last)"
	else
		LAST="${MONTH}"
	fi

	if [ ! -e ${LOG_DIR}/${MONTH} ]; then
		BACKUP_LEVEL=${MONTH}
		BACKUP_TYPE="monthly"
		NEWER=""
		# If we're doing a monthly backup, we'll also save a copy of /etc.
		sudo tar czpf ${INFO_DIR}/etc.tar.gz /etc
		sudo chown --reference ~ ${INFO_DIR}/etc.tar.gz

	elif [ ! -e ${LOG_DIR}/${WEEK} ]; then
		BACKUP_LEVEL=${WEEK}
		BACKUP_TYPE="weekly"
		NEWER="-newer ${LOG_DIR}/${MONTH}"

	elif [ ! -e ${LOG_DIR}/${DAY} ]; then
		BACKUP_LEVEL=${DAY}
		BACKUP_TYPE="daily"
		NEWER="-newer ${LOG_DIR}/${WEEK}"

	elif [ ! -e ${LOG_DIR}/${HOUR} ]; then
		BACKUP_LEVEL=${HOUR}
		BACKUP_TYPE="hourly"
		NEWER="-newer ${LOG_DIR}/${DAY}"

	elif [ ! -e ${LOG_DIR}/${MINUTE} ]; then
		BACKUP_LEVEL=${MINUTE}
		BACKUP_TYPE="minute"
		NEWER="-newer ${LOG_DIR}/${HOUR}"

	else
		log "Backup already completed this minute"
		log "Exiting..."
		deinit
		exit 1
	fi

	log "Performing ${BACKUP_TYPE} backup..."
	if [ -f ${INFO_DIR}/last ]; then
		log "Date of last backup: $(cat ${INFO_DIR}/last)"
	fi

	TAR_FILE=/tmp/${BACKUP_LEVEL}.tar.gz
}

# Save lists of the installed programs and a snapshot of the environment's settings.
function save_lists {
	log "Creating list of programs and variables..."

	pacman -Q > ${PROGRAM_DIR}/${BACKUP_LEVEL}-Q
	pacman -Qte > ${PROGRAM_DIR}/${BACKUP_LEVEL}-Qte

	set > ${ENV_DIR}/${BACKUP_LEVEL}
}

# Create the archive for the backup.
function create_archive {
	log "Creating archive: ${TAR_FILE}"

	# Create the list of newer files.
	find ~ -depth -type f ${NEWER} > ${LIST_DIR}/${BACKUP_LEVEL}

	# Figure out what directories we don't want to backup.
	for DIR in ${IGNORE_DIRS}; do
		log "\tSkipping ${DIR}"
		cp ${LIST_DIR}/${BACKUP_LEVEL} /tmp/file-list
		grep -v ${DIR} /tmp/file-list > ${LIST_DIR}/${BACKUP_LEVEL}
		rm /tmp/file-list
	done


	# Create the gzipped archive.
	tar -czpf ${TAR_FILE} --files-from ${LIST_DIR}/${BACKUP_LEVEL}
	RET=${?}
	if [ ${RET} -ne 0 ]; then
		log "\ttar error: ${RET}"
		log "\texiting..."
		ERROR="yes"
		clean_up
		deinit
		exit 1
	fi

	SIZE="$(du -h ${TAR_FILE} | awk -F ' ' '{ print $1 }')"
	NUMBER="$(cat ${LIST_DIR}/${BACKUP_LEVEL} | wc -l)"
	log "\tCompressed archive successfully created (${SIZE} bytes in ${NUMBER} files)"
}

# Save the compressed archive to the specified directory.
function save_archive {
	log "Moving archive to ${SAVE_DIR}"
	if [ ! -w ${SAVE_DIR} ]; then
		SUDO=sudo
	fi
	${SUDO} cp ${TAR_FILE} ${SAVE_DIR}
	RET=${?}
	if [ ${RET} -ne 0 ]; then
		log "\tcp error: ${RET}"
		log "\tnot erasing backup at ${TAR_FILE}"
		log "\texiting..."
		deinit
		exit 1
	fi

	sync

	log "Backup complete"
}

# Clean up the temporary files created.
function clean_up {
	# If we backed up /etc, we can remove that archive now (because the main backup has a copy of it now).
	if [ -f ${INFO_DIR}/etc.tar.gz ]; then
		rm ${INFO_DIR}/etc.tar.gz
	fi

	# Remove the local copy of the archive.
	if [ -f ${TAR_FILE} ]; then
		rm ${TAR_FILE}
	fi
}

function deinit {
	# If we're bailing because of an error, remove any (now-inaccurate) info files.
	if [ "${ERROR}" == "yes" ]; then
		for DIR in ${LIST_DIR} ${LOG_DIR} ${PROGRAM_DIR} ${ENV_DIR}; do
			if [ -e ${DIR}/${BACKUP_LEVEL} ]; then
				rm ${DIR}/${BACKUP_LEVEL}
			fi
		done
	else
		# Make note of when this backup happened, to print for the next backup.
		if [ -e ${INFO_DIR}/last ]; then
			rm ${INFO_DIR}/last
		fi
		log "${BACKUP_LEVEL}" "${INFO_DIR}/last"

		END_TS=$(date +%s)
		log "-- $(date) (${END_TS}) --"

		# Save a copy of the log.
		cp ${LOG_FILE} ${LOG_DIR}/${BACKUP_LEVEL}
	fi
}


# Make sure we can write to the specified log file.
if [ -f ${LOG_FILE} ]; then
	rm ${LOG_FILE}
fi
touch ${LOG_FILE}
if [ ${?} -ne 0 ]; then
	echo "Unable to write to specified log file"
	exit 1
fi

# Make sure we have a place to put the archive when the backup is complete.
if [ -d "${1}" ]; then
	SAVE_DIR=${1}
else
	log "Must specifiy directory for archive"
	exit 1
fi

init
get_level
save_lists
create_archive
save_archive
clean_up
deinit
