# Getting Started

This package is a suite of utilities that help make it easier to set up and maintain
Moodle environments with Docker or podman. There are convenience scripts for handling
backups, restores, upgrades, and more.

## Installation/Uninstallation

Use this command to download and run the installer:

```bash
bash <(curl -H 'Cache-Control: no-cache, no-store' -o- https://raw.githubusercontent.com/uicpharm/mdl/refs/heads/main/installers/install.sh)
```

Correspondingly, if you want to uninstall, you can download and run the uninstall script:

```bash
bash <(curl -H 'Cache-Control: no-cache, no-store' -o- https://raw.githubusercontent.com/uicpharm/mdl/refs/heads/main/installers/uninstall.sh)
```

## Initializing an Environment

The tooling is now ready for you to set up a Moodle environment. The tool can keep track
of multiple environments. To create an environment called `mymoodle`, you can run:

```sh
mdl init mymoodle
```

You will be guided through the process of configuring your environment.

## Installing as a Service on Servers

If your server is running Docker, just starting the environment (i.e.
`mdl start mymoodle`) is sufficient. Docker will restart containers if they crash, or
after a system reboot.

If your server is running Podman, the containers will not automatically restart on a
reboot unless you install them as a service. The [docker-host][docker-host] project
provides a `podman-install-service` script to simplify this process for our needs:

```bash
mdl start mymoodle
podman-install-service mymoodle
```

At that point, it can be controlled via `systemctl`, so you can issue commands like
`systemctl stop mymoodle` or `systemctl start mymoodle`, etc. You can continue to use our
helper commands like `mdl start`, `mdl status`, `mdl stop`, etc without conflicting with
the service.

## Contributing

To develop for the [mdl](https://github.com/uicpharm/mdl) project, you can install it in
dev mode, where the mdl commands will be linked to a git checkout of the project. To do
this, uninstall the traditional installation if it is already installed, check out the
project, and install it in dev mode like this:

```sh
git clone git@github.com:uicpharm/mdl.git
cd mdl
./installers/install.sh --dev
```

Now you can work on the scripts in the project and the will be used when you run any mdl
commands. If you run `mdl info` it will confirm that it is running in dev mode.

[docker-host]: https://github.com/uicpharm/docker-host#readme
