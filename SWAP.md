# Swap management

The installer manages `/swap.vm` on ext2/3/4 and XFS, or `/swap.virtualmin/swapfile` on Btrfs. Other swap, including `/swap.img`, partitions, encrypted swap and zram, stays untouched. Active swap counts toward automatic sizing.

Run `sh virtualmin-install.sh` with:

| Options | Result |
| --- | --- |
| None | Install with automatic swap sizing. Leave an existing managed swapfile alone. |
| `--swap 2G` | Install and create, resize or reuse a 2 GiB swapfile. |
| `--swap-only --swap 2G` | Configure that swapfile without installing or changing repositories. Works after installation. |
| `--swap-only --swap 0` | Remove that swapfile and its boot configuration. |
| `--swap-only` | Apply automatic sizing without installing. |
| `--no-swap` | Skip all swap checks and changes. |

`--yes` skips confirmation. `--swap-only` cannot be combined with `--setup`, `--uninstall` or `--connect`. `--swap` and `--no-swap` cannot be combined. `VIRTUALMIN_SETUP_ONLY=1` forces repository setup without swap changes.

## Sizing

Bare numbers mean MiB. Suffixes `K`, `M`, `G` and an optional `B` are accepted, regardless of case; all use binary units. Positive sizes round up to whole MiB and must be below 1 TiB. Usable swap is slightly smaller because of its header.

Swap needs depend on workload, as [Red Hat's guidance](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_storage_devices/getting-started-with-swap) explains. The numbers below are Virtualmin installation defaults, not a universal Linux sizing standard or a hibernation allowance.

Automatic sizing leaves an existing managed swapfile unchanged. When no managed swapfile exists:

1. Calculate the gap to **8 GiB**: `8 GiB - (detected RAM + active swap)`. Add nothing if the target is already met.
2. Round the gap and **twice RAM** up to whole GiB. Use the smaller value.
3. Reserve **3 GiB** for full installation, **2 GiB** for mini, or **1 GiB** for `--swap-only`. Each includes **1 GiB** of disk headroom; the rest is for installation packages. Cap added swap using the remaining free space:

| Free space after reserve | Below 5 GiB | 5–<10 GiB | 10–<20 GiB | 20–<40 GiB | 40+ GiB |
| --- | --- | --- | --- | --- | --- |
| Maximum added swap | None | 1 GiB | 2 GiB | 3 GiB | 6 GiB |

Example: with 4 GiB detected RAM, no active swap and 15 GiB free disk, a full installation reserves 3 GiB. The remaining 12 GiB caps added swap at **2 GiB**.

Explicit sizes bypass these caps but still need space for the new file, the retained original and the reserve.

## Safety

Creation follows the documented [Linux swapfile](https://man7.org/linux/man-pages/man8/swapon.8.html#NOTES) and [Btrfs](https://btrfs.readthedocs.io/en/latest/Swapfile.html) requirements for allocation and activation.

- Unsafe files, conflicting boot entries and custom systemd swap settings require manual review.
- Deactivating swap needs enough available RAM for its used pages plus 256 MiB. Swapfile hibernation or an unverified resume target blocks resizing and removal.
- A replacement is tested before disabling the original. The original is kept until activation and the atomic fstab update succeed; failures attempt rollback.
- Runs are locked, concurrent fstab edits abort the update, and existing fstab options are preserved. Added `nofail` keeps missing swap from blocking boot.
- Power loss or SIGKILL can leave `.new.*` or `.new.*.old` files. Check active swap before deleting them; failed recovery reports what was retained.

Btrfs needs `btrfs-progs` 6.1+. A dedicated subvolume keeps swap from blocking root snapshots; restrictions on balance and scrub still apply. Systemd ordering avoids simultaneous swap activation conflicts. The empty subvolume stays after removal. Legacy `/swap.vm` on Btrfs can be reused or removed, but not resized.

## Output

The preview highlights swap sizes. Normal installation logs successful swap changes quietly. `--swap-only` prints its log path and plan with INFO, then SUCCESS or ERROR. Any swap failure stops the operation and suggests `--no-swap`, replacing `--swap` if supplied.

Requires Linux and matching `slib.sh` with `SLIB_SWAP_API=2`; `--setup` and `--no-swap` also work with older libraries. Shell syntax is POSIX.

References: [Btrfs swapfiles](https://btrfs.readthedocs.io/en/latest/Swapfile.html), [swapon](https://man7.org/linux/man-pages/man8/swapon.8.html), [systemd swap units](https://man7.org/linux/man-pages/man5/systemd.swap.5.html).
