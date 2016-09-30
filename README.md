puppet-dspace-demo
=============

This repo includes the server initialization files for the 'http://demo.dspace.org' server.

This includes the following:
* [`cloud-init.yaml`](https://github.com/DSpace-Labs/puppet-dspace-demo/blob/master/cloud-init.yaml) : a [cloud-init](https://help.ubuntu.com/community/CloudInit) Config data file (to be passed via userdata) to initialize server in EC2
* [`Puppetfile`](https://github.com/DSpace-Labs/puppet-dspace-demo/blob/master/Puppetfile) : a [librarian-puppet](http://librarian-puppet.com/) config file used to install all necessary Puppet modules
* [`manifests/site.pp`](https://github.com/DSpace-Labs/puppet-dspace-demo/blob/master/manifests/site.pp) : the actual Puppet script to run via 'puppet apply'
* Basic configs required for Puppet

How to use it
-------------

1. Spin up a new Ubuntu 16.04 LTS (64-bit, [HVM Virtualization](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/virtualization_types.html), EBS-SSD boot), e.g. [ami-e3c3b8f4](https://console.aws.amazon.com/ec2/home?region=us-east-1#launchAmi=ami-e3c3b8f4) from Ubuntu's [Amazon EC2 AMI Locator](https://cloud-images.ubuntu.com/locator/ec2/)
   * Select instance size (currently using 'm3.medium' for demo.dspace.org)
   * Upload the included 'cloud-init.yaml' as "User Data"
   * Storage: Update to at least 75GB storage for ROOT
   * Launch the instance
2. Sit back and wait while 'cloud-init' & Puppet does all the hard work for you.
3. (Temporary) At this point in time, there's an odd bug where PostgreSQL doesn't startup correctly when Puppet is run from `cloud-init`.  So, you have to MANUALLY trigger the Puppet build.
   * SSH to the server
   * Run: `sudo puppet apply /etc/puppet/manifests/site.pp -v`
   * Wait for Puppet to install DSpace, and setup the Demo server.


How it works
------------

All of the hard work is taken care of by cloud-init (and Puppet).
Here's what the [`cloud-init.yaml`](https://github.com/duraspace/puppet-dspace-demo/blob/master/cloud-init.yaml) does for you:

1. Sets the server hostname & FQDN
2. Adds all necessary Apt repositories
3. Runs 'apt-get update' and 'apt-get upgrade' to ensure all is up-to-date (reboots if needed)
4. Installs all necessary software on server (e.g. Puppet, librarian-puppet, Git)
5. Clones this 'puppet-dspace-demo' GitHub repo to server (at `/etc/puppet/`)
6. Runs '[librarian-puppet](http://librarian-puppet.com/)' to install any Puppet module dependencies (specified in Puppetfile)
7. Runs `puppet apply /etc/puppet/manifests/site.pp` to finish the setup of the server

*Note: all actions taken by 'cloud-init' are logged to `/var/log/cloud-init.log`. The output/results are logged to `/var/log/cloud-init-output.log`.*


What it sets up
----------------
The Puppet script that does all the setup is [`manifests/site.pp`](https://github.com/DSpace-Labs/puppet-dspace-demo/blob/master/manifests/site.pp).

Here's what it currently does:

1. Setup Ubuntu unattended_upgrades (via [puppet-unattended_upgrades](https://github.com/voxpupuli/puppet-unattended_upgrades) module)
2. Setup DSpace, including all prerequisites (via our separate [puppet-dspace](https://github.com/DSpace/puppet-dspace) module). This includes setting up all of the following:
  * PostgreSQL database (via [puppetlabs-postgresql](https://github.com/puppetlabs/puppetlabs-postgresql/) module)
  * Tomcat (via [puppetlabs-tomcat](https://github.com/puppetlabs/puppetlabs-tomcat/) module)
  * Apache web server (via [puppetlabs-apache](https://github.com/puppetlabs/puppetlabs-apache/) module), communicates with Tomcat via AJP
  * 'dspace' OS user account (which is the owner of DSpace installation)
3. Setup splash page (homepage of http://demo.dspace.org), by checking out/installing the https://github.com/DSpace/demo.dspace.org project
  * Also includes the useful scripts / cron jobs from that project
4. 'kompewter' IRC bot (from https://github.com/DSpace-Labs/kompewter)
5. Setup custom Message of the Day for server and other basic files

**WARNING:** Currently this script does restore APIs from the `~dspace/AIP-restore` folder. It does download the AIPs from a private S3 location, but you must manually run the restore script. The folder should look something like this:

* `~dspace/AIP-restore/`
  * `SITE@10673-0.zip` (Site AIP corresponding to 10673/0 handle)
  * `COMMUNITY@[handle].zip` (one or more Community AIPs using 10673 handle prefix)
  * `COLLECTION@[handle].zip` (one or more Collection AIPs using 10673 handle prefix)
  * `ITEM@[handle].zip` (one or more ITEM AIPs using 10673 handle prefix)


License
--------

This work is licensed under the [DSpace BSD 3-Clause License](http://www.dspace.org/license/), which is just a standard [BSD 3-Clause License](http://opensource.org/licenses/BSD-3-Clause).
