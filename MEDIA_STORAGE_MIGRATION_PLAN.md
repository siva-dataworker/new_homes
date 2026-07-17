# Media Storage Migration Plan
**Priority: 🚨 CRITICAL — Data Loss Issue**  
**Issue:** ISSUE-41 from CODE_AUDIT_REPORT.md  
**Impact:** All uploaded files deleted on every Render deployment

---

## Current Situation

**Problem:**
```python
# settings.py
MEDIA_ROOT = BASE_DIR / 'media'
```

- Render uses **ephemeral filesystem**
- Every deployment wipes the filesystem
- All uploaded files are permanently lost:
  - Site photos
  - Bills and invoices
  - Vendor agreements
  - Site plans
  - Architectural drawings
  - Engineer documents

**Database Impact:**
- Database still stores file URLs like `/media/photos/abc.jpg`
- Files are gone but references remain
- Results in 404 errors for all media

---

## Solution: Migrate to Supabase Storage

### Why Supabase Storage?
- ✅ Already using Supabase for database
- ✅ No additional service needed
- ✅ Built-in authentication and access control
- ✅ Free tier: 1GB storage
- ✅ Signed URLs for secure access
- ✅ Integration libraries available

### Architecture Change

**Before:**
```
Flutter App → Django Backend → Local filesystem (/media/)
                                    ↓
                            Lost on deployment
```

**After:**
```
Flutter App → Django Backend → Supabase Storage (persistent)
                                    ↓
                            Signed URLs returned
```

---

## Implementation Steps

### Step 1: Install Supabase Python Client

```bash
cd django-backend
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install supabase
pip freeze > requirements.txt
```

### Step 2: Add Supabase Storage Config to .env

```env
# .env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key-here
SUPABASE_STORAGE_BUCKET=construction-media
```

### Step 3: Update settings.py

```python
# settings.py

# Supabase Storage Configuration
SUPABASE_URL = config('SUPABASE_URL')
SUPABASE_SERVICE_KEY = config('SUPABASE_SERVICE_KEY')
SUPABASE_STORAGE_BUCKET = config('SUPABASE_STORAGE_BUCKET', default='construction-media')

# Keep MEDIA_ROOT for backwards compatibility during migration
MEDIA_ROOT = BASE_DIR / 'media'
MEDIA_URL = '/media/'
```

### Step 4: Create Storage Service Helper

Create `django-backend/api/storage_service.py`:

```python
import os
import uuid
import mimetypes
from django.conf import settings
from supabase import create_client, Client
import logging

logger = logging.getLogger(__name__)

class SupabaseStorageService:
    def __init__(self):
        self.client: Client = create_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_SERVICE_KEY
        )
        self.bucket = settings.SUPABASE_STORAGE_BUCKET
    
    def upload_file(self, file, folder='uploads'):
        """
        Upload a file to Supabase Storage.
        
        Args:
            file: Django UploadedFile object
            folder: Folder path within bucket (e.g., 'photos', 'bills', 'documents')
        
        Returns:
            dict: {'success': bool, 'url': str, 'path': str, 'error': str}
        """
        try:
            # Generate unique filename
            ext = os.path.splitext(file.name)[1]
            unique_name = f"{uuid.uuid4()}{ext}"
            file_path = f"{folder}/{unique_name}"
            
            # Read file content
            file_content = file.read()
            
            # Get mimetype
            content_type = mimetypes.guess_type(file.name)[0] or 'application/octet-stream'
            
            # Upload to Supabase
            response = self.client.storage.from_(self.bucket).upload(
                path=file_path,
                file=file_content,
                file_options={"content-type": content_type}
            )
            
            # Get public URL
            public_url = self.client.storage.from_(self.bucket).get_public_url(file_path)
            
            return {
                'success': True,
                'url': public_url,
                'path': file_path,
                'error': None
            }
            
        except Exception as e:
            logger.error(f"Supabase upload failed: {str(e)}")
            return {
                'success': False,
                'url': None,
                'path': None,
                'error': str(e)
            }
    
    def get_signed_url(self, file_path, expires_in=3600):
        """
        Generate a signed URL for private file access.
        
        Args:
            file_path: Path within bucket
            expires_in: Expiry time in seconds (default 1 hour)
        
        Returns:
            str: Signed URL or None if error
        """
        try:
            signed_url = self.client.storage.from_(self.bucket).create_signed_url(
                file_path,
                expires_in
            )
            return signed_url['signedURL']
        except Exception as e:
            logger.error(f"Failed to create signed URL: {str(e)}")
            return None
    
    def delete_file(self, file_path):
        """Delete a file from Supabase Storage."""
        try:
            self.client.storage.from_(self.bucket).remove([file_path])
            return True
        except Exception as e:
            logger.error(f"Failed to delete file: {str(e)}")
            return False

# Singleton instance
storage_service = SupabaseStorageService()
```

