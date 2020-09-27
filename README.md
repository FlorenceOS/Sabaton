# Sabaton bootloader

Sabaton is a Stivale2 bootloader targetting different aarch64 enviroments.

## Differences from stivale2
Due to the memory layout of aarch64 devices being so far from standardized, a few changes have been made:
* Bottom half is still identity mapped, but it has been extended to encompass all of physical RAM.
* Your kernel has to be located in the higher half.
* All your kernel sections need to be 64K aligned, you don't know the page size (4K, 16K or 64K) ahead of time.
