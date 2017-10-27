# Zimbra Collaboration Suite Docker Test Cluster

## Preconditions

You should have Docker (and Docker Compose) installed and know how to create a swarm. The instructions that follow assume you are working in a shell that is configured to talk to a Docker swarm.

## Setup

- Clone this repository.
- You may build the images locally: `make all`.  If you do not, they will be pulled down from Docker Hub.

### Optional - Passwords

Deploying the `zm-docker` stack (via the `make up` command) will generate some default values for passwords for you.  If you like, you may change them to be whatever you like.  Just do the following:

	make clean && make init-passwords

Then edit these files in the `.secrets` directory and enter passwords that you want to be used for the corresponding services:
  - `admin_account_password`
  - `ham_account_password`
  - `ldap.amavis_password`
  - `ldap.master_password`
  - `ldap.nginx_password`
  - `ldap.postfix_password`
  - `ldap.replication_password`
  - `ldap.root_password`
  - `mysql.password`
  - `spam_account_password`
  - `virus_quarantine_account_password`

1. The default value of `admin_account_password` is `test123`.  This is what the Genesis tests expect it to be.
2. Note that `make clean` will remove the `.config`, `.secrets`, and `.keystore` directories, so exercise caution with that command.

### Optional - Other Config

If desired, edit these files in the `.config` directory and enter your preferred values.

  - `admin_account_name`
  - `av_notify_email`
  - `domain_name`
  - `gal_sync_account_name`
  - `ham_account_name`
  - `spam_account_name`
  - `virus_quarantine_account_name`


## Deploying the Stack

	make up

If desired, monitor the state of of the `zm-docker_zmc-proxy` service. When it has completed initialization, all services will be available:

	$ docker service logs -f zm-docker_zmc-proxy
	
	...

	2017-10-18 21:15:05 +0000 :: zmc-proxy  :: END        :: Waiting for service...                             :: 00:00:56 :: 00:01:58
	2017-10-18 21:15:05 +0000 :: zmc-proxy  :: BEGIN      :: Publishing service...                              :: 00:00:00 :: 00:01:58
	2017-10-18 21:15:05 +0000 :: zmc-proxy  :: END        :: Publishing service...                              :: 00:00:00 :: 00:01:58
	2017-10-18 21:15:05 +0000 :: zmc-proxy  :: SERVICE    :: INITIALIZED                                        ::          :: 00:01:58
	(^C to exit)
	* Running on http://0.0.0.0:5000/ (Press CTRL+C to quit)



## Undeploying the Stack

	make down
