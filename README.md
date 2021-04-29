# Scripting
Ce Github est réservé à un cours de scripting sur Linux.

Nous apprendrons à utiliser des scripts .sh, déployer un serveur backup et un serveur
web permettant l'hébergement de sites internet et leurs administrations.

## Sommaire
1. [Service d'hébergement de sites clients](#Service-d'hebergement-de-sites-clients)
    - [Script d'installation](#Script-d'installation)

# Service d'hebergement de sites clients

## Configuration de la VM
On suppose que vous travaillez en local sur des VM Linux.

Installer et configurer une VM avec VirtualBox, 
et une image disk au format .iso d'Ubuntu (version 20).

Après avoir fait la configuration classique de la VM, 
n'oubliez pas de configurer le mode d'accès réseau de la VM 
en 'bridge' (accès par pont).
Pour cela, depuis l'interface VirtualBox, aller dans configuration 
(de la VM serveur web), onglet réseau.

NB : pour la majorité des commandes qui suivront, 
vous aurez probablement besoin des droits sudo.

## Script d'installation
Afin de pouvoir déployer rapidement les serveurs, des scripts .sh sont disponibles
sur notre Github. De préférences, placer les dans le dossier ```/usr/local/bin``` de votre
VM.

Utiliser le fichier ```init_vm.sh``` afin de faire l'installation complète des librairies
nécessaire au fonctionnement du serveur web.

Le script ```deploy_website.sh``` permet de déployer un nouveau site wordpress en 
saisissant simplement un nom de projet et un mot de passe.

Ajouter le script python ```firewall.py``` dans le dossier ```/usr/bin/python``` 
(crée le dossier python si besoin).
Lancer le script avec la commande ```python3 firewall.py```.
Ce script permettra de bloquer les ip ayant échoué 5 fois à la connexion 
sur wordpress en utilisant iptables.




## Préparation du serveur Web manuel

### SSH
Sur votre serveur web, utiliser la commande ```sudo apt install net-tools```, 
afin de pouvoir utiliser la commande ```ifconfig```.

Celle-ci vous permettra de récupérer l'adresse IP du serveur,
pour se connecter en ssh (ex: 192.168.1.30). 
Elle devrait se trouver dans la section enp0s3 (inet).

Maintenant, utiliser la commande ```sudo apt install openssh-server```. 

Pour se connecter à votre VM depuis un terminal extérieur, 
entrer la commande ```ssh nomDeLutilisateur@ip``` (ex: coding@192.168.1.30). 

À la première connexion, une question devrait être posée,
afin de ne plus entrer de mot de passe aux prochaines connexions. 
On peut bien sûr entrer 'yes' ou 'no'.
Un mot de passe sera demandé, celui de l'utilisateur créer sur la VM linux.


