puppet-dspace-demo
=============

This repo includes the server initialization files for the 'http://demo.dspace.org' server. 

This includes the following:
* [`cloud-init.yaml`](https://github.com/duraspace/puppet-dspace-demo/blob/master/cloud-init.yaml) : a [cloud-init](https://help.ubuntu.com/community/CloudInit) Config data file (to be passed via userdata) to initialize server in EC2
* [`Puppetfile`](https://github.com/duraspace/puppet-dspace-demo/blob/master/Puppetfile) : a [librarian-puppet](http://librarian-puppet.com/) config file used to install all necessary Puppet modules
* [`manifests/site.pp`](https://github.com/duraspace/puppet-dspace-demo/blob/master/manifests/site.pp) : the actual Puppet script to run via 'puppet apply' (requires [hiera](http://docs.puppetlabs.com/hiera/1/index.html) data files which are stored in Amazon S3)
* Basic configs required for Puppet

How to use it
-------------

*Prerequisites:*

* Must have an Amazon IAM role created which provides these permissions:
   * Create/Delete access for Snapshots, and Describe access for Instances/volumes (needed for auto-snapshotting to work)
   * Read/Write access to the S3 bucket containing Puppet hieradata  

Once the pre-requisites are in place, all you need to do is:

1. Spin up a new Ubuntu 14.04 LTS, 64-bit (e.g. [ami-74e27e1c](https://console.aws.amazon.com/ec2/home?region=us-east-1#launchAmi=ami-74e27e1c) from alestic.com)
   * Attach the created Amazon IAM role to the instance
   * Upload the included 'cloud-init.yaml' as "User Data"
   * Attach a second EBS volume (for the /space volume) at '/dev/sdb'
   * Launch the instance
2. Sit back and wait while 'cloud-init' & Puppet does all the hard work for you.


How it works
------------

All of the hard work is taken care of by cloud-init (and Puppet).
Here's what the [`cloud-init.yaml`](https://github.com/duraspace/puppet-dspace-demo/blob/master/cloud-init.yaml) does for you:

1. Sets the server hostname & FQDN
2. Adds all necessary Apt repositories
3. Runs 'apt-get update' and 'apt-get upgrade' to ensure all is up-to-date (reboots if needed)
4. Installs all necessary software on server (e.g. Puppet, AWS CLI, librarian-puppet, Git)
5. Copies SSH key from our private S3 bucket (for access to private GitHub repos)
6. Clones this 'puppet-dspace-demo' GitHub repo to server (at `/etc/puppet/`)
7. Runs '[librarian-puppet](http://librarian-puppet.com/)' to install any Puppet module dependencies (specified in Puppetfile)
   * The primary dependency is [`puppet-server`](https://github.com/duraspace/puppet-server) which does most of the basic DuraSpace server setup.
8. Copies the Hiera data files from our private S3 bucket. These hiera files configure what `puppet-server` installs, including:
   * Staff user accounts (and public SSH keys)
   * Java (oracle or openjdk)
   * Auto-snapshotting of volumes
   * Auto-updating of packages via apt-get
9. Runs `puppet apply /etc/puppet/manifests/site.pp` to finish the setup of the server
11. Restricts access to EC2 Metadata, so that only `root` can access metadata or server IAM Roles

*Note: all actions taken by 'cloud-init' are logged to `/var/log/cloud-init.log`. The output/results are logged to `/var/log/cloud-init-output.log`.*
