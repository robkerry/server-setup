#! /usr/bin/env bash

#############################################
########## RUN THIS SCRIPT AS root ##########
#############################################


#########   CHANGE THESE SETTINGS   #########

TIMEZONE="Europe/London"
DATADRIVE="/dev/sdb"

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
sudo apt-get install -y ca-certificates
sudo apt-get -y update
sudo apt-get -y upgrade

### Install Required Software ###
sudo apt-get install -y build-essential
sudo apt-get install -y dnsutils
sudo apt-get install -y software-properties-common
sudo apt-get install -y nscd
sudo apt-get install -y nano
sudo apt-get install -y git
sudo apt-get install -y python-pip
sudo apt-get install -y gcc
sudo apt-get install -y autoconf
sudo apt-get install -y curl
sudo apt-get install -y libtool
sudo apt-get install -y python-dev
sudo apt-get install -y make
sudo apt-get install -y g++
sudo apt-get install -y ufw
sudo apt-get install -y fail2ban

sudo apt-get -y auto-remove

### Mount & Format Data Drive ###

sudo umount "$DATADRIVE"
printf "o\nn\np\n1\n\n\nw\n" | sudo fdisk "$DATADRIVE"
sudo mkfs.ext4 "${DATADRIVE}1"
sudo tune2fs -m 0.5 "$DATADRIVE"
sudo mkdir /data
sudo echo -e "${DATADRIVE}\t/data\text4\tdefaults,noatime\t0\t0\n" >> /etc/fstab
sudo mount -a

IPADDRESS=`dig -4 @resolver1.opendns.com -t a myip.opendns.com +short`
IFS='.' read -r -a array1 <<< ${HOSTNAME}; SHORTNAME=${array1[0]};
BASH_USERNAME=${USER}
CLIENTIP=`echo $SSH_CLIENT | awk '{ print $1}'`

## Fix the hostname ##

hostname $HOSTNAME
sudo echo ${HOSTNAME} > /etc/hostname
sudo echo -e "127.0.0.1\tlocalhost ${HOSTNAME} ${SHORTNAME}\n${IPADDRESS}\t${HOSTNAME} ${SHORTNAME}\n\n" > /etc/hosts

### Add Google DNS Resolvers ###
sudo rm -Rf /etc/resolvconf/resolv.conf.d/*
sudo touch /etc/resolvconf/resolv.conf.d/base
sudo touch /etc/resolvconf/resolv.conf.d/head
sudo touch /etc/resolvconf/resolv.conf.d/original
sudo echo -e "nameserver 127.0.0.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4\noptions timeout 1\n" > /etc/resolvconf/resolv.conf.d/tail
resolvconf -u

### Configure Time Server & Timezone ###
sudo rm -Rf /etc/localtime;ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
sudo rm -Rf /etc/timezone;ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/timezone
sudo apt-get install -y ntp
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

### Configure Elastic Search ###
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get -y install oracle-java8-installer
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
sudo apt-get -y update
sudo apt-get -y install elasticsearch
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable elasticsearch.service
sudo systemctl start elasticsearch.service

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
