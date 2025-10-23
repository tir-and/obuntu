# Obuntu defaults
export EDITOR=vim
export GTK_THEME=Celestial:dark
alias ll='ls -alF'
neofetch || true

# Load Xresources (colors/fonts for XTerm)
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
