#!/bin/sh

for name in /var/www/*; do
    [ ! -d "$name" ] && continue # if different than a dir, break
    backup_files="$name/wp-content/uploads" #final is /uploads
    [ ! -d "$backup_files" ] && continue # if doesn't contains wp-content, break

    domain="$(basename "$name")"
    # Create archive filename.
    day=$(date +%Y%m%d)
    archive_file="$day-$domain.tgz"
    echo "$archive_file created, containing $backup_files"

    tar czf "$archive_file" -P $backup_files
done

