#!/bin/bash
# This script is used to deploy the Puppetmaster virtual machine into a resource group in the australiasoutheast
# region so you can configure it as a master of masters.
# Use in combination with the resource templates.
#
az group create -n puppetmasterrg  -l australiasoutheast
az group deployment create -g puppetmasterrg --template-file puppetmaster-template.json --parameters @puppetmaster-params.json


