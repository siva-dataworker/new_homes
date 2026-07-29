# Switching Photo/Document Storage to Supabase S3 Storage

**Why**: uploads currently land on the VPS's local disk (`django-backend/media/`).
That's not backed up, doesn't survive a VPS rebuild, and doesn't scale well.
Supabase Storage (S3-compatible) fixes all three.

**Good news**: the code side is already done (commit `b1f8c66`, from an earlier
session) — `django-storages` + `boto3` are wired up in `settings.py` and every
upload endpoint already calls `default_storage.url(path)` instead of
hardcoding local paths, so switching is purely a **configuration** change, not
a code change. Nothing below requires touching Python code.

---

## 1. Create a Storage bucket in Supabase

1. Go to your Supabase project dashboard → **Storage** (left sidebar)
2. Click **New bucket**
3. Name it `site-media` (matches the default the code already expects —
   use a different name only if you also set `AWS_STORAGE_BUCKET_NAME`
   to match)
4. Set it **Public** — the app displays photos via plain `<img>`/`CachedNetworkImage`
   URLs with no auth token attached, so the bucket needs to allow public reads.
   (Public bucket ≠ public *write* — uploads still only happen server-side,
   authenticated via the S3 access keys below, which stay secret in `.env`.)

## 2. Get S3-compatible credentials

1. In the Supabase dashboard: **Project Settings** → **Storage**
2. Find the **S3 Connection** section
3. Note the **Endpoint URL** shown there — looks like:
   `https://<project-ref>.supabase.co/storage/v1/s3`
4. Under **Access Keys** (same page), click **New access key** (sometimes
   labeled "Generate S3 access keys") — this gives you an
   **Access Key ID** and **Secret Access Key**. Save both immediately;
   the secret is only shown once.

## 3. Add the credentials to the VPS `.env`

SSH in, then:
```bash
cd ~/projects/new_homes/django-backend
nano .env
```

Add these four lines (using your actual values from step 2):
```env
AWS_ACCESS_KEY_ID=<access key id from step 2>
AWS_SECRET_ACCESS_KEY=<secret access key from step 2>
AWS_S3_ENDPOINT_URL=https://<project-ref>.supabase.co/storage/v1/s3
AWS_STORAGE_BUCKET_NAME=site-media
```

This is additive — don't remove anything already in `.env` (DB credentials,
`SECRET_KEY`, `CORS_ALLOWED_ORIGINS`, `SERVE_MEDIA`, etc. all stay as-is).

**How this takes effect**: `settings.py` checks
`USE_SUPABASE_STORAGE = bool(AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and AWS_S3_ENDPOINT_URL)`
— once all three are non-empty, it flips from local-disk storage to
`storages.backends.s3boto3.S3Boto3Storage` automatically. No other setting
to toggle.

## 4. Confirm the package is actually installed

It should be already (from the last `pip install -r requirements.txt` you
ran), but double check:
```bash
source venv/bin/activate
pip show django-storages boto3
```
If either is missing: `pip install -r requirements.txt` again.

## 5. Restart

```bash
sudo systemctl restart essentialhomes
sudo systemctl status essentialhomes
curl http://127.0.0.1:8000/api/health/
```

## 6. Test it

1. In the app, upload a new photo (any role/screen with photo upload).
2. In the Supabase dashboard → Storage → `site-media` bucket, confirm the
   file actually landed there.
3. Check the photo displays correctly in the app (confirms the returned
   `image_url` — now a Supabase URL, not `/media/...` — is publicly
   fetchable).

## Important: existing photos don't move automatically

Everything currently in `django-backend/media/` on the VPS **stays there** —
switching `USE_SUPABASE_STORAGE` on only affects *new* uploads going forward.
Old photo records in the database still point to `/media/...` paths served
locally (which still works fine, that's what `SERVE_MEDIA=True` is for).

If you want existing photos migrated into Supabase too (optional, separate
task): that needs a one-off script that reads each local file, re-uploads it
to the Supabase bucket via the same `boto3`/`storages` client, and updates
the corresponding `image_url`/`file_url` column in the database to the new
Supabase URL. Not needed to make new uploads work — only relevant if you
want old photos to also benefit from off-VPS backup/CDN delivery. Ask if you
want this built out later.

## Rolling back

If something goes wrong, just remove (or comment out) the four `AWS_*` lines
from `.env` and restart the service — `USE_SUPABASE_STORAGE` goes back to
`False` and it falls back to local disk exactly as it works right now.
