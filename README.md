# Recent vanilla Kernels for Debian based distributions

[![Generic badge](https://img.shields.io/badge/deb-packagecloud.io-844fec.svg)](https://packagecloud.io/debian-kernels/buster)


## Motivation

For me, Debian is the obvious choice for a server. But sometimes I need a more
recent kernel. As I am lazy, I do not want to build the kernel and shuffle 
around the deb-files on my machines, so this is where this repo comes in.

## Kernel Configuration

I used the **Debian kernel** configuration found in /boot/config-* and imported 
it using `make oldconfig` and used the default values offered.

A linux kernel also knows `make deb-pkg` as a target, so packaging is done in 
a breeze.

Attention: This kernel is **NOT** signed.

## [FAQs](https://toeirei.github.io/kernel-deb/faq/)

## Debian Kernel from vanilla sources

Kernel.org recent kernel sources with the trusty old debian config.

Sources: 
- https://kernel.org

Changes:
- enabled virtio RNG as a hardware RNG for me to be used on KVM guests
- Added exFAT support
- Added Landlock support

## VM Kernel from vanilla sources

Kernel.org recent kernel sources with debian config as a base, most of
the drivers stripped and tuned to run on a VM

Sources:
 - https://kernel.org

Changes:
- stripped drivers except for VirtIO, Xen, etc
- set 'MQ Deadline' as the default IO Scheduler 
- set default TCP congestion control to be BBR
- Added Landlock support

## Gentoo based kernel

Kernel.org recent kernel sources with Gentoo Patches tuned for Gameservers
running as KVM Guest

Sources: 
- https://kernel.org
- https://dev.gentoo.org/~mpagano/genpatches/

Changes:
- enabled virtio RNG as a hardware RNG for me to be used on KVM guests
- Added exFAT support
- Added Landlock support
- Enabled 'kernel self defense' settings

## Gentoo based VM kernel

Kernel.org recent kernel sources with Gentoo Patches tuned for Gameservers
running as KVM Guest

Sources: 
- https://kernel.org
- https://dev.gentoo.org/~mpagano/genpatches/

Changes:
- stripped drivers except for VirtIO/KVM/Qemu
- set 'MQ Deadline' as the default IO Scheduler
- set default TCP congestion control to be Westwood+ for better networking over WAN/WLAN
- CONFIG_HZ set to 1000Hz for better responses
- Preemption Model set to Desktop for better respones
- Maximum number of CPUs set to 8
- Enabled 'kernel self defense' settings


# Installation

## Debian 

1. Add the repository:
   ```
   curl -s https://packagecloud.io/install/repositories/debian-kernels/buster/script.deb.sh | sudo bash
   ```

2. Install the kernel
   ```
   sudo apt update
   sudo apt install <kernel-flavor>
   ```
   kernel-flavor can be any of vanilla-kernel, vm-kernel or gameserver-kernel


## Any other distro supporting debian packages

1. Download the zip files from the release page
2. Unzip the archive
3. Use dpkg -i to install the packages (`dpkg -i *.deb` works fine on Ubuntu as well)

## Non-DEB Package distros

You may want to try the program [Alien](https://sourceforge.net/projects/alien-pkg-convert/) to convert the package to the format of your liking.
(Example: `alien --to-rpm /path/to/file.deb`)
If this doesn't work, you can convert the packages to be a tarball and unpack the kernel and modules into your system.

# Sponsors
A big thank you to https://packagecloud.io/ for providing me with repository hosting for those packages as it wouldn't be possible for me to host the repository on my line here.

<a href="https://packagecloud.io/"><img height="46" width="158" alt="Private NPM registry and Maven, RPM, DEB, PyPi and RubyGem Repository · packagecloud" src="https://packagecloud.io/images/packagecloud-badge.png" /></a>
