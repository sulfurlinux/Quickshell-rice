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
1. Make sure you got the dependencies installed. (This comand was written for Arch, if you use another Distro you will have to install them manuely.)
```
sudo pacman -S quickshell ghostty hyprlock ly fish fastfetch ttf-jetbrains-mono-nerd nautilus zed starship
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay
yay -S rose-pine-hyprcursor
```

2. Clone the repository and move the needed files into your .config directory
```
git clone https://github.com/sulfurlinux/Quickshell-rice.git
cd Quickshell-rice
rm -rf .gitignore .lunarc.json README.md
cp -r * /home/$USER/.config/
cd ..
rm -rf Quickshell-rice
```

3. Change the shell to fish
```
chsh -s /usr/bin/fish
```

4. Set the hyprcursor and gtk theme
```
hyprctl setcursor rose-pine-hyprcursor 28
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
```

5. Setup the user folders if they don't exist yet (Executing the command if they do exist won't do anything and will not overwrite any existing files)
```
mkdir /home/$USER/Desktop
mkdir /home/$USER/Documents
mkdir /home/$USER/Downloads
mkdir /home/$USER/Music
mkdir /home/$USER/Pictures
mkdir /home/$USER/Pictures/Wallpapers
mkdir /home/$USER/Videos
```

6. Reload
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
