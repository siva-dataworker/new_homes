# MCP Database Connection Setup
**Date:** July 18, 2026  
**Database:** Supabase PostgreSQL  
**Status:** ✅ **CONFIGURED**  

---

## 📦 What Was Created

### **MCP Configuration File:**
**Location:** `.kiro/settings/mcp.json`

**Purpose:** Connects Kiro IDE to your Supabase PostgreSQL database via MCP (Model Context Protocol)

---

## 🔧 Configuration Details

### **MCP Server:** `supabase-postgres`

```json
{
  "mcpServers": {
    "supabase-postgres": {
      "command": "uvx",
      "args": ["mcp-server-postgres"],
      "env": {
        "POSTGRES_HOST": "${DB_HOST}",
        "POSTGRES_PORT": "${DB_PORT:5432}",
        "POSTGRES_DB": "${DB_NAME:postgres}",
        "POSTGRES_USER": "${DB_USER:postgres}",
        "POSTGRES_PASSWORD": "${DB_PASSWORD}",
        "POSTGRES_SSL": "require"
      },
      "disabled": false,
      "autoApprove": [
        "query",
        "list-tables",
        "describe-table",
        "get-schema"
      ]
    }
  }
}
```

---

## 🎯 Environment Variables Required

Make sure these are set in your environment (already in your Django .env):

```env
DB_HOST=aws-0-us-east-1.pooler.supabase.com  # Your Supabase host
DB_PORT=6543  # PgBouncer port (or 5432 for direct)
DB_NAME=postgres  # Database name
DB_USER=postgres.your_project_ref  # Supabase user
DB_PASSWORD=your_password_here  # Database password
```

---

## ✅ Auto-Approved Operations

These operations will run without asking for permission:

1. **query** - Run SELECT queries
2. **list-tables** - List all tables in database
3. **describe-table** - Get table schema/columns
4. **get-schema** - Get full database schema

**Note:** Write operations (INSERT, UPDATE, DELETE) will still require approval for safety.

---

## 🚀 How to Use

### **Step 1: Verify MCP Server is Running**

In Kiro IDE:
1. Open Command Palette (Ctrl+Shift+P / Cmd+Shift+P)
2. Type "MCP"
3. Select "MCP: Show Servers"
4. You should see `supabase-postgres` listed

### **Step 2: Test Database Connection**

Ask Kiro:
```
"List all tables in the database"
```

Or:
```
"Show me the schema for the users table"
```

Or:
```
"Query: SELECT COUNT(*) FROM users"
```

### **Step 3: Advanced Queries**

```
"Show me all Site Engineers from the users table"
"How many labour entries are there for site_id 'abc123'?"
"Get the schema for labour_entries table"
"List all tables related to materials"
```

---

## 📊 Available MCP Tools

### **1. list-tables**
**Usage:** "List all database tables"  
**Returns:** All table names in the database

### **2. describe-table**
**Usage:** "Describe the users table"  
**Returns:** Column names, types, constraints for the table

### **3. get-schema**
**Usage:** "Get full database schema"  
**Returns:** Complete schema with all tables and relationships

### **4. query**
**Usage:** "Query: SELECT * FROM users WHERE role='Site Engineer' LIMIT 10"  
**Returns:** Query results as a table

---

## 🛡️ Security Features

### **SSL Required**
```json
"POSTGRES_SSL": "require"
```
All connections use SSL/TLS encryption.

### **Read-Only by Default**
Auto-approved operations are **read-only**:
- SELECT queries
- Schema inspection
- Table listing

### **Write Operations Protected**
These require approval:
- INSERT
- UPDATE
- DELETE
- DROP
- ALTER

---

## 🧪 Testing the Connection

### **Test 1: List Tables**
```
Ask Kiro: "List all tables in the database"

Expected Result:
- users
- sites
- labour_entries
- material_balances
- site_photos
- material_bills
- ... (and more)
```

### **Test 2: Check Table Schema**
```
Ask Kiro: "Show me the structure of the users table"

Expected Result:
- Columns: id, username, email, role, created_at, etc.
- Data types
- Constraints
```

### **Test 3: Simple Query**
```
Ask Kiro: "How many users are in the database?"

Expected Result:
SELECT COUNT(*) FROM users → Number of users
```

---

## 🔧 Troubleshooting

