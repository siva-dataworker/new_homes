"""Test database connection for MCP setup"""
import os
import sys
from pathlib import Path

# Add Django project to path
django_dir = Path(__file__).parent
sys.path.insert(0, str(django_dir))

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
import django
django.setup()

from api.database import fetch_all, fetch_one

def test_database_connection():
    """Test if database connection works and list tables"""
    print("🔄 Testing database connection...")
    print()
    
    # Test 1: List all tables
    print("=" * 60)
    print("TEST 1: List all tables in database")
    print("=" * 60)
    
    query = """
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name
    """
    
    tables = fetch_all(query)
    
    if tables:
        print(f"✅ Found {len(tables)} tables:")
        print()
        for i, table in enumerate(tables, 1):
            print(f"  {i:2d}. {table['table_name']}")
        print()
    else:
        print("❌ No tables found or connection failed")
        return False
    
    # Test 2: Count users
    print("=" * 60)
    print("TEST 2: Count users in database")
    print("=" * 60)
    
    query = "SELECT COUNT(*) as user_count FROM users"
    result = fetch_one(query)
    
    if result:
        print(f"✅ Total users: {result['user_count']}")
        print()
    else:
        print("❌ Failed to count users")
        return False
    
    # Test 3: Count sites
    print("=" * 60)
    print("TEST 3: Count sites in database")
    print("=" * 60)
    
    query = "SELECT COUNT(*) as site_count FROM sites"
    result = fetch_one(query)
    
    if result:
        print(f"✅ Total sites: {result['site_count']}")
        print()
    else:
        print("❌ Failed to count sites")
        return False
    
    # Test 4: Get database info
    print("=" * 60)
    print("TEST 4: Database information")
    print("=" * 60)
    
    query = "SELECT version()"
    result = fetch_one(query)
    
    if result:
        print(f"✅ PostgreSQL Version:")
        print(f"   {result['version']}")
        print()
    else:
        print("❌ Failed to get database info")
        return False
    
    print("=" * 60)
    print("✅ ALL TESTS PASSED - Database connection working!")
    print("=" * 60)
    print()
    print("📊 Summary:")
    print(f"   • Tables: {len(tables)}")
    print(f"   • Users: {result['user_count']}")
    print(f"   • Sites: {result['site_count']}")
    print()
    print("🎉 MCP database connection should work once Kiro is restarted!")
    
    return True

if __name__ == '__main__':
    try:
        test_database_connection()
    except Exception as e:
        print(f"❌ Error testing connection: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
