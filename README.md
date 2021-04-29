# Scripting
cours de scripting sur linux

##Sommaire

##Script d'installation
Afin de pouvoir déployer rapidement les serveurs, des scripts .sh sont disponibles
sur notre Github. De préférences, placé les dans le dossier /usr/local/bin de votre
VM.


Utilisé le fichier ```init_vm.sh``` afin de faire l'installation complete des librairies
nécessaire au fonctionnement du serveur web.
Le script ```deploy_website.sh``` permet de déployer un nouveau site wordpress en 
saissisant simplement un nom de projet et un mot de passe.


Ajouter le script python ```firewall.py``` dans le dossier ```/usr/bin/python``` 
(crée le dossier python si besoin).
Lancé le avec la commande ```python3 firewall.py```.
Ce script permettra de bloquer les ip ayant échoué 5 fois à se connecter

#Service d'hébergement de sites clients

##Préparation du serveur Web manuel

###Configuration de la VM
On suppose que vous travailler en local sur une VM Linux 
qui servira de serveur web.

Installer et configurer une VM avec VirtualBox, 
et une image disk au format .iso de Ubuntu (version 20).

Aprés avoir fait la configuration classique de la VM, 
n'oubliez pas de configurer le mode d'accés réseau de la VM 
en 'bridge' (acces par pont).
Pour cela, depuis l'interface VirtualBox, aller dans configuration 
(de la VM serveur web), onglet réseau.

NB : pour toutes les commandes qui suivront, 
vous aurez probablement besoin des droits sudo.


###SSH
Sur votre serveur web, utiliser la commande
```sudo apt install net-tools```, 
afin de pouvoir utiliser la commande ```ifconfig```.

Cela vous permettra de recuperer l'adresse IP du serveur,
pour se connecter en ssh (ex:192.168.1.30). 
Elle devrait se trouver dans la section enp0s3 (inet).

Maintenant, utiliser la commande 
```sudo apt install openssh-server```. 

Pour se connecter à votre VM depuis un terminal exterieur, 
entrer la commande ```ssh nomDeLutilisateur@ip``` 
(ex: coding@192.168.1.30). 

A la première connexion, une question devrait être posé,
afin de ne plus entrer de mot de passe au prochaines connexions. 
On peut bien sûr entrer 'yes' ou 'no'.
Un mot de passe devrait être demandé, celui de l'utilisateur
créer sur la VM linux.


