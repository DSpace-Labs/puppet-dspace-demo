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

->

#--------------------------------
# Create DSpace OS owner
#--------------------------------
class { 'dspace::owner':
  username => 'dspace',
  sudoer   => true,
}

->

#---------------------------------
# Install PostgreSQL prerequisite
#---------------------------------
class { 'dspace::postgres':
  version => '9.4',
}

->

#-----------------------------
# Install Tomcat prerequisite
#-----------------------------
class { 'dspace::tomcat':
  package => 'tomcat7',
  owner   => 'dspace',
}

#->

#---------------------
# Install DSpace
#---------------------
#class { 'dspace::install':
#  owner   => 'dspace',
#  version => '6.0-SNAPSHOT',
#  notify  => Service['tomcat'],
#}
