#!/bin/bash
IPADDR=`hostname -I`
echo "$IPADDR puppetmaster.example.com puppet.example.com puppet puppetmaster" >> /etc/hosts
systemctl disable firewalld
systemctl stop firewalld

setenforce 0
sed -i -e 's/enforcing/permissive/g' /etc/sysconfig/selinux

cd /var/tmp/
wget 'https://pm.puppetlabs.com/cgi-bin/download.cgi?dist=el&rel=7&arch=x86_64&ver=latest' -O pe.tgz

yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install which git vim mlocate curl sudo unzip file python-devel python-pip python34 python34-devel wget bind-utils gcc openssl-devel

curl -O https://bootstrap.pypa.io/get-pip.py
/usr/bin/python3 get-pip.py
/usr/bin/pip3 install azure-cli
rm -f /bin/python
ln -s /bin/python3 /bin/python
