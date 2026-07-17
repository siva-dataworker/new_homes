#!/usr/bin/env python
"""
Create refresh_tokens table for JWT refresh token system.
Simple version that prompts for database URL or uses environment variable.
"""

import sys
import os

try:
    import psycopg
except ImportError:
    print("❌ Error: psycopg not installed")
    print("Install it with: pip install psycopg")
    sys.exit(1)

def create_refresh_tokens_table():
    """Create refresh_tokens table in the database."""
    
    print("🔧 Creating refresh_tokens table for JWT refresh token system")
    print()
    
    # Get database URL from environment or prompt
    db_url = os.environ.get('DATABASE_URL')
    
    if not db_url:
        print("DATABASE_URL not found in environment.")
        print("Please provide the database connection URL:")
        print("Format: postgresql://user:password@host:port/database")
        print()
        db_url = input("Database URL: ").strip()
        
        if not db_url:
            print("❌ No database URL provided. Exiting.")
            return False
    
    print(f"Connecting to database...")
    print()
    
    # SQL from refresh_tokens_schema.sql
    sql = """
-- Refresh Tokens Table
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_id UUID NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    device_info TEXT,
    ip_address INET
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token_id ON refresh_tokens(token_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_revoked ON refresh_tokens(revoked) WHERE revoked = TRUE;

-- Comments
COMMENT ON TABLE refresh_tokens IS 'Stores JWT refresh tokens with revocation capability';
COMMENT ON COLUMN refresh_tokens.token_id IS 'UUID from JWT payload - used to revoke specific tokens';
COMMENT ON COLUMN refresh_tokens.revoked IS 'TRUE if token has been manually revoked (logout, security)';
"""
    
    try:
        # Connect to database
        conn = psycopg.connect(db_url, sslmode='require')
        
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
        
    except psycopg.OperationalError as e:
        print(f"❌ Database connection error: {e}")
        print()
        print("Troubleshooting:")
        print("1. Check database URL is correct")
        print("2. Ensure database is accessible from this network")
        print("3. Verify SSL/TLS settings")
        print()
        return False
    except psycopg.errors.ForeignKeyViolation:
        print(f"❌ Error: users table doesn't exist")
        print()
        print("The refresh_tokens table references the users table.")
        print("Please ensure the main database schema is created first.")
        print()
        return False
    except Exception as e:
        print(f"❌ Error creating table: {e}")
        print()
        return False

if __name__ == '__main__':
    print("=" * 70)
    print("JWT Refresh Tokens Table Migration")
    print("=" * 70)
    print()
    
    success = create_refresh_tokens_table()
    sys.exit(0 if success else 1)
