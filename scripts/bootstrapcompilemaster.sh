#!/bin/bash
#
# p - instance private key
# c - instance cert
# a - Puppet CA public cert
# e - eyaml private key
#

mkdir -p /etc/puppetlabs/puppet/ssl/

while getopts :p:c:a:e: opt "$@"; do
  case $opt in
    p)
      #echo "-p was triggered, Parameter: $OPTARG" >&2
      echo "$OPTARG" > /etc/puppetlabs/puppet/ssl/privkey.pem
      ;;
    c)
      #echo "-c was triggered, Parameter: $OPTARG" >&2
      echo "$OPTARG" > /etc/puppetlabs/puppet/ssl/cert.pem
      ;;
    a)
      #echo "-a was triggered, Parameter: $OPTARG" >&2
      echo "$OPTARG" > /etc/puppetlabs/puppet/ssl/ca.pem
      ;;
    e)
      #echo "-e was triggered, Parameter: $OPTARG" >&2
      echo "$OPTARG" > /etc/puppetlabs/puppet/ssl/eyaml.pem
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac

done
