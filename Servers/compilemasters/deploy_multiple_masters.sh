#!/bin/bash
# Deploy a set of compile masters into australiasoutheast using a set of nested templates
# and the Azure CLI
az group create --location australiasoutheast -n compilemastersrg
az group  deployment create -g compilemastersrg --template-file multiple-compilemaster-template.json 
