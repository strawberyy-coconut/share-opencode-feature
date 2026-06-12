# Share OpenCode (devcontainer feature)

Mounts host OpenCode directories into a devcontainer so that configuration,
plugins, the CLI binary, and runtime state are shared between host and container.

## What gets shared

| Host path | Container path | Content |
|---|---|---|
| `~/.config/opencode` | `/opencode-host/config` | User config (`opencode.jsonc`), plugins, `node_modules` |
| `~/.opencode` | `/opencode-host/cli` | CLI binary, plugins, package dependencies |
| `~/.local/share/opencode` | `/opencode-host/data` | Database, snapshots, logs, tool output cache |
| `~/.local/state/opencode` | `/opencode-host/state` | App state (theme, model prefs, prompt history) |

Symlinks are created from the container user's home directory to the mount
points so opencode finds them at the expected paths.

## Usage

```jsonc
// .devcontainer/devcontainer.json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/strawberyy-coconut/share-opencode-feature/share-opencode:1": {
            "shareAuth": false
        }
    }
}
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `shareAuth` | boolean | `false` | When `true`, the host's `auth.json` (API keys) is shared with the container. When `false`, all other data files are shared but `auth.json` is excluded. |

## Missing directories

If a host directory (e.g. `~/.config/opencode`) does not exist, Docker creates an
empty directory on the host for the bind mount. The install script detects this
and skips the symlink for that directory, so opencode will use its defaults.

## Security

By default (`shareAuth: false`), `auth.json` containing API keys is **not**
shared. Each container can configure its own API keys. Set `shareAuth: true` if
you trust the container environment and want to reuse the host's keys.
