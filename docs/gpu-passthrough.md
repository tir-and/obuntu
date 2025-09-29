# GPU Passthrough (Reference)

> This is a *reference* checklist. Nothing here is applied by default.

## 1) Enable IOMMU
Edit `/etc/default/grub`:
- Intel: add `intel_iommu=on`
- AMD: add `amd_iommu=on`

Example:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on"
```
Then:
```
sudo update-grub
sudo reboot
```

## 2) Verify IOMMU groups
```
find /sys/kernel/iommu_groups/ -type l | sort
lspci -nn
```

## 3) Identify devices to passthrough
Use `lspci -nn` to get GPU and its audio function (same vendor/device IDs).

## 4) Bind to vfio-pci
Create `/etc/modprobe.d/vfio.conf` with:
```
options vfio-pci ids=AAAA:BBBB,CCCC:DDDD
```
(Replace IDs with your GPU/audio IDs.)

Ensure modules load in `/etc/modules`:
```
vfio
vfio-pci
vfio-iommu-type1
```

## 5) Blacklist host drivers (optional)
Create `/etc/modprobe.d/blacklist-gpu.conf` if needed:
```
blacklist nouveau
blacklist radeon
blacklist amdgpu
blacklist nvidia
```

## 6) OVMF (UEFI) & virt-manager
- Choose **UEFI** firmware (OVMF) for the guest.
- Add PCI devices (GPU + its audio function).
- Set **virtio** disk/network.
- Install **virtio drivers** (for Windows, mount the ISO).

## 7) Hugepages (optional)
Add to `/etc/sysctl.conf` and VM XML if you want hugepages for performance.

## 8) Troubleshooting
- Disable `virtio-gpu`/`qxl` display in the VM when passing through real GPU.
- Ensure the GPU is in its own IOMMU group (or ACS override kernel patch if necessary).
