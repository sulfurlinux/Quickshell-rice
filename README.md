# Quickshell-rice
A personal Linux rice using Arch, Hyprland and Quickshell.

## Todo
- Hyprctl kill
- Add timestamps and a do not disturb to the notification center
- Split Shutdown, Reboot etc into a submenu in the /Luncher!!!
- Fix the Workspace order
- Freeze the screen when Screenshotting
- Fix the screenshot utility white background stacking
- Fix the Launcher buging when the cursor is inside the window
- make the louncher icons use the text color


## Install
1. Make sure you got Quickshell, Ghostty, Fish, Ly, Hyprlock and the Hyprcursor Theme installed. (This comand was written for Arch, if you use another Distro you will have to install them manuely.)
```
sudo pacman -S quickshell ghostty hyprlock ly fish
yay -S rose-pine-hyprcursor
```
2. Clone the repository
```
git clone https://github.com/sulfurlinux/Quickshell-rice.git
```
3. And move the files into your .config directory
```
cd Quickshell-rice
rm -rf .gitignore .lunarc.json README.md
cp -r * /home/$USER/.config/
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

- yay, fastfetch, Fonts, shell change, Starship, Wallpaper, User folders, Set Mouse theme, Install Nautilus, Darkmode theme

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
