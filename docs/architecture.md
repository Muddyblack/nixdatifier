# How it works

The QML engine runs small helper scripts from `package/contents/tools/sh/` and parses their output. Each host supplies its own process runner. Expensive reads go through `run cached`, a result cache shared by every widget instance. System changes go through `run mutate`, a lock that prevents two operations from running at once.

```mermaid
flowchart TD
    subgraph Hosts
        P["main.qml (Plasma)<br/>PlasmaProcess.qml"]
        Q["NixdatifierShell.qml (Hyprland)<br/>ProcessAdapter.qml"]
        W["Main.qml (standalone)<br/>ProcessRunner (C++ QProcess)"]
    end

    subgraph Core ["Shared QML"]
        E[Engine.qml]
        A[ApplicationView.qml]
        F["FullView.qml + tabs"]
    end

    subgraph Scripts ["tools/sh"]
        R["run (cache + lock)"]
        G["generations, details, change-counts"]
        FL["flake-context, flake-probe, dry-run-preview"]
        T["hash, secrets, store-usage, devenv, diskusage, history"]
        TE["terminal, terminal-job"]
    end

    subgraph System
        N["nix / nix-store / nix-env"]
        K["pkexec (polkit)"]
        S["/run/secrets, flake repo"]
    end

    P --> E
    Q --> E
    W --> E
    E --> A --> F
    E --> R
    R --> G & FL & T
    E --> TE
    G & FL & T --> N
    E -->|generation actions, cleanup| K
    T --> S
```

## Idle cost

The widget does as little as possible while you are not looking at it:

- **Settings do not poll while idle.** Info wakes only for a pending request timeout, retry, or refresh cooldown. Once loaded, its timer stops. Closing settings destroys the Info pane, aborts its requests, and releases their callbacks.
- **Tray animation reuses artwork.** The Quickshell tray helper rasterizes the SVG once and caches at most 60 smoothly rotated frames. It releases the animation frames when idle and ignores duplicate status updates.
- **Package previews have a deadline.** A stalled download, evaluation, or cache-lock wait ends after three minutes with a retryable error instead of leaving the loading indicator running indefinitely.
- **No expensive background timers.** Measuring the store (`du -sb /nix/store`, plus `nix-store --gc --print-dead` for the reclaimable size) walks the whole store, so it runs only while the popup is open, at most every 30 minutes, never twice at once, and at `nice -n 19` / idle I/O priority.
- **Animations stop when the popup closes.** Every looping animation is tied to whether the popup is on screen, so a closed popup does not keep the render loop awake.
- **The flake cache watch cannot spin.** Cross-instance sync waits on `inotifywait`. If that is missing or unusable, the widget falls back to a slow poll instead of respawning the watch in a tight loop.
- **Package lookups are bounded.** Homepage lookups are batched into one evaluation. The `/nix/store` fallback scan is a single pass and is skipped for large diffs.

While closed, a configured widget runs one `flake-probe` per check interval (hourly by default, shared between instances) and one cheap `sysinfo` read every 30 minutes.
