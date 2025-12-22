#!/bin/bash
set -e   # Stop on any error
set -u   # Treat unset vars as errors
cd $HOME # Run script in home directory

# === Prevent accidentally running ===
echo "=== INFO ==="
echo "Primarily designed for arch linux, but will work on other systems"
echo "Full media codecs will be installed on Fedora systems"
echo "Designed for KDE Plasma, will not apply KDE configs if plasmashell does not exist"
echo ""
read -p "Are you sure you want to start the setup? [Y/n]" {confirm,,}
if [[ $confirm = "y" || $confirm = "yes" || -z $confirm ]]; then
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
    LINUX="fedora"
    PKG_INSTALL="sudo dnf install -y --skip-unavailable"
elif [ -f /etc/arch-release ]; then
    LINUX="arch"
    PKG_INSTALL="sudo pacman -Syu --noconfirm"
elif [ -f /etc/debian_version ]; then
    LINUX="debian"
    PKG_INSTALL="sudo apt install -y"
else
    echo "Unsupported distro. Please edit script to add support."
    exit 1
fi

# === Check package manager for the system is functional ===
if [ $LINUX = "fedora" ] && ! command -v dnf &> /dev/null; then
        echo "Something has gone terribly wrong, dnf was not found!"
        echo "Try to remedy this by installing dnf (if this is Fedora, of course) or by reinstalling Fedora from https://fedoraproject.org (legitimate site)"
        exit 1
fi
if [ $LINUX = "arch" ] && ! command -v pacman &> /dev/null; then
        echo "Something has gone terribly wrong, pacman was not found!"
        echo "Try to remedy this by installing pacman (if this is Arch Linux, of course) or by reinstalling Arch Linux from https://archlinux.org (legitimate site)"
        exit 1
fi
if [ $LINUX = "debian" ] && ! command -v apt &> /dev/null; then
        echo "Something has gone terribly wrong, apt was not found!"
        echo "Try to remedy this by installing apt (if this is Debian, of course) or by reinstalling Debian from https://debian.org (legitimate site)"
        exit 1
fi


# === Update the system ===
if [ $LINUX = "fedora" ]; then
    sudo dnf update -y
elif [ $LINUX = "arch" ]; then
    sudo pacman -Syu --noconfirm
elif [ $LINUX = "debian" ]; then
    sudo apt update && sudo apt upgrade
fi

# === Set DNF defaultyes to "Y" ===
if [ $LINUX = "fedora" ]; then
    echo "Setting DNF to assume 'yes' for all prompts..."
    sudo echo "defaultyes=True" | sudo tee -a /etc/dnf/dnf.conf
    
    # === Full media codecs on Fedora ===
    # === Add RPM Fusion media repo ===
    echo "Adding required repositories..."
    $PKG_INSTALL https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    # === Update the system ===
    echo "Making sure the system is up to date..."
    sudo dnf update -y

    # === Swap codecs ===
    echo "Installing full media codec support..."
    sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
fi

# === Install dependencies ===
echo "Installing dependencies..."
$PKG_INSTALL git zsh curl wget cowsay

# === Install yay (AUR helper, Arch only) ===
if [ $LINUX = "arch" ]; then
    if ! command -v yay &>/dev/null; then
        echo "Installing yay (AUR helper)..."
        $PKG_INSTALL base-devel
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

# === Ask for GPU vendor ===
while true; do
    read -p "Enter GPU vendor (AMD/NVIDIA/Intel): " gpu
    gpu=${gpu,,}
    case "$gpu" in
        amd|intel|nvidia)
            break
            ;;
        *)
            echo "Invalid entry. Please enter AMD, NVIDIA, or Intel."
            ;;
    esac
done

