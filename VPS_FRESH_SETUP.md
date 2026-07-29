# Fresh Setup — new_homes Backend on the VPS (from a clean clone)

Run these on the VPS via SSH. Database is external (Supabase Postgres), so no
local DB install needed — just the connection credentials.

## 1. Python environment

```bash
cd ~/new_homes/django-backend   # adjust to wherever you cloned it
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 2. Create `.env`

```bash
nano .env
```

Paste in (fill in the Supabase values from your saved backup):

```env
SECRET_KEY=<generate one, see command below>
JWT_SECRET_KEY=<generate one, see command below>
DEBUG=False
ALLOWED_HOSTS=187.127.164.22,srv1651526.hstgr.cloud

# Supabase Postgres — from your saved credentials
DB_HOST=<your-project>.supabase.co
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=<your saved password>
DB_PORT=5432

# CORS — add every origin the frontend will call from.
# For local Flutter web dev, pin a port and list it here:
CORS_ALLOWED_ORIGINS=http://localhost:5173
```

Generate the two secret keys:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(50))"
python3 -c "import secrets; print(secrets.token_urlsafe(50))"
```

Save and exit (`Ctrl+O`, Enter, `Ctrl+X` in nano).

## 3. Apply migrations

Safe to run whether the Supabase DB already has the schema or not — it only
applies migrations that haven't run yet:
```bash
python manage.py migrate
```

If this is truly a brand-new/empty Supabase database (no existing data),
you'll also need to create the roles and an admin user. Check the repo root
for a script like `create_admin.py` or `add_sample_sites.py` if so — if the
Supabase DB already has your real production data, **skip this**, migrate is
enough.

## 4. Start the server bound to all interfaces

Quick test first:
```bash
python manage.py runserver 0.0.0.0:8000
```

In a second SSH session, sanity check locally:
```bash
curl http://127.0.0.1:8000/api/health/
curl http://127.0.0.1:8000/api/health/db/
```

Both should return `{"status": "healthy", ...}`. The second one confirms the
Supabase connection actually works — if it fails, double check the `DB_*`
values in `.env`.

Then confirm the bind address:
```bash
sudo ss -tlnp | grep 8000
```
Should show `0.0.0.0:8000`, not `127.0.0.1:8000`.

## 5. Make it persistent

`runserver` is dev-only and dies when you close the SSH session. For anything
beyond a quick test, use gunicorn instead, kept alive with `tmux`:

```bash
tmux new -s backend
source venv/bin/activate
gunicorn backend.wsgi:application --bind 0.0.0.0:8000 --workers 3
# Ctrl+B then D to detach, leaving it running
```

(Reattach later with `tmux attach -t backend`.)

## 6. Confirm external reachability

Once steps 1–5 are done, tell me and I'll test
`http://187.127.164.22:8000/api/health/` from here again. If it *still* times
out at that point — with the server confirmed bound to `0.0.0.0:8000` and
responding locally — that's the point where we go check Hostinger's Cloud
Firewall in hPanel, since everything on your end would be correctly
configured and the block would have to be upstream of the VPS.
