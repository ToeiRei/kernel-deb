# Recent Vanilla Kernels for Debian Based Distributions

[![Generic badge](https://img.shields.io/badge/deb-packagecloud.io-844fec.svg)](https://packagecloud.io/debian-kernels/buster)

## Need a Newer Kernel, Fast?

Debian's solid, but sometimes you need something fresh under the hood.  This repo delivers recent vanilla Linux kernels for Debian distributions, pre-configured and ready to roll. No kernel builds, no messy deb shuffling – just get it done.

## How It Works

I start with the trusty Debian kernel configuration found in `/boot/config-*` and use `make oldconfig` with default values.  Then `make deb-pkg` handles packaging for a seamless install.

**Important:** These kernels are *not* signed (disabled signing options). 


## What's Included?

* **Debian Kernel:** Fresh from the source, configured using the Debian template.
* **VM Kernel:** Optimized for virtual machines with stripped drivers.

## Installation

**Debian:**

1. Add the repository:
   ```bash
   curl -s https://packagecloud.io/install/repositories/debian-kernels/buster/script.deb.sh | sudo bash
   ```
2. Install your chosen kernel: 
   ```bash
   sudo apt update
   sudo apt install <kernel-flavor>
   ```
   (Replace `<kernel-flavor>` with "vanilla-kernel" or "vm-kernel")

**Other Debian Based Distributions:**

1. Download the `.zip` files from the release page.
2. Unzip and use `dpkg -i *.deb`. (Ubuntu also works fine!)

**Non-Debian Packages:**

Try [Alien](https://sourceforge.net/projects/alien-pkg-convert/) to convert packages.



## Thanks!

Huge shoutout to [packagecloud.io](https://packagecloud.io/) for hosting this repository – makes life so much easier!

<a href="https://packagecloud.io/"><img height="46" width="158" alt="Private NPM registry and Maven, RPM, DEB, PyPi and RubyGem Repository · packagecloud" src="https://packagecloud.io/images/packagecloud-badge.png" /></a>