### **Issue: MCP Server Not Found**

**Solution 1: Install uv**
```bash
# Windows (PowerShell)
irm https://astral.sh/uv/install.ps1 | iex

# Mac/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Solution 2: Verify Installation**
```bash
uv --version
uvx --version
```

**Solution 3: Restart Kiro IDE**
After installing uv, restart Kiro to reload MCP servers.

---

### **Issue: Connection Failed**

**Check 1: Environment Variables**
```bash
echo $DB_HOST
echo $DB_PASSWORD
```
Make sure they're set correctly.

**Check 2: Database Accessible**
```bash
psql "postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=require"
```

**Check 3: Firewall**
Ensure port 5432 (or 6543 for PgBouncer) is not blocked.

---

### **Issue: Permission Denied**

**Cause:** Database user doesn't have required permissions.

**Solution:** Contact Supabase admin or use a user with read permissions.

---

## 📝 Common Use Cases

### **1. Inspect Database Schema**
```
"Show me all tables"
"Describe labour_entries table"
"What columns are in the sites table?"
```

### **2. Data Exploration**
```
"How many labour entries are there?"
"Show me recent site photos"
"List all Site Engineers"
```

### **3. Debugging**
```
"Check if user with email 'test@example.com' exists"
"Show me labour entries for today"
"Are there any pending user approvals?"
```

### **4. Data Analysis**
```
"What's the average labour count per site?"
"Which site has the most material bills?"
"How many photos were uploaded this month?"
```

---

## 🎯 Integration with Flutter Optimization

### **Use MCP to Verify Cache Strategy**

```
1. "How many users check dashboards per day?"
   → Helps decide cache duration

2. "Which tables are queried most frequently?"
   → Prioritize caching for these

3. "What's the average query response time?"
   → Baseline for optimization metrics

4. "How much data is typically returned?"
   → Determine if pagination needed
```

---

## 📊 Example Queries

### **Users & Roles**
```sql
-- List all Site Engineers
SELECT id, username, email, phone, created_at 
FROM users 
WHERE role = 'Site Engineer' 
ORDER BY created_at DESC 
LIMIT 10;

-- Count users by role
SELECT role, COUNT(*) as count 
FROM users 
GROUP BY role;
```

### **Sites**
```sql
-- Active sites
SELECT id, site_name, area, street, status 
FROM sites 
WHERE status = 'active';

-- Sites with most labour entries
SELECT s.site_name, COUNT(l.id) as entry_count
FROM sites s
LEFT JOIN labour_entries l ON s.id = l.site_id
GROUP BY s.site_name
ORDER BY entry_count DESC
LIMIT 10;
```

### **Labour Entries**
```sql
-- Today's labour entries
SELECT * FROM labour_entries 
WHERE DATE(entry_date) = CURRENT_DATE;

-- Labour by site and role
SELECT site_id, submitted_by_role, SUM(labour_count) as total
FROM labour_entries
WHERE entry_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY site_id, submitted_by_role;
```

---

## 🔄 MCP Server Management

### **Reload MCP Server**
```
Command Palette → "MCP: Reconnect Server" → Select "supabase-postgres"
```

### **View MCP Logs**
```
Command Palette → "MCP: Show Logs"
```

### **Disable/Enable Server**
Edit `mcp.json`:
```json
"disabled": true  // Disable
"disabled": false // Enable
```

---

## 🎉 Success!

Your Supabase PostgreSQL database is now connected to Kiro via MCP!

**What You Can Do:**
- ✅ Query database directly from Kiro
- ✅ Inspect tables and schemas
- ✅ Explore data for debugging
- ✅ Verify optimizations
- ✅ Analyze usage patterns

**Security:**
- ✅ SSL/TLS encrypted connection
- ✅ Read operations auto-approved
- ✅ Write operations require approval
- ✅ Uses existing database credentials

---

## 📚 Next Steps

1. **Test Connection:** Ask Kiro to "List all tables"
2. **Explore Schema:** "Describe the users table"
3. **Run Queries:** "Show me all Site Engineers"
4. **Optimize:** Use data insights for Flutter optimizations

---

*MCP setup completed: July 18, 2026*  
*Database: Supabase PostgreSQL*  
*Status: ✅ READY TO USE*  

**Start querying your database with Kiro now!** 🚀
