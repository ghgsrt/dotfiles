source $PROFILE/share/zsh/plugins/zsh-antigen/antigen.zsh

echo "Loading zsh-antigen plugins..."

antigen use oh-my-zsh

antigen bundle git
antigen bundle zsh-users/zsh-syntax-highlighting

antigen theme romkatv/powerlevel10k

antigen apply

if [ -z "$TMUX" ]; then
  exec tmux
fi

should_sudo() {
	if [ "$USER" = "root" ]; then
        $@
		return
    fi

	# Check if user is in wheel group
    if groups "$USER" | grep -q "\bwheel\b"; then
	   echo "Sudoing $@"
        sudo "$@"
    fi
}

alias git='should_sudo git'

alias ls='should_sudo ls -ACFL --color=auto'
alias ll='ls -l'  # list format
alias lt='ls -t'  # sort by time
alias la='ls -u'  # sort by last access
alias lss='ls -s' # show size

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias q='exit'
alias c='clear'
alias h='history'

rerun_init() {
	if [ -z "$1" ]; then
		echo "Re-running init script with current configuration"
		$DOTFILES_DIR/init.sh
	else
		echo "Re-running init script with (system: $1) configuration"
		$DOTFILES_DIR/init.sh $1
	fi
}
alias redots='rerun_init'

alias srec='echo Error: your current distro does not support reconfiguration'
alias hrec='echo Error: your current distro does not support reconfiguration'

srec_guix() {
	if [ -z "$1" ]; then
        echo "srec: using current system $SYSTEM"
    fi
    guix system -L $IX_CONFIG_DIR reconfigure $IX_CONFIG_DIR/system/${1-$SYSTEM}.scm
}
hrec_guix() {
	if [ -z "$1" ]; then
		echo "hrec: using current home $HOME_NAME"
	fi
	guix home -L $IX_CONFIG_DIR reconfigure $IX_CONFIG_DIR/home/${1-$HOME_NAME}.scm
}

if [ "$DISTRO" = "guix" ]; then
	alias srec='should_sudo srec_guix'
	alias hrec='hrec_guix' #! DO NOT SUDO ON HOME RECONFIGURES

	alias pull='should_sudo guix pull'
	alias herd='should_sudo herd'
	alias sdesc='system describe'
	alias hdesc='home describe'

	alias package='guix package'
	alias system='guix system'
	alias home='guix home'

	alias update='pull && should_sudo package -u'
	alias install='package -i'
	alias remove='package -r'
	alias search='package -s'
	alias info='package -I'
	alias list='package -p'
fi

srec_nix() {
	if [ -z "$1" ]; then
		echo "srec: using current system $SYSTEM"
	fi
	cd $IX_CONFIG_DIR
	nixos-rebuild switch --flake .#${1-$SYSTEM}
	cd -
}
hrec_nix() {
	if [ -z "$1" ]; then
		echo "hrec: using current home $HOME_NAME"
	fi
	cd $IX_CONFIG_DIR
	home-manager switch --flake .#${1-$HOME_NAME}
	cd -
}

if [ "$DISTRO" = "nix" ]; then
	alias srec='should_sudo srec_nix'
	alias hrec='hrec_nix' #! DO NOT SUDO ON HOME RECONFIGURES

	alias upflake='nix flake update'

	alias home='home-manager'
fi
