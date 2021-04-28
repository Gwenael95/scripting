#!/usr/bin/env bash


USERNAME=$1 # username

DB_NAME=$(basename `pwd`)  
DB_NAME=${USERNAME%.*}  
DB_USER=$USERNAME  
DB_PASSWORD=$USERNAME 
DB_HOST="localhost"
DB_COLLATE="utf8_default_ci"

TEMP_FILE="/tmp/out.tmp.$$"

WPDIR="." # ou wordpress
WP_DEBUG=true

# generate wp-config.php by copying wp-config-sample.php
cp $WPDIR/wp-config-sample.php $WPDIR/wp-config.php
DB_DEFINES=('DB_NAME' 'DB_USER' 'DB_PASSWORD' 'DB_HOST' 'WPLANG' 'DB_COLLATE')

#loop for update all the config file DB data
for DB_PROPERTY in ${DB_DEFINES[@]} ;
do
    OLD="define('$DB_PROPERTY', '.*')"
    NEW="define('$DB_PROPERTY', '${!DB_PROPERTY}')"  # Will probably need some pretty crazy escaping to allow for better passwords

    sed "s/$OLD/$NEW/g" $WPDIR/wp-config.php > $TEMP_FILE && mv $TEMP_FILE $WPDIR/wp-config.php
done


# Some good practice settings, found on internet, search why it's interesting
WP_DEBUG="define('WP_DEBUG', true); define('FORCE_SSL_LOGIN', false); define('FORCE_SSL_ADMIN', false); define('DISALLOW_FILE_EDIT', true); define('DISALLOW_FILE_MODS', false);"

sed "s/define('WP_DEBUG', false);/$WP_DEBUG/g" $WPDIR/wp-config.php > $TEMP_FILE && mv $TEMP_FILE $WPDIR/wp-config.php



#create database, user, with all privileges on his table
REQUEST="
CREATE DATABASE $DB_NAME CHARACTER SET UTF8 COLLATE UTF8_BIN;
CREATE USER '$DB_NAME'@'%' IDENTIFIED BY '$DB_NAME';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_NAME'@'%';
FLUSH PRIVILEGES;
"
mysql --user=root <<EOFMYSQL
$REQUEST
EOFMYSQL


#cd ./template
#./setup.sh

exit 0