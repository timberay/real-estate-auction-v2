# SQLite Backup Operations

## What the task does

`bin/rails db:backup` backs up all four production SQLite databases to a local directory.

### Databases backed up

- `storage/production.sqlite3` — primary application data
- `storage/production_cache.sqlite3` — Solid Cache
- `storage/production_queue.sqlite3` — Solid Queue
- `storage/production_cable.sqlite3` — Action Cable

### Where backups are written

```
/var/backups/auction/
├── daily/
│   ├── 20260511-040000/
│   │   ├── production.sqlite3
│   │   ├── production_cache.sqlite3
│   │   ├── production_queue.sqlite3
│   │   └── production_cable.sqlite3
│   └── ...
└── weekly/
    ├── 20260510-040000/   ← Sunday runs go here
    └── ...
```

Backups run on Sunday are placed under `weekly/`; all other days go under `daily/`.

### Rotation policy

| Bucket | Retention |
|--------|-----------|
| `daily/` | 14 days |
| `weekly/` | 28 days |

Subdirectories older than the retention threshold are deleted automatically at the end of each `db:backup` run.

### Integrity check

After each `.backup` call, `PRAGMA integrity_check` is run against the backup file. If the check does not return `ok`, the task raises an error. This catches silent corruption at backup time.

## No external copies

External off-host backup is intentionally **not** automated (decision made 2026-05-04). If an off-host copy is desired, the operator must copy files manually after confirming the local backup looks good.

## Cron registration on Cafe24

The cron entry must run the command **inside the container** using `kamal app exec`. Add the following entry via `crontab -e` on the **host** (as the deploy user):

```
0 4 * * * /usr/bin/kamal app exec "bin/rails db:backup" >> /var/log/auction-backup.log 2>&1
```

This runs the backup daily at 04:00 local time. The output log captures both stdout (target path) and stderr (any errors).

> **Why `kamal app exec`?** The Rails process runs inside a Docker container managed by Kamal. Running `bin/rails` directly on the host will not work — it is not in the container's environment. `kamal app exec` executes the command in the running container.

### Pre-requisite: host directory must exist before first deploy

`/var/backups/auction` is bind-mounted from the host into the container at the same path (`config/deploy.yml`). The host directory **must be created with the correct ownership BEFORE the first `kamal deploy`** after this change. If the directory does not exist, Docker will create it as root and backups will fail with a permission error.

Run these commands once on the Cafe24 host:

```sh
sudo mkdir -p /var/backups/auction
sudo chown 1000:1000 /var/backups/auction   # UID:GID matching the container's rails user (1000:1000 in the standard rails image)
sudo chmod 775 /var/backups/auction
```

To confirm the UID inside the container:

```sh
kamal app exec "id"
```

If the output shows a different UID, adjust the `chown` command accordingly.

## Manually verifying a backup

```sh
sqlite3 /var/backups/auction/daily/<timestamp>/production.sqlite3 "PRAGMA integrity_check"
# Expected output: ok
```

Replace `daily` with `weekly` and `<timestamp>` with the actual directory name (e.g., `20260511-040000`).

## Restoring from a backup

**Stop Rails before restoring** to avoid write conflicts.

```sh
# 1. Stop the application
systemctl stop rails  # or however the service is managed

# 2. Copy the backup file over the live database
cp /var/backups/auction/daily/<timestamp>/production.sqlite3 /rails/storage/production.sqlite3

# 3. Verify the restored file
sqlite3 /rails/storage/production.sqlite3 "PRAGMA integrity_check"

# 4. Restart the application
systemctl start rails
```

Repeat for `production_cache`, `production_queue`, and `production_cable` if needed.
