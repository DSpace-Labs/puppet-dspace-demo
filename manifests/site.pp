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

# Run an apt update each time Puppet is run
# See https://forge.puppet.com/puppetlabs/apt
class { 'apt':
  update => {
    frequency => 'always',
  },
}

# Enable unattended upgrades via APT
include unattended_upgrades

# Global default to requiring all packages be installed & apt-update to be run first
Package {
  ensure => latest,        # requires latest version of each package to be installed
  require => Class['apt'], # Require 'apt' module to run an update first
}

# Global default path settings for all 'exec' commands
Exec {
  path => "/usr/bin:/usr/sbin/:/bin:/sbin:/usr/local/bin:/usr/local/sbin",
}

#------------------------------------------------------------
# Initialize base pre-requisites and define global variables.
#------------------------------------------------------------
# Initialize the DSpace module. This actually installs Java/Ant/Maven,
# and globally saves the versions of PostgreSQL and Tomcat we will install below.
#
# NOTE: ANY of these values (or any other parameter of init.pp) can be OVERRIDDEN
# via hiera in 'default.yaml' or your 'local.yaml'. Just specify the parameter like
# "dspace::[param-name] : [param-value]" in local.yaml.
class { 'dspace':
  java_version       => '8',
  postgresql_version => '9.5',
  tomcat_package     => 'tomcat7',
  owner              => 'dspace',  # OS user who "owns" DSpace
  db_name            => 'dspace',   # Name of database to use
  db_owner           => 'dspace',   # DB owner account info
  db_owner_passwd    => 'dspace',
  db_admin_passwd    => 'postgres', # DB password for 'postgres' acct
  tomcat_ajp_port    => 8009,
  # Custom CATALINA_OPTS to enable YourKit (see install below)
  catalina_opts      => '-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Xmx2048m -Xms1024m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC -agentpath:/opt/yjp/bin/linux-x86-64/libyjpagent.so',
}

#----------------------------------------------------------------
# Create the DSpace owner and populate any of the owner's configs
#----------------------------------------------------------------
# This also saves our Committer public SSH keys to ~/.ssh/authorized_keys
# See the ./files/authorized_keys file.
dspace::owner { $dspace::owner :
  gid                    => $dspace::group,
  sudoer                 => true,
  authorized_keys_source => undef,  # We'll copy in our own authorized keys (see below)
}

# Download SSH info (authorized_keys, etc) from private S3 folder (copy to ~/.ssh/)
$ssh_key_in_s3 = "s3://dspacedemo-setup/ssh/"
exec { "Download demo SSH key/authorizations from ${ssh_key_in_s3}" :
  command => "/usr/local/bin/aws s3 sync ${ssh_key_in_s3} . && chown ${dspace::owner}:${dspace::group} * && chmod 600 authorized_keys id_rsa && chmod 644 known_hosts id_rsa.pub",
  cwd     => "/home/${dspace::owner}/.ssh/",
  creates => "/home/${dspace::owner}/.ssh/id_rsa.pub",
  require => Dspace::Owner[$dspace::owner],
  # Need these SSH keys to install anything from GitHub
  before  => [Dspace::Install["/home/${dspace::owner}/dspace"],
              Exec["Cloning demo.dspace.org source into ${dspace::catalina_base}/webapps/ROOT/"]],
}

# Create a daily cron job to sync changes to ~/.ssh up to private S3 folder
file { "/etc/cron.daily/sync-ssh-to-s3" :
  ensure  => file,
  mode    => 0755,
  content => "/usr/local/bin/aws s3 sync /home/${dspace::owner}/.ssh ${ssh_key_in_s3} --sse",
  require => Dspace::Install["/home/${dspace::owner}/dspace"],
}

#----------------------------------------------------------------
# Create the PostgreSQL database (based on above global settings)
#----------------------------------------------------------------
dspace::postgresql_db { $dspace::db_name :
  require => Dspace::Owner[$dspace::owner],
}

