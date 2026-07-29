# Making the Backend Run 24/7 (systemd + gunicorn)

`manage.py runserver` is a dev server — it dies when you close the SSH
session, doesn't restart on crash, and doesn't come back after a reboot.
`gunicorn` run as a `systemd` service fixes all three. Run these on the VPS.

## 1. Stop whatever's currently running

If `runserver` is still running in a foreground session or `tmux`, stop it
first (Ctrl+C, or attach to the tmux session and kill it) so it doesn't fight
over port 8000 with the new service.

## 2. Confirm gunicorn is installed

It should already be in `requirements.txt`, but confirm:
```bash
cd ~/projects/new_homes/django-backend
source venv/bin/activate
pip show gunicorn
```
If missing: `pip install gunicorn`.

## 3. Create the systemd service file

```bash
sudo nano /etc/systemd/system/essentialhomes.service
```

Paste this in (adjust the path if your clone isn't at `~/projects/new_homes`):

```ini
[Unit]
Description=Essential Homes Django Backend (gunicorn)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/projects/new_homes/django-backend
ExecStart=/root/projects/new_homes/django-backend/venv/bin/gunicorn backend.wsgi:application --bind 0.0.0.0:8000 --workers 3 --timeout 120
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Save (`Ctrl+O`, Enter) and exit (`Ctrl+X`).

**Note on `User=root`**: matches how you've been running everything so far,
so nothing else changes. Running a web-facing process as root isn't best
practice long-term (worth creating a dedicated non-root user later), but
switching that now is a separate hardening step, not required to get 24/7
uptime working.

## 4. Enable and start it

```bash
sudo systemctl daemon-reload
sudo systemctl enable essentialhomes    # starts automatically on every boot
sudo systemctl start essentialhomes
```

## 5. Verify it's actually running

```bash
sudo systemctl status essentialhomes
```
Should show `active (running)`. Then the same health checks as before:
```bash
curl http://127.0.0.1:8000/api/health/
curl http://127.0.0.1:8000/api/health/db/
```

## 6. Test that it survives things

```bash
# Test it survives you disconnecting: close your SSH session entirely,
# reconnect later, and re-run the curl checks above — should still respond.

# Test it survives a crash:
sudo systemctl status essentialhomes   # note the PID
sudo kill -9 <PID>
sleep 3
sudo systemctl status essentialhomes   # should show a NEW PID, active again
```

## 7. Useful commands going forward

```bash
sudo systemctl restart essentialhomes   # after a git pull / code change
sudo systemctl stop essentialhomes      # to stop it
sudo journalctl -u essentialhomes -f    # live logs (replaces watching the runserver terminal)
sudo journalctl -u essentialhomes -n 100 --no-pager   # last 100 log lines
```

**After every `git pull` on the VPS from now on, run `sudo systemctl restart
essentialhomes`** instead of manually restarting `runserver` — gunicorn
doesn't auto-reload on code changes the way the dev server's `--reload` does.
