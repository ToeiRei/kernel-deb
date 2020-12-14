## Motivation

For me, debian is the obvious choice for a server. But sometimes I need a more recent kernel. As I am lazy, I do not want to build the kernel and shuffle around the deb-files on my machines, so this is where this repo comes in.

## Kernel Configuration

I used the debian kernel configuration found in /boot/config-* and imported it using `make oldconfig` and used the default values offered. Changes due to what I need are:
- enabled virtio RNG as a hardware RNG for me to be used on KVM guests

## Debian Kernel from vanilla sources

A linux kernel knows `make deb-pkg` as a target. It just needs to be done.

## Installation

### Add the public GPG key to the apt sources keyring:

`wget -qO - https://raw.githubusercontent.com/ToeiRei/kernel-deb/main/stargazer.key | sudo apt-key add -`

### Add the repository to your sources.list or sources.list.d

`deb http://USERNAME.github.io/REPOSITORY CODENAME COMPONENT`

## Removal

### Remove the public GPG key from the apt sources keyring:

To list and remove a key from apt sources use the following commands respectively:

```
apt-key list
sudo apt-key del KEY.ID
```

### Remove the repository from your sources.list or remove the file from sources.list.d
