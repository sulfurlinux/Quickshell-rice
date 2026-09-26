# Quickshell-rice

A personal Linux desktop setup for Arch Linux, Hyprland, and Quickshell. This repository contains the desktop shell and configs for the terminal, prompt, system information tools, and lock screen.

The setup is a work in progress. See [Todo](#todo) for known issues and [Roadmap](#roadmap) for planned features.

## What's included

- **Quickshell:** a bar with workspaces, clock, and audio controls; an app launcher; notifications; screenshots; and a wallpaper picker.
- **Hyprland:** window rules, keyboard shortcuts, Spotify and Discord scratchpads, and a Hyprlock config.
- **Wallpaper colors:** a Python script that derives an accent color from the wallpaper for Quickshell and generates Hyprlock theme files.
- **Terminal:** Ghostty with cursor shaders, Fish, and a Starship prompt.
- **System tools:** Fastfetch, btop, and Cava configs.

## Before installing

Use an existing Arch Linux installation with a working Hyprland session. The Hyprland config in this repository uses Lua (`hypr/hyprland.lua`); your Hyprland installation must support that configuration format.

These are personal configs, so monitor names, application choices, and home-directory paths need adjusting. Back up any existing configs you want to keep: the copy commands below overwrite matching files.

Run the installation commands in **Bash**. Other distributions need equivalent packages installed with their own package manager.

## Installation

### 1. Install dependencies

Install the applications used by the setup, plus screenshot, audio, brightness, media, and wallpaper-color tools:

```bash
sudo pacman -S --needed quickshell ghostty hyprlock fish fastfetch \
  ttf-jetbrains-mono-nerd nautilus zed starship firefox \
  grim slurp hyprpicker wl-clipboard util-linux wireplumber brightnessctl playerctl python \
  xorg-xrandr git base-devel
```

Optional packages: `ly` for a login manager, `btop` and `cava` for the included system-tool configs, and Spotify and Discord for their scratchpad shortcuts. Installing a login manager does not configure or enable it.

The cursor theme is installed from the AUR. If you already have `yay`, skip its build commands:

```bash
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
yay -S rose-pine-hyprcursor
```

Read package-manager prompts before accepting them. Press Enter when the displayed default is the option you want.

![Example package installation prompt](Install.png)

### 2. Copy the configs

Clone the repository, then copy only the configuration directories and Starship config into `~/.config`:

```bash
git clone https://github.com/sulfurlinux/Quickshell-rice.git
cd Quickshell-rice
mkdir -p "$HOME/.config"
cp -r hypr quickshell ghostty fish fastfetch btop cava "$HOME/.config/"
cp starship.toml "$HOME/.config/"
```

Keep the cloned repository if you want to pull updates or edit the source later.

### 3. Personalize paths and hardware settings

Edit the copied files in `~/.config` before loading the setup:

| File                                                     | What to adjust                                                                                                                 |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `hypr/modules/monitors.lua`                              | Monitor names, resolutions, refresh rates, and positions. Run `hyprctl monitors` to see your outputs.                          |
| `hypr/modules/autostart.lua` and `quickshell/shell.qml`  | The `DP-1` primary-monitor setting, if your output has a different name.                                                       |
| `hypr/modules/input.lua` and `hypr/modules/programs.lua` | Keyboard layout, mouse settings, and preferred applications.                                                                   |
| `quickshell/modules/Wallpaper.qml`                       | Replace every `/home/sulfur` with your actual home-directory path, including the Python environment and wallpaper cache paths. |
| `fish/config.fish` and `fish/fish_variables`             | Remove or adapt the personal Spicetify paths if you do not use them.                                                           |

Create the user folders and the Python environment used by the wallpaper-color script:

```bash
mkdir -p "$HOME"/{Desktop,Documents,Downloads,Music,Pictures/Wallpapers,Videos}
python3 -m venv "$HOME/.cache/quickshell_venv"
"$HOME/.cache/quickshell_venv/bin/python3" -m pip install Pillow
```

Put a wallpaper at `~/Pictures/Wallpapers/wallpaper.png`, or change the default wallpaper paths in `Wallpaper.qml` to point to your own image. Additional wallpapers in that directory can be selected through the launcher.

Generate the initial theme files used by Quickshell and Hyprlock:

```bash
"$HOME/.cache/quickshell_venv/bin/python3" \
  "$HOME/.config/quickshell/modules/extract_color.py" \
  "$HOME/Pictures/Wallpapers/wallpaper.png"
```

If you chose another image, use its path in the command above.

### 4. Apply the shell and appearance settings

To make Fish your login shell:

```bash
chsh -s /usr/bin/fish
```

The shell change takes effect the next time you log in.

From your Hyprland session, apply the cursor and GTK appearance:

```bash
hyprctl setcursor rose-pine-hyprcursor 28
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
```

### 5. Load the setup

Reload Hyprland:

```bash
hyprctl reload
```

Quickshell starts automatically when a new Hyprland session starts. To start it in the current session if it is not already running:

```bash
qs
```

## Everyday controls

`Super` is usually the Windows key. All bindings are defined in `hypr/modules/binds.lua`.

| Shortcut                      | Action                                                          |
| ----------------------------- | --------------------------------------------------------------- |
| `Super + Space`               | Toggle the launcher                                             |
| `Super + N`                   | Toggle the notification center                                  |
| `Print`                       | Select a screenshot area, save it, and copy it to the clipboard |
| `Super + Q` / `W` / `E` / `Z` | Open the terminal / browser / file manager / editor             |
| `Super + Shift + R`           | Reload Hyprland and restart Quickshell                          |

Screenshots are saved in `~/Pictures/Screenshots`. In the launcher, type `/wallpaper` to choose an image, or `/power` to open the shutdown, restart, lock, and logout submenu. Type after `/power` to filter its actions. Press `Escape` or choose “Back to commands” to return. The `/shutdown`, `/reboot`, `/lock`, and `/logout` shortcuts still work directly.

All power and session actions run immediately without a confirmation dialog.

Area screenshots freeze all displays while you select. Press `Escape` to cancel; repeated screenshot requests are ignored until the current capture finishes. Save-and-copy uses one capture for both the file and clipboard. `hyprpicker` provides the frozen backdrop, and `flock` (from `util-linux`) prevents overlapping captures.

## Todo

- Add timestamps and a do not disturb to the notification center
- Fix the Workspace order

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
