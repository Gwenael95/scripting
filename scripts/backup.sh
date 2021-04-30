#!/bin/bash

########################################################################
# This script is used to save all MySQL database from our server,      #
# and wp-content/uploads from each client wordpress site.              #
# We will zip all these files and send them to our backup server.      #
########################################################################

## region FTP server Setup ###
FTPD="/var/backups/backupweb"
FTPU="username"
FTPP="mot de passe"
FTPS="192.168.0.00" # A MODIFIER
## endregion

DAY=$(date +%Y%m%d)

TMP="/tmp/backup" #save backup files into tmp

if [ ! -d "$TMP" ]; then
  mkdir $TMP
fi
cd $TMP || return

## region save mysql
DB_FILE_NAME="$TMP/$DAY-db.sql"

/usr/bin/mysqldump --defaults-file=/etc/mysql/my.cnf --single-transaction --all-databases --triggers --routines --user=root --password="" > "$DB_FILE_NAME"
tar czf "$DB_FILE_NAME.tgz" -P "$DB_FILE_NAME"
rm "$DB_FILE_NAME"
## endregion

## region save domain wp-content/uploads in tmp
for name in /var/www/*; do
    [ ! -d "$name" ] && continue # if different than a dir, break
    backup_files="$name/wp-content/uploads" #final is /uploads
    [ ! -d "$backup_files" ] && continue # if doesn't contains wp-content, break

    domain="$(basename "$name")"
    # Create archive filename.
    archive_file="$TMP/$DAY-$domain.tgz"
    echo "$archive_file created, containing $backup_files"

    tar czf "$archive_file" -P "$backup_files"
done
## endregion


## region Dump backup using FTP ###
cd $TMP || return
ftp -n $FTPS <<END_SCRIPT
quote USER $FTPU
quote PASS $FTPP
cd $FTPD
mkdir $DAY-log
cd $DAY-log
prompt n
mput *.tgz
quit
END_SCRIPT
## endregion
