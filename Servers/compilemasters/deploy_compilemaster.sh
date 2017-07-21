#!/bin/bash
# Deploy a single compile master from the template files into australiasoutheast using the CLI.
#
az group create --location australiasoutheast -n compilemastersrg
az group  deployment create -g compilemastersrg --template-file multiple-compilemaster-template.json --parameters @compilemaster-params.json
