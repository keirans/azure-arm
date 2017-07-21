# Compile Master - eyaml gem installation example
# Keiran Sweet <keiran@gmail.com>
# ----------------------------------------
# This Sample Puppet class, when applied to Puppet masters will install the 
# hiera-eyaml gem into the Puppet server and restart it.
# It would be used in conjunction with the Puppetmaster node group
# and compile masters to ensure that when they are provisioned that they
# contain all the Ruby functionality to decrypt the eyaml secrets.
# For this to function, we'd use hiera5 and the hierachy configuration
# in the control repo.
#
#

class compilemasters { 

  package { 'hiera-eyaml':
    ensure   => present,
    provider => puppetserver_gem,
    notify   => Service['pe-puppetserver']
  }

}
