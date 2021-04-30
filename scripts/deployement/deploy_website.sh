#!/bin/bash

#########################################################################
# This script is used to deploy a new wordpress site on our server.     #
# We create a new user on server, also on mysql and its database.       #
# We prepare the virtualHost and all config to deploy wordpress easily. #
#                                                                       #
# Require mysql_create.sh in same directory.                            #
#########################################################################

wget=/usr/bin/wget
tar=/bin/tar

wordpress_filename="latest-fr_FR.tar.gz"
wordpress_filepath="/tmp/$wordpress_filename"

_WORDPRESS="https://fr.wordpress.org/latest-fr_FR.tar.gz"
_TEMPLATE_VH="template_vh"

function get_wordpress() {
  cd "/tmp" || return

  if "$1" ; then
    $wget "${_WORDPRESS}"
    exist=$?
    if [ $exist -ne 0 ]; then
      echo "wget ${_WORDPRESS} failed"
      exit 1
    fi
  fi
  $tar xf "$wordpress_filepath" # add v next x to Display progress in the terminal
  cd "$OLDPWD" || return
}

clear


## region optional args
while getopts n:p:hf flag
do
  case "${flag}" in
      n) PROJECT_NAME=${OPTARG};;
      p) PASSWORD=${OPTARG};;
      h) HELP=true;;
      f) FORCE=true;;
  esac
done
## endregion

## region help
if [ -n "$HELP" ]; then
echo "
 Use -h to ask help.
 Use -n to give a project name without extension.
 Use -p to set a password.
 Use -f to force creation (don't ask confirmation).
"
exit 0
fi
## endregion

echo "¤ Deploy website ¤"
echo ""
echo "Be sure to be in 'sudo su' before starting..."
echo "Else, press Ctrl+C and do it!"
echo ""


# get project name and password, in order to create user if not in options
if [ -z "$PROJECT_NAME" ]; then
  read -p "Enter a project name (without extension) : " PROJECT_NAME
fi
if [ -z "$PASSWORD" ]; then
  PASSWORD=$(</dev/urandom tr -dc _!A-Z-a-z-0-9 | head -c12)
fi

echo "Choose your extension:"
echo ""
select extension in "net" "com" "local" "org"
  do
  if [ -n "$extension" ] ; then
      echo "You have chosen $extension"
      break
  fi
done

PROJECT_NAME="$PROJECT_NAME.$extension"

echo "
Create project: $PROJECT_NAME, with password= $PASSWORD"
if [ -z "$FORCE" ]; then
  echo "Confirm your choice:"
  echo ""
  select confirmation in "yes" "no"
  do
  if [ -n "$confirmation" ] ; then
      if [ $confirmation = "no" ] ; then
        echo "Cancel project ..."
        exit 1
      fi
      break
  fi
  done
fi


# check any project has same name
egrep "^$PROJECT_NAME" /etc/passwd >/dev/null
exist=$?

if [ $exist -eq 0 ]; then
echo "Project $PROJECT_NAME already exists!"
exit 1
fi
## endregion


ARR_IN=("${PROJECT_NAME//./}")

USERNAME="${ARR_IN[0]}"

## region create user
sudo useradd -m -G "www-data" -p "$PASSWORD" "$USERNAME"
[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
## endregion

sudo bash mysql_create.sh -n "$USERNAME" -p"$PASSWORD"

## region wget to download VERSION file
if [ ! -f "$wordpress_filepath" ] ; then
  echo "Download wordpress"
  get_wordpress true

else
  # will check if wordpress is recently downloaded, if not we will remove the old one and download a newer version
  echo "$wordpress_filename already downloaded!"
  date_now=$(date +%s)
  date_file=$(date -r "$wordpress_filepath" +%s)
  seconds_between=$(("$date_now"-"$date_file"))
  seconds_in_1_week=$((60*60*24*7))

  if [ "$seconds_between" -gt "$seconds_in_1_week" ] ; then
    sudo rm "$wordpress_filepath"
    echo "Download a newer wordpress version"
    get_wordpress true
  else
    echo "$wordpress_filename previously downloaded extraction"
    get_wordpress false
  fi
fi

## region user website folder
mkdir "/var/www/$PROJECT_NAME"
sudo mv "/tmp/wordpress/"* "/var/www/$PROJECT_NAME"
sudo rm -r "/tmp/wordpress"

cd "/var/www/$PROJECT_NAME" || return
## endregion

## endregion

sudo chmod -R 755 "/var/www/$PROJECT_NAME"

mkdir "/var/log/apache2/$PROJECT_NAME"
cd "/var/log/apache2/$PROJECT_NAME" && touch "error.log" && touch "access.log"
sudo service apache2 reload

## region Prepar wordpress config
DB_NAME=$USERNAME
DB_USER=$USERNAME
DB_PASSWORD=$PASSWORD
DB_HOST="localhost"

TEMP_FILE="/tmp/out.tmp.$$"

# generate wp-config.php by copying wp-config-sample.php
sudo cp "/var/www/$PROJECT_NAME/wp-config-sample.php" "/var/www/$PROJECT_NAME/wp-config.php"
sudo chown www-data.www-data "/var/www/$PROJECT_NAME/"* -R

_DB_DEFINES=('DB_NAME' 'DB_USER' 'DB_PASSWORD' 'DB_HOST' 'WPLANG')

## region loop for update all the config file DB data row
for DB_PROPERTY in "${_DB_DEFINES[@]}" ;
do
  NEW="define('$DB_PROPERTY', '${!DB_PROPERTY}');"  # Will probably need some pretty crazy escaping to allow for better passwords
  sed "/$DB_PROPERTY/s/.*/$NEW/" "/var/www/$PROJECT_NAME/wp-config.php" > $TEMP_FILE && mv $TEMP_FILE "/var/www/$PROJECT_NAME/wp-config.php"
done
## endregion
## endregion

## region enable site
sudo cp "/etc/apache2/sites-available/$_TEMPLATE_VH" "/etc/apache2/sites-available/$PROJECT_NAME.conf"
sudo sed -i "s/__PROJECTNAME__/$PROJECT_NAME/g" "/etc/apache2/sites-available/$PROJECT_NAME.conf"

# prepare DNS on server side
IP_MACHINE=$(hostname -I)
sudo sed -i "1s/^/$IP_MACHINE $PROJECT_NAME\n/" /etc/hosts

# prepare firewall for this project
sudo touch "/usr/bin/python/$PROJECT_NAME.yaml"
sudo sed -i "1s/^/hostname: '$PROJECT_NAME'\n/" "/usr/bin/python/$PROJECT_NAME.yaml"

sudo a2ensite "$PROJECT_NAME.conf"
sudo service apache2 reload
## endregion

echo "Done, please browse to http://$PROJECT_NAME to check!"
