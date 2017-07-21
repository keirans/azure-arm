#!/bin/bash
# This script purges the compile master nodes from the Puppet environment
# between 0 and COUNT. Handy for removing compile masters from your environment
# when testing.
# Use with caution.

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
