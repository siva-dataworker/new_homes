# Running new_homes Backend Alongside the Existing One (Same VPS, Same DB)

Goal: deploy `django-backend/` from this repo on the Hostinger VPS (`187.127.164.22`)
on a **different port** than whatever is currently running, sharing the **same**
production database. Run these commands yourself via SSH — this environment
couldn't reach the VPS on any port (including 22) when tested, so this has to be
done from your side.

## 0. First, find out what's already running (don't collide with it)

```bash
ssh root@187.127.164.22   # or your actual SSH user

# See what's listening on which ports
sudo ss -tlnp
# or: sudo netstat -tlnp

# Find the existing Django process and its working directory
ps aux | grep -E "gunicorn|manage.py"
```

Note the port the existing instance uses (commonly 8000). Pick a **different**
port for the new one below — this guide uses **8001**; substitute if taken.

## 1. Clone this repo into its own directory (do not touch the existing deployment's folder)

```bash
cd ~
git clone https://github.com/siva-dataworker/new_homes.git new_homes_test
cd new_homes_test/django-backend
```

## 2. Python environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 3. Copy the DB credentials from the existing deployment's `.env`

Since you're sharing the same production database, copy `DB_HOST`, `DB_NAME`,
`DB_USER`, `DB_PASSWORD`, `DB_PORT` from the existing instance's `.env` file
into a new `.env` here (find the existing one at whatever path `ps aux` showed
above, e.g. `~/existing_project/django-backend/.env`):

```bash
# find + inspect the existing .env (don't paste its contents anywhere public)
cat ~/<existing-project-dir>/django-backend/.env
```

Create `.env` in `~/new_homes_test/django-backend/`:

```env
SECRET_KEY=<generate a new one, doesn't need to match the existing instance>
JWT_SECRET_KEY=<generate a new one, or reuse the existing instance's if you want
                 tokens issued by one instance to validate on the other>
DEBUG=False
ALLOWED_HOSTS=187.127.164.22

# Same DB as the existing instance:
DB_HOST=<copied from existing .env>
DB_NAME=<copied from existing .env>
DB_USER=<copied from existing .env>
DB_PASSWORD=<copied from existing .env>
DB_PORT=<copied from existing .env>

# CORS — add your local web dev origin(s) here, comma-separated, e.g.:
CORS_ALLOWED_ORIGINS=http://localhost:5173
```

Generate a random `SECRET_KEY`/`JWT_SECRET_KEY` quickly with:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(50))"
```

**Do not run migrations** here — the schema already exists (it's the same
database the existing instance uses). Running `manage.py migrate` should be a
no-op if nothing changed, but skip it unless you specifically need to apply a
new migration that isn't on the existing instance yet.

## 4. Run it on the new port (foreground test first)

```bash
gunicorn backend.wsgi:application --bind 0.0.0.0:8001
```

Leave this running and open a **second** SSH session to test:

```bash
curl http://localhost:8001/api/health/
curl http://localhost:8001/api/health/db/
```

Both should return `{"status": "healthy", ...}`. If `health/db/` fails, the DB
credentials in `.env` are wrong — double check against the existing instance's.

## 5. Open the firewall for the new port (needed to reach it from outside the VPS)

```bash
sudo ufw status                 # check if ufw is active
sudo ufw allow 8001/tcp
sudo ufw status                 # confirm it's now listed
```

If you're not using `ufw`, check whatever firewall/security-group mechanism
Hostinger's panel exposes (hPanel → VPS → Firewall) and allow port 8001 there too —
this is very likely also needed for the *existing* instance's ports (80/443/8000/22)
which were all unreachable from outside when tested earlier, so there may be a
network-level firewall (not just `ufw`) blocking everything by default.

## 6. Make it persistent (survives SSH disconnect / reboot)

For a quick test, `screen`/`tmux`/`nohup` is enough:
```bash
tmux new -s new_homes_test
source venv/bin/activate
gunicorn backend.wsgi:application --bind 0.0.0.0:8001
# Ctrl+B then D to detach, leaving it running
```

For anything longer-term, set it up as a `systemd` service instead (copy the
pattern from however the existing instance is run, if it's already a service —
check `systemctl list-units | grep gunicorn` to see if one exists you can copy).

## 7. Test from outside (your own machine, not the VPS)

```powershell
Invoke-WebRequest -Uri "http://187.127.164.22:8001/api/health/" -UseBasicParsing
```

If this still times out even after the `ufw allow`, the block is happening at a
level above the VPS's own firewall (Hostinger's cloud firewall / security group
in hPanel) — check there next.

## 8. Once reachable, point the Flutter web app at it

```bash
flutter run -d chrome --web-port=5173 --dart-define=BASE_URL=http://187.127.164.22:8001/api
```

(Matches the `CORS_ALLOWED_ORIGINS=http://localhost:5173` set in step 3 — keep
these in sync if you change the port.)
