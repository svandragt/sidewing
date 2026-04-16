# Example Plugins

These example plugins are intended to ship with `Sidewing` as Linux-friendly references for common status items.

Included examples:

- [action-demo.30s.sh](./action-demo.30s.sh)
- [public-ip.5m.sh](./public-ip.5m.sh)
- [available-memory.10s.sh](./available-memory.10s.sh)
- [available-disk-space.1m.sh](./available-disk-space.1m.sh)
- [github-assigned-prs.5m.sh](./github-assigned-prs.5m.sh)
- [variable-demo.1m.sh](./variable-demo.1m.sh)

Notes:

- They are written for Linux and avoid macOS-specific commands.
- The GitHub example requires the `gh` CLI and an authenticated session.
- The public IP example uses `https://api.ipify.org`; network failure is handled as a normal plugin error state.
- Variable-backed plugins get a `<plugin>.vars.json` sidecar created next to the plugin when Sidewing discovers them.

To try them manually:

```sh
chmod +x examples/plugins/*.sh
./examples/plugins/action-demo.30s.sh
./examples/plugins/public-ip.5m.sh
./examples/plugins/available-memory.10s.sh
./examples/plugins/available-disk-space.1m.sh
./examples/plugins/github-assigned-prs.5m.sh
./examples/plugins/variable-demo.1m.sh
```
