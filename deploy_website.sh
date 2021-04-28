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

  mysql -u root "" -e "CREATE DATABASE $username CHARACTER SET UTF8 COLLATE UTF8_BIN;"
  mysql -u root "" -e "CREATE USER '$username'@'%' IDENTIFIED BY '$password';"
  mysql -u root "" -e "GRANT ALL PRIVILEGES ON $username.* TO '$username'@'%';"
  mysql -u root "" -e "FLUSH PRIVILEGES;"

  mkdir "/var/www/$username"
  read -p "Mkdir : "
  echo "J'ai mkdir"

  cd "/var/www/$username" || return
  read -p "cd var/www : "
  echo "J'ai CD"

  # wget to download VERSION file
  $wget "${WORDPRESS}"

  read -p "je vais dezipper : "

  $tar xvf "latest-fr_FR.tar.gz"

  sudo mv "/var/www/$username/wordpress/"* "/var/www/$username"

  read -p "mv wordpress : "

  sudo rm -r "wordpress"

  read -p "je remove unused dir : "

  sudo cp /etc/apache2/sites-available/template /etc/apache2/sites-available/$projectname

  sudo sed -i 's/template/'$username'/g' /etc/apache2/sites-available/$projectname".conf"

  sudo sed -i '1s/^/192.168.1.61  '$projectname'\n/' /etc/hosts

  sudo a2ensite $projectname".conf"
  sudo service apache2 reload

  echo "Done, please browse to http://$projectname to check!"

fi