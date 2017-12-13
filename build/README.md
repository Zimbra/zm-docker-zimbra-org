# Creating a Custom Build of `zm-docker`
This container facilitates the production of a custom build of the Zimbra software that can then be used to build `zm-docker`.

## Customize the Build Configuration
`./config/config.build` contains all the flags that will be used to customize the execution of the build process. For the most part you have to reference the [zm-build/build.pl at develop](https://github.com/Zimbra/zm-build/blob/develop/build.pl) file to understand what flags are available.

## Produce a new build of Zimbra FOSS
- Once you have all your `SSH keys` in place and customized your `config.build` make sure your CWD is `./zm-docker`
- Run `make compile`. Compiling all Zimbra artifacts takes some time
  - *NOTE:* if you `SSH key` has a passphrase, then you will promted to type it

		Enter passphrase for `{your SSH key}`:

- If all goes well you can find the produced build into the `zm-docker/BUILDS` directory
- After the build completes successfully a symbolic link is generated `zm-docker/BUILDS/latest` that points at the most recently produced build.

## Build `zm-docker` containers using the new build of Zimbra FOSS
- Make sure your CWD is `zm-docker`
- Run `make clean`
- Run `make compile` to compile the Zimbra FOSS software
- Run `make build-all` to build the zm-docker Docker containers
- Run `make up` to start the Docker containers using Docker Swarm
