# Accountant Screens State Management & Color Theme Integration Guide

## Overview
This guide shows how to integrate the new state management providers and dark blue navy color scheme into the accountant screens.

---

## 1. COLOR SCHEME REFERENCE

### Dark Blue Navy Theme Colors
```dart
// Primary
AppColors.deepNavy              // #1A1A2E (Dark Navy) - Main color
AppColors.deepNavyDark          // #0F0F1E (Darker Navy) - Borders, shadows
AppColors.deepNavyLight         // #2D2E47 (Light Navy) - Hover states

// Accountant-Specific
AppColors.accountantPrimary     // #1A1A2E (Dark Navy)
AppColors.accountantAccent      // #2563EB (Bright Blue)
AppColors.accountantSuccess     // #059669 (Green - for confirmed)
AppColors.accountantWarning     // #F59E0B (Amber - for pending)
AppColors.accountantError       // #DC2626 (Red - for errors)
AppColors.accountantBackground  // #F8F9FA (Light background)

// Text
AppColors.textPrimary           // #1A1A2E (Navy)
AppColors.textSecondary         // #4A5568 (Medium Navy)
AppColors.textTertiary          // #718096 (Light Navy)
```

---

## 2. SETUP PROVIDERS AT APP LEVEL

### In `main.dart` or your app initialization:

```dart
import 'package:provider/provider.dart';
import 'lib/providers/accountant_dashboard_provider.dart';
import 'lib/providers/accountant_entries_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AccountantDashboardProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AccountantEntriesProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
```

---

## 3. UPDATING COMPARE SCREEN

### Import providers:
```dart
import 'package:provider/provider.dart';
import '../providers/accountant_entries_provider.dart';
import '../utils/app_colors.dart';
```

### In _loadComparisonData(), update provider:
```dart
Future<void> _loadComparisonData() async {
  final provider = context.read<AccountantEntriesProvider>();
  
  provider.setIsLoading(true);
  provider.setError(null);

  try {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final supervisorData = await _constructionService
        .getEntriesByDateAndRole(dateStr, 'Supervisor');
    final engineerData = await _constructionService
        .getEntriesByDateAndRole(dateStr, 'Site Engineer');
    final accountantData = await _constructionService
        .getEntriesByDateAndRole(dateStr, 'Accountant');

    // Update provider state
    provider.setSupervisorEntries(supervisorData);
    provider.setEngineerEntries(engineerData);
    provider.setAccountantEntries(accountantData);
    provider.setIsLoading(false);

  } catch (e) {
    provider.setError(e.toString());
    provider.setIsLoading(false);
  }
}
```

### Update AppBar colors:
```dart
appBar: AppBar(
  backgroundColor: Colors.white,  // Keep white
  iconTheme: const IconThemeData(color: AppColors.deepNavy),
  // ...
)
```

### Update card colors:
```dart
Card(
  margin: EdgeInsets.only(bottom: 12.h),
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12.r),
    side: BorderSide(
      color: isSelected 
          ? AppColors.accountantAccent 
          : AppColors.deepNavy.withValues(alpha: 0.2),
      width: isSelected ? 2 : 1,
    ),
  ),
  // ...
)
```

### Update text colors:
```dart
Text(
  'Supervisor Entries',
  style: TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.bold,
    color: AppColors.deepNavy,  // Changed from Color(0xFF059669)
  ),
),
```

### Update button colors:
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.accountantSuccess,  // Green for confirm
  ),
  child: const Text(
    'Confirm Selection',
    style: TextStyle(color: Colors.white),
  ),
),
```

---

## 4. UPDATING APPROVED ENTRIES SCREEN

### Import providers:
```dart
import 'package:provider/provider.dart';
import '../providers/accountant_entries_provider.dart';
import '../utils/app_colors.dart';
```

### Update loading colors:
```dart
if (_isLoading)
  const Center(
    child: CircularProgressIndicator(
      color: AppColors.accountantAccent,  // Blue instead of default
    ),
  )
```

### Update role section header:
```dart
Container(
  padding: EdgeInsets.all(12.r),
  decoration: BoxDecoration(
    color: isSelected
        ? AppColors.accountantAccent.withValues(alpha: 0.1)  // Blue tint
        : Colors.grey.shade50,
    borderRadius: BorderRadius.circular(10.r),
    border: Border.all(
      color: isSelected
          ? AppColors.accountantAccent
          : Colors.grey.shade300,
    ),
  ),
  // ...
)
```

### Update "Selected" badge:
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
  decoration: BoxDecoration(
    color: AppColors.deepNavy.withValues(alpha: 0.1),  // Navy tint
    borderRadius: BorderRadius.circular(20.r),
  ),
  child: Text(
    'Selected: ${isSourceAccountant ? '👤 Accountant' : isSourceSupervisor ? '👤 Supervisor' : '🔧 Site Engineer'}',
    style: TextStyle(
      fontSize: 11.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.deepNavy,
    ),
  ),
)
```

