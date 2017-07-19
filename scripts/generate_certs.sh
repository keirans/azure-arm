#!/bin/bash
# Generate Certs - Pregenerate and store Puppet compile master certs into Azure Key Vault
# Keiran Sweet <Keiran@gmail.com>
# ------------------------------------------------------------------------------------------
# Example code - Use at your own risk
#
# This script demonstrates how to do the following when run from a Puppet Master of Masters
# with the Azure CLI configured and authenticated with the correct access to create Resource Groups
# Key Vaults and other resources.
#
# - Create a resource group for the Keyvault
# - Create a keyvault to store the compile master secrets and related data (puppetsecretsvault)
# - Create a set of compileMaster Certs with altdns names (40 certs by default)
# - Upload the keys and certs to the keyvault that we have just created
# - Upload the eyaml private key to the keyvault that we have just created
# 
# The structure of the key vault content, using compilemaster0 as an example is below:
#
# ->  puppetsecretsvault
#   -> secrets
#     -> compilemaster0-example-com-cert
#     -> compilemaster0-example-com-privkey
#     -> compilemaster0-example-com-pubkey 
#     -> puppetmaster-CA-cert
#     -> eyamlprivate
#
# Modify these values for your environment.
#
export RGNAME='puppetsecretsrg'
export VAULTNAME='puppetsecretsvault'
export COMPILEMASTERPREFIX='compilemaster'
export FQDN='.example.com'
export COMPILEMASTERCOUNT='40'
export AZUREREGION='australiasoutheast'
export EYAMLPRIVATEKEYPATH='/etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem'

# Backup your SSL data first.
echo "Backing up all SSL data into /var/tmp/ first"
tar -zcvf /var/tmp/puppet-ssl-backup.tgz.$$ /etc/pupppetlabs/puppet/ssl/
chmod 700 /var/tmp/puppet-ssl-backup.tgz.$$

# Create your Resource Group and Key Vault
echo "Creating Resource Group ${RGNAME} in ${AZUREREGION}"
az group create -n ${RGNAME} -l ${AZUREREGION} > /dev/null
echo "Creating keyvault ${VAULTNAME} in ${RGNAME}"
az keyvault create --enabled-for-deployment true --location ${AZUREREGION} --resource-group ${RGNAME} --enabled-for-template-deployment true --sku standard -n ${VAULTNAME} > /dev/null

# Lets create a set of suitable compile master keys based on the count variable
seq 0 ${COMPILEMASTERCOUNT} | while read COMPILEMASTERID
do
  echo "Generating Compile Master certs for ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}"
  puppet cert generate ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} --dns_alt_names ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN},${COMPILEMASTERPREFIX}${COMPILEMASTERID},puppet,puppet${FQDN} > /dev/null
  
  COMPILEMASTERFQDNVAULT=`echo ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} | sed 's/\./-/g'` 
  echo "Uploading Private keys ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} to ${VAULTNAME} as ${COMPILEMASTERFQDNVAULT}-privkey"
  az keyvault secret set --file /etc/puppetlabs/puppet/ssl/private_keys/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.pem --description "${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}-privkey" --vault-name ${VAULTNAME} --name ${COMPILEMASTERFQDNVAULT}-privkey --encoding ascii > /dev/null
  echo "Uploading Public key ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} to ${VAULTNAME} as ${COMPILEMASTERFQDNVAULT}-pubkey"
az keyvault secret set --file /etc/puppetlabs/puppet/ssl/public_keys/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.pem --description "${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}pubkey" --vault-name ${VAULTNAME} --name ${COMPILEMASTERFQDNVAULT}-pubkey --encoding ascii > /dev/null
  echo "Uploading Public cert ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} to ${VAULTNAME} as ${COMPILEMASTERFQDNVAULT}-cert" 
  az keyvault secret set --file /etc/puppetlabs/puppet/ssl/certs/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.pem --description "${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}-cert" --vault-name ${VAULTNAME} --name ${COMPILEMASTERFQDNVAULT}-cert --encoding ascii > /dev/null
done

# If the eyaml key exists, lets also upload that as 'eyamlprivate' into the vault

if [ -f $EYAMLPRIVATEKEYPATH ]; then
  echo "Found eyaml private key. Uploading to vault as eyamlprivate"
  az keyvault secret set --file $EYAMLPRIVATEKEYPATH --description "hiera eyaml private key" --vault-name ${VAULTNAME} --name eyamlprivate --encoding ascii > /dev/null
fi

