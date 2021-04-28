#!/bin/bash

wget=/usr/bin/wget
tar=/bin/tar

WORDPRESS="https://fr.wordpress.org/latest-fr_FR.tar.gz"

read -p "Enter a project name : " projectname
read -s -p "Enter password : " password
egrep "^$projectname" /etc/passwd >/dev/null
echo $?
exist=$?

if [ $exist ]; then
  echo "projectname exists!"
  exit 1
else
  arrIN=(${projectname//./ })

  username="${arrIN[1]}"
  sudo useradd -m -G "www-data" -p "$password" "$username"

  [ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"

  mysql -u root -p -e "CREATE DATABASE $username CHARACTER SET UTF8 COLLATE UTF8_BIN;"
  mysql -u root -p -e "CREATE USER '$username'@'%' IDENTIFIED BY '$password';"
  mysql -u root -p -e "GRANT ALL PRIVILEGES ON $username.* TO '$username'@'%';"
  mysql -u root -p -e "FLUSH PRIVILEGES;"

  sudo mkdir "var/www/$username"

  sudo cd "var/www/$username" || return

  # wget to download VERSION file
  $wget "${WORDPRESS}"

  $tar xvf "latest-fr_FR.tar.gz"

  sudo mv -r "wordpress/*" "var/www/$username/"

  sudo rm -r "wordpress"

  sudo cp /etc/apache2/sites-available/template /etc/apache2/sites-available/$projectname

  sudo sed -i 's/template/'$username'/g' /etc/apache2/sites-available/$projectname

  sudo sed -i '1s/^/192.168.1.61       '$projectname'\n/' /etc/hosts

  sudo a2ensite $projectname
  sudo service apache2 reload

  echo "Done, please browse to http://$projectname to check!"

fi