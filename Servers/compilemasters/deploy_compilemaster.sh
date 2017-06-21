#!/bin/bash

az group create --location australiasoutheast -n compilemastersrg
az group  deployment create -g compilemastersrg --template-file multiple-compilemaster-template.json --parameters @compilemaster-params.json
