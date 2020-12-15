# Frequently Asked Questions

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
you absolutely want me to do it, feel free to hire me.
