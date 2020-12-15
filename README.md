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

### How to request inclusion of drivers or config change
If you have some shiny piece of hardware that is not yet supported by the 
[kernel](https://kernel.org) itself, you're out of luck as I do not write 
custom kernel modules. But if your hardware is supported by upstream, file an
[issue](https://github.com/ToeiRei/kernel-deb/issues/new) stating the 
CONFIG_ option and I will see what I can do.

### Architecture is only amd64
I do not have the resources to build any other kernels on a foreign architecture
or cross-compile for some other architecture other than amd64 for now.

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

1. Add the public GPG key to the apt sources keyring:
   ```
   wget -qO - https://raw.githubusercontent.com/ToeiRei/kernel-deb/main/stargazer.key | sudo apt-key add -
   ```

2. Add the repository to your sources.list or sources.list.d
   ```
   deb http://toeirei.github.io/kernel-deb buster main
   ```

3. Make sure apt-transport-https is installed
   ```
   sudo apt install apt-transport-https
   ```

4. Install the kernel
   ```
   sudo apt update
   sudo apt install <kernel-flavor>
   ```
   kernel-flavor can be any of vanilla-kernel, vm-kernel or gameserver-kernel

# Removal

1. Remove the public GPG key from the apt sources keyring:

   To list and remove a key from apt sources use the following commands respectively:
   ```
   sudo apt-key list
   sudo apt-key del 7BAABD559DCE074A
   ```

2. Remove the repository from your sources.list or remove the file from sources.list.d

3. Remove the kernel packages
   ```
   sudo apt remove <kernel-flavor>
   ```
