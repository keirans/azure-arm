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
export COMPILEMASTERCOUNT='3'
export AZUREREGION='australiasoutheast'
export EYAMLPRIVATEKEYPATH=''


# Lets Create a bunch of suitable compile master keys
seq 0 ${COMPILEMASTERCOUNT} | while read COMPILEMASTERID
do
  echo "Purging Compile master node - ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}"
  puppet node purge ${COMPILEMASTERPREFIX}${COMPILEMASTERID}${FQDN}
done