---

## 5. UPDATING ACCOUNTANT DASHBOARD

### Import providers:
```dart
import 'package:provider/provider.dart';
import '../providers/accountant_dashboard_provider.dart';
import '../utils/app_colors.dart';
```

### Update data loading:
```dart
Future<void> _loadAccountantDataWithCache() async {
  final provider = context.read<AccountantDashboardProvider>();
  
  provider.setIsLoading(true);
  
  try {
    // ... fetch data ...
    
    provider.setLabourEntriesCount(count);
    provider.setWorkingSitesCount(sitesCount);
    provider.setTotalConfirmedSalary(totalSalary);
    provider.setApprovedEntriesCount(approvedCount);
    provider.setIsLoading(false);
    
  } catch (e) {
    provider.setError(e.toString());
    provider.setIsLoading(false);
  }
}
```

### Update card styling:
```dart
Card(
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12.r),
  ),
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(
        color: AppColors.deepNavy.withValues(alpha: 0.1),
      ),
    ),
    child: Padding(
      padding: EdgeInsets.all(16.r),
      child: Column(
        children: [
          // Header icon with navy background
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: AppColors.deepNavy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.people,
              color: AppColors.deepNavy,
              size: 24.sp,
            ),
          ),
          // ...
        ],
      ),
    ),
  ),
)
```

### Update text colors:
```dart
Text(
  'Labour Entries',
  style: TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,  // Navy gray
  ),
),

Text(
  '4',  // Count
  style: TextStyle(
    fontSize: 24.sp,
    fontWeight: FontWeight.bold,
    color: AppColors.deepNavy,  // Dark navy
  ),
),
```

---

## 6. PROVIDER USAGE PATTERNS

### Watch provider state (rebuilds when state changes):
```dart
final provider = context.watch<AccountantEntriesProvider>();

// Use provider state
final entries = provider.supervisorEntries;
final isLoading = provider.isLoading;
```

### Read provider state (doesn't rebuild):
```dart
final provider = context.read<AccountantEntriesProvider>();

// Update state without rebuilding
provider.selectEntry(entryId, 'supervisor');
```

### Update state in response to events:
```dart
ElevatedButton(
  onPressed: () {
    final provider = context.read<AccountantEntriesProvider>();
    provider.selectEntry(entryId, entryType);
    provider.setIsConfirming(true);
    
    // Perform async action
    _confirmSelection().then((_) {
      provider.setIsConfirming(false);
    });
  },
  child: const Text('Confirm'),
)
```

---

## 7. COLOR MIGRATION CHECKLIST

- [ ] Replace `Color(0xFF059669)` with `AppColors.accountantSuccess`
- [ ] Replace `Color(0xFF2563EB)` with `AppColors.accountantAccent`
- [ ] Replace `Color(0xFF1A1A2E)` with `AppColors.deepNavy`
- [ ] Update all green accent colors to navy/blue
- [ ] Update all black text to `AppColors.deepNavy`
- [ ] Update card shadows to use navy
- [ ] Update border colors to use navy with alpha
- [ ] Update icon colors to use navy
- [ ] Update success indicators to use `accountantSuccess`
- [ ] Update pending indicators to use `accountantWarning`

---

## 8. QUICK MIGRATION SCRIPT

Find and replace in your accountant screens:

```
// Find              Replace With
0xFF059669      →   AppColors.accountantSuccess
0xFF1A1A2E      →   AppColors.deepNavy
Colors.green    →   AppColors.accountantSuccess
Colors.black    →   AppColors.deepNavy
const Color(0xFF2563EB)  →  AppColors.accountantAccent
```

---

## 9. TESTING THE IMPLEMENTATION

1. **Test Provider Setup:**
   - Check that app starts without errors
   - Verify providers are accessible from accountant screens

2. **Test Color Scheme:**
   - Verify all text is dark navy
   - Check cards have navy borders
   - Confirm success indicators are green
   - Check pending indicators are amber

3. **Test State Management:**
   - Load comparison data and verify provider updates
   - Change filters and verify state updates
   - Navigate between screens and verify state persistence

---

## 10. TROUBLESHOOTING

**Imports not found:**
- Ensure provider files exist in `lib/providers/`
- Add them to your project structure

**Provider not available:**
- Check `MultiProvider` setup in `main.dart`
- Verify `ChangeNotifierProvider` is wrapping the widget

**Colors not applying:**
- Check `app_colors.dart` imports
- Verify `AppColors.` prefix is used correctly
- Clear app cache and rebuild

---

## Next Steps

1. Set up providers in `main.dart` first
2. Migrate **Compare Screen** (simplest)
3. Migrate **Approved Entries Screen**
4. Migrate **Dashboard** (most complex)
5. Test all screens thoroughly
6. Remove old color constants

