#!/bin/bash

########################################################################
# This script is used to deploy a new wordpress site on our server.    #
# We create a new user on server, also on mysql and its database.      #
# We prepare the virtualHost and all config to deploy wordpress easily.#
########################################################################

wget=/usr/bin/wget
tar=/bin/tar

WORDPRESS="https://fr.wordpress.org/latest-fr_FR.tar.gz"

# get project name and password, in order to create user
read -p "Enter a project name : " projectname
read -s -p "Enter password : " password

# check any project has same name
egrep "^$projectname" /etc/passwd >/dev/null
exist=$?
echo $exist

if [ $exist -eq 0 ]; then
  echo "projectname exists!"
  exit 1
else
  ARR_IN=("${projectname//./ }")

  USERNAME="${ARR_IN[0]}"

  ## region create user
  sudo useradd -m -G "www-data" -p "$password" "$USERNAME"
  [ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
  ## endregion

  ## region create database, user, with all privileges on his table
  REQUEST="
  CREATE DATABASE $USERNAME CHARACTER SET UTF8 COLLATE UTF8_BIN;
  CREATE USER '$USERNAME'@'%' IDENTIFIED BY '$password';
  GRANT ALL PRIVILEGES ON $USERNAME.* TO '$USERNAME'@'%';
  FLUSH PRIVILEGES;
  "
  mysql --user=root <<EOFMYSQL
  $REQUEST
EOFMYSQL
  ## endregion

  ## region user website folder
  mkdir "/var/www/$USERNAME"
  cd "/var/www/$USERNAME" || return
  ## endregion

  ## region wget to download VERSION file
  $wget "${WORDPRESS}"
  $tar xvf "latest-fr_FR.tar.gz"

  sudo mv "/var/www/$USERNAME/wordpress/"* "/var/www/$USERNAME"
  sudo rm -r "wordpress"
  ## endregion


  sudo chmod -R 755 "/var/www/$USERNAME"

  mkdir "/var/www/$USERNAME/logs"
  cd "/var/www/$USERNAME/logs" && touch "error.log" && touch "access.log"
  sudo service apache2 reload

  ## region Prepar wordpress config
  DB_NAME=$USERNAME
  DB_USER=$USERNAME
  DB_PASSWORD=$password
  DB_HOST="localhost"

  TEMP_FILE="/tmp/out.tmp.$$"

  # try generate random password
  DB_PASSWORD=< /dev/urandom tr -dc A-Za-z0-9 | head -c14;

  # generate wp-config.php by copying wp-config-sample.php
  sudo cp "/var/www/$USERNAME/wp-config-sample.php" "/var/www/$USERNAME/wp-config.php"
  DB_DEFINES=('DB_NAME' 'DB_USER' 'DB_PASSWORD' 'DB_HOST' 'WPLANG')

  ## region loop for update all the config file DB data row
  for DB_PROPERTY in "${DB_DEFINES[@]}" ;
  do
      NEW="define('$DB_PROPERTY', '${!DB_PROPERTY}');"  # Will probably need some pretty crazy escaping to allow for better passwords
      sed "/$DB_PROPERTY/s/.*/$NEW/" "/var/www/$USERNAME/wp-config.php" > $TEMP_FILE && mv $TEMP_FILE "/var/www/$USERNAME/wp-config.php"
  done
  ## endregion
  ## endregion


  ## region enable site
  sudo cp /etc/apache2/sites-available/template "/etc/apache2/sites-available/$projectname.conf"
  sudo sed -i "s/template/$USERNAME/g" "/etc/apache2/sites-available/$projectname.conf"

  IP_MACHINE=$(hostname -I)
  sudo sed -i "1s/^/$IP_MACHINE"  "$projectname\n/" /etc/hosts

  sudo a2ensite "$projectname.conf"
  sudo service apache2 reload
  ## endregion

  echo "Done, please browse to http://$projectname to check!"

fi
