source $SHARE/zsh/plugins/zsh-antigen/antigen.zsh

echo "Loading zsh-antigen plugins..."

antigen use oh-my-zsh

antigen bundle git
antigen bundle zsh-users/zsh-syntax-highlighting

antigen theme romkatv/powerlevel10k

antigen apply