# Create PG pass file to not require authentication for postgres
file { "/home/${dspace::owner}/.pgpass" :
  ensure  => file,
  owner  => $dspace::owner,
  group  => $dspace::group,
  mode    => 0600,
  content => "localhost:5432:*:postgres:${dspace::db_admin_passwd}",
}

#-----------------------------------------------------
# Install Tomcat instance (based on above global settings)
# Tell it to use owner's ~/dspace/webapps as the webapps location
#-----------------------------------------------------
dspace::tomcat_instance { "/home/${dspace::owner}/dspace/webapps" :
  require => Dspace::Owner[$dspace::owner],
}

# Link ~/tomcat to Tomcat installation for easy finding
file { "/home/${dspace::owner}/tomcat" :
  ensure => link,
  owner  => $dspace::owner,
  group  => $dspace::group,
  target => $dspace::catalina_base,
}

#----------------------------------------
# Install Apache Site for demo.dspace.org
# This automatically hooks up Apache to Tomcat via AJP
#----------------------------------------
dspace::apache_site { "demo.dspace.org" :
  ssl => true,
  require => Dspace::Tomcat_instance["/home/${dspace::owner}/dspace/webapps"],
}


#---------------------------------------------------
# Install DSpace in the owner's ~/dspace/ directory
#---------------------------------------------------
# Download our local.cfg file from a *private* S3 folder (copy it to ~/local.cfg)
$local_cfg_in_s3 = "s3://dspacedemo-setup/config/local.cfg"
exec { "Download local.cfg from ${local_cfg_in_s3}" :
  command => "/usr/local/bin/aws s3 cp ${local_cfg_in_s3} . && chown ${dspace::owner}:${dspace::group} local.cfg",
  cwd     => "/home/${dspace::owner}/",
  creates => "/home/${dspace::owner}/local.cfg",
}

# Actually install DSpace from DSpace-Labs/demo.dspace.org (demo branch)
# NOTE: this is a fork with minor customizations for the demo site
dspace::install { "/home/${dspace::owner}/dspace" :
  git_repo   => 'git@github.com:DSpace-Labs/demo.dspace.org',
  git_branch => 'demo',
  local_config_source => "file:///home/${dspace::owner}/local.cfg", # Install custom local.cfg
  mvn_params => '-Dmirage2.on=true',                               # Install Mirage 2 theme
  require    => [DSpace::Postgresql_db[$dspace::db_name],             # Must first have a database
                 Exec["Download local.cfg from ${local_cfg_in_s3}"]], # and local.cfg
  notify     => Service['tomcat'],                       # Tell Tomcat to reboot after install
}

# Create a daily cron job to sync changes to local.cfg up to private S3 folder
file { "/etc/cron.daily/sync-local-cfg-to-s3" :
  ensure  => file,
  mode    => 0755,
  content => "/usr/local/bin/aws s3 cp /home/${dspace::owner}/dspace/config/local.cfg ${local_cfg_in_s3} --sse",
  require => Dspace::Install["/home/${dspace::owner}/dspace"],
}


#---------------------
# Install PSI Probe
#---------------------
# For convenience in troubleshooting Tomcat, let's install Psi-probe
# https://github.com/psi-probe/psi-probe
$probe_version = "2.4.0.SP1"
exec {"Download and install the PSI Probe v${probe_version} war":
  command   => "/usr/bin/wget --quiet --continue https://github.com/psi-probe/psi-probe/releases/download/${probe_version}/probe.war",
  cwd       => "${dspace::catalina_base}/webapps",
  creates   => "${dspace::catalina_base}/webapps/probe.war",
  user      => $dspace::owner,
  logoutput => true,
  tries     => 3,                            # In case of a network hiccup, try this download 3 times
  require   => [File[$dspace::catalina_base], Dspace::Owner[$dspace::owner]], # CATALINA_BASE must exist before downloading
}

->

