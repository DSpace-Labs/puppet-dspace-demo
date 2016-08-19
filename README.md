puppet-dspace-demo
=============

NOT YET FUNCTIONAL / WORK IN PROGRESS.

This repo includes the server initialization files for the 'http://demo.dspace.org' server.

This includes the following:
* [`cloud-init.yaml`](https://github.com/tdonohue/puppet-dspace-demo/blob/master/cloud-init.yaml) : a [cloud-init](https://help.ubuntu.com/community/CloudInit) Config data file (to be passed via userdata) to initialize server in EC2
* [`Puppetfile`](https://github.com/tdonohue/puppet-dspace-demo/blob/master/Puppetfile) : a [librarian-puppet](http://librarian-puppet.com/) config file used to install all necessary Puppet modules
* [`manifests/site.pp`](https://github.com/tdonohue/puppet-dspace-demo/blob/master/manifests/site.pp) : the actual Puppet script to run via 'puppet apply'
* Basic configs required for Puppet

How to use it
-------------

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
5. Clones this 'puppet-dspace-demo' GitHub repo to server (at `/etc/puppet/`)
6. Runs '[librarian-puppet](http://librarian-puppet.com/)' to install any Puppet module dependencies (specified in Puppetfile)
7. Runs `puppet apply /etc/puppet/manifests/site.pp` to finish the setup of the server

*Note: all actions taken by 'cloud-init' are logged to `/var/log/cloud-init.log`. The output/results are logged to `/var/log/cloud-init-output.log`.*


License
--------

This work is licensed under the [DSpace BSD 3-Clause License](http://www.dspace.org/license/), which is just a standard [BSD 3-Clause License](http://opensource.org/licenses/BSD-3-Clause).