# === Install GPU Drivers (Arch) ===
if [ $LINUX = "arch" ]; then 
    if [ $gpu = "amd" ]; then
        $PKG_INSTALL mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu
    elif [ $gpu = "intel" ]; then
        $PKG_INSTALL mesa lib32-mesa vulkan-intel lib32-vulkan-intel xf86-video-intel
    elif [ $gpu = "nvidia" ]; then
        $PKG_INSTALL nvidia nvidia-dkms nvidia-utils lib32-nvidia-utils
        read -p "Install CUDA? [Y/n]" cuda
        cuda=${cuda,,}
        if [[ $cuda = "y" || $cuda = "yes" || -z $cuda ]]; then
            $PKG_INSTALL cuda
        else
            echo "Skipping CUDA installation..."
        fi
    fi
fi

# === Install GPU Drivers (Fedora) ===
if [ $LINUX = "fedora" ]; then
    if [ $gpu = "amd" ]; then
        echo "Installing GPU accelerated media packages for AMD..."
        $PKG_INSTALL mesa-vdpau-drivers libva-utils

        read -p "Would you like to install ROCm? (recommended for Machine Learning) [y/N]" rocm
        rocm=${rocm,,}
        if [[ $rocm = "y" || $rocm = "yes" ]]; then
            echo "Adding ROCm repository..."
            wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
            rpm -ivh epel-release-latest-10.noarch.rpm
            dnf config-manager --enable codeready-builder-for-rhel-10-x86_64-rpms
            $PKG_INSTALL python3-setuptools python3-wheel

            echo "Installing ROCm..."
            usermod -a -G render,video $LOGNAME # Add the current user to the render and video groups
            $PKG_INSTALL rocm
        fi

    elif [ $gpu = "intel" ]; then
        echo "Installing GPU accelerated media packages for Intel..."
        $PKG_INSTALL intel-media-driver libva-utils

    elif [ $gpu = "nvidia"]; then
        echo "Installing NVIDIA driver and GPU accelerated media packages..."
        $PKG_INSTALL akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver

        read -p "Would you like to install additional CUDA libraries? (reccomended for Machine Learning) [Y/n]" mlcuda
        mlcuda=${mlcuda,,}
        if [[ $mlcuda = "y" || $mlcuda = "yes" || -z $mlcuda ]]; then
            echo "Adding CUDA repository..."
            dnf config-manager addrepo --from-repofile=https://developer.download.nvidia.com/compute/cuda/repos/fedora42/$(uname -m)/cuda-fedora42.repo
            dnf clean all

            echo "Installing additional CUDA libraries..."
            dnf config-manager setopt cuda-fedora42-$(uname -m).exclude=nvidia-driver,nvidia-modprobe,nvidia-persistenced,nvidia-settings,nvidia-libXNVCtrl,nvidia-xconfig
            $PKG_INSTALL cuda-toolkit xorg-x11-drv-nvidia-cuda
        fi
    fi
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
else
    read -p "Overwrite .zshrc ? [Y/n]" owzsh
    owzsh=${owzsh,,}
    if [[ $owzsh = "y" || $owzsh = "yes" || -z $owzsh ]]; then
        echo "Overwriting .zshrc ..."
        cp -f "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
    else
        continue
    fi
fi

# === Copy powerlevel10k config ===
if [ -f "$HOME/.p10k.zsh" ]; then
    echo "Copying powerlevel10k configuration..."
    cp -f "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
else
    read -p "Overwrite .p10k.zsh ? [Y/n]" ptenk
    ptenk=${ptenk,,}
    if [[ $ptenk = "y" || $ptenk = "yes" || -z $ptenk ]]; then
        echo "Overwriting .p10k.zsh ..."
        cp -f "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
    else
        continue
    fi
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
        echo "Could not automatically apply cursor - please select it manually in system settings."
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

# === KDE Only, skip otherwise ===
if command -v plasmashell &>/dev/null; then
    echo "Applying colours..."

    # Icon theme
    lookandfeeltool --apply org.kde.breeze.desktop || true
    kwriteconfig6 --file kdeglobals --group Icons --key Theme "$ICON_THEME"

    # Color scheme
    kwriteconfig6 --file kdeglobals --group General --key AccentColor "$ACCENT_COLOR"
    plasma-apply-colorscheme BreezeDark