# Add a Tomcat Context for / (root path) to point at this ROOT webapp
tomcat::config::server::context { 'Enable PSI Probe (/probe) context in Tomcat':
  catalina_base  => $dspace::catalina_base,
  context_ensure => present,
  doc_base       => "${dspace::catalina_base}/webapps/probe.war",
  parent_engine  => 'Catalina',
  parent_host    => 'localhost',
  additional_attributes => {
    'path' => '/probe',
    'privileged' => 'true',
  },
  notify         => Service['tomcat'],   # If changes are made, notify Tomcat to restart
}

->

# Setup the UserDatabase for authentication to PSI Probe
tomcat::config::context::resourcelink { 'Enable Users database in Tomcat for PSI Probe':
  catalina_base  => $dspace::catalina_base,
  resourcelink_name => 'users',
  resourcelink_type => 'org.apache.catalina.UserDatabase',
  additional_attributes => {
    'global' => 'UserDatabase',
  },
}

->

# Add a "dspace" Tomcat User (password="dspace") who can login to PSI Probe
# (NOTE: This line will only be added after <tomcat-users> if it doesn't already exist there)
file_line { 'Add \'dspace\' Tomcat user for PSI Probe':
  path    => "${dspace::catalina_base}/conf/tomcat-users.xml", # File to modify
  after   => '<tomcat-users>',                         # Add content immediately after this line
  line    => '<role rolename="probeuser"/><user username="dspace" password="dspace" roles="probeuser"/>', # Lines to add to file
  notify  => Service['tomcat'],                        # If changes are made, notify Tomcat to restart
}

#-----------------------------
# Install YourKit to /opt/yjp
#-----------------------------
# For Java Profiling, install YourKit
# http://www.yourkit.com/docs/95/help/profiling_j2ee_remote.jsp
$yourkit_version = "yjp-2016.02-b42"
$yourkit_tarfile = "${yourkit_version}-linux.tar.bz2"
$yourkit_url = "https://www.yourkit.com/download/${yourkit_tarfile}"
$yourkit_download = "/opt/${yourkit_tarfile}"
$yourkit_install = "/opt/yjp"

exec { "Download YourKit ${yourkit_url}":
  command => "/usr/bin/wget ${yourkit_url} -O ${yourkit_download}",
  creates => $yourkit_download,
}

->

exec { "Untar YourKit ${yourkit_tarfile} to /opt/yjp":
  command => "/bin/mkdir ${yourkit_install} && /bin/tar xfj ${yourkit_download} -C ${yourkit_install} --strip-components 1",
  creates => $yourkit_install,
}

#-------------------------------------
# Install / Setup Splash Page
#-------------------------------------
# if the ROOT Tomcat webapp does not yet exist, create it
# AND ensure it is empty
file { "${dspace::catalina_base}/webapps/ROOT":
  ensure => directory,
  owner  => $dspace::owner,
  group  => $dspace::group,
  mode   => 0700,
}

# Clone Splash Page code into ROOT webapp (from DSpace-Labs/demo.dspace.org-site repo)
exec { "Cloning demo.dspace.org source into ${dspace::catalina_base}/webapps/ROOT/":
  command   => "sudo rm -rf * && git clone git@github.com:DSpace-Labs/demo.dspace.org-site.git .",
  creates   => "${dspace::catalina_base}/webapps/ROOT/.git",
  cwd       => "${dspace::catalina_base}/webapps/ROOT", # run command from this directory
  logoutput => true,
  user      => $dspace::owner,
  tries     => 4,    # try 4 times
  timeout   => 600,  # set a 10 min timeout.
  require   => [File["${dspace::catalina_base}/webapps/ROOT"],
                Dspace::Owner[$dspace::owner]],
}

# Add a Tomcat Context for / (root path) to point at this ROOT webapp
tomcat::config::server::context { 'Enable splashpage at ROOT (/) context in Tomcat':
  catalina_base  => $dspace::catalina_base,
  context_ensure => present,
  doc_base       => "${dspace::catalina_base}/webapps/ROOT",
  parent_engine  => 'Catalina',
  parent_host    => 'localhost',
  additional_attributes => {
    'path' => '/',
  },
  require        => File["${dspace::catalina_base}/webapps/ROOT"],
  notify         => Service['tomcat'],   # If changes are made, notify Tomcat to restart
}

