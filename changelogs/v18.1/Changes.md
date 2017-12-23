Polo v18.1 is now available

## **What's New**

- Added options for comparing text files with Diffuse

- Redesigned the bookmarks popup

- Previous version had a minor lag while navigating folders, due to changes that were done for querying folders asynchronously. This has been fixed.

- Added appdata file for displaying app info and screenshots in Software Center applications

- Improved the chroot command in Terminal's right-click menu. 

  - It's now based on the arch-chroot script and more robust
  - Backup will be created for resolv.conf in chroot path, and restored on exit. This avoids breaking symlinks on systems where resolv.conf is symlinked to another path. 
  - GUI sharing issues were fixed. You can now run GUI applications installed on the chrooted system.

- Added *Properties* menu item to Device context menu. GPT label info will also be displayed in filesystem properties.

- Installers now use XZ compression and are much smaller in size

  ​

