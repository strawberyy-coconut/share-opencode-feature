#!/bin/sh
set -e

SHARE_AUTH="${SHAREAUTH:-false}"

# ---------------------------------------------------------------------------
# step 1 – detect the container user and their home directory
# ---------------------------------------------------------------------------
if [ -n "$_CONTAINER_USER" ]; then
    CONTAINER_USER="$_CONTAINER_USER"
elif [ -n "$SUDO_USER" ]; then
    CONTAINER_USER="$SUDO_USER"
elif [ -n "$_REMOTE_USER" ]; then
    CONTAINER_USER="$_REMOTE_USER"
else
    CONTAINER_USER="vscode"
fi

USER_HOME=$(getent passwd "$CONTAINER_USER" 2>/dev/null | cut -d: -f6)
if [ -z "$USER_HOME" ]; then
    echo "Warning: Could not determine home dir for '$CONTAINER_USER'. Exiting."
    exit 0
fi

echo "OpenCode share: setting up for '$CONTAINER_USER' ($USER_HOME)"

# ---------------------------------------------------------------------------
# step 2 – helpers
# ---------------------------------------------------------------------------

# Check whether a bind-mount exists and holds at least one file.
mount_populated() {
    [ -d "$1" ] && [ -n "$(ls -A "$1" 2>/dev/null)" ]
}

# Symlink $1 → $2, creating parent dirs and removing any previous entry at $2.
link_mount() {
    local src="$1" dst="$2"

    if ! mount_populated "$src"; then
        echo "  skip    $src  (does not exist or is empty)"
        return
    fi

    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    ln -sf "$src" "$dst"

    echo "  link    $(basename "$src")  →  $dst"
}

# Symlink every item inside $1/ into $2/, except $3 (if given).
link_mount_items() {
    local src="$1" dst="$2" exclude="$3"

    if ! mount_populated "$src"; then
        echo "  skip    $src  (does not exist or is empty)"
        return
    fi

    rm -rf "$dst"
    mkdir -p "$dst"

    # Shell glob: visible files + hidden files, minus the exclude.
    for item in "$src"/* "$src"/.[!.]*; do
        [ -e "$item" ] || continue
        base=$(basename "$item")
        [ "$base" = "$exclude" ] && continue
        ln -sf "$item" "$dst/$base"
    done

    if [ -n "$exclude" ]; then
        echo "  link    $(basename "$src")/*  →  $dst/  (excluded $exclude)"
    else
        echo "  link    $(basename "$src")/*  →  $dst/"
    fi
}

# ---------------------------------------------------------------------------
# step 3 – wire up the four mount points
# ---------------------------------------------------------------------------

# Config  ──  ~/.config/opencode
link_mount "/opencode-host/config" "$USER_HOME/.config/opencode"

# CLI binary & plugins  ──  ~/.opencode
link_mount "/opencode-host/cli" "$USER_HOME/.opencode"

# Runtime state  ──  ~/.local/state/opencode
link_mount "/opencode-host/state" "$USER_HOME/.local/state/opencode"

# Data  ──  ~/.local/share/opencode  (with optional auth.json exclusion)
if [ "$SHARE_AUTH" = "true" ]; then
    link_mount "/opencode-host/data" "$USER_HOME/.local/share/opencode"
else
    link_mount_items "/opencode-host/data" "$USER_HOME/.local/share/opencode" "auth.json"
fi

# ---------------------------------------------------------------------------
# step 4 – ensure the symlinks (not the mount targets) belong to the user
# ---------------------------------------------------------------------------
chown -hR "$CONTAINER_USER:$CONTAINER_USER" \
    "$USER_HOME/.config/opencode" \
    "$USER_HOME/.opencode" \
    "$USER_HOME/.local" \
    2>/dev/null || true

echo "OpenCode share: done"
