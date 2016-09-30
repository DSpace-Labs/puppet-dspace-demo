# Configuration for librarian-puppet (http://librarian-puppet.com/)
# This installs necessary third-party Puppet Modules for us.

# Default forge to download modules from
forge "https://forgeapi.puppetlabs.com"

# Install modules to manage APT repositories and enable
# unattended-upgrades on server.
# See https://github.com/voxpupuli/puppet-unattended_upgrades
mod "puppetlabs-apt", "2.3.0"
mod "puppet-unattended_upgrades", "2.0.0"

# Install PuppetLabs Standard Libraries (includes various useful puppet methods)
# See: https://github.com/puppetlabs/puppetlabs-stdlib
mod "puppetlabs-stdlib", "4.12.0"

# Install Puppet Labs PostgreSQL module
# https://github.com/puppetlabs/puppetlabs-postgresql/
mod "puppetlabs-postgresql", "4.8.0"

# Install Puppet Labs Tomcat module
# https://github.com/puppetlabs/puppetlabs-tomcat/
mod "puppetlabs-tomcat", "1.5.0"

# Install Puppet Labs Apache http module
# https://github.com/puppetlabs/puppetlabs-apache/
mod "puppetlabs-apache", "1.10.0"

# Custom Module to install DSpace
mod "DSpace/dspace",
   :git => "https://github.com/DSpace/puppet-dspace.git"
