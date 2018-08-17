# /bin/bash
# Thank you, Paul Whipp (paulwhippconsulting.com/)
# decrypt with:
	# gpg --output <tarfile> <gpgfile>>
	
start_time=`/usr/bin/date +%s`
backup_dir=~/.backup
logfile=~/.logs/backup

ping -w 10 -c 1 drive.google.com > /dev/null
if [ $? -ne 0 ]; then
	echo "No internet for backup"
	exit 1
fi
	
function log {
	/usr/bin/echo -e "\t$1" >> $logfile
}

function get_date {
	if [ ! -e $lists/$month ]; then
		#prepare base backup
		date=$month
		/usr/bin/tar czpf $backup_dir/etc.tar.gz /etc 2> /dev/null
		level=0
		type="monthly"
		
	elif [ ! -e $lists/$week ]; then
		#prepare level 1 backup
		date=$week
		time="-newer $lists/$month"
		level=1
		type="weekly"
		
	elif [ ! -e $lists/$day ]; then
		#prepare level 2 backup
		date=$day
		time="-newer $lists/$week"
		level=2
		type="daily"
		
	else
		log "backup already completed today"
		log "exiting..."
		clean_up
		exit 1
	fi	
}

function set_env {
	timestamp=`/usr/bin/date +%Y-%m-%d-%H-%M-%S`
	year=`/usr/bin/date +%Yy`
	month=$year-`/usr/bin/date +%mm`
	week=$month-`/usr/bin/date +%Ww`
	day=$week-`/usr/bin/date +%dd`

	lists=$backup_dir/lists
	logs=$backup_dir/logs
	programs=$backup_dir/programs
	environment=$backup_dir/environment
	
	get_date
	
	log "beginning level $level backup ($type)..."
	if [ -f $backup_dir/last ]; then
		log "date of last backup: `/usr/bin/less $backup_dir/last`"
	fi
	tarfile=$date.tar.gz
	gpgfile=$tarfile.gpg
}
	
function perform_backup {
	log ""
	log "creating list of programs and variables..."
	/usr/bin/pacman -Q > $programs/$date-Q
	/usr/bin/pacman -Qte > $programs/$date-Qte
	set > $environment/$date

	log "creating archive..."
	/usr/bin/find ~ -depth -type f $time | /usr/bin/grep -v .cache | /usr/bin/grep -v .mozilla | /usr/bin/grep -v .skip > $lists/$date
	/usr/bin/echo $timestamp > $backup_dir/last
	/usr/bin/tar -czpf /tmp/$tarfile --files-from $lists/$date 2> /dev/null
	if [ $? -eq 0 ]; then
		log "tar successfully created"
		log "size of archive: `/usr/bin/du -h /tmp/$tarfile | /usr/bin/awk -F ' ' '{ print $1 }'`"
	else
		log "tar error: $?"
		log "exiting..."
		clean_up 11
		exit 1
	fi
	
	log "number of files backed up: `/usr/bin/less $lists/$date | /usr/bin/wc -l`"

	/usr/bin/gpg --symmetric --batch --passphrase-file $backup_dir/.info --output /tmp/$gpgfile /tmp/$tarfile
	if [ "${?:-0}" -eq 0 ]; then
		log "tar successfully encrypted with gpg"
		log "size of encrypted archive: `/usr/bin/du -h /tmp/$gpgfile | /usr/bin/awk -F ' ' '{ print $1 }'`"
	else
		log "gpg error: $?"
		log "exiting..."
		clean_up 12
		exit 1
	fi
}

function clean_up {
	for file in $backup_dir/etc.tar.gz /tmp/$tarfile /tmp/$gpgfile; do
		if [ -f $file ]; then
			if [ "${1:-0}" -eq 23 ] || [ "${1:-0}" -eq 24 ]; then
				if [ "$file" = "/tmp/$gpgfile" ]; then
					continue
				fi
			fi
			/usr/bin/rm $file
		fi
	done
	
	if [ $1 ]; then
		for dir in lists logs programs environment; do
			if [ -f $dir/$date ]; then
				/usr/bin/rm $dir/$date
			fi
		done
	fi
}

function calculate_time {
	end_time=`/usr/bin/date +%s`
	total_time=$(( end_time - start_time ))
	minutes=$(( $total_time / 60 ))
		if [ $minutes -ne 1 ]; then
			time_m="$minutes minutes"
		else
			time_m="$minutes minute"
		fi
	minutes=$(( $minutes * 60 ))
	total_time=$(( $total_time - $minutes ))
	if [ $total_time -ne 1 ]; then
		time_s="$total_time seconds"
	else
		time_s="$total_time second"
	fi
	
	/usr/bin/echo "$time_m, $time_s"
}
	

/usr/bin/echo "backup started on `/usr/bin/date` (`/usr/bin/date +%s`)" > $logfile
/usr/bin/echo "Backing up..."

set_env
perform_backup
~/bin/gupload /tmp/$gpgfile
clean_up

log ""
log "backup completed in `calculate_time`"
log "-- `/usr/bin/date` --"
cp $logfile $logs/$date
/usr/bin/echo "Backup completed in `calculate_time`"