### Step 5: Update File Upload Views

Example for photo upload in `views_construction.py`:

```python
from .storage_service import storage_service

@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def upload_site_images(request):
    try:
        site_id = request.data.get('site_id')
        uploaded_by = request.user.get('user_id')
        
        images = request.FILES.getlist('images')
        if not images:
            return Response({'error': 'No images provided'}, status=400)
        
        results = []
        for image in images:
            # Upload to Supabase Storage
            upload_result = storage_service.upload_file(image, folder=f'photos/{site_id}')
            
            if not upload_result['success']:
                logger.error(f"Failed to upload {image.name}: {upload_result['error']}")
                continue
            
            # Save metadata to database with Supabase URL
            photo_id = str(uuid.uuid4())
            execute_query("""
                INSERT INTO site_photos (id, site_id, image_url, uploaded_by, storage_path)
                VALUES (%s, %s, %s, %s, %s)
            """, (photo_id, site_id, upload_result['url'], uploaded_by, upload_result['path']))
            
            results.append({
                'id': photo_id,
                'url': upload_result['url'],
                'name': image.name
            })
        
        return Response({'photos': results}, status=201)
        
    except Exception as e:
        logger.error(f"Upload failed: {str(e)}")
        return Response({'error': str(e)}, status=500)
```

### Step 6: Create Supabase Storage Bucket

Via Supabase Dashboard:
1. Go to Storage in Supabase dashboard
2. Create new bucket: `construction-media`
3. Set public/private access (recommend private with signed URLs)
4. Configure RLS policies if needed

### Step 7: Update Database Schema

Add `storage_path` column to track files:

```sql
-- For site_photos table
ALTER TABLE site_photos ADD COLUMN storage_path TEXT;

-- For bills table
ALTER TABLE bills ADD COLUMN storage_path TEXT;

-- For documents tables
ALTER TABLE architect_documents ADD COLUMN storage_path TEXT;
ALTER TABLE engineer_documents ADD COLUMN storage_path TEXT;
ALTER TABLE site_documents ADD COLUMN storage_path TEXT;
```

### Step 8: Migration Script for Existing Files

Create `migrate_existing_media.py` to upload existing local files:

```python
import os
from pathlib import Path
from django.conf import settings
from api.storage_service import storage_service
from api.database import execute_query, fetch_all

def migrate_photos():
    """Migrate existing local photos to Supabase."""
    photos = fetch_all("SELECT id, image_url FROM site_photos WHERE storage_path IS NULL")
    
    for photo in photos:
        local_path = settings.BASE_DIR / photo['image_url'].lstrip('/')
        if not local_path.exists():
            continue
        
        with open(local_path, 'rb') as f:
            result = storage_service.upload_file(f, folder='photos')
            
            if result['success']:
                execute_query("""
                    UPDATE site_photos 
                    SET image_url = %s, storage_path = %s 
                    WHERE id = %s
                """, (result['url'], result['path'], photo['id']))
                print(f"✅ Migrated photo {photo['id']}")

if __name__ == '__main__':
    migrate_photos()
```

---

## Testing Checklist

After implementation:

- [ ] Upload a site photo → verify it appears in Supabase Storage dashboard
- [ ] Delete photo → verify it's removed from Supabase
- [ ] Deploy to Render → verify photos persist across deployments
- [ ] Test all file upload endpoints (photos, bills, documents)
- [ ] Check file URLs return 200 (not 404)
- [ ] Test signed URLs for private access

---

## Rollback Plan

If issues occur:
1. Keep old MEDIA_ROOT code path active
2. Add feature flag: `USE_SUPABASE_STORAGE = config('USE_SUPABASE_STORAGE', default=False, cast=bool)`
3. Toggle between local and Supabase storage

---

## Estimated Time

- Setup and configuration: 30 minutes
- Update all upload endpoints: 2 hours
- Testing: 1 hour
- Migration of existing files: 1 hour (if any)

**Total: ~4 hours**

---

## Additional Benefits

Once migrated:
✅ No more data loss on deployments  
✅ Centralized storage management  
✅ Better scalability (no disk space limits)  
✅ Automatic backups (Supabase handles this)  
✅ CDN delivery for faster loading  
✅ Access control via signed URLs

---

*Priority: URGENT — Implement before next production deployment*
