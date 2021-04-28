#!/bin/bash

#########################
######TO BE MODIFIED#####

### System Setup ###
BACKUP=YOUR_LOCAL_BACKUP_DIR

### MySQL Setup ###
MUSER="coding"
MPASS="Coding123!"
MHOST="localhost"

### FTP server Setup ###
FTPD="/mnt/backups"
FTPU="backup"
FTPP="coding"
FTPS="192.168.0.0" # A MODIFIER

######DO NOT MAKE MODIFICATION BELOW#####
#########################################

### Binaries ###
TAR="$(which tar)"
GZIP="$(which gzip)"
FTP="$(which ftp)"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

### Today + hour in 24h format ###
NOW=$(date +"%d%H")

### Create hourly dir ###

mkdir $BACKUP/$NOW

### Get all databases name ###
DBS="$($MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse 'show databases')"
for db in $DBS
do

### Create dir for each databases, backup tables in individual files ###
  mkdir $BACKUP/$NOW/$db

  # shellcheck disable=SC2006
  for i in `echo "show tables" | $MYSQL -u $MUSER -h $MHOST -p$MPASS $db|grep -v Tables_in_`;
  do
    FILE=$BACKUP/$NOW/$db/$i.sql.gz
    echo $i; $MYSQLDUMP --add-drop-table --allow-keywords -q -c -u $MUSER -h $MHOST -p$MPASS $db $i | $GZIP -9 > $FILE
  done
done

backup_files="/var/www/codingfactory/wp-content/uploads"

mkdir $BACKUP/$NOW/"wp-uploads"

# Where to backup to.
dest="$BACKUP/$NOW/wp-uploads"

# Create archive filename.
day=$(date +%A)
archive_file="$day-codingfactory.tgz"

# Backup the files using tar.
tar czf "$dest"/"$archive_file" $backup_files

### Compress all tables in one nice file to upload ###

ARCHIVE=$BACKUP/"$NOW-codingfactory.tar.gz"
ARCHIVED=$BACKUP/$NOW

$TAR -cvf $ARCHIVE $ARCHIVED

### Dump backup using FTP ###
cd $BACKUP || return
DUMPFILE=$NOW.tar.gz
$FTP -n $FTPS <<END_SCRIPT
quote USER $FTPU
quote PASS $FTPP
cd $FTPD
mput $DUMPFILE
quit
END_SCRIPT

### Delete the backup dir and keep archive ###

rm -rf $ARCHIVED