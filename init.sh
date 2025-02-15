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

should_sudo() {
	if [ "$USER" = "root" ]; then
        $@
		return
    fi

	# Check if user is in wheel group
    if groups "$USER" | grep -q "\bwheel\b"; then
        sudo "$@"
    fi
}

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
            should_sudo rm "$dst"
        fi
    elif [ -e "$dst" ]; then
        # If it's a regular file, warn and skip
        echo "Warning: $dst exists and is not a symlink"
        return
    fi

    should_sudo ln -sf "$src" "$dst"
}

recursive_symlink() {
    local src_dir="$1"
    local dst_dir="$2"
	local -a exclusions=("${@:3}") # Get all arguments after the first two as exclusions

    # Ensure source directory exists
    if [ ! -d "$src_dir" ]; then
        echo "Source directory $src_dir does not exist"
        return 1
    fi

    # Create destination directory if it doesn't exist
    if [ ! -d "$dst_dir" ]; then
        should_sudo mkdir -p "$dst_dir"
    fi

	local exclude_expr=""
    for excl in "${exclusions[@]}"; do
        if [ -n "$exclude_expr" ]; then
            exclude_expr="$exclude_expr -o "
        fi
        exclude_expr="$exclude_expr -path \"$src_dir/$excl/*\" -o -path \"$src_dir/$excl\""
    done

    # Use find with exclusion if paths exist
    if [ -n "$exclude_expr" ]; then
        eval "find \"$src_dir\" -type f ! \( $exclude_expr \) -print0"
    else
        find "$src_dir" -type f -print0
    fi | while IFS= read -r -d $'\0' src_path; do
        # Calculate relative path from source directory
        local rel_path="${src_path#$src_dir/}"
        local dst_path="$dst_dir/$rel_path"

        # Create parent directories in destination if needed
        local dst_parent_dir=$(dirname "$dst_path")
        if [ ! -d "$dst_parent_dir" ]; then
            sudo mkdir -p "$dst_parent_dir"
        fi

        create_symlink "$src_path" "$dst_path"
    done
}

exclusions=(".git" "README.md" "LICENSE" ".github" ".gitignore" "init.sh" "fonts" "users" "tmux" "sway")
setup_system() {
    echo "Setting up system configuration..."

    # Ensure XDG directory exists
    # should_sudo mkdir -p "$XDG_DIR"

    # Link dotfiles to /etc/xdg
	# recursive_symlink "$DOTFILES_DIR" "$XDG_DIR" "${exclusions[@]}"

    # Handle non-XDG compliant configs
	# create_symlink "$DOTFILES_DIR/tmux/tmux.conf" "/etc/tmux.conf"

	# should_sudo mkdir -p "/etc/sway"
	# create_symlink "$DOTFILES_DIR/sway/config" "/etc/sway/config"
    # Add other non-XDG compliant symlinks here

	# Ensure /etc/zshrc does not already exist
	if [ -e "/etc/zshrc" ]; then
		echo "Warning: /etc/zshrc already exists. Please remove it to replace it."
		return
	fi

	# Ensure generated directory exists
	should_sudo mkdir -p "${DOTFILES_DIR}/generated"

	# Generate system zshrc for default environment variables
	cat << EOF | should_sudo tee "${DOTFILES_DIR}/generated/system-zshrc" > /dev/null
# Generated by init script - DO NOT EDIT

export DOTFILES_DIR="${DOTFILES_DIR}"
export BOS_CONFIG_DIR="$(dirname "$DOTFILES_DIR")"

export SYSTEM="${SYSTEM}"
export DISTRO="${DISTRO}"

export XDG_CONFIG_HOME="\${XDG_CONFIG_HOME:-\$HOME/.config}"

export XDG_CONFIG_DIRS="\${DOTFILES_DIR}/home/base:\${XDG_CONFIG_DIRS}"
if [ ! -d "\${DOTFILES_DIR}/\$USER" ]; then
	export XDG_CONFIG_DIRS="\${DOTFILES_DIR}/home/\${USER}:\${XDG_CONFIG_DIRS}"
fi
export XDG_CONFIG_DIRS="\${XDG_CONFIG_DIRS}:\${DOTFILES_DIR}/base"

#export ZDOTDIR="\${XDG_CONFIG_HOME}/zsh"

# source non-XDG compliant shell configs
# (typically those that want to exist under /etc, but may conflict if symlinked to /etc)
#source "$XDG_DIR/zsh/.zshenv"

#source "$XDG_DIR/zsh/p10k-instant-prompt-root.zsh"
#source "$XDG_DIR/zsh/.p10k.zsh"

#source "$XDG_DIR/zsh/.zshrc"
# source "$XDG_DIR/zsh/.zprofile"
EOF

    # Ensure the generated file is readable
    should_sudo chmod 644 "${DOTFILES_DIR}/generated/system-zshrc"

    # Link it to /etc/zshrc
	# (MUST BE zshrc, otherwise guix bash profile will overwrite the XDG_CONFIG_DIRS
	#  and the user zshrc won't have the env vars set if zlogin)
    create_symlink "${DOTFILES_DIR}/generated/system-zshrc" "/etc/zshrc"

}

setup_user() {
    echo "Setting up user configuration for $USER..."

    # Create user .config if it doesn't exist
    mkdir -p "$HOME/.config"

    # If user-specific configs exist, link them
    if [ -d "$DOTFILES_DIR/users/$USER" ]; then
        recursive_symlink "$DOTFILES_DIR/users/$USER" "$HOME/.config"
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
