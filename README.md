# Quickshell-rice
A personal Linux rice using Arch, Hyprland and Quickshell.

## Todo
- Fix the Workspace order
- Freeze the screen when Screenshotting
- Fix the screenshot utility white background stacking
- Fix the Launcher buging when the cursor is inside the window

## Install
1. Make sure you got Quickshell, Ghostty, Fish, Ly and Hyprlock installed. (This comand was written for Arch, if you use another Distro you will have to install them manuely.)
```
sudo pacman -S quickshell ghostty hyprlock ly fish
```
2. Clone the repository
```
git clone https://github.com/sulfurlinux/Quickshell-rice.git
```
3. And move the files into your .config directory
```
cd Quickshell-rice
cp -r * /home/$USER/.config/
rm -rf .gitignore .lunarc.json README.md
cd ..
```
4. Don't forget to delete the left over clone
```
rm -rf Quickshell-rice
```
5. Reload
```
hyprctl reload
```

## Roadmap
- [x] Add Screenshot Utility
- [ ] Clipboard
- [x] Cursor
- [x] Fancy Text cursor in the Terminal
- [x] Logout menu
- [ ] Launcher
  - [x] App Launcher
  - [ ] pkiller
- [x] Wallpaper system
  - [x] Wallpaper switcher in launcher
- [ ] Dynamic theme system
  - [x] Extract color palette from wallpaper
  - [x] Integratation in Quickshell
  - [ ] Integratation in Hyprland
- [ ] Bar
  - [ ] Logout menu button
  - [ ] Music
  - [x] Dynamic workspaces
  - [x] Audio meter
  - [ ] Cava
  - [ ] System resource usage
  - [x] Clock
- [ ] Customize lockscreen / login screen
- [ ] Customize Boot animation / limine
- [ ] Music player
- [x] Custom Spotify and Discord scratchpads
- [ ] Fetch / system information
- [x] Notification System
  - [x] Notification daemon
  - [x] Notification center
