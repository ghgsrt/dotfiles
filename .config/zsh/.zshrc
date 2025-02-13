source $BOS_HOME_PROFILE/share/zsh/plugins/zsh-antigen/antigen.zsh

#echo "Loading zsh-antigen plugins..."

#source ~/.config/zsh/.p10k.zsh

antigen use oh-my-zsh

antigen bundle git
antigen bundle zsh-users/zsh-syntax-highlighting

antigen theme romkatv/powerlevel10k

antigen bundle sainnhe/dotfiles .zsh-theme/gruvbox-material-dark.zsh

antigen apply


# Enable Powerlevel10k instant prompt. Should stay close to the top of /zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
#if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
#fi

# To customize prompt, run `p10k configure` or edit /zsh/.p10k.zsh.
#[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh


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
        echo "srec: using current system '$SYSTEM'"
    fi
    should_sudo guix system -L $BOS_CONFIG_DIR reconfigure $BOS_CONFIG_DIR/system/${1-$SYSTEM}.scm
}
hrec_guix() {
	if [ -z "$1" ]; then
		echo "hrec: using current home '$BOS_HOME_NAME'"
	fi
	#! DO NOT SUDO ON HOME RECONFIGURES
	guix home -L $BOS_CONFIG_DIR reconfigure $BOS_CONFIG_DIR/home/${1-$BOS_HOME_NAME}.scm
}

if [ "$BOS_HOME_TYPE" = "guix" ]; then
	alias hrec='hrec_guix'
	alias hdesc='home describe'
	alias home='guix home'
fi

if [ "$DISTRO" = "guix" ]; then
	alias srec='srec_guix'

	alias pull='should_sudo guix pull'
	alias herd='should_sudo herd'
	alias sdesc='system describe'

	alias package='guix package'
	alias system='guix system'

	alias update='pull && should_sudo package -u'
	alias install='package -i'
	alias remove='package -r'
	alias search='package -s'
	alias info='package -I'
	alias list='package -p'
fi

srec_nix() {
	if [ -z "$1" ]; then
		echo "srec: using current system '$SYSTEM'"
	fi
	cd $BOS_CONFIG_DIR
	should_sudo nixos-rebuild switch --flake .#${1-$SYSTEM} --impure
	cd -
}
hrec_nix() {
	if [ -z "$1" ]; then
		echo "hrec: using current home '$BOS_HOME_NAME'"
	fi
	cd $BOS_CONFIG_DIR
	#! DO NOT SUDO ON HOME RECONFIGURES
	home-manager switch --flake .#${1-$BOS_HOME_NAME}-${USER} --impure
	cd -
}

if [ "$BOS_HOME_TYPE" = "nix" ]; then
	alias hrec='hrec_nix'
	alias home='home-manager'
fi

if [ "$DISTRO" = "nix" ]; then
	alias srec='srec_nix'

	alias upflake='nix flake update'
fi
