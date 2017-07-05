#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Compile Master Bootstrap"
  echo "Usage: $0 -t <tennantid> -u <username> -p <password>"
  exit 1
fi

export COMPILEMASTERPREFIX='compilemaster'
export FQDN='.example.com'
export  COMPILEMASTERFQDNVAULT=`echo $(hostname)${FQDN} | sed 's/\./-/g'`

# Put in the Puppet master IPs in the place of having DNS for now.
echo "$(hostname -I) $(hostname)${FQDN} $(hostname)" >> /etc/hosts
echo "10.1.0.4 puppetmaster.example.com puppetmaster" >> /etc/hosts

# CWD
cd /var/tmp/

yum -y -q  install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y -q install which git vim mlocate curl sudo unzip file python-devel python-pip python34 python34-devel wget bind-utils gcc openssl-devel

curl -q -O https://bootstrap.pypa.io/get-pip.py > /dev/null
/usr/bin/python3 get-pip.py > /dev/null
/usr/bin/pip3 install azure-cli -q

rm -f /bin/python
ln -s /bin/python3 /bin/python

mkdir -p /etc/puppetlabs/puppet/ssl/{private_keys,public_keys,certs}
mkdir -p /etc/puppetlabs/puppet/eyaml

while getopts :t:u:p:h opt "$@"; do
  case $opt in
    t)
#      echo "-t was triggered, Parameter: $OPTARG" >&2
      export TENANTID=$OPTARG
      ;;
    u)
#      echo "-u was triggered, Parameter: $OPTARG" >&2
      export USERNAME=$OPTARG
      ;;
    p)
#      echo "-p was triggered, Parameter: $OPTARG" >&2
      export PASSWORD=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac

done

# Login to Azure with our service principals

az login --tenant ${TENANTID} --service-principal -u ${USERNAME} --password ${PASSWORD}

#
# We can now grab all our files from the Vault and put them on the filesystem !
#

# Grab the eyaml key and put it in place
az keyvault secret download --name eyamlprivate --vault-name puppetsecretsvault -f /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem

# Grab the Instance specific components and put them in place
az keyvault secret download --name ${COMPILEMASTERFQDNVAULT}-privkey --vault-name puppetsecretsvault -f /etc/puppetlabs/puppet/ssl/private_keys/$(hostname)${FQDN}.pem
az keyvault secret download --name ${COMPILEMASTERFQDNVAULT}-pubkey --vault-name puppetsecretsvault -f /etc/puppetlabs/puppet/ssl/public_keys/$(hostname)${FQDN}.pem
az keyvault secret download --name ${COMPILEMASTERFQDNVAULT}-cert --vault-name puppetsecretsvault -f /etc/puppetlabs/puppet/ssl/certs/$(hostname)${FQDN}.pem

# Logout of the azure environment - We no login need any access
#az logout

# Finally - Fix python again
#rm -f /bin/python
#ln -s /bin/python2 /bin/python
