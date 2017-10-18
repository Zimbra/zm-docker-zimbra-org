# Zimbra Collaboration Suite Docker Test Cluster

## Preconditions

You should have Docker (and Docker Compose) installed and know how to create a swarm. The instructions that follow assume you are working in a shell that is configured to talk to a Docker swarm.

## Setup

- Clone this repository.
- Edit these files in the `.secrets` diretory and enter passwords that you want to be used for the corresponding services:
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
- If desired, edit these files in the `.config` directory and enter your preferred values. This is optional, as they already contain sensible defaults.
  - `admin_account_name`
  - `av_notify_email`
  - `domain_name`
  - `gal_sync_account_name`
  - `ham_account_name`
  - `spam_account_name`
  - `virus_quarantine_account_name`
- Build the images: `make all`

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



## Undeploying the Stadck

	make down
