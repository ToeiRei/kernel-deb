# Frequently Asked Questions

## Kernel Issues:

* **My kernel isn't booting! Help!**  😱 First off, don't panic. Most likely, you need to update your firmware. Grab the latest from [https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git) or use this handy clone command:

```bash
apt install git
cd /lib
mv firmware firmware.old
git clone  git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git firmware
```


* **How do I go back to my old kernel?** 🔙 Your bootloader (GRUB usually) has your back! Just pick the older kernel during boot, and then remove these packages.

* **Will this kernel work on [insert hardware or hypervisor]?** 🤔 Since we use the Debian kernel config, it *should* work anywhere the default Debian kernel ran – unless you've got something truly exotic. If in doubt, try the 'vanilla' kernel first and report back!

* **Is this compatible with Ubuntu?** ✅ Yes, it is! Just grab the 'vanilla' kernel if you're running a physical machine.

* **What's the difference between 'vm' and 'vanilla'?**  🧠 'Vanilla' kernels include all drivers for physical machines (and some common VM drivers). 'VM' kernels are stripped down for virtualized environments.

* **Why "buster" in the repo names?** 🤨 It started with Debian 10 ("Buster"), and I wasn't sure it would last this long!


## Project Stuff:

* **Want to add a driver or change something?**  ✨ File an [issue](https://github.com/ToeiRei/kernel-deb/issues/new/choose) – make sure the driver is supported upstream in the kernel itself, though. I'm not writing custom modules.
 
* **Why only AMD64?** 🤔 Resources are limited, so for now, it's just AMD64. If you need something else, consider sponsoring the project!

* **Use at your own risk!**  ⚠️ This is common sense, but double-checking never hurts.

* **Where can I find sources?** 💻 All the kernel goodies are at [https://kernel.org](https://kernel.org), and my config files are in [this directory](https://github.com/ToeiRei/kernel-deb/tree/main/kernel-configs).

* **The kernel doesn't work for me!** 🤯 Help me out by opening an issue – I need to know what you're trying to do!
