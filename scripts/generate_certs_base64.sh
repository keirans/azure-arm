#!/bin/bash
set -x
# This script does the following actions
# Creates a resource group
# Creates a keyvault
# Generates a set of CompileMaster Certs with altdns names
#
#
#

export RGNAME='puppetsecrets'
export VAULTNAME='puppetsecretsvault'
export COMPILEMASTERPREFIX='compilemaster'
export FQDN='.domain.com'
export DNSALTNAMES=''
export COMPILEMASTERCOUNT='3'
export AZUREREGION='australiasoutheast'
export EYAMLPRIVATEKEYPATH=''

az group create -n ${RGNAME} -l ${AZUREREGION}
az keyvault create --enabled-for-deployment true --location ${AZUREREGION} --resource-group ${RGNAME} --enabled-for-template-deployment true --sku standard -n ${VAULTNAME}



# Lets Create a bunch of suitable compile master keys
seq 0 ${COMPILEMASTERCOUNT} | while read COMPILEMASTERID
do
  echo "Generating Compile Master certs for ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}"
  puppet cert generate ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} --dns_alt_names ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN},${COMPILEMASTERPREFIX}${COMPILEMASTERID},puppet,puppet${FQDN}
  echo "Converting Private and Public Keys to Base64 in prepartion for upload to keyvault"
  base64 /etc/puppetlabs/puppet/ssl/private_keys/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.pem > /etc/puppetlabs/puppet/ssl/private_keys/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.b64
  base64 /etc/puppetlabs/puppet/ssl/public_keys/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.pem > /etc/puppetlabs/puppet/ssl/public_keys/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.b64
  base64 /etc/puppetlabs/puppet/ssl/certs/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.pem > /etc/puppetlabs/puppet/ssl/certs/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.b64
  
  COMPILEMASTERFQDNVAULT=`echo ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} | sed 's/\./-/g'` 
  echo "Uploading Private keys  ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} to ${VAULTNAME} as ${COMPILEMASTERFQDNVAULT}privkey"
  az keyvault secret set --file /etc/puppetlabs/puppet/ssl/private_keys/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.b64 --description "${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}privkey" --vault-name ${VAULTNAME} --name ${COMPILEMASTERFQDNVAULT}privkey --encoding base64
  echo "Uploading Public key  ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} to ${VAULTNAME} as ${COMPILEMASTERFQDNVAULT}pubkey"
az keyvault secret set --file /etc/puppetlabs/puppet/ssl/public_keys/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.b64 --description "${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}pubkey" --vault-name ${VAULTNAME} --name ${COMPILEMASTERFQDNVAULT}pubkey --encoding base64
  echo "Uploading Public cert  ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN} to ${VAULTNAME} as ${COMPILEMASTERFQDNVAULT}cert" 
  az keyvault secret set --file /etc/puppetlabs/puppet/ssl/certs/${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}.b64 --description "${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}cert" --vault-name ${VAULTNAME} --name ${COMPILEMASTERFQDNVAULT}cert --encoding base64

done
