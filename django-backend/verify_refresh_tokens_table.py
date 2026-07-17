#!/usr/bin/env python
"""Verify refresh_tokens table was created successfully"""

import psycopg

print("🔍 Verifying refresh_tokens table...")
print()

try:
    conn = psycopg.connect(
        host='aws-1-ap-northeast-1.pooler.supabase.com',
        port=5432,
        dbname='postgres',
        user='postgres.ctwthgjuccioxivnzifb',
        password='Appdevlopment@2026',
        sslmode='require',
        connect_timeout=10
    )
    
    with conn.cursor() as cur:
        # Check if table exists
        cur.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'refresh_tokens'
            );
        """)
        exists = cur.fetchone()[0]
        
        if not exists:
            print("❌ Table refresh_tokens does not exist!")
            conn.close()
            exit(1)
        
        print("✅ Table refresh_tokens exists!")
        print()
        
        # Get column details
        cur.execute("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns 
            WHERE table_name = 'refresh_tokens'
            ORDER BY ordinal_position;
        """)
        columns = cur.fetchall()
        
        print("📋 Table columns:")
        for col in columns:
            nullable = "NULL" if col[2] == 'YES' else "NOT NULL"
            print(f"  {col[0]:20} {col[1]:30} {nullable}")
        print()
        
        # Get indexes
        cur.execute("""
            SELECT indexname, indexdef
            FROM pg_indexes
            WHERE tablename = 'refresh_tokens'
            ORDER BY indexname;
        """)
        indexes = cur.fetchall()
        
        print("📇 Indexes:")
        for idx in indexes:
            print(f"  {idx[0]}")
        print()
        
        # Check foreign key
        cur.execute("""
            SELECT
                tc.constraint_name,
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.constraint_column_usage AS ccu
              ON ccu.constraint_name = tc.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_name = 'refresh_tokens';
        """)
        fkeys = cur.fetchall()
        
        if fkeys:
            print("🔗 Foreign keys:")
            for fk in fkeys:
                print(f"  {fk[0]} -> {fk[1]}.{fk[2]}")
            print()
        
        # Count any existing rows
        cur.execute("SELECT COUNT(*) FROM refresh_tokens;")
        count = cur.fetchone()[0]
        print(f"📊 Current rows: {count}")
        print()
        
    conn.close()
    
    print("✅ Verification complete!")
    print()
    print("🎉 refresh_tokens table is ready for JWT refresh token system!")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
