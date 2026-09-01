#!/usr/bin/env bash
# Print a Python that can run MCUBoot imgtool.
# The TF-M SPE .venv is not used: it is often half-upgraded
# (cryptography 50.0.0 vs 50.0.1) and then default_backend() crashes.

set -u
NS_APP="$(cd "$(dirname "$0")" && pwd)"
VENV="${NS_APP}/.sign-venv"

check() {
    local py="$1"
    [ -x "$py" ] || command -v "$py" >/dev/null 2>&1 || return 1
    "$py" - <<'PY' 2>/dev/null
import intelhex, click, cbor2
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.backends import default_backend
default_backend()
PY
}

candidates=()
if [ -n "${PYTHON:-}" ]; then
    candidates+=("$PYTHON")
fi
candidates+=("${VENV}/bin/python" python3 python)

for p in "${candidates[@]}"; do
    if check "$p"; then
        if command -v "$p" >/dev/null 2>&1 && [ ! -x "$p" ]; then
            command -v "$p"
        else
            echo "$p"
        fi
        exit 0
    fi
done

echo "imgtool: creating ${VENV} (not using a broken TF-M .venv)" >&2
python3 -m venv "$VENV"
"$VENV/bin/python" -m pip install -q intelhex click cryptography cbor2 pyyaml
echo "$VENV/bin/python"
