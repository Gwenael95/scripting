#!/usr/bin/env bash

# args : 1 = username (used for DB username, dbname)

USERNAME=$1 # username

DB_NAME=$(basename `pwd`)
DB_NAME=${USERNAME%.*}
DB_USER=$USERNAME
DB_PASSWORD=$USERNAME
DB_HOST="localhost"
DB_COLLATE="utf8_default_ci"

TEMP_FILE="/tmp/out.tmp.$$"

WPDIR="."
WP_DEBUG=true


# try generate random password
DB_PASSWORD=< /dev/urandom tr -dc A-Za-z0-9 | head -c14;


# generate wp-config.php by copying wp-config-sample.php
cp $WPDIR/wp-config-sample.php $WPDIR/wp-config.php
DB_DEFINES=('DB_NAME' 'DB_USER' 'DB_PASSWORD' 'DB_HOST' 'WPLANG' 'DB_COLLATE')


#loop for update all the config file DB data
for DB_PROPERTY in ${DB_DEFINES[@]} ;
do
    OLD="define(.*'$DB_PROPERTY', '.*'.*);"
    NEW="define('$DB_PROPERTY', '${!DB_PROPERTY}');"  # Will probably need some pretty crazy escaping to allow for better passwords

    sed "/$DB_PROPERTY/s/.*/$NEW/" $WPDIR/wp-config.php > $TEMP_FILE && mv $TEMP_FILE $WPDIR/wp-config.php
done


# Some good practice settings, found on internet, search why it's interesting
WP_DEBUG="define('WP_DEBUG', true); define('FORCE_SSL_LOGIN', false); define('FORCE_SSL_ADMIN', false); define('DISALLOW_FILE_EDIT', true); define('DISALLOW_FILE_MODS', false);"

sed "s/define('WP_DEBUG', false);/$WP_DEBUG/g" $WPDIR/wp-config.php > $TEMP_FILE && mv $TEMP_FILE $WPDIR/wp-config.php




# @todo peut etre pas utile tout ce bloc, a voir
# Add unique table_prefix
#	@ strings not found, need apt-get install binutils
#TABLE_PREFIX=`cat /dev/urandom | strings | grep -o '[[:alnum:]]' | head -n 5 | tr -d '\n' ; echo -n ;  echo -n "_wp_"`
TABLE_PREFIX=`cat /dev/urandom | grep -o '[[:alnum:]]' | head -n 5 | tr -d '\n' ; echo -n ;  echo -n "_wp_"`

sed "s/$table_prefix  = 'wp_'/$table_prefix  = '$TABLE_PREFIX'/g" $WPDIR/wp-config.php > $TEMP_FILE && mv $TEMP_FILE $WPDIR/wp-config.php

# Setup keys and salts
OLD="codingfactory"
CONFIG=`cat $WPDIR/wp-config.php`

while [[ $CONFIG ==  *$OLD* ]] ; do
    # Generate hash
    NEW=$(cat /dev/urandom | env LC_CTYPE=C tr -cd 'a-zA-Z0-9 .,:;!?=+-_@()[]{}#$&%~^`<>*|/' | head -c 64)
    NEW=$(echo "${NEW}" | sed "s/\\\/ /g") # No idea why backslashes are in this string, but let's replace them

    CONFIG="${CONFIG/$OLD/$NEW}" # Escape sed's escape character
done

echo "$CONFIG" > $WPDIR/wp-config.php

# Deny access to .htaccess
echo "<Files wp-config.php>
    Order allow, deny
    Deny from all
</Files>" > "${WPDIR}"/.htaccess






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


#cd ./template_vh
#./setup.sh

exit 0