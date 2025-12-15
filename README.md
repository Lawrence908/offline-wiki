## Offline Wiki Archive (Kiwix)

Offline Wikipedia (and other ZIMs) for your LAN, designed to keep working when the internet is down. Runs via Docker Compose, stores data under `/mnt/storage/kiwix` by default, and fits your `~/services/*` homelab layout.

---

## Quick Start

### 1. Repo location

Place this repo under your services tree (symlinked to `/mnt/storage`):

```bash
cd ~/services
mkdir -p offline-wiki
cd offline-wiki
```

Copy the scaffolded files into this directory (or initialize git here later).

### 2. Create `.env`

Create `./.env` and adjust as needed:

```bash
cat > .env <<'EOF'
KIWIX_PORT=8282
KIWIX_DATA_DIR=/mnt/storage/kiwix
KIWIX_ZIM_DIR=/mnt/storage/kiwix/zims
KIWIX_LIBRARY=/mnt/storage/kiwix/library.xml
KIWIX_BACKUP_DIR=/mnt/storage/kiwix/backups
BACKUP_ZIMS=false
RESTIC_PASSWORD=change-me-strong-password
TZ=America/Vancouver
EOF
```

### 3. Initialize directories and network

```bash
chmod +x scripts/*.sh
./scripts/init.sh
```

This will:

- Create `${KIWIX_DATA_DIR}`, `${KIWIX_ZIM_DIR}`, `${KIWIX_BACKUP_DIR}`, and `${KIWIX_DATA_DIR}/tmp`
- Ensure the docker network `homelab-web` exists
- Create `.env` from `.env.example` if it ever exists and `.env` is missing

### 4. Download ZIMs (manual)

1. Browse ZIMs at `https://download.kiwix.org/zim/`
2. Pick the collections you want, e.g.:
   - `wikipedia_en_all_nopic_YYYY-MM.zim`
   - `wikipedia_en_all_maxi_YYYY-MM.zim`
3. Download them into your ZIM directory:

```bash
mkdir -p /mnt/storage/kiwix/zims
cd /mnt/storage/kiwix/zims

wget "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_nopic_2024-01.zim"
```

### 5. Build the library and start the stack

```bash
cd ~/services/offline-wiki
./scripts/add_zims.sh
docker compose up -d
``>

Browse from your LAN:

- `http://<host-ip>:8282/`

---

## Configuration

Environment variables (in `.env`):

- `KIWIX_PORT` – Host port for `kiwix-serve` (default `8282`)
- `KIWIX_DATA_DIR` – Base data directory (default `/mnt/storage/kiwix`)
- `KIWIX_ZIM_DIR` – ZIM directory (default `${KIWIX_DATA_DIR}/zims`)
- `KIWIX_LIBRARY` – Path to `library.xml` (default `${KIWIX_DATA_DIR}/library.xml`)
- `KIWIX_BACKUP_DIR` – Backup directory (default `${KIWIX_DATA_DIR}/backups`)
- `BACKUP_ZIMS` – Include ZIMs in backups (`true`/`false`, default `false`)
- `RESTIC_PASSWORD` – Restic repository password (required for backup/restore)
- `RESTIC_REPOSITORY` – Optional; defaults to `${KIWIX_BACKUP_DIR}/restic-repo`
- `KIWIX_ZIM_UPDATE_BASE_URL` – Optional base URL for automatic ZIM updates, e.g. `https://download.kiwix.org/zim/wikipedia`
- `KIWIX_HEALTH_TITLE` – Expected title/keyword on the library page for health checks (default `Wikipedia`)
- `TZ` – Timezone (default `America/Vancouver`)

---

## Docker Compose Services

`compose.yaml` defines:

- `kiwix-serve`
  - Image: `ghcr.io/kiwix/kiwix-serve:latest`
  - Port: `${KIWIX_PORT}:80`
  - Volume: `${KIWIX_DATA_DIR}:/data:ro`
  - Command: `--library /data/library.xml --port 80`
  - Healthcheck: `curl http://localhost:80/`
  - Network: `homelab-web` (external)

- `updater` (optional helper)
  - Image: `alpine:3.20`
  - Mounts `/data` and `./scripts` read-only
  - Idle container you can `docker compose run` into if you want to run updates from within Docker

---

## Scripts

All scripts live in `scripts/` and assume `.env` is in the repo root.

### `scripts/init.sh`

- Creates required directories:
  - `${KIWIX_DATA_DIR}`
  - `${KIWIX_ZIM_DIR}`
  - `${KIWIX_BACKUP_DIR}`
  - `${KIWIX_DATA_DIR}/tmp`
- Ensures docker network `homelab-web` exists.
- Creates `.env` from `.env.example` if `.env` is missing.

Run:

```bash
./scripts/init.sh
```

### `scripts/add_zims.sh`

