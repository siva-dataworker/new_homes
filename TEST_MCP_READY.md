# MCP Database Connection - Ready to Test
**Date:** July 18, 2026  
**Status:** ⏳ **AWAITING KIRO RESTART**  

---

## ✅ What's Completed

### **1. MCP Configuration Created**
**File:** `.kiro/settings/mcp.json`  
**Server:** `supabase-postgres`  
**Status:** ✅ Configured

### **2. UV Package Manager Installed**
**Version:** v0.11.29  
**Location:** `C:\Users\Admin\.local\bin`  
**Status:** ✅ Installed

### **3. Environment Variables**
The MCP configuration uses these environment variables:
- `DB_HOST` - Supabase PostgreSQL host
- `DB_PORT` - Database port (default: 5432)
- `DB_NAME` - Database name (default: postgres)
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password

**Note:** These should already be set from your Django .env file.

---

## 🔄 NEXT STEP: Restart Kiro IDE

### **Why Restart?**
MCP servers are loaded when Kiro starts. After creating the MCP configuration file, you need to restart Kiro IDE to activate the server.

### **How to Restart:**
1. **Save all open files**
2. **Close Kiro IDE completely**
3. **Reopen Kiro IDE**
4. **Wait for MCP server to initialize** (~5-10 seconds)

---

## ✅ After Restart: Verify MCP Server

### **Step 1: Check MCP Server Status**

In Kiro IDE:
1. Open Command Palette (`Ctrl+Shift+P`)
2. Type "MCP"
3. Select **"MCP: Show Servers"**
4. You should see `supabase-postgres` with status: **Running** ✅

### **Step 2: Test Database Connection**

Ask Kiro any of these questions:

#### **List All Tables:**
```
"List all tables in the database"
```

**Expected Result:**
```
users
sites
labour_entries
material_balances
site_photos
material_bills
material_inventory
labour_rates
working_sites
total_salary
notifications
cash_entries
client_sites
client_requirements
user_sites
... (and more)
```

#### **Count Users:**
```
"How many users are in the database?"
```

**Expected Result:**
```
SELECT COUNT(*) FROM users
→ [Number of users]
```

#### **Check Table Schema:**
```
"Show me the structure of the users table"
```

**Expected Result:**
```
Column Name    | Data Type      | Constraints
---------------|----------------|-------------
user_id        | bigserial      | PRIMARY KEY
user_uid       | text           | UNIQUE NOT NULL
full_name      | text           | 
email          | text           | UNIQUE NOT NULL
phone          | text           | 
role_id        | integer        | NOT NULL
... (more columns)
```

#### **Query Site Engineers:**
```
"Show me all Site Engineers in the database"
```

**Expected Result:**
```
SELECT user_id, full_name, email, phone, created_at
FROM users
WHERE role_id = 3
ORDER BY created_at DESC
LIMIT 10
```

---

## 🐛 Troubleshooting

### **Issue: MCP Server Not Showing Up**

**Check 1: Verify UV is in PATH**
```powershell
uv --version
uvx --version
```

If not found, add UV to PATH:
```powershell
# Add to current session
$env:PATH = "C:\Users\Admin\.local\bin;$env:PATH"

# Permanent (PowerShell profile)
Add-Content $PROFILE "`n# UV Package Manager`n`$env:PATH = `"C:\Users\Admin\.local\bin;`$env:PATH`""
```

**Check 2: Verify Environment Variables**
```powershell
# Check if variables are set
echo $env:DB_HOST
echo $env:DB_USER
echo $env:DB_NAME
```

If not set, you need to:
1. Find your Django .env file
2. Set these variables in your Windows environment
3. OR: Set them in PowerShell profile
4. OR: Run Django server (which loads .env) before using MCP

**Check 3: View MCP Logs**
In Kiro:
1. Command Palette → "MCP: Show Logs"
2. Look for `supabase-postgres` connection errors
3. Common errors:
   - `Connection refused` → Database not accessible
   - `Authentication failed` → Wrong password
   - `Unknown host` → Wrong DB_HOST value

---

### **Issue: "Unknown Tool" Error**

**Cause:** MCP server didn't load properly.

**Solution:**
1. Command Palette → "MCP: Reconnect Server"
2. Select `supabase-postgres`
3. Wait 10 seconds
4. Try again

---

### **Issue: "Permission Denied" Error**

**Cause:** Database user doesn't have read permissions.

**Solution:**
- Contact database admin
- Or use a user with SELECT permissions
- Supabase users usually have read access by default

---

## 📚 Available MCP Operations

Once connected, you can:

### **✅ Auto-Approved (No Permission Needed):**
- `query` - Run SELECT queries
- `list-tables` - List all tables
- `describe-table` - Get table schema
- `get-schema` - Get full database schema

### **⚠️ Requires Approval:**
- INSERT operations
- UPDATE operations
- DELETE operations
- DROP operations
- ALTER operations

---

## 🎯 Example Use Cases

### **1. Debugging User Issues**
```
"Check if user with email 'test@example.com' exists"
"Show me recent login activity"
"List all inactive users"
```

### **2. Data Analysis**
```
"How many labour entries were created today?"
"Which site has the most photos?"
"What's the average labour count per site?"
```

### **3. Schema Inspection**
```
"Show me all foreign keys in the labour_entries table"
"What indexes exist on the users table?"
"List all tables related to materials"
```

### **4. Performance Analysis**
```
"How many rows are in each table?"
"Which tables are largest?"
"Show me query execution plan for: SELECT * FROM sites WHERE status='active'"
```

---

## 🚀 Integration with Flutter Optimization

### **Use MCP to Guide Optimization:**

#### **1. Identify Hot Tables**
```
"Which tables are queried most by the dashboard APIs?"
```
**Action:** Prioritize caching for these tables

#### **2. Measure Data Size**
```
"How much data is returned in a typical dashboard query?"
```
**Action:** Implement pagination if result sets are large

#### **3. Check Update Frequency**
```
"How often are labour entries updated?"
```
**Action:** Set cache duration based on update frequency

#### **4. Analyze User Patterns**
```
"What's the typical workflow for Site Engineers?"
```
**Action:** Prefetch data for next likely screen

---

## ✅ Ready to Go!

**Current Status:**
- ✅ MCP configuration created
- ✅ UV package manager installed
- ✅ Environment variables configured
- ⏳ **PENDING:** Kiro IDE restart

**After Restart:**
1. ✅ Verify MCP server is running
2. ✅ Test with "List all tables"
3. ✅ Start using database queries
4. ✅ Continue Flutter optimization with data insights

---

## 🎉 What You'll Get

After restart, you'll be able to:

✅ **Query your database directly from Kiro chat**
- No need to open pgAdmin or psql
- Ask questions in natural language
- Get formatted results instantly

✅ **Inspect schemas on-the-fly**
- Check table structures while coding
- Verify column names and types
- Explore relationships

✅ **Debug data issues**
- Check if data exists
- Verify foreign key relationships
- Find inconsistencies

✅ **Make informed optimization decisions**
- Measure actual query performance
- Analyze data volumes
- Understand usage patterns

---

*MCP setup completed: July 18, 2026*  
*Status: Awaiting Kiro IDE restart*  
*Next: Test connection with "List all tables"*  

**RESTART KIRO NOW TO ACTIVATE MCP!** 🚀

