#!/bin/bash

########################################################################
# This script is used to deploy a new wordpress site on our server.    #
# We create a new user on server, also on mysql and its database.      #
# We prepare the virtualHost and all config to deploy wordpress easily.#
########################################################################

wget=/usr/bin/wget
tar=/bin/tar

WORDPRESS="https://fr.wordpress.org/latest-fr_FR.tar.gz"

## region optional args
while getopts n:p:h:f flag
do
    case "${flag}" in
        n) PROJECT_NAME=${OPTARG};;
        p) PASSWORD=${OPTARG};;
        h) HELP=true;;
        f) FORCE=true
    esac
done
## endregion

## region help
if [ -n "$HELP" ]; then
  echo "
  use -n to give a project name.
  use -p to set a password.
  use -f to force creation (don't ask confirmation).
  "
  exit 0
fi
## endregion

# get project name and password, in order to create user if not in options
if [ -z "$PROJECT_NAME" ]; then
  read -p "Enter a project name : " PROJECT_NAME
fi
if [ -z "$PASSWORD" ]; then
  PASSWORD=$(</dev/urandom tr -dc _!A-Z-a-z-0-9 | head -c12)
fi
## endregion

## region confirm creation if no -f option
if [ -z "$FORCE" ]; then
  read -p "A new site will be created with user= $PROJECT_NAME and password= $PASSWORD.
 Should we create it?[y/n]" CONFIRM
fi

if ( [ -n "$FORCE" ] && $FORCE) || [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "yes" ] ; then
    echo "Site for $PROJECT_NAME is ready to be created."
else
    echo "Cancel project."
    exit 0
fi
## endregion


# check any project has same name
egrep "^$PROJECT_NAME" /etc/passwd >/dev/null
exist=$?
echo $exist

if [ $exist -eq 0 ]; then
  echo "projectname exists!"
  exit 1
else
  ARR_IN=("${PROJECT_NAME//./ }")

  USERNAME="${ARR_IN[0]}"
  sudo bash mysql_create.sh -n "$USERNAME" -p"$PASSWORD"

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
  DB_PASSWORD=$PASSWORD
  DB_HOST="localhost"

  TEMP_FILE="/tmp/out.tmp.$$"

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
  sudo cp /etc/apache2/sites-available/template "/etc/apache2/sites-available/$PROJECT_NAME.conf"
  sudo sed -i "s/__PROJECTNAME__/$USERNAME/g" "/etc/apache2/sites-available/$PROJECT_NAME.conf"

  IP_MACHINE=$(hostname -I)
  sudo sed -i "1s/^/$IP_MACHINE"  "$PROJECT_NAME\n/" /etc/hosts

  sudo a2ensite "$PROJECT_NAME.conf"
  sudo service apache2 reload
  ## endregion

  echo "Done, please browse to http://$PROJECT_NAME to check!"

fi
