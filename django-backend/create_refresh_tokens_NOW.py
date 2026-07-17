#!/usr/bin/env python
"""
Create refresh_tokens table - Direct connection version
Uses connection details from test_connection.py
"""

import psycopg

print("=" * 70)
print("JWT Refresh Tokens Table Migration")
print("=" * 70)
print()
print("🔧 Creating refresh_tokens table...")
print()

# SQL to create table
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
    print("Connecting to Supabase database...")
    conn = psycopg.connect(
        host='aws-1-ap-northeast-1.pooler.supabase.com',
        port=5432,
        dbname='postgres',
        user='postgres.ctwthgjuccioxivnzifb',
        password='Appdevlopment@2026',
        sslmode='require',
        connect_timeout=10
    )
    print("✅ Connected!")
    print()
    
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
    
    # Verify table exists
    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'refresh_tokens'
            ORDER BY ordinal_position;
        """)
        columns = cur.fetchall()
        
        print("✅ Verified table columns:")
        for col in columns:
            print(f"  - {col[0]:20} {col[1]}")
    
    conn.close()
    
    print()
    print("🎉 Database migration complete!")
    print()
    print("=" * 70)
    print("Next steps:")
    print("=" * 70)
    print("1. ✅ Table created - Done!")
    print("2. Deploy backend changes to Render")
    print("3. Test login endpoint returns refresh_token")
    print("4. Test /api/auth/refresh/ endpoint")
    print()
    
except psycopg.OperationalError as e:
    print(f"❌ Database connection error: {e}")
    print()
    print("Troubleshooting:")
    print("1. Check network connection")
    print("2. Verify Supabase is accessible")
    print()
except Exception as e:
    print(f"❌ Error: {e}")
    print()
    import traceback
    traceback.print_exc()
    print()
