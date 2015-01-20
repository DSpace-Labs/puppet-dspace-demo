# Configuration for librarian-puppet (http://librarian-puppet.com/)
# This installs necessary third-party Puppet Modules for us.

# Default forge to download modules from
forge "http://forge.puppetlabs.com"

# Install PuppetLabs Standard Libraries (includes various useful puppet methods)
# See: https://github.com/puppetlabs/puppetlabs-stdlib
mod "puppetlabs/stdlib"

# Install our DuraSpace "server" (private) module via SSH
mod "duraspace/server",
   :git => "git@github.com:duraspace/puppet-server.git"