### Apache
Sur votre serveur web, utilisé la commande  ```sudo apt install apache2```.
Pour tester que le service apache fonctionne bien, 
on peut aller sur un navigateur web et saisir ```http://ip``` 
(ex: http://192.168.1.30). On devrait arriver sur une page 
au contenu par défaut d'Ubuntu.


### DNS
Pour configurer les DNS, commencer par 
la commande ```sudo vi /etc/hosts``` côté serveur web.
On ajoute alors une ligne ```ip nomDuDomaine``` 
(ex: 192.168.1.30 coding.com). 
On peut ajouter plusieurs lignes avec cette même ip, 
ce seront toutes des alias amenant au même site.

Dans un second temps, comme l'environnement de développement est local, 
il faut également modifier le fichier ```/etc/hosts``` de notre machine 
(Mac, Windows ou Linux).

Pour Mac et Linux, on doit pouvoir suivre les instructions précédentes
pour le DNS en mettant à jour le fichier ```/etc/hosts``` de notre ordinateur.
Sur Windows, cela diffère. @todo brian : expliquer la démarche à suivre

On doit maintenant pouvoir accéder au site depuis un navigateur web via l'url
```http://nomDuDomaine``` (ex: http://coding.com).


### VirtualHost
Une fois qu'apache est installé sur le serveur, on peut s'occuper du virtual host.
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

- Utiliser la commande ```sudo a2ensite nomDuDomaine```  (ex: a2ensite coding.com).
- On relance apache avec la commande ```systemctl reload apache2```

[
si la commande ne fonctionne pas et renvoie une erreur
```apache2.service is not active, cannot reload.```, 
essayer d'entrer les commandes : 
```apachectl stop```, 
```/etc/init.d/apache2 start```
```/etc/init.d/apache2 reload```.
]

#### Template Virtual host
Un template de VirtualHost est disponible sur notre Github (fichier template). 
Ajouté ce template dans ```/etc/apache2/sites-available/```.
Celui-ci permettra de générer simplement un VirtualHost adapté à notre utilisateur
via les scripts (notamment pour la localisation des logs).


### Wordpress

#### Mysql 
Afin de pouvoir utiliser wordpress, vous aurez besoin d'installer mysql, 
de créer des databases, des utilisateurs et gérer leurs droits.

Commencer par saisir la commande 
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

#### Completion d'Apache
On doit ajouter certaines librairies pour utiliser wordpress tel que php.

Sur le serveur web, saisir la commande 
```sudo apt install php php-mysql libapache2-mod-php```.
Php et maintenant installé, il faut relancer apache, utiliser 
la commande ```service apache2 restart```.

#### Fichiers wordpress
On peut installer wordpress sur le serveur.
Placez-vous dans le dossier ```/tmp```, afin d'éviter de polluer
le serveur avec les fichiers téléchargé.

Entrer ensuite les commandes :
```
wget https://wordpress.org/latest.tar.gz
tar -zxvf latest.tar.gz
sudo mv wordpress/* /var/www/nomDuDomaine/
sudo chown www-data.www-data /var/www/nomDuDomaine/* -R
sudo cp wp-config-sample.php wp-config.php
sudo vi wp-config.php
```

À l'intérieur du fichier ```wp-config.php```, on mettra les informations
de la base de données aux lignes correspondantes.
```
define('DB_NAME', 'wordpress');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', 'password');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
```


### Cron
On souhaite avoir des sauvegardes automatiques des bases de données
et d'une partie du contenu des domaines de nos utilisateurs.

Il faut donc un script de backup compatible avec Cron : ```backup.sh```.
Placer ce script dans ```/usr/local/bin```.

Si cron n'est pas installé, utilisé les commandes 
```sudo apt install cron``` et ```sudo systemctl enable cron```.

Pour créer une tache cron, utilisé la commande 
```crontab -e```, et ajouter une ligne
```* * * * * /usr/local/bin/backup.sh```.
Noté que la précédente commande avec et sans sudo seront 2 fichiers 
bien distincts, nous avons utilisé cette commande en sudo.

Pour que cron puisse exécuter le script backup.sh, ne pas oublier de donner
les droits d'exécution au script. on peut par exemple entrer la 
commande ```sudo chmod 755 /usr/local/bin/backup.sh```.

Pour recevoir les messages d'erreur visible dans ```/var/userName/mail```, 
très utile pour tester la tache cron,
il vous faudra peut-être utilisé la commande ```sudo apt install postfix```.
Vous pouvez suivre l'installation par défaut.

Initialement, le script devrait générer les fichiers compressés 
dans le dossier ```/tmp/backup/```.

### Backup
Pour des raisons de sécurité et conservation des données, il faut pouvoir
transférer les données compressées de nos utilisateurs avec cron sur un serveur backup.

Il faut donc qu'un serveur soit configuré afin de modifier
le script ```backup.sh``` avec les données correspondantes.
                                                              
- FTPD => destination des fichiers sur le serveur backup
- FTPU => nom d'utilisateur du serveur backup  
- FTPP => mot de passe de l'utilisateur du serveur backup    
- FTPS => ip du serveur backup  



## Preparation du serveur backup manuel
L'objectif de ce serveur backup sera de stocker des sauvegardes
des bases de données mysql du serveur web, ainsi que des données wordpress
d'un serveur web ; afin de pouvoir restaurer
l'ensemble des données en cas de problème important sur le serveur web.

@todo expliquez toute la mise en place du serveur backup

### Gestion des disques
Afin de pouvoir ajouter des disques et ainsi augmenter l'espace de stockage
disponible sur un serveur sans perturber son fonctionnement, on prépare une LVM
(logical volume manager).

Comme on travaille en local, l'ajout de disk ne se fait pas physiquement.
On doit aller sur l'interface virtualBox de la VM, dans configuration, 
stockage (contrôleur SATA).

Après avoir relancé la VM, diriger vous dans le dossier ```/dev```.
Vous devriez avoir des périphériques nommés sda, sdb, sdc ...
Le nouveau disque installé est l'élément au nom contenant 'sd' 
portant la lettre la plus proche de z dans l'ordre alphabétique.

#### Partitionnement
exécuter la commandes suivante ```sudo fdisk /dev/sdb ```.
Entrer la valeur ```n```, suivez les instructions qui s'afficheront, et sauver
les modifications en entrant ```w```. Vous avez ainsi partitionné le disque.

Cette nouvelle partition portera le nom du disque suivi du chiffre saisi 
lors de la creation (ex : sdb1).

#### Creation d'un LVM

#### Creation des volumes
On commence par crée le volume physique (pv), ceci avec la commande
```sudo pvcreate /dev/sdb1```, sdb1 évidemment remplacé par le nom 
de la partition crée précédemment.

On génère ensuite le groupe de volume (vg), avec la commande 
```sudo vgcreate backup-vg /dev/sdb1```.
Le premier paramètre est le nom du futur groupe de volume 
(ici backup-vg).
C'est sur ce dernier que l'on pourra ajouter 
du stockage avec de nouveau disque.

On crée ensuite un volume logique (lv), avec la commande 
```sudo lvcreate -n Vol1 -L 1.5g backup-vg```.
le paramètre -n défini le nom du volume, -L sa taille (1.5g = 1.5 Go), 
et le dernier paramètre est le nom du groupe de volume 
auquel se rattachera ce volume logique

#### Montages des volumes
Dans ```/dev/mapper```, on doit trouver le fichier ```backup--vg-Vol1```
(nomDuGroupe-nomDuVolume).
Il reste à le monter, ceci avec la commande 
```sudo mount /dev/mapper/backup--vg-Vol1 /var/backups```.
```/var/backups``` sera le dossier utilisé pour stocker les données
backup du serveur web.

Utilisé la commande ```sudo mkfs.ext4 /dev/mapper/backup--vg-Vol1```
pour formater le système de fichier en ext4.
Taper la commande ```blkid```, si tout c'est dérouler normalement
une ligne correspondant à ```backup--vg-Vol1``` devrait être visible.
La commande ```sudo df -kh``` afficheras quant à elle tout les 
volumes logiques monté.
[Si non, vous pouvez tenter de démonter le disque avec
```sudo umount backup--vg-Vol1```
et faite ```sudo mount -a```.
Essayez aussi de redémarrer la VM, avec ```reboot```.
]

```blkid``` permet de récupérer l'UUID du volume, que l'on peut
utiliser pour editer le fichier ```/etc/fstab```.
Celui-ci va nous permettre de ne pas perdre le montage du disque lors
de reboot.

On l'edite avec ```sudo vi /etc/fstab``` en ajoutant une ligne
```
/dev/disk/by-uiid/UUIDduVolume  /var/backups ext4 defaults 0 2
#OU
/dev/mapper/backup--vg-Vol1 /var/backups ext4 defaults 0 2
```

#### Extension du volume
On peut ensuite ajouter des extensions de volumes afin
d'augmenter l'espace de stockage du serveur sans perturber son fonctionnement.

Pour cela, il faut ajouter un disque (comme vu précédemment).
On peut alors saisir les commandes 
```
pvcreate sdc1
vgextend backup-vg sdc1
```
Le stockage est ainsi étendu, et on peut déplacé les données d'un
disque a l'autre avec la commande ```pvmove sdb1 sdc1```.

Ainsi, on pourra retirer le disque sans perdre de données
avec la commande ```vgreduce backup-vg sdb1```.
Les fichiers dans le dossier ```/var/backups``` devrait toujours être présent.


### SSH backup
Afin de pouvoir envoyer les fichiers backup sur le serveur prévu
à cet effet, on peut utiliser le SSH pour les transmettre.
Vous pouvez vous référer à la même section pour le 
[serveur web](#SSH) afin de préparer le serveur

### Reception des backups
Afin de pouvoir recevoir des backups sur ce serveur depuis le serveur web,
il faut pouvoir communiquer avec ce serveur à l'aide d'un utilisateur 
ayant les droits d'accès au repertoire ```/var/backups```.

Créer l'utilisateur avec la commande ```adduser backupuser```, puis la commande
```usermod -aG sudo backupuser``` afin de lui attribuer des droits sudo.
Transmettez le nom d'utilisateur, le password et l'ip du serveur backup au 
serveur web afin de configurer les bonnes valeurs dans le script ```get-uploads.sh```. 

- FTPD => destination =/var/backups
- FTPU => username = backupuser
- FTPP => password = le mot de passe saisi
- FTPS => ip serveur = 192.168.X.X


