#!/bin/bash
#set -x
# This script does the following actions
# Creates a resource group
# Creates a keyvault
# Generates a set of CompileMaster Certs with altdns names
#
#
#

export RGNAME='keyvaultsg'
export VAULTNAME='puppetvault'
export COMPILEMASTERPREFIX='compilemaster'
export FQDN='.domain.com'
export DNSALTNAMES=''
export COMPILEMASTERCOUNT='40'
export AZUREREGION='australiasoutheast'
export EYAMLPRIVATEKEYPATH=''

echo "Creating Resource Group ${RGNAME} in ${AZUREREGION}"
az group create -n ${RGNAME} -l ${AZUREREGION} > /dev/null
echo "Creating keyvault ${VAULTNAME} in ${RGNAME}"
az keyvault create --enabled-for-deployment true --location ${AZUREREGION} --resource-group ${RGNAME} --enabled-for-template-deployment true --sku standard -n ${VAULTNAME} > /dev/null



# Lets Create a bunch of suitable compile master keys
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
