#! /usr/bin/env bash

#############################################
########## RUN THIS SCRIPT AS root ##########
#############################################


#########   CHANGE THESE SETTINGS   #########

TIMEZONE="Europe/London"

###############   ALL DONE!   ###############

echo -e "\nPlease enter a hostname for the server to begin."
read -p 'Hostname: ' hostvar
HOSTNAME=$hostvar

echo -e "\nPlease enter a username to create."
read -p 'Username: ' uservar
USERNAME=$uservar

echo -e "\nPlease enter your SSH public key (Starts with 'ssh-rsa ' and often found by typing 'cat ~/.ssh/id_rsa.pub' in Terminal/Console)."
read -p 'SSH Public Key: ' sshvar
SSHPUBKEY=$sshvar

echo "Starting setup script..."

### Run Software Updates First ###
sudo apt install -y ca-certificates
sudo add-apt-repository -y ppa:nginx/development
#sudo add-apt-repository -y ppa:ondrej/php
sudo apt -y update
sudo apt -y upgrade

### Install Required Software ###
sudo apt install -y unattended-upgrades htop build-essential dnsutils software-properties-common nscd nano git python2.7 python-pip python3 gcc autoconf curl libtool python-dev make g++ ufw fail2ban wget zip unzip ntp
sudo apt install -y redis-server nginx php7.2-fpm php7.2-cli php7.2-sqlite3 php7.2-mysql php7.2-gd php7.2-curl php7.2-memcached php7.2-imap php7.2-mbstring php7.2-xml php7.2-zip php7.2-bcmath php7.2-soap php-redis php7.2-intl php7.2-readline php7.2-dev

sudo apt autoremove

IPADDRESS=`dig -4 @resolver1.opendns.com -t a myip.opendns.com +short`
IFS='.' read -r -a array1 <<< ${HOSTNAME}; SHORTNAME=${array1[0]};
BASH_USERNAME=${USER}
CLIENTIP=`echo $SSH_CLIENT | awk '{ print $1}'`

## Fix the hostname ##

hostname $HOSTNAME
sudo echo ${HOSTNAME} > /etc/hostname
sudo echo -e "127.0.0.1\tlocalhost ${HOSTNAME} ${SHORTNAME}\n${IPADDRESS}\t${HOSTNAME} ${SHORTNAME}\n\n" > /etc/hosts

### Configure Time Server & Timezone ###
sudo rm -Rf /etc/localtime;ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
sudo rm -Rf /etc/timezone;ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/timezone
sudo service ntp stop
sudo ntpd -gq
sudo service ntp start

### Configure SSH ###
sudo adduser ${USERNAME}
sudo adduser ${USERNAME} sudo
sudo mkdir -p /home/${USERNAME}/.ssh
sudo echo ${SSHPUBKEY} > /home/${USERNAME}/.ssh/authorized_keys
sudo chown -Rf ${USERNAME}:${USERNAME} /home/${USERNAME}
sudo wget "https://raw.githubusercontent.com/robkerry/server-setup/master/config/sshd_config" -O sshd_config
sudo mv -f /etc/ssh/sshd_config /etc/ssh/sshd_config.old
sudo mv -f sshd_config /etc/ssh/sshd_config

### Configure NGINX ###

curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.2/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = Off/" /etc/php/7.2/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 2048M/" /etc/php/7.2/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = Europe\/London/" /etc/php/7.2/cli/php.ini
sudo sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 2048M/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = Europe\/London/" /etc/php/7.2/fpm/php.ini

sudo sed -i "s/;opcache.enable=.*/opcache.enable=1/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=512/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=16/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=0/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/;opcache.save_comments=.*/opcache.save_comments=0/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/;opcache.fast_shutdown=.*/opcache.fast_shutdown=1/" /etc/php/7.2/fpm/php.ini

sudo chmod 733 /var/lib/php/sessions
sudo chmod +t /var/lib/php/sessions
sudo service php7.2-fpm restart

sudo rm -Rf /var/www/html/*
sudo echo -e "<?php echo gethostname(); ?>" > /var/www/html/index.php

sudo wget "https://raw.githubusercontent.com/robkerry/server-setup/master/config/nginx_default" -O nginx_default && sudo mv -f nginx_default /etc/nginx/sites-available/default

echo -e "\n\nNext we'll create a 'website' user, that will be used by NGINX, PHP and when uploading website files...\n\n" && sleep 5

sudo adduser website
sudo usermod -aG sudo website
sudo chown -Rf website:website /var/www/html
sudo sed -i "s/user = .*/user = website/" /etc/php/7.2/fpm/pool.d/www.conf
sudo sed -i "s/group = .*/group = website/" /etc/php/7.2/fpm/pool.d/www.conf

sudo sed -i "s/pm.max_children = .*/pm.max_children = 10/" /etc/php/7.2/fpm/pool.d/www.conf
sudo sed -i "s/pm.start_servers = .*/pm.start_servers = 4/" /etc/php/7.2/fpm/pool.d/www.conf
sudo sed -i "s/pm.min_spare_servers = .*/pm.min_spare_servers = 4/" /etc/php/7.2/fpm/pool.d/www.conf
sudo sed -i "s/pm.max_spare_servers = .*/pm.max_spare_servers = 6/" /etc/php/7.2/fpm/pool.d/www.conf
sudo sed -i "s/;pm.max_requests = .*/pm.max_requests = 10000/" /etc/php/7.2/fpm/pool.d/www.conf

sudo sysctl -w net.core.somaxconn=100000
sudo sysctl -w net.ipv4.ip_local_port_range="10000 65535"
sudo sysctl -w net.ipv4.tcp_tw_reuse=1
sudo echo -e "net.core.somaxconn=100000\nnet.ipv4.ip_local_port_range=10000 65535\nsysctl -w net.ipv4.tcp_tw_reuse=1\n" > /etc/sysctl.d/network-tuning.conf

sudo phpdismod xdebug

sudo service php7.2-fpm restart
sudo service nginx restart

### Configure Firewall ###

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22123/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow from ${CLIENTIP}
sudo ufw enable

sudo service ufw restart
sudo service ssh restart

sudo echo -e "\nInstall Complete!\n\nIn future, SSH into this server using 'ssh ${USERNAME}@${HOSTNAME} -p 22123'"
