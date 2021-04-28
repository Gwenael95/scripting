WPDIR="wordpress"

DB_NAME=$(basename `pwd`)
DB_NAME=${DB_NAME%.*}
DB_USER="root"
DB_PASSWORD="root"
DB_HOST="localhost"
DB_COLLATE="utf8_default_ci"

WP_DEBUG=true


# Default values
PROPERTY=0
for item in "$@"
do

    if [ $PROPERTY != 0 ] ; then
        export $PROPERTY=$item
        PROPERTY=0
    elif [ $item = '-l' ] ; then
        PROPERTY=WPLANG
    elif [ $item = '-v' ] ; then
        PROPERTY=WP_VERSION
    elif [ ${item:0:1} = '-' ] ; then
        PROPERTY=0
    fi

done


# Set WPLANG
if [ -z $WPLANG ] ; then
    WPLANG=`locale | grep LANG`
    WPLANG=${WPLANG#*"\""}
    WPLANG=${WPLANG%.*}

    if [[ $WPLANG == LANG\=* ]] ; then
        WPLANG='sv_SE'
    fi
fi

if [ $WPLANG == "sv_SE" ] ; then
    DB_COLLATE="utf8_swedish_ci"
fi

# Set WP_VERSION
if [ -z $WP_VERSION ] ; then
    WP_VERSION=`svn ls http://core.svn.wordpress.org/tags | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | tail -n 1`
fi


WP_SVN_URL="http://core.svn.wordpress.org/tags/${WP_VERSION}"
WPLANG_SVN_URL="http://svn.automattic.com/wordpress-i18n/${WPLANG}/tags/${WP_VERSION}/"

# Temp file needed by sed et. al
TEMP_FILE="/tmp/out.tmp.$$"

# Get latest WordPress from svn
svn co $WP_SVN_URL $WPDIR

# Copy index.php file to root directory and set $WPDIR path
cp $WPDIR/index.php .

OLD="\.\/wp-blog-header\.php"
NEW="\.\/$WPDIR\/wp-blog-header\.php"
sed "s/$OLD/$NEW/g" index.php > $TEMP_FILE && mv $TEMP_FILE index.php

# Setup wp-config.php
cp $WPDIR/wp-config-sample.php $WPDIR/wp-config.php

# Set database connection
DB_DEFINES=('DB_NAME' 'DB_USER' 'DB_PASSWORD' 'DB_HOST' 'WPLANG' 'DB_COLLATE')

for DB_PROPERTY in ${DB_DEFINES[@]} ;
do
    OLD="define('$DB_PROPERTY', '.*')"
    NEW="define('$DB_PROPERTY', '${!DB_PROPERTY}')"  # Will probably need some pretty crazy escaping to allow for better passwords

    sed "s/$OLD/$NEW/g" $WPDIR/wp-config.php > $TEMP_FILE && mv $TEMP_FILE $WPDIR/wp-config.php
done

# Some good practice settings
WP_DEBUG="define('WP_DEBUG', true); define('FORCE_SSL_LOGIN', false); define('FORCE_SSL_ADMIN', false); define('DISALLOW_FILE_EDIT', true); define('DISALLOW_FILE_MODS', false);"

sed "s/define('WP_DEBUG', false);/$WP_DEBUG/g" $WPDIR/wp-config.php > $TEMP_FILE && mv $TEMP_FILE $WPDIR/wp-config.php

# Add unique table_prefix
TABLE_PREFIX=`cat /dev/urandom | strings | grep -o '[[:alnum:]]' | head -n 5 | tr -d '\n' ; echo -n ;  echo -n "_wp_"`
sed "s/$table_prefix  = 'wp_'/$table_prefix  = '$TABLE_PREFIX'/g" $WPDIR/wp-config.php > $TEMP_FILE && mv $TEMP_FILE $WPDIR/wp-config.php

# Setup keys and salts
OLD="put your unique phrase here"
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

# Get language files
svn co "${WPLANG_SVN_URL}dist/" "${WPDIR}-${WPLANG}"
find "${WPDIR}-${WPLANG}" -name .svn -exec rm -rf {} \; &>/dev/null
cp -Rv "${WPDIR}-${WPLANG}"/* "${WPDIR}"
rm -rf "${WPDIR}-${WPLANG}"

svn co "${WPLANG_SVN_URL}messages/" "${WPDIR}-${WPLANG}"
find "${WPDIR}-${WPLANG}" -name .svn -exec rm -rf {} \; &>/dev/null
test -d "${WPDIR}"/wp-content/languages/ || mkdir -p "${WPDIR}"/wp-content/languages/
cp -vR "${WPDIR}-${WPLANG}"/* "${WPDIR}"/wp-content/languages/
rm -rf "${WPDIR}-${WPLANG}"


# Install some plugins
cd $WPDIR/wp-content/plugins/

PLUGINS=('any-hostname' 'logged-in' 'regenerate-thumbnails' 'email-address-encoder')
for PLUGIN in ${PLUGINS[@]} ;
do
    PLUGIN_VERSION=`svn ls http://plugins.svn.wordpress.org/${PLUGIN}/tags | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | tail -n 1`
    PLUGIN_SVN_URL="http://plugins.svn.wordpress.org/${PLUGIN}/tags/${PLUGIN_VERSION}"

    echo ${PLUGIN_SVN_URL}

    svn co "${PLUGIN_SVN_URL}" "${PLUGIN}"
done

# Pull from private git (sorry folks)
git clone git@juliet:hwptypekit

# Plugins not available in WP plugins repository
curl -A "Mozilla/4.0" -O http://www.cssigniter.com/freebies/plugins/ci-retina.zip
unzip ci-retina.zip
rm ci-retina.zip


# Install some themes
cd ../themes/

git clone git@bitbucket.org:dessibelle/themes-hobo-theme hobo-theme
git clone git@bitbucket.org:dessibelle:themes-template template

# Use mysql if available, otherwise default to MAMP version
MYSQL_PATH=`which mysql`
if [ -z "$MYSQL_PATH" ] ; then
    MYSQL_PATH='/Applications/MAMP/Library/bin/mysql'
fi

# Create database
$MYSQL_PATH --user=$DB_USER --password=$DB_PASSWORD<<EOFMYSQL
CREATE DATABASE IF NOT EXISTS $DB_NAME;
EOFMYSQL

cd ./template
./setup.sh

exit 0