else
    continue
fi

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
    cp -r "$DOTFILES_DIR/icons/"* ~/.local/share/icons/
    fc-cache -fv
fi

# === KDE Only, skip otherwise ===
if command -v plasmashell &>/dev/null; then
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
else
    echo "Plasma not installed, apply icons, colours, fonts, and wallpapers manually..."
fi

# === Change default shell to zsh ===
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
fi

# === Package Installation ===
read -p "Would you like to install packages? [Y/n]" appsq
appsq=${appsq,,}
if [[ $appsq = "y" || $appsq = "yes" || -z $appsq ]]; then
    if [ $LINUX = "fedora" ]; then
        $PKG_INSTALL android-tools ark btop cava cmatrix discord easyeffects fastfetch goverlay mangohud python python-websockets qbittorrent qt6-qtwebsockets-devel speedtest-cli steam vlc vlc-plugins-all
        
        echo "Enabling flatpak repository..."
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    elif [ $LINUX = "arch" ]; then
        $PKG_INSTALL android-tools ark btop cava cmatrix discord easyeffects ffmpeg fastfetch firefox flatpak goverlay mangohud partitionmanager prismlauncher python python-websockets qbittorrent qt6-websockets speedtest-cli steam vlc vlc-plugins-all
    elif [ $LINUX = "debian" ]; then
        $PKG_INSTALL ark btop cava cmatrix discord easyeffects fastfetch flatpak google-android-platform-tools-installer goverlay mangohud python python-websockets qbittorrent qt6-websockets speedtest-cli steam vlc vlc-plugins-all
    fi
else
    echo "Skipping package installation..."
fi

# === Flatpak Installation ===
read -p "Would you like to install essential flatpak apps? [Y/n]" flatpakq
flatpakq=${flatpakq,,}
if [[ $flatpakq = "y" || $flatpakq = "yes" || -z $flatpakq ]]; then
    flatpak install com.dec05eba.gpu_screen_recorder com.github.tchx84.Flatseal it.mijorus.gearlever org.localsend.localsend_app
    
    # === Ask for gaming flatpaks ===
    read -p "Would you like to install essential gaming flatpaks? [Y/n]" gamefpk
    gamefpk=${gamefpk,,}
    if [[ $gamefpk = "y" || $gamefpk = "yes" || -z $gamefpk ]]; then
        echo "Installing gaming flatpaks..."
        flatpak install -y com.github.Matoking.protontricks net.davidotek.pupgui2 com.steamgriddb.SGDBoop
    else
        echo "Skipping..."
        continue
    fi

else
    echo "Skipping flatpak installation..."
fi

# === Package Installation (AUR) ===
if [ $LINUX = "arch" ]; then
    read -p "Would you like to install AUR packages? [Y/n]" aur_appsq
    aur_appsq=${aur_appsq,,}
    if [[ $aur_appsq = "y" || $aur_appsq = "yes" || -z $aur_appsq ]]; then
        yay -S --needed visual-studio-code-bin plasma6-applets-kurve
    else
        echo "Skipping AUR package installation..."
    fi
fi

# === Copy Pacman config (Arch only) ===
if [ $LINUX = "arch" ]; then
    if [ -f "$DOTFILES_DIR/pacman.conf" ]; then
        echo "Applying custom pacman configuration..."
        sudo cp -f "$DOTFILES_DIR/pacman.conf" /etc/pacman.conf
    else
        echo "No pacman.conf found in dotfiles, skipping..."
    fi
fi

fastfetch
echo "=== Setup Complete! ==="
read -p "Do you wish to reboot? (please make sure everything is saved) [Y/n]" reboot
reboot=${reboot,,}
if [[ $reboot = "y" || $reboot = "yes" || -z $reboot ]]; then
    reboot now
fi
