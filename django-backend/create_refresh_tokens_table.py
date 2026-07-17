#!/usr/bin/env python
"""
Create refresh_tokens table for JWT refresh token system.
This script reads database credentials from .env file and creates the table.
"""

import os
import sys
from pathlib import Path

# Add parent directory to path to import Django settings
sys.path.insert(0, str(Path(__file__).parent))

# Set Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

import django
django.setup()

from django.conf import settings
import psycopg

def create_refresh_tokens_table():
    """Create refresh_tokens table in the database."""
    
    print("🔧 Creating refresh_tokens table...")
    print(f"Database: {settings.DATABASES['default']['NAME']}")
    print(f"Host: {settings.DATABASES['default']['HOST']}")
    print()
    
    # SQL from refresh_tokens_schema.sql
    sql = """
-- Refresh Tokens Table
-- Stores refresh tokens for JWT authentication with revocation capability
-- Part of ISSUE-37 fix: JWT refresh token implementation

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_id UUID NOT NULL UNIQUE,  -- Matches token_id in JWT payload
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    device_info TEXT,  -- Optional: track which device/browser
    ip_address INET   -- Optional: track IP for security
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token_id ON refresh_tokens(token_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Cleanup old/expired tokens periodically
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_revoked ON refresh_tokens(revoked) WHERE revoked = TRUE;

COMMENT ON TABLE refresh_tokens IS 'Stores JWT refresh tokens with revocation capability';
COMMENT ON COLUMN refresh_tokens.token_id IS 'UUID from JWT payload - used to revoke specific tokens';
COMMENT ON COLUMN refresh_tokens.revoked IS 'TRUE if token has been manually revoked (logout, security)';
"""
    
    try:
        # Connect to database using Django settings
        conn = psycopg.connect(
            host=settings.DATABASES['default']['HOST'],
            port=settings.DATABASES['default']['PORT'],
            dbname=settings.DATABASES['default']['NAME'],
            user=settings.DATABASES['default']['USER'],
            password=settings.DATABASES['default']['PASSWORD'],
            sslmode='require'
        )
        
        with conn:
            with conn.cursor() as cur:
                # Execute the SQL
                cur.execute(sql)
                
        print("✅ Successfully created refresh_tokens table!")
        print()
        print("📊 Table structure:")
        print("  - id (UUID, primary key)")
        print("  - user_id (UUID, foreign key to users)")
        print("  - token_id (UUID, unique)")
        print("  - created_at (timestamp)")
        print("  - expires_at (timestamp)")
        print("  - revoked (boolean)")
        print("  - revoked_at (timestamp)")
        print("  - device_info (text)")
        print("  - ip_address (inet)")
        print()
        print("✅ Indexes created:")
        print("  - idx_refresh_tokens_user_id")
        print("  - idx_refresh_tokens_token_id")
        print("  - idx_refresh_tokens_expires_at")
        print("  - idx_refresh_tokens_revoked")
        print()
        print("🎉 Database migration complete!")
        print()
        print("Next steps:")
        print("1. Deploy backend changes to Render")
        print("2. Test login endpoint returns refresh_token")
        print("3. Test /api/auth/refresh/ endpoint")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Error creating table: {e}")
        print()
        print("Troubleshooting:")
        print("1. Check database credentials in .env file")
        print("2. Ensure database is accessible")
        print("3. Verify users table exists (refresh_tokens references it)")
        print()
        return False

if __name__ == '__main__':
    success = create_refresh_tokens_table()
    sys.exit(0 if success else 1)
