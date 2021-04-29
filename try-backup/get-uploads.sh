#!/bin/sh

TMP="/tmp/backup" #save backup files into tmp
if [ ! -d "$TMP" ]; then
  mkdir $TMP
fi

#DOMAIN_ARRAY=()
declare -a DOMAIN_ARRAY # array of all domains containing wp-content/uploads directory

#will save all DB and domain wp-content/uploads in tmp
for name in /var/www/*; do
    [ ! -d "$name" ] && continue # if different than a dir, break
    backup_files="$name/wp-content/uploads" #final is /uploads
    [ ! -d "$backup_files" ] && continue # if doesn't contains wp-content, break

    domain="$(basename "$name")"
    # Create archive filename.
    day=$(date +%Y%m%d)
    archive_file="$TMP/$day-$domain.tgz"
    echo "$archive_file created, containing $backup_files"

    tar czf "$archive_file" -P $backup_files
    DOMAIN_ARRAY[${#DOMAIN_ARRAY[*]}]=$domain
done

TEST="${DOMAIN_ARRAY[*]}"

##issue with mysqldump
DB_FILE_NAME="$TMP/db.sql"

#mysqldump --all-databases > "$DB_FILE_NAME" # work when not a CRON

#mysqldump -u root --all-databases > "$DB_FILE_NAME"
#mysqldump --defaults-file=/home/achamberlain/.my.cnf --databases 360_projects --single-transaction --all-databases --triggers --routines -u backup > "$DB_FILE_NAME"
mysqldump  --single-transaction --all-databases --triggers --routines -u backup > "$DB_FILE_NAME"

gzip "$DB_FILE_NAME"


#send them to backup server, @todo test it
#scp file1 file2 login@ip:chemin_destination/
#scp "$TEST" login@ip:/var/backup

