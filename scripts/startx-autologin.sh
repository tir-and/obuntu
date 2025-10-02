#!/usr/bin/env bash\nset -euo pipefail\nREPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"\n\n#!/usr/bin/env bash
if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    exec startx
fi
