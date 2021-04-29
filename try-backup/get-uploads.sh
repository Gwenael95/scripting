#!/bin/bash

### FTP server Setup ###
FTPD="/mnt/backups"
FTPU="username"
FTPP="mot de passe"
FTPS="192.168.0.00" # A MODIFIER

TMP="/tmp/backup" #save backup files into tmp

if [ ! -d "$TMP" ]; then
  mkdir $TMP
fi

#DOMAIN_ARRAY=()
declare -a DOMAIN_ARRAY # array of all domains containing wp-content/uploads directory
day=$(date +%Y%m%d)

cd $TMP || return

DB_FILE_NAME="$TMP/$day-db.sql"

/usr/bin/mysqldump --defaults-file=/etc/mysql/my.cnf --single-transaction --all-databases --triggers --routines --user=root -password="" > "$DB_FILE_NAME"

tar czf "$DB_FILE_NAME.tgz" -P "$DB_FILE_NAME"
rm "$DB_FILE_NAME"

#will save all DB and domain wp-content/uploads in tmp
for name in /var/www/*; do
    [ ! -d "$name" ] && continue # if different than a dir, break
    backup_files="$name/wp-content/uploads" #final is /uploads
    [ ! -d "$backup_files" ] && continue # if doesn't contains wp-content, break

    domain="$(basename "$name")"
    # Create archive filename.
    archive_file="$TMP/$day-$domain.tgz"
    echo "$archive_file created, containing $backup_files"

    tar czf "$archive_file" -P $backup_files
done

### Dump backup using FTP ###
cd $TMP || return
ftp -n $FTPS <<END_SCRIPT
quote USER $FTPU
quote PASS $FTPP
cd $FTPD
prompt n
mput *.tgz
quit
END_SCRIPT