#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

printf "Check if dpkg is available...\n"
which dpkg > /dev/null
if [ $? -ne 0 ]
then
    printf "This script is only for Linux with dpkg and apt.\n"
    exit 254
fi

printf "Check if MySQL is already installed...\n"
dpkg -l | egrep -q "mariadb-server|mysql-server"
if [ $? -ne 0 ]
then
    _NEW_MYSQL=1
    while [ "x${_PASSWORD}" == "x" ]
    do
        printf "Enter the new root password: "
        read -s _PASSWORD
        printf "\n"
        printf "Retype the new root password: "
        read -s _PASSWORD_CHECK
        printf "\n"
        if [ "x${_PASSWORD}" != "x${_PASSWORD_CHECK}" ]
        then
            _PASSWORD=""
            printf "The two passwords are not the same.\n"
        fi
    done
else
    _NEW_MYSQL=0
    while [ "x${_PASSWORD}" == "x" ]
    do
        printf "Enter the root password: "
        read -s _PASSWORD
        printf "\n"
        mysql -u root -p${_PASSWORD} -e "show databases" > /dev/null 2>&1
        if [ $? -ne 0 ]
        then
            printf "The root password is not OK. Retype the password\n"
            _PASSWORD=""
        fi
    done
fi

printf "Configure new database for FOS-Streaming-v1...\n"
printf "Enter the name of new database:"
read _DB_NAME_FOS
printf "Enter the new user for database ${_DB_NAME_FOS}:"
read _DB_USER_FOS
while [ "x${_DB_PASS_FOS}" == "x" ]
do
    printf "Enter the new ${DB_USER_FOS} password: "
    read -s _DB_PASS_FOS
    printf "\n"
    printf "Retype the new ${DB_USER_FOS} password: "
    read -s _PASSWORD_CHECK
    printf "\n"
    if [ "x${_DB_PASS_FOS}" != "x${_PASSWORD_CHECK}" ]
    then
        _DB_PASS_FOS=""
        printf "The two passwords are not the same.\n"
    fi
done
printf "\n"

printf "Configure directory for installation FOS-Streaming-v1...\n"
printf "Enter the directory for installation FOS-Streaming-v1:"
read _DIRECTORY_FOS
mkdir -p "$(dirname ${_DIRECTORY_FOS})"
if [ $? -ne 0 ]
then
    printf "Can not create directory. Exit...\n"
    exit 253
fi

which aptitude > /dev/null
if [ $? -eq 0 ]
then
    _APT="aptitude"
else
    _APT="apt-get"
fi

printf "Upgrade apt...\n"
${_APT} update
${_APT} -y full-upgrade

printf "Install packages...\n"
if [ ${_NEW_MYSQL} -eq 1 ]
then
    ${_APT} -y install nginx-full php-fpm ffmpeg git ca-certificates composer php-mbstring php-zip php-mysql mariadb-server curl
    printf "Configure MySQL...\n"
    echo -e "grant all privileges on *.* to 'root'@'localhost' identified by '${_PASSWORD}' with grant option;\nupdate mysql.user set password=password('${_PASSWORD}') where user='root';\ndelete from mysql.user where user='';delete from mysql.user where user='root' and host = 'unix_socket';\ndelete from mysql.db where db='test' or db='test\\_%';\nflush privileges;\n" | mysql
else
    ${_APT} -y install nginx-full php-fpm ffmpeg git ca-certificates composer php-mbstring php-zip php-mysql curl
    printf "Configure MySQL...\n"
fi

mysql -u root -p${_PASSWORD} -e "create database ${_DB_NAME_FOS}"
mysql -u root -p${_PASSWORD} -e "grant all privileges on ${_DB_NAME_FOS}.* to '${_DB_USER_FOS}'@'localhost' identified by '${_DB_PASS_FOS}'"

printf "Get FOS-Streaming-v1...\n"
git clone https://github.com/nmichael000/FOS-Streaming-v1.git ${_DIRECTORY_FOS}
chown -R www-data: ${_DIRECTORY_FOS}
mkdir -p /var/www/.composer
chown www-data: /var/www/.composer/
printf "Install package by composer...\n"
su - www-data -c "composer install -d ${_DIRECTORY_FOS}" --shell=/bin/bash

printf "Configure FOS-Streaming-v1 and nginx...\n"
sed -i -e 's/xxx/'${_DB_NAME_FOS}'/g' -e 's/ttt/'${_DB_USER_FOS}'/g' -e 's/zzz/'${_DB_PASS_FOS}'/g' ${_DIRECTORY_FOS}/config.php
cp -p ${_DIRECTORY_FOS}/config/fos-streaming.nginx /etc/nginx/sites-available/fos-streaming
sed -i 's/yyy/'${_DIRECTORY_FOS}'/g' /etc/nginx/sites-available/fos-streaming
ln -s /etc/nginx/sites-available/fos-streaming /etc/nginx/sites-enabled/
/etc/init.d/nginx restart

printf "Migrate the database for FOS-Streaming-v1...\n"
cp -p ${_DIRECTORY_FOS}/install_database_tables.php ${_DIRECTORY_FOS}/install_database.php
sed -i -e 's/.*logincheck.*//g' -e 's#yyy#'${_DIRECTORY_FOS}'/hls#g' ${_DIRECTORY_FOS}/install_database.php
curl "http://127.0.0.1:8000/install_database.php?install"
curl "http://127.0.0.1:8000/install_database.php?update"
rm ${_DIRECTORY_FOS}/install_database.php
