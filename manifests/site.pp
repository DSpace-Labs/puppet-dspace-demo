##
# site.pp
#
# This Puppet script does the following:
# * Initializes the 'server' (with default settings in Hiera)
# * Creates the Staff user accounts (configured in Hiera)
##

###################
# Initialize Server
###################
include server

##########################
# Setup all Staff Accounts (based on Hiera data configuration)
##########################
# Create the 'staff' group for our staff users (if it doesn't already exist)
group { "staff":
  ensure => present,        
  gid => 50,        # On Ubuntu, 50 is the default gid for this "staff" group
}

# These next few lines load the Hiera data configs and creates a new "server::user"
# for every user defined under "User_Accts" in the 'hieradata/common.yaml' file.
# Concept borrowed from http://drewblessing.com/blog/-/blogs/puppet-hiera-implement-defined-resource-types-in-hiera

$user_accts = hiera('User_Accts', []) # First read the site configs under "User_Accts" (default to doing nothing, [], if nothing is defined under "User_Accts")
create_resources('server::user', $user_accts) # Then, create a new "server::user" for each account
