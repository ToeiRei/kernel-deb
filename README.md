# Kernel.org Kernels for Debian 10

## Motivation

For me, Debian is the obvious choice for a server. But sometimes I need a more
recent kernel. As I am lazy, I do not want to build the kernel and shuffle 
around the deb-files on my machines, so this is where this repo comes in.

## Kernel Configuration

I used the **Debian kernel** configuration found in /boot/config-* and imported 
it using `make oldconfig` and used the default values offered.

Attention: This kernel is **NOT** signed.

Changes due to what I need are:
- enabled virtio RNG as a hardware RNG for me to be used on KVM guests

### How to request inclusion of drivers
If you have some shiny piece of hardware that is not yet supported by the 
[kernel](https://kernel.org) itself, you're out of luck as I do not write 
custom kernel modules. But if your hardware is supported by upstream, file an
[issue](https://github.com/ToeiRei/kernel-deb/issues/new) stating the 
CONFIG_ option and I will see what I can do.

## Debian Kernel from vanilla sources

A linux kernel knows `make deb-pkg` as a target. It just needs to be done.

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
   sudo apt install vanilla-kernel
   ```

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
   sudo apt remove vanilla-kernel
   ```
