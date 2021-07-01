# Frequently Asked Questions

# Kernel FAQs (shamelessly taken from the issues)

## How to revert to an older kernel
First of all: Do not panic. The bootloader (usually GRUB) has you covered. Just select the older kernel when booting and remove my packages

## Will the kernel boot on (insert hardware or hypervisor here)
As I am using the Debian kernel config, the 'vanilla' or 'bare metal' kernels **should** boot anywhere the default debian kernel did run as I did not change drivers. For the 'vm' kernels, they have most of their drivers pulled to reduce their size. If it does not boot, take the 'vanilla' or 'bare metal' kernels, try again and report back please.

## Does this kernel work on Ubuntu?
Yes, they do. Just keep in mind to grab the vanilla or gentoo-bm if you plan to run it on a physical machine

## What is the difference between 'vm' and the other flavors?
The 'vm' kernels are stripped down versions of the kernel. Drivers for many devices are removed to make it smaller whereas 'vanilla' and 'bm' drivers indicate that they include all drivers intended to run on physical machines (bare metal) but also include common VM drivers.


# Project FAQs

## How to request inclusion of drivers or config change
If you have some shiny piece of hardware that is not yet supported by the 
[kernel](https://kernel.org/) itself, you're out of luck as I do not write
custom kernel modules. 

But if your hardware is supported by upstream, file an [issue](https://github.com/ToeiRei/kernel-deb/issues/new/choose)
stating the CONFIG_ option and I will see what I can do.

## Architecture is only amd64
I do not have the resources to build any other kernels on a foreign 
architecture or cross-compile for some other architecture other than amd64 
for now.

## Use at your own risk
This should be obvious, but you are responsible for your machine. Seriously.
I assume no liability for the accuracy, correctness, completeness, or 
usefulness of any information or package provided by this site nor for 
any sort of damages using these may cause.

## Where do I find sources?
https://kernel.org provides the sources of the Linux Kernel I build here.
Genpatches live at https://dev.gentoo.org/~mpagano/genpatches/

Any config I used to build the packages are [in this directory](https://github.com/ToeiRei/kernel-deb/tree/main/kernel-configs)
and open to you to take a peek or use them for yourself.

## The kernel does not work for me
I do not know what you are trying to use the kernel for. If you want me to
look at it, get in touch with me by opening an issue and I will see what I 
can do - but no promises.

## Custom Kernels
I do not have the resources to build custom kernels for you only. In case
you absolutely want me to do it, feel free to hire me or fund this project.
