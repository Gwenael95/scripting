#!/bin/bash

########################################################################
# This script is used to save all MySQL database from our server,      #
# and wp-content/uploads from each client wordpress site.              #
# We will zip all these files and send them to our backup server.      #
########################################################################

## region FTP server Setup ###
_FTPD="/var/backups/backupweb"
_FTPU="username"
_FTPP="mot de passe"
_FTPS="192.168.0.00" # A MODIFIER
## endregion

_DAY=$(date +%Y%m%d)

_TMP="/tmp/backup" #save backup files into tmp

if [ ! -d "$_TMP" ]; then
  mkdir $_TMP
fi
cd $_TMP || return

## region save mysql
_DB_FILE_NAME="$_TMP/$_DAY-db.sql"

/usr/bin/mysqldump --defaults-file=/etc/mysql/my.cnf --single-transaction --all-databases --triggers --routines --user=root --password="" > "$_DB_FILE_NAME"
tar czf "$_DB_FILE_NAME.tgz" -P "$_DB_FILE_NAME"
rm "$_DB_FILE_NAME"
## endregion

## region save domain wp-content/uploads in tmp
for name in /var/www/*; do
    [ ! -d "$name" ] && continue # if different than a dir, break
    backup_files="$name/wp-content/uploads" #final is /uploads
    [ ! -d "$backup_files" ] && continue # if doesn't contains wp-content, break

    domain="$(basename "$name")"
    # Create archive filename.
    archive_file="$_TMP/$_DAY-$domain.tgz"
    echo "$archive_file created, containing $backup_files"

    tar czf "$archive_file" -P "$backup_files"
done
## endregion


## region Dump backup using FTP ###
cd $_TMP || return
ftp -n $_FTPS <<END_SCRIPT
quote USER $_FTPU
quote PASS $_FTPP
cd $_FTPD
mkdir $_DAY-log
cd $_DAY-log
prompt n
mput *.tgz
quit
END_SCRIPT
## endregion
