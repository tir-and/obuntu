1. Preparation

Check current version, note the codename (e.g. noble, oracular, etc.).
```
lsb_release -a
```
Update all packages before upgrading
```
sudo apt update && sudo apt full-upgrade
sudo reboot
```
Backup configs and scripts
```
mkdir -p ~/backup-obuntu
sudo rsync -a /etc/skel ~/backup-obuntu/skel-backup
sudo rsync -a ~/obuntu-setup ~/backup-obuntu/scripts
```
If you use git:
```
git add . && git commit -m "Before upgrade to <new release>"
```
Optionally export installed packages
```
dpkg --get-selections | grep -v deinstall > ~/backup-obuntu/packages.list
```

2. Update PPA and script references
Search your scripts for the current Ubuntu codename (e.g. noble) and replace it with the new one (oracular, plucky, etc.):
Files to edit:

desktop.sh → PPA line for zquestz:
```
echo "deb [signed-by=/usr/share/keyrings/zquestz-archive-keyring.gpg] https://zquestz.github.io/ppa/ubuntu <new_codename> main"
```
Any other PPAs or theme sources you may have added.


3. Perform the upgrade
Option A – In-place upgrade (keeps all files):
```
sudo do-release-upgrade
```
Option B – Clean install (recommended for major LTS upgrades):
a. Install the new Ubuntu Server (Minimal) ISO.
b. Copy your obuntu-setup folder to /home/<user>/.
c. Run:
```
cd obuntu-setup
sudo bash base.sh
sudo bash desktop.sh
sudo reboot
```

4. Post-upgrade verification
After reboot, confirm each component:

| Check               | Command or action                                  | Expected result       |
|---------------------|----------------------------------------------------|-----------------------|
| **Display manager** | LightDM shows login screen                         | ✅                     |
| **Desktop session** | Openbox loads, Rofi/Plank/Picom start              | ✅                     |
| **Audio**           | `pactl info` or `systemctl --user status pipewire` | ✅ active              |
| **Network**         | `nmcli` shows devices                              | ✅ working             |
| **Fonts**           | `fc-list \| grep Hack`                             | ✅ found               |
| **Theme**           | GTK apps use “Celestial”                           | ✅ correct             |
| **Dock**            | Plank-Reloaded visible                             | ✅                     |
| **System logs**     | `sudo journalctl -p 3 -xb`                         | no errors             |


If anything fails, re-run:
```
sudo bash base.sh
sudo bash desktop.sh
```
This re-applies tweaks without harming your system.

5. Clean up and finalize
Remove old apt lists and packages:
```
sudo apt autoremove --purge -y
sudo apt clean
```
Refresh font cache:
```
sudo fc-cache -f -v
```
Commit or zip your updated setup folder.

6. Quick reference (things that may change per release)

| Area                     | What to check                              |
|--------------------------|--------------------------------------------|
| **PPA codename**         | Update in `desktop.sh`                     |
| **Renamed packages**     | e.g., audio libs, GTK names                |
| **Removed dependencies** | Optional; drop from script if 404s         |
| **Themes/fonts**         | Verify GitHub sources still exist          |
| **Network setup**        | Ensure NetworkManager enabled post-upgrade |



7. Emergency restore
If something breaks badly:
```
sudo xargs -a ~/backup-obuntu/packages.list apt install -y
```
Then re-run both setup scripts.

Summary
| Step | Action                        |
| ---- | ----------------------------- |
| 1    | Backup configs & scripts      |
| 2    | Update PPAs to new codename   |
| 3    | Run upgrade or clean install  |
| 4    | Re-run base + desktop scripts |
| 5    | Verify functionality          |
| 6    | Clean & reboot                |

