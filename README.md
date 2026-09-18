# Quickshell-rice

A personal Linux desktop rice built around Hyprland and Quickshell.

## Todo

- Lockscreen keeps breaking > The Content of hyprlock.conf keeps disappearing
  - Write the Wallpaper into a separate file and read from there instead of writing into the config, implement a Fallback  
- Fix the Workspace order
- Freeze the screen when Screenshotting
- Fix the screenshot utility white background stacking
- Fix the Launcher buging when the cursor is inside the window

## Install

1. Make sure you got Quickshell, Ghostty and Hyprlock installed.

```
sudo pacman -S quickshell ghostty hyprlock
```

2. Clone the repository

```
git clone --bare --depth 1 https://github.com/sulfurlinux/Quickshell-rice.git
```

3. And move the files into your .config directory

```
cd Quickshell-rice
cp * $USER/.config/
rm .gitignore .lunarc.json README.md
cd ..
```

4. Don't forget to delete the left over clone

```
rm -rf Quickshell-rice
```
5. Reload

```
hopefully reload
```
## Roadmap

- [x] Add Screenshot Utility
- [x] beautify ls
- [ ] Find a good filemanager
- [ ] Clipboard
- [ ] Cursor
- [x] Fancy Text cursor in the Terminal
- [x] Logout menu
- [ ] Launcher
  - [x] App Launcher
  - [ ] pkiller
  - [ ] System settings
  - [ ] (Transparency)
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
- [x] Custom Spotify and Discord scratchpads
- [ ] Fetch / system information
- [x] Notification System
  - [x] Notification daemon
  - [x] Notification center
