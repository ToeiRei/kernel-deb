# Kernel flavors

This repository currently holds the following 'flavors'

## Vanilla Kernel
Default Debian kernel options ported to a recent kernel

### Changes to complete vanilla Debian Kernel
- Virtio RNG driver selected

## VM Kernel
This kernel is a default debian config tuned to run on virtual machines. As virtual hardware it is, the huge load of drivers needed for real hardware is stripped
** do not use when passing through hardware from the host machine **

### Changes to the Debian Kernel
- All VM unrelated drivers except for some bare minimums stripped
- Disk scheduler set to 'Deadline' as a VM does not handle the real disks
- 
