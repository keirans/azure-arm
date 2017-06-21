#!/bin/bash
az group create -n puppetmasterrg  -l australiasoutheast
az group deployment create -g puppetmasterrg --template-file puppetmaster-template.json --parameters @puppetmaster-params.json


