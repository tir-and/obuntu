# ==== Obuntu User Profile ====

# Preferred editor
export EDITOR=vim

# Default GTK theme (Celestial)
export GTK_THEME=Celestial:dark

# PATH adjustments (add ~/.local/bin)
export PATH="$HOME/.local/bin:$PATH"

# ---- Load Xresources (fonts, colors, XTerm theme) ----
if [ -f "$HOME/.Xresources" ]; then
  xrdb -merge "$HOME/.Xresources"
fi

# ---- PipeWire environment (fallback in case not set globally) ----
export PIPEWIRE_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pipewire"
export PULSE_SERVER="unix:${PIPEWIRE_RUNTIME_DIR}/pipewire-0"

# ---- Visual preferences ----
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'

# ---- System Info (optional) ----
if command -v neofetch >/dev/null 2>&1; then
  neofetch
fi