###Apache
Sur votre serveur web, utilisé la commande 
```sudo apt install apache2```.
Pour tester que le service apache fonctionne bien, 
on peut aller sur un navigateur web et saisir ```http://ip``` 
(ex: http://192.168.1.30). On devrait arriver sur une page 
au contenu par defaut de ubuntu.


###DNS
Pour configurer les DNS, commencerer par 
la commande ```sudo vi /etc/hosts``` côté serveur web.
On ajoute alors une ligne ```ip nomDuDomaine``` 
(ex: 192.168.1.30  coding.com). On peut ajouter plusieurs
ligne avec cette même ip, ce seront tous des alias amenant au
même site.

Dans un second temps, comme l'environnement de développement est local, 
il faut également modifier le fichier /etc/hosts de notre machine 
(Mac, Windows ou Linux).

Pour Mac et Linux, on doit pouvoir suivre les instructions précédente
pour le DNS en mettant à jour le fichier ```/etc/hosts```.
Sur Windows, cela diffère. @todo brian : expliquer la demarche à suivre

On doit pouvoir acceder au site depuis un navigateur web via l'url
```http://nomDuDomaine``` (ex: http://coding.com).


###VirtualHost
Une fois qu'apache est installé sur le serveur, 
on peut s'occuper du virtual host.
- Entrer la commande ```cd /etc/apache2/site-available```
- ```sudo vi nomDuDomaine.conf```, (ex:vi coding.com.conf)
- Ajouter au minimum ces quelques lignes:
```
<VirtualHost *:80>
	DocumentRoot /var/www/coding.com
	ServerName coding.com
</VirtualHost>
```
Remplacer bien sûr 'coding.com' par le nom de votre domaine.

- Utiliser la commande ```sudo a2ensite nomDuDomaine``` 
(ex: a2ensite coding.com).
- On relance apache avec la commande 
```systemctl reload apache2```

[si la commande ne fonctionne pas et renvoie une erreur
```apache2.service is not active, cannot reload.```, 
essayer d'entrer les commandes : ```apachectl stop```, 
```/etc/init.d/apache2 start```
```/etc/init.d/apache2 reload```.
]

###Template Virtual host
Ajouté un template dans /etc/apache2/sites-available/template.
Celui-ci permettra de générer simplement un VirtualHost 
adapté à notre utilisateur (log).

###Wordpress

####Mysql 
Afin de pouvoir utiliser wordpress, vous aurez besoin 
d'installer mysql et de créer des databases, des utilisateurs
et gérer leurs droits.

Commence par saisir la commande 
```sudo apt install mysql-server mysql-client``` sur le serveur web.

Créer la base données et un utilisateur avec la commande
````
sudo mysql -u root <<EOFMYSQL
CREATE DATABASE wordpress CHARACTER SET UTF8 COLLATE UTF8_BIN;
CREATE USER 'wordpress'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'%';
FLUSH PRIVILEGES;
EOFMYSQL
````
On peut remplacer 'wordpress' par tout autre nom d'utilisateur, 
et 'password' par un mot de passe plus sécurisé dans cette requête.

####Apache
On doit ajouter certaines librairies pour utiliser wordpress
tel que php.

Sur le serveur web, saisir la commande 
```sudo apt install php php-mysql libapache2-mod-php```.
Php et maintenant installé, il faut relancer apache, utiliser 
la commande ```service apache2 restart```.

####fichiers wordpress
On peut installer wordpress sur le serveur.
Se placer  d'abord dans le dossier ```/tmp```.
Entrer ensuite les commandes:
```
wget https://wordpress.org/latest.tar.gz
tar -zxvf latest.tar.gz
sudo mv wordpress/* /var/www/nomDuDomaine/
sudo chown www-data.www-data /var/www/nomDuDomaine/* -R
sudo cp wp-config-sample.php wp-config.php
sudo vi wp-config.php
```

A l'interieur de ce fichier, on mettra les informations
de la base de données au ligne correpondante.
```
define('DB_NAME', 'wordpress');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', 'password');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
```


###Cron
On souhaite avoir des sauvegardes automatiques des bases de données
et d'une parti du contenu des domaines de nos utilisateurs.

Il faut donc un script de backup compatible avec Cron : backup.sh.
Placer ce script dans /usr/local/bin.

Si cron n'est pas installé, utilisé les commandes 
```sudo apt install cron``` et ```sudo systemctl enable cron```.

Pour créer une tache cron, utilisé la commande 
```crontab -e```, et ajouter une ligne
```* * * * * /usr/local/bin/backup.sh```.
Noté que la précédente commande avec et sans sudo seront 2 fichiers 
bien distinct.

Pour que cron puisse executer le script, ne pas oublier de donner
les droits d'execution au script. on peut par exemple entrer la 
commande ```sudo chmod 755 /usr/local/bin/backup.sh```.

Pour recevoir les message d'erreur visible dans /var/userName/mail, 
trés utile pour tester la tache cron,
il vous faudra peut-être utilisé la commande ```sudo apt-get install postfix```.

###Backup
Pour des raisons de sécurité et conservation des données, nous allons transféré 
les données compressé de nos utilisateurs avec cron sur un serveur backup.

Il faut donc qu'un serveur soit configuré afin de modifier le le script ```get-uploads.sh```
Avec les données correspondante 
                                                              
- FTPD => destination 
- FTPU => username  
- FTPP => password  
- FTPS => ip serveur 



##Preparation du serveur backup manuel
L'objectif de ce serveur backup sera de stocker des sauvegardes
des bases de données mysql du serveur web, afin de pouvoir restaurer
l'ensemble des données en cas de problème important sur le serveur web.

@todo expliquez toute la mise en place du serveur backup

###SSH backup
Afin de pouvoir envoyer les fichiers backup sur le serveur prévu
à cet effet, on peut utiliser le SSH pour les transmettre.
Vous pouvez vous référez-vous a la même section pour le 
[serveur web](#SSH) afin de préparer le serveur

###Reception des backups
Afin de pouvoir recevoir des backups sur ce serveur depuis le serveur web,
il faut pouvoir communiquer avec ce serveur à l'aide d'un utilisateur 
ayant les droits d'accès au repertoire /var/backups.

Creer l'utilisateur avec la commande ```adduser backupuser```, puis la commande
```usermod -aG sudo backupuser``` afin de lui attribuer des droits sudo.
Transmetter le nom d'utilisateur, le password et l'ip du serveur backup au 
serveur web afin de configurer les bonnes valeurs dans le script ```get-uploads.sh```. 

- FTPD => destination =/var/backups
- FTPU => username = backupuser
- FTPP => password = le mot de passe saisi
- FTPS => ip serveur = 192.168.X.X

