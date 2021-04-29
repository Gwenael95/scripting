#!/bin/bash

wget=/usr/bin/wget
tar=/bin/tar

WORDPRESS="https://fr.wordpress.org/latest-fr_FR.tar.gz"

read -p "Enter a project name : " projectname
read -s -p "Enter password : " password
egrep "^$projectname" /etc/passwd >/dev/null
exist=$?
echo $exist

if [ $exist -eq 0 ]; then
  echo "projectname exists!"
  exit 1
else
  arrIN=(${projectname//./ })

  username="${arrIN[0]}"
  sudo useradd -m -G "www-data" -p "$password" "$username"

  [ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"

  #create database, user, with all privileges on his table
  REQUEST="
  CREATE DATABASE $username CHARACTER SET UTF8 COLLATE UTF8_BIN;
  CREATE USER '$username'@'%' IDENTIFIED BY '$password';
  GRANT ALL PRIVILEGES ON $username.* TO '$username'@'%';
  FLUSH PRIVILEGES;
  "
  mysql --user=root <<EOFMYSQL
  $REQUEST
EOFMYSQL

  mkdir "/var/www/$username"

  cd "/var/www/$username" || return

  # wget to download VERSION file
  $wget "${WORDPRESS}"

  $tar xvf "latest-fr_FR.tar.gz"

  sudo mv "/var/www/$username/wordpress/"* "/var/www/$username"

  sudo rm -r "wordpress"

  sudo cp /var/www/$username/wp-config-sample.php /var/www/$username/wp-config.php

  sudo chmod -R 755 "/var/www/$username"

  mkdir "/var/www/$username/logs"
  cd "/var/www/$username/logs" && touch "error.log" && touch "access.log"
  sudo service apache2 reload

  #Prepare la config de wordpress
  DB_NAME=$username
  DB_USER=$username
  DB_PASSWORD=$password
  DB_HOST="localhost"

  TEMP_FILE="/tmp/out.tmp.$$"

  # try generate random password
  DB_PASSWORD=< /dev/urandom tr -dc A-Za-z0-9 | head -c14;

  # generate wp-config.php by copying wp-config-sample.php
  sudo cp /var/www/$username/wp-config-sample.php /var/www/$username/wp-config.php
  DB_DEFINES=('DB_NAME' 'DB_USER' 'DB_PASSWORD' 'DB_HOST' 'WPLANG')

  #loop for update all the config file DB data
  for DB_PROPERTY in ${DB_DEFINES[@]} ;
  do
      OLD="define(.*'$DB_PROPERTY', '.*'.*);"
      NEW="define('$DB_PROPERTY', '${!DB_PROPERTY}');"  # Will probably need some pretty crazy escaping to allow for better passwords

      sed "/$DB_PROPERTY/s/.*/$NEW/" /var/www/$username/wp-config.php > $TEMP_FILE && mv $TEMP_FILE /var/www/$username/wp-config.php
  done
  #Fin de la config wordpress

  sudo cp /etc/apache2/sites-available/template /etc/apache2/sites-available/"$projectname.conf"

  sudo sed -i 's/template/'$username'/g' /etc/apache2/sites-available/"$projectname.conf"

  ipMachine=$(hostname -I)

  sudo sed -i '1s/^/'$ipMachine'  '$projectname'\n/' /etc/hosts

  sudo a2ensite "$projectname.conf"
  sudo service apache2 reload

  echo "Done, please browse to http://$projectname to check!"

fi