#-------------------------------------
# Install / Setup ~/bin/ scripts
#-------------------------------------
# Link the ~/bin directory to the Linux scripts provided under webapp ./scripts/linux folder
file { "/home/${dspace::owner}/bin" :
  ensure  => link,
  owner   => $dspace::owner,
  group   => $dspace::group,
  target  => "${dspace::catalina_base}/webapps/ROOT/scripts/linux",
  require => Exec["Cloning demo.dspace.org source into ${dspace::catalina_base}/webapps/ROOT/"],
}


#------------------------------------
# Setup AIPs for initial content
#------------------------------------
# Download AIPs from private S3 folder (copy to ~/AIP-restore/)
$AIPs_in_s3 = "s3://dspacedemo-setup/AIP-restore/"
$AIP_directory = "/home/${dspace::owner}/AIP-restore/"
exec { "Download demo AIPs from ${AIPs_in_s3}" :
  command => "mkdir ${AIP_directory} && /usr/local/bin/aws s3 sync ${AIPs_in_s3} ${AIP_directory} && chown -R ${dspace::owner}:${dspace::group} ${AIP_directory}",
  creates => $AIP_directory,
  require => Dspace::Install["/home/${dspace::owner}/dspace"],
}

# Create a daily cron job to sync changes to ~/.ssh up to private S3 folder
file { "/etc/cron.daily/sync-AIPs-to-s3" :
  ensure  => file,
  mode    => 0755,
  content => "/usr/local/bin/aws s3 sync ${AIP_directory} ${AIPs_in_s3} --sse",
  require => Dspace::Install["/home/${dspace::owner}/dspace"],
}


#-------------------------------------
# Install / Setup Cron Jobs
#-------------------------------------
# Install mycrontab (provided in demo.dspace.org source repo)
file { "/home/${dspace::owner}/mycrontab" :
  ensure  => link,
  owner   => $dspace::owner,
  group   => $dspace::group,
  target  => "${dspace::catalina_base}/webapps/ROOT/scripts/linux/crontab",
  require => Exec["Cloning demo.dspace.org source into ${dspace::catalina_base}/webapps/ROOT/"],
}

exec { "Init Cron Jobs from /home/${dspace::owner}/mycrontab":
  command     => "/usr/bin/crontab /home/${dspace::owner}/mycrontab",
  user        => $dspace::owner,
  subscribe   => File["/home/${dspace::owner}/mycrontab"],
  refreshonly => true,
}


#-----------------------------------------
# Install custom Message of the Day (MOTD)
#-----------------------------------------
# In Ubuntu 16.04, /etc/motd will be appended on the dynamic MOTD
file { "/etc/motd" :
  ensure => file,
  source => "puppet:///files/motd",
}


#-----------------------------------------
# Install server README for 'dspace' account
#-----------------------------------------
file { "/home/${dspace::owner}/README" :
  ensure => file,
  source => "puppet:///files/server_README",
  owner  => $dspace::owner,
  group  => $dspace::group,
}

#-----------------------------------------
# Install / Setup 'kompewter' IRC bot
#-----------------------------------------
# Install required packages for kompewter
exec { '/usr/local/bin/pip install BeautifulSoup':
  unless => '/usr/local/bin/pip list | /bin/grep BeautifulSoup 2>/dev/null',
}

->

# Clone 'kompewter' project to ~/kompewter
exec { "Cloning kompewter IRC bot source into /home/${dspace::owner}/kompewter/":
  command   => "git clone https://github.com/DSpace-Labs/kompewter.git kompewter && chown -R ${dspace::owner}:${dspace::group} kompewter",
  creates   => "/home/${dspace::owner}/kompewter/.git",
  cwd       => "/home/${dspace::owner}/", # run command from this directory
  logoutput => true,
  tries     => 4,    # try 4 times
  timeout   => 600,  # set a 10 min timeout.
  require   => File["/home/${dspace::owner}/"],
}
