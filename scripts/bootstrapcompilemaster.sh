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
echo "Setting up host entries for the instance"
echo "$(hostname -I) $(hostname)${FQDN} $(hostname)" >> /etc/hosts
echo "10.1.0.4 puppetmaster.example.com puppetmaster" >> /etc/hosts

# Disable some services for the PoC
echo "Disabling the Firewall on the host for this instance"
systemctl disable firewalld
systemctl stop firewalld

# CWD
cd /var/tmp/
echo "Setting up the EPEL Repo and installing all the additional software that is required"
yum -y -q  install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y -q install which git vim mlocate curl sudo unzip file python-devel python-pip python34 python34-devel wget bind-utils gcc openssl-devel

echo "Installing PIP into the new version of Python we have put in place"
curl -q -O https://bootstrap.pypa.io/get-pip.py > /dev/null
/usr/bin/python3 get-pip.py > /dev/null

echo "Installing the Azure CLI via PIP"
/usr/bin/pip3 install azure-cli -q

echo "Temporarilly setting the default version of Python to version 3 for the Azure actions"
rm -f /bin/python
ln -s /bin/python3 /bin/python

echo "Setting up all the Puppet vert and eyaml dirs for population out of Key Vault"
mkdir -p /etc/puppetlabs/puppet/ssl/{private_keys,public_keys,certs,ca}
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
echo "Logging into the Azure service with out Credentials passed to the bootstrap script"
az login --tenant ${TENANTID} --service-principal -u ${USERNAME} --password ${PASSWORD}

#
# We can now grab all our files from the Vault and put them on the filesystem !
#

# Grab the eyaml key and put it in place
echo "Downloading and installing the Puppet eyaml key"
az keyvault secret download --name eyamlprivate --vault-name puppetsecretsvault -f /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem

# Grab the Puppet CA's Public cert and put it in place
echo "Downloading and installing the Puppet CA cert"
az keyvault secret download --name puppetmaster-CA-cert  --vault-name puppetsecretsvault -f /etc/puppetlabs/puppet/ssl/ca/ca_crt.pem

# Grab the Instance specific components and put them in place
echo "Downloading and installing trhe Puppet compilemaster private key"
az keyvault secret download --name ${COMPILEMASTERFQDNVAULT}-privkey --vault-name puppetsecretsvault -f /etc/puppetlabs/puppet/ssl/private_keys/$(hostname)${FQDN}.pem
echo "Downloading and installing the Puppet compilemaster public key"
az keyvault secret download --name ${COMPILEMASTERFQDNVAULT}-pubkey --vault-name puppetsecretsvault -f /etc/puppetlabs/puppet/ssl/public_keys/$(hostname)${FQDN}.pem
echo "Downloading and installing the Puppet compilemaster public cert"
az keyvault secret download --name ${COMPILEMASTERFQDNVAULT}-cert --vault-name puppetsecretsvault -f /etc/puppetlabs/puppet/ssl/certs/$(hostname)${FQDN}.pem

# Logout of the azure environment - We no login need any access
echo "Logging out of the Azure API - We no longer need these privs"
#az logout

# Fix python again
echo "Returning the System Python version to version 2 - We are done with the Azure CLI"
rm -f /bin/python
ln -s /bin/python2 /bin/python

# Bootstrap from the master - Note this goes into the background.
echo "Installing Puppet from the Master of Masters - We already have all the secrets for the node in place"
curl -k https://puppetmaster.example.com:8140/packages/current/install.bash -o /var/tmp/install.bash
chmod 755 /var/tmp/install.bash
/var/tmp/install.bash  main:dns_alt_names='puppetmaster.example.com,puppet.example.com,puppet,puppetmaster,`hostname`,`hostname`.example.com'

#
# Lets wait for up to 6 minutes for the initial Puppet run to complete before running Puppet
# manually 2 more times to ensure everything is online, green in the console and the permissions
# on the eyaml files are correct.
#
COUNT=0
while [ $COUNT -ne 10 ]
do
  if [ -f /opt/puppetlabs/puppet/cache/state/agent_catalog_run.lock ]; then
    echo "It appears that Puppet is currently running. Sleeping for a minute before trying to run again ($COUNT / 10)"
    sleep 60
    COUNT=$(( $COUNT + 1 ))

  else
    echo "It appears that Puppet is not running, lets trigger it twice"
    /opt/puppetlabs/puppet/bin/puppet agent -tov # Run Once
    /opt/puppetlabs/puppet/bin/puppet agent -tov # Run Twice
    chown -R pe-puppet:pe-puppet /etc/puppetlabs/puppet/eyaml/ # Ensure perms on eyaml files
    exit 0
  fi
done

echo "Waited for 10 minutes for Puppet bootstrap to complete its initial runs - Failing build - Please investigate the logs"
exit 1
