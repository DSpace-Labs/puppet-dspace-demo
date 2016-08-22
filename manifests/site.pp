##
# site.pp
#
# This Puppet script does the following:
# 1. Initializes the VM
# 2. Installs base DSpace prerequisites (Java, Maven, Ant) via our custom "dspace" Puppet module
# 3. Installs PostgreSQL (via a third party Puppet module)
# 4. Installs Tomcat (via a third party Puppet module)
# 5. Installs DSpace via our custom "dspace" Puppet Module
#
# Tested on:
# - Ubuntu 16.04LTS
##

# Global default to requiring all packages be installed & apt-update to be run first
Package {
  ensure => latest,                # requires latest version of each package to be installed
  require => Exec["apt-get-update"],
}

# Global default path settings for all 'exec' commands
Exec {
  path => "/usr/bin:/usr/sbin/:/bin:/sbin:/usr/local/bin:/usr/local/sbin",
}

# Run apt-get update before installing anything
exec {"apt-get-update":
  command => "/usr/bin/apt-get update",
  refreshonly => true, # only run if notified
}

#--------------------------------------------------
# Initialize base pre-requisites (Java, Maven, Ant)
#--------------------------------------------------
# Initialize the DSpace module in order to install base prerequisites.
# These prerequisites are simply installed via the OS package manager
# in the DSpace module's init.pp script
include dspace

#--------------------------------
# Create DSpace OS owner named 'dspace'
#--------------------------------
dspace::owner { 'dspace':
  sudoer   => true,
}

->

#--------------------------------------------
# Create a PostgreSQL database named 'dspace'
#--------------------------------------------
dspace::postgresql_db { 'dspace':
  version           => '9.4',
  postgres_password => 'postgres', # DB root password (for postgres superuser)
  user              => 'dspace',   # DB owner
  password          => 'dspace',   # DB owner password
  port              => 5432,
}

->

#-------------------------------------------
# Install Tomcat instance, and tell it to use
# ~/dspace/webapps as the webapps location
#-------------------------------------------
dspace::tomcat_instance { '/home/dspace/dspace/webapps' :
  package => 'tomcat8',
  owner   => 'dspace',           # Owned by OS user 'dspace'
  port    => 8080,
}

#->

#-------------------------------------------
# Install DSpace in the specified directory
#-------------------------------------------
#dspace::install { '/home/dspace/dspace' :
#  owner   => 'dspace',          # Owned by OS user 'dspace'
#  version => '6.0-SNAPSHOT',
#  notify  => Service['tomcat'], # Tell Tomcat to reboot after install
#}