Rebuilds `library.xml` from all ZIMs in `${KIWIX_ZIM_DIR}` in a deterministic, sorted order, and signals `kiwix-serve` to reload.

Implementation details:

- Uses a temporary `kiwix/kiwix-tools` container to run `kiwix-manage`
- Recreates `library.xml` from scratch
- Adds ZIMs in sorted order
- Sends `SIGHUP` to the `offline-wiki` container if it is running

Run:

```bash
./scripts/add_zims.sh
```

### `scripts/update_zims.sh`

Performs “continuous-ish” ZIM updates:

- Scans existing `${KIWIX_ZIM_DIR}/*.zim`
- For files matching `<name>_YYYY-MM.zim`, derives `name` and the current month
- Fetches directory listing from `${KIWIX_ZIM_UPDATE_BASE_URL}`
- Picks the latest available `name_YYYY-MM.zim`
- Downloads with resume support (`wget -c`) to a `.partial` file under `${KIWIX_DATA_DIR}/tmp`
- Attempts SHA256 verification if `<file>.sha256` exists
- Atomically moves the new ZIM into `${KIWIX_ZIM_DIR}` and keeps the old ZIM alongside it
- Calls `add_zims.sh` to rebuild `library.xml`

If `KIWIX_ZIM_UPDATE_BASE_URL` is not set, the script exits cleanly and does nothing.

Run manually:

```bash
./scripts/update_zims.sh
```

Or inside the updater container:

```bash
docker compose run --rm updater /opt/offline-wiki/scripts/update_zims.sh
```

### `scripts/backup.sh`

Uses restic to back up:

- `library.xml`
- `scripts/`, `.env`, and `compose.yaml` (or `docker-compose.yml` if present)
- `${KIWIX_ZIM_DIR}` (optional, controlled by `BACKUP_ZIMS`)

Features:

- Local restic repo at `${KIWIX_BACKUP_DIR}/restic-repo` by default
- Retention policy:
  - 7 daily snapshots
  - 4 weekly snapshots
  - 6 monthly snapshots
- Safe: restic handles atomic snapshots and pruning

Prerequisites:

- `restic` installed on the host
- `RESTIC_PASSWORD` set

Run:

```bash
./scripts/backup.sh
```

### `scripts/restore.sh`

Restores from restic into `${KIWIX_DATA_DIR}`:

- Restores the specified snapshot (or `latest` by default) into a temporary directory
- `rsync`s restored data back into `${KIWIX_DATA_DIR}`
- Brings the stack down and back up with `docker compose`

Usage:

```bash
./scripts/restore.sh            # restore latest snapshot
./scripts/restore.sh <snapshot> # restore a specific snapshot ID
```

### `scripts/healthcheck.sh`

Performs a basic healthcheck:

- Hits `http://localhost:${KIWIX_PORT}/`
- Greps for `KIWIX_HEALTH_TITLE` (default `Wikipedia`)

Usage:

```bash
./scripts/healthcheck.sh
```

Exit codes:

- `0` – OK
- `1` – HTTP failure or expected title missing

---

## systemd Units (Host Side)

All units assume the repo lives at `~/services/offline-wiki` (symlinked to `/mnt/storage/services/offline-wiki`). Adjust `WorkingDirectory` and `EnvironmentFile` if you place it elsewhere.

### Update Timer (`offline-wiki-update.*`)

- `systemd/offline-wiki-update.service`:
  - Runs `scripts/update_zims.sh` as a oneshot
- `systemd/offline-wiki-update.timer`:
  - Runs daily at 03:15

Install and enable:

```bash
sudo cp systemd/offline-wiki-update.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now offline-wiki-update.timer
```

### Backup Timer (`offline-wiki-backup.*`)

- `systemd/offline-wiki-backup.service`:
  - Runs `scripts/backup.sh` as a oneshot
- `systemd/offline-wiki-backup.timer`:
  - Runs daily at 03:45

Install and enable:

```bash
sudo cp systemd/offline-wiki-backup.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now offline-wiki-backup.timer
```

Check timers:

```bash
systemctl list-timers '*offline-wiki*'
```

---

## Operations

### Bring the stack up

```bash
cd ~/services/offline-wiki
docker compose up -d
```

### View logs

```bash
docker logs -f offline-wiki
```

### Add new ZIMs

1. Download ZIMs into `${KIWIX_ZIM_DIR}`:

   ```bash
   cd "${KIWIX_ZIM_DIR}"
   wget "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_nopic_2024-02.zim"
   ```

2. Rebuild library and reload:

   ```bash
   cd ~/services/offline-wiki
   ./scripts/add_zims.sh
   ```

### Run an update now

```bash
cd ~/services/offline-wiki
./scripts/update_zims.sh
```

### Backup now

```bash
cd ~/services/offline-wiki
./scripts/backup.sh
```

### Restore

