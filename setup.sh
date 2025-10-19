#!/bin/bash
set -e  # Stop on any error
set -u  # Treat unset vars as errors

# === Prevent accidentally running ===
read -p "Are you sure you want to start the setup? [Y/n]" {confirm,,}
if [ $confirm = "y" ] || [ $confirm = "yes" ] || [ -z $confirm ]; then
    echo "Starting system setup & configuration..."
else
    echo "Setup aborted!"
fi

# === CONFIG ===
GITHUB_USER="Spicy-Steve"
DOTFILES_REPO="dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

CURSOR_NAME="Bibata-6bcde"             # Use from plasma-apply-cursortheme --list-themes
ICON_THEME="Papirus-Dark"              # Choose: Papirus, Papirus-Dark, Papirus-Light
ACCENT_COLOR="#ff0000"                 # Example: orange accent; use your hex color
PLASMA_THEME="Breeze-Dark"             # Your preferred Plasma look & feel theme
WALLPAPER_PATH="$DOTFILES_DIR/wallpapers"

echo "=== Starting setup for $USER ==="

# === Detect distro ===
if [ -f /etc/fedora-release ]; then
    PKG_INSTALL="sudo dnf install -y"
elif [ -f /etc/arch-release ]; then
    PKG_INSTALL="sudo pacman -Syu --noconfirm"
elif [ -f /etc/debian_version ]; then
    PKG_INSTALL="sudo apt install -y"
else
    echo "Unsupported distro. Please edit script to add support."
    exit 1
fi

# === Update the system ===
if [ -f /etc/fedora-release ]; then
    sudo dnf update
elif [ -f /etc/arch-release ]; then
    sudo pacman -Syu
elif [ -f /etc/debian_version ]; then
    sudo apt update && sudo apt upgrade
else
    echo "Unsupported distro. Please edit script to add support."
    exit 1
fi

# === Install dependencies ===
echo "Installing dependencies..."
$PKG_INSTALL git zsh curl wget cowsay

# === Install yay (AUR helper, Arch only) ===
if [ -f /etc/arch-release ]; then
    if ! command -v yay &>/dev/null; then
        echo "Installing yay (AUR helper)..."
        sudo pacman -S --needed --noconfirm base-devel git
        mkdir ~/.yay
        git clone https://aur.archlinux.org/yay-bin.git ~/.yay
        cd ~/.yay
        makepkg -si --noconfirm
    else
        echo "yay is already installed."
    fi
else
    echo "Skipping yay install - not an Arch system."
fi

# === Install GPU Drivers (ARCH ONLY) ===
if [ -f /etc/arch-release ]; then    
    echo "What is the GPU Vendor? (amd/nvidia/intel)"
    read gpu
    if [ $gpu = "amd" ]; then
        $PKG_INSTALL mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu
    elif [ $gpu = "intel" ]; then
        $PKG_INSTALL mesa lib32-mesa vulkan-intel lib32-vulkan-intel xf86-video-intel
    elif [ $gpu = "nvidia" ]; then
        $PKG_INSTALL nvidia nvidia-dkms nvidia-utils lib32-nvidia-utils
        read -p "Install CUDA? [Y/n]" cudaq
        if [ ${cudaq,,} = "y" ] || [ ${cudaq,,} = "yes" ] || [ $cudaq = "" ]; then
            $PKG_INSTALL cuda
        else
            echo "Skipping CUDA installation..."
        fi
    else
        echo "Invalid GPU Vendor, skipping..."
    fi
else
    echo "GPU Driver Installation only works on Arch Linux, skipping..."
fi


# === Clone dotfiles repo ===
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning dotfiles from GitHub..."
    git clone "https://github.com/$GITHUB_USER/$DOTFILES_REPO.git" "$DOTFILES_DIR"
else
    echo "Dotfiles already cloned — pulling latest changes..."
    git -C "$DOTFILES_DIR" pull
fi

# === Install Oh My Zsh ===
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed."
fi

