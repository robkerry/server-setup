#! /usr/bin/env bash

#############################################
########## RUN THIS SCRIPT AS root ##########
#############################################


#########   CHANGE THESE SETTINGS   #########

TIMEZONE="America/New_York"

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
apt-get install -y ca-certificates
apt-get -y update
apt-get -y upgrade

### Install Required Software ###
apt-get remove -y memcached
apt-get remove -y unbound
apt-get install -y build-essential
apt-get install -y dnsutils
apt-get install -y nscd
apt-get install -y nano
apt-get install -y git
apt-get install -y python-pip
apt-get install -y gcc
apt-get install -y autoconf
apt-get install -y curl
apt-get install -y libtool
apt-get install -y python-dev
apt-get install -y make
apt-get install -y g++
apt-get install -y ufw

IPADDRESS=`dig -4 @resolver1.opendns.com -t a myip.opendns.com +short`
IFS='.' read -r -a array1 <<< ${HOSTNAME}; SHORTNAME=${array1[0]};
BASH_USERNAME=${USER}
CLIENTIP=`echo $SSH_CLIENT | awk '{ print $1}'`

## Fix the hostname ##

hostname $HOSTNAME
echo ${HOSTNAME} > /etc/hostname
echo -e "127.0.0.1\tlocalhost ${HOSTNAME} ${SHORTNAME}\n${IPADDRESS}\t${HOSTNAME} ${SHORTNAME}\n\n" > /etc/hosts

### Add Google DNS Resolvers ###
rm -Rf /etc/resolvconf/resolv.conf.d/*
touch /etc/resolvconf/resolv.conf.d/base
touch /etc/resolvconf/resolv.conf.d/head
touch /etc/resolvconf/resolv.conf.d/original
echo -e "nameserver 127.0.0.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4\noptions timeout 1\n" > /etc/resolvconf/resolv.conf.d/tail
resolvconf -u

### Configure Time Server & Timezone ###
rm -Rf /etc/localtime;ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
rm -Rf /etc/timezone;ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/timezone
apt-get install -y ntp
service ntp stop
ntpd -gq
service ntp start

### Configure SSH ###
adduser ${USERNAME}
adduser ${USERNAME} sudo
mkdir -p /home/${USERNAME}/.ssh
echo ${SSHPUBKEY} > /home/${USERNAME}/.ssh/authorized_keys
chown -Rf ${USERNAME}:${USERNAME} /home/${USERNAME}
wget "https://raw.githubusercontent.com/robkerry/server-setup/master/config/sshd_config" -O sshd_config
mv -f /etc/ssh/sshd_config /etc/ssh/sshd_config.old
mv -f sshd_config /etc/ssh/sshd_config

### Configure Firewall ###

ufw default deny incoming
ufw default allow outgoing
ufw allow 22123/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from ${CLIENTIP}
ufw enable

service ufw restart
service ssh restart

echo -e "\nInstall Complete!\n\nIn future, SSH into this server using 'ssh ${USERNAME}@${HOSTNAME} -p 22123'"
