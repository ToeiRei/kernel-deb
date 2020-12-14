### Motivation

For me, debian is the obvious choice for a server. But sometimes I need a more recent kernel. As I am lazy, I do not want to build the kernel and shuffle around the deb-files on my machines, so this is where this repo comes in.

#### Configuration

I used the debian kernel configuration found in /boot/config-* and imported it using `make oldconfig` and used the default values offered. Changes due to what I need are:
- enabled virtio RNG as a hardware RNG for me to be used on KVM guests

### Debian Kernel from vanilla sources

A linux kernel knows `make deb-pkg` as a target. It just needs to be done.

### Installation

TBD;