# === Install extra zsh stuff ===
if [ ! -d "$ZSH_CUSTOM" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
    git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
else
    echo "OMZ Plugins already installed, skipping..."
fi

# === Copy Zsh config ===
if [ -f "$DOTFILES_DIR/.zshrc" ]; then
    echo "Applying .zshrc from dotfiles..."
    cp -f "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
fi

# === Copy Oh My Zsh custom configs if they exist ===
if [ -d "$DOTFILES_DIR/oh-my-zsh-custom" ]; then
    echo "Copying custom Oh My Zsh configuration..."
    mkdir -p "$HOME/.oh-my-zsh/custom/"
    cp -r "$DOTFILES_DIR/oh-my-zsh-custom/"* "$HOME/.oh-my-zsh/custom/"
fi

# === KDE Appearance ===
echo "Applying KDE customization..."

# === Apply cursor from dotfiles ===
if [ -d "$DOTFILES_DIR/cursors" ]; then
    echo "Installing and applying custom cursor..."
    mkdir -p ~/.icons
    cp -r "$DOTFILES_DIR/cursors"/* ~/.icons/

    # Assuming your cursor folder name matches the theme name
    CURSOR_NAME=$(ls "$DOTFILES_DIR/cursors" | head -n 1)

    # Apply cursor (KDE or GNOME based)
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_NAME"
    elif command -v plasma-apply-cursortheme &>/dev/null; then
        plasma-apply-cursortheme Bibata-6bcde
    else
        echo "Could not automatically apply cursor — please select it manually in system settings."
    fi
else
    echo "No cursor directory found in dotfiles."
fi

# === Install Papirus Icon Theme ===
echo "Installing Papirus icons..."
$PKG_INSTALL papirus-icon-theme
echo "Applying folder colours..."
wget -qO- https://git.io/papirus-folders-install | sh
papirus-folders -C carmine --theme Papirus-Dark

# Icon theme
lookandfeeltool --apply org.kde.breeze.desktop || true
kwriteconfig6 --file kdeglobals --group Icons --key Theme "$ICON_THEME"

# Color scheme
kwriteconfig6 --file kdeglobals --group General --key AccentColor "$ACCENT_COLOR"
plasma-apply-colorscheme BreezeDark

# Wallpaper
if [ -d "$WALLPAPER_PATH" ]; then
    echo "Copying wallpapers..."
    mkdir -p ~/Pictures/Backgrounds/
    cp -r "$WALLPAPER_PATH"/* ~/Pictures/Backgrounds/
fi

# === Fonts ===
if [ -d "$DOTFILES_DIR/fonts" ]; then
    echo "Installing custom fonts..."
    mkdir -p ~/.local/share/fonts/
    cp -r "$DOTFILES_DIR/fonts/"* ~/.local/share/fonts/
    fc-cache -fv
fi

# === Icons ===
if [ -d "$DOTFILES_DIR/icons" ]; then
    echo "Installing custom icons..."
    mkdir -p ~/.local/share/fonts/
    cp -rf "$DOTFILES_DIR/icons/"* ~/.local/share/icons/
    fc-cache -fv
fi

# === Config ===
if [ -d "$DOTFILES_DIR/kde-config" ]; then
    echo "Copying config files..."
    cp -r "$DOTFILES_DIR/kde-config/"* ~/.config/
fi

# === Konsole config ===
if [ -d "$DOTFILES_DIR/konsole" ]; then
    echo "Applying Konsole profiles and color schemes..."
    mkdir -p ~/.local/share/konsole/
    cp -r "$DOTFILES_DIR/konsole/"* ~/.local/share/konsole/
fi

# === Change default shell to zsh ===
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
fi

# === Package Installation ===
read -p "Would you like to install packages? [Y/n]" {appsq,,}
if [ $appsq = "y" ] || [ $appsq = "yes" ] || [ -z $appsq ]; then
    if [ -f /etc/fedora-release ]; then
        $PKG_INSTALL android-tools ark btop cava cmatrix discord easyeffects ffmpeg-full fastfetch flatpak goverlay mangohud pavucontrol prismlauncher python python-websockets qbittorrent qt6-qtwebsockets-devel speedtest-cli steam vlc vlc-plugins-all
    elif [ -f /etc/arch-release ]; then
        $PKG_INSTALL android-tools ark btop cava cmatrix discord easyeffects ffmpeg fastfetch firefox flatpak goverlay mangohud partitionmanager pavucontrol prismlauncher python python-websockets qbittorrent qt6-websockets speedtest-cli steam vlc vlc-plugins-all
    elif [ -f /etc/debian_version ]; then
        $PKG_INSTALL ark btop cava cmatrix discord easyeffects fastfetch flatpak google-android-platform-tools-installer goverlay mangohud pavucontrol prismlauncher python python-websockets qbittorrent qt6-websockets speedtest-cli steam vlc vlc-plugins-all
    fi
else
    echo "Skipping package installation..."
fi

# === Flatpak Installation ===
read -p "Would you like to install flatpak && flatpak apps? [Y/n]" {flatpakq,,}
if [ $flatpakq = "y" ] || [ $flatpakq = "yes" ] || [ -z $flatpakq ]; then
    flatpak install com.dec05eba.gpu_screen_recorder com.github.Matoking.protontricks com.github.tchx84.Flatseal com.steamgriddb.SGDBoop com.vysp3r.ProtonPlus io.missioncenter.MissionCenter it.mijorus.gearlever org.localsend.localsend_app
else
    echo "Skipping flatpak installation..."
fi

# === Package Installation (AUR) ===
if [ -f /etc/arch-release ]; then
    read -p "Would you like to install AUR packages? [Y/n]" {aur_appsq,,}
    if [ $aur_appsq = "y" ] || [ $aur_appsq = "yes" ] || [ -z $aur_appsq ]; then
        yay visual-studio-code-bin coolercontrol coolercontrold plasma6-applets-kurve
    else
        echo "Skipping AUR package installation..."
    fi
fi

# === Copy Pacman config (Arch only) ===
if [ -f /etc/arch-release ]; then
    if [ -f "$DOTFILES_DIR/pacman.conf" ]; then
        echo "Applying custom pacman configuration..."
        sudo cp -f "$DOTFILES_DIR/pacman.conf" /etc/pacman.conf
    else
        echo "No pacman.conf found in dotfiles, skipping..."
    fi
fi

# Restart Plasma shell to apply changes (optional)
if pgrep plasmashell &>/dev/null; then
    echo "Restarting Plasma shell..."
    pkill plasmashell && kstart5 plasmashell &
fi

fastfetch
echo "=== Setup complete! ==="
echo "Log out/in for changes to apply."