```bash
cd ~/services/offline-wiki
./scripts/restore.sh          # latest
./scripts/restore.sh <id>     # specific snapshot
```

---

## Notes & Guidance

### ZIM Updates and Tradeoffs

- ZIM updates are **full file replacements**, not incremental diffs
- External bandwidth is used each time a new monthly ZIM is downloaded
- By default, old ZIMs are kept so you can roll back or compare; delete manually once satisfied

### Disk Sizing

- `*_maxi_*.zim` variants:
  - Full-fat: images + media
  - Much larger; plan for hundreds of GB if you pull multiple languages
- `*_nopic_*.zim` variants:
  - Text-only, no images
  - Much smaller; ideal for constrained storage or many languages
- Keep ZIMs on a storage pool with:
  - Adequate space
  - Snapshots/backups (if you choose to back them up)

### Security

- By default, Kiwix is exposed only on your LAN port (`${KIWIX_PORT}`)
- Recommended:
  - Bind Docker to LAN-only IP, or
  - Use firewall rules to restrict access
- Optional Caddy snippet for reverse proxy:

```caddy
# wiki.chrislawrence.ca
wiki.chrislawrence.ca:80 {
    reverse_proxy offline-wiki:80
}
```

Or under `dev.chrislawrence.ca` as a path:

```caddy
handle_path /wiki {
    reverse_proxy offline-wiki:80
}

handle_path /wiki/* {
    reverse_proxy offline-wiki:80
}
```

Integrate these into your existing Caddyfile and Cloudflare tunnel patterns as needed.

---

## Troubleshooting

### Library not updating

- Run:

  ```bash
  cd ~/services/offline-wiki
  ./scripts/add_zims.sh
  docker compose restart kiwix-serve
  ```

- Verify `library.xml` timestamp and content:

  ```bash
  ls -lh /mnt/storage/kiwix/library.xml
  ```

### Permissions on mounted volumes

- Ensure the docker engine user can read from `${KIWIX_DATA_DIR}`:

  ```bash
  sudo chown -R root:docker /mnt/storage/kiwix
  sudo chmod -R 750 /mnt/storage/kiwix
  ```

  (Adjust groups/ownership to match your homelab standards.)

### Slow or interrupted downloads

- Downloads use `wget -c` to resume:
  - You can re-run `./scripts/update_zims.sh` and it will continue downloading `.partial` files
- Consider:
  - Running updates overnight (systemd timer)
  - Using a local HTTP proxy or caching if bandwidth is constrained

### Healthcheck failures

- Run:

  ```bash
  cd ~/services/offline-wiki
  ./scripts/healthcheck.sh
  ```

- If HTTP fails:
  - Check container status: `docker ps | grep offline-wiki`
  - Inspect logs: `docker logs offline-wiki`

- If title missing:
  - Confirm ZIMs exist in `${KIWIX_ZIM_DIR}`
  - Confirm `library.xml` contains entries
  - Adjust `KIWIX_HEALTH_TITLE` to match your collection (e.g. language)

---

## Improvements & Enhancements

### Automatic Library Reloading

The `-M` flag enables automatic library monitoring - when you add new ZIMs and rebuild `library.xml`, kiwix-serve will automatically detect and reload without needing a container restart.

### Performance Tuning

The `-t 8` flag sets the number of worker threads to 8 (default is 4). Adjust based on your server's CPU cores.

### Caddy Reverse Proxy Integration

**Option 1: Subdomain** (e.g., `wiki.chrislawrence.ca`):

Add to your Caddyfile (`services/daedalus-infra/proxy/Caddyfile`):

```caddy
# Offline Wiki Archive
wiki.chrislawrence.ca:80 {
    reverse_proxy offline-wiki:80 {
        header_up Host {host}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-For {remote}
        header_up X-Real-IP {remote}
    }
    
    log {
        level INFO
        format json
        output file /data/logs/wiki.json {
            roll_size 15mb
            roll_keep 8
            roll_keep_for 168h
        }
    }
}
```

Then add Cloudflare Tunnel route and Access application (see `new-app.md` patterns).

**Option 2: Path-based** (e.g., `dev.chrislawrence.ca/wiki`):

Add to the `dev.chrislawrence.ca:80` block:

```caddy
handle_path /wiki {
    reverse_proxy offline-wiki:80 {
        header_down -X-Frame-Options
    }
}

handle_path /wiki/* {
    reverse_proxy offline-wiki:80 {
        header_down -X-Frame-Options
    }
}
```

## Integration with Homelab Metadata

Once the service is working, integrate into your homelab source of truth similar to other services:

- `services.yml`:
  - Add an `offline-wiki` entry under applications or infrastructure
- `dashy/conf.yml`:
  - Add LAN and Tailscale URLs for quick access
- Optional:
  - Add to any monitoring script you use (curl-based checks)

Follow the patterns from your `new-app.md` guide for consistent naming, categories, and monitoring.


