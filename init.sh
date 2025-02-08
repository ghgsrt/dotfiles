set -euo pipefail

# Default values
SYSTEM=${1:-$SYSTEM}
#! VALID SYSTEMS: "desktop", "thinkpad", "zenbook", "vm", "wsl", "server"
if [ -z "$SYSTEM" ]; then
	echo "No system specified. Please provide an arg in position 1 or set the SYSTEM environment variable."
	exit 1
fi

DISTRO=${2:-$DISTRO}
#! VALID DISTROS: "guix", "nix", "arch", "void", "alpine"
if [ -z "$DISTRO" ]; then
	echo "No distro specified. Please provide an arg in position 2 or set the DISTRO environment variable."
	exit 1
fi

USER=${USER:-$(whoami)}
MODE=${3:-"all"}  # all, system, or user

# Paths
DOTFILES_DIR=$(dirname "$(readlink -f "$0")")
echo "Using dotfiles directory: $DOTFILES_DIR"
XDG_DIR="/etc/xdg"

create_symlink() {
    local src="$1"
    local dst="$2"

	if [ ! -e "$src" ]; then
		echo "Source file $src does not exist"
		return
	fi

    # If destination exists and is a symlink
    if [ -L "$dst" ]; then
        local current_target=$(readlink -f "$dst")
        # If it's already pointing to our source, skip
        if [ "$current_target" = "$(readlink -f "$src")" ]; then
            echo "Symlink already correctly set for $dst"
            return
        else
            # If it's pointing somewhere else, replace it
            echo "Replacing existing symlink $dst"
            sudo rm "$dst"
        fi
    elif [ -e "$dst" ]; then
        # If it's a regular file/directory, warn and skip
        echo "Warning: $dst exists and is not a symlink"
        return
    fi

    sudo ln -sf "$src" "$dst"
}

setup_system() {
    echo "Setting up system configuration..."

    # Ensure XDG directory exists
    sudo mkdir -p "$XDG_DIR"

    # Link dotfiles to /etc/xdg
    sudo cp -rs "$DOTFILES_DIR/"* "$XDG_DIR/"

    # Handle non-XDG compliant configs
    # Add other non-XDG compliant symlinks here

	# Ensure /etc/zshenv does not already exist
	if [ -e "/etc/zshenv" ]; then
		echo "Warning: /etc/zshenv already exists. Please remove it to replace it."
		return
	fi

	# Ensure generated directory exists
	sudo mkdir -p "${DOTFILES_DIR}/generated"

	# Generate system zshenv for default environment variables
	cat > "${DOTFILES_DIR}/generated/system-zshenv" << EOF
# Generated by init script - DO NOT EDIT

export DOTFILES_DIR="${DOTFILES_DIR}"
export IX_CONFIG_DIR="$(dirname "$DOTFILES_DIR")"

export SYSTEM="${SYSTEM}"
export DISTRO="${DISTRO}"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"

export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"

source "$XDG_DIR/zsh/.zshenv"
source "$XDG_DIR/zsh/.zshrc"
# source "$XDG_DIR/zsh/.zprofile"
EOF

    # Ensure the generated file is readable
    chmod 644 "${DOTFILES_DIR}/generated/system-zshenv"

    # Link it to /etc/zshenv
    create_symlink "${DOTFILES_DIR}/generated/system-zshenv" "/etc/zshenv"

}

setup_user() {
    echo "Setting up user configuration for $USER..."

    # Create user .config if it doesn't exist
    mkdir -p "$HOME/.config"

    # If user-specific configs exist, link them
    if [ -d "$DOTFILES_DIR/users/$USER" ]; then
        cp -rs "$DOTFILES_DIR/users/$USER/"* "$HOME/.config/"
    fi
}

# Main
echo "Setting up configuration for $USER on $SYSTEM with $DISTRO..."
case "$MODE" in
    "all")
        setup_system
        setup_user
        ;;
    "system")
        setup_system
        ;;
    "user")
        setup_user
        ;;
    *)
        echo "Invalid mode: $MODE"
        exit 1
        ;;
esac