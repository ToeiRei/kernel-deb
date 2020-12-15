# Kernel.org Kernels for Debian 10

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

## FAQs

see https://toeirei.github.io/kernel-deb/faq/

## Debian Kernel from vanilla sources

Kernel.org recent kernel sources with the trusty old debian config.

Changes:
- enabled virtio RNG as a hardware RNG for me to be used on KVM guests

## VM Kernel from vanilla sources

Kernel.org recent kernel sources with debian config as a base, most of
the drivers stripped and tuned to run on a VM

Changes:
- stripped drivers except for VirtIO, Xen, etc
- set 'MQ Deadline' as the default IO Scheduler 
- set default TCP congestion control to be BBR

## Gameserver ready kernel

Kernel.org recent kernel sources with Gentoo Patches tuned for Gameservers
running as KVM Guest

Changes:
- stripped drivers except for VirtIO/KVM/Qemu
- set 'MQ Deadline' as the default IO Scheduler
- set default TCP congestion control to be Westwood+ for better networking over WAN/WLAN
- CONFIG_HZ set to 1000Hz for better responses
- Preemption Model set to Desktop for better respones
- Maximum number of CPUs set to 8

# Installation

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
