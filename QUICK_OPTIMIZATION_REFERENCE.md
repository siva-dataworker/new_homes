# Quick Optimization Reference Card
**For Flutter Developers**  
**Last Updated:** July 18, 2026  

---

## 🚀 3 Most Common Patterns

### 1️⃣ Dashboard with Cache (99% of dashboards)

```dart
import '../utils/cached_screen_wrapper.dart';

class MyDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CachedScreenWrapper<Map<String, dynamic>>(
      cacheKey: 'my_dashboard_$userId',
      cacheDuration: Duration(minutes: 15),
      fetchData: () => api.getDashboard(),
      skeletonBuilder: () => SkeletonLoader(itemCount: 3),
      builder: (context, data, refresh) {
        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: YourDashboardContent(data),
        );
      },
    );
  }
}
```

**When to use:** All dashboard screens  
**Time to implement:** 15-30 minutes  
**Impact:** 2-5 seconds → < 100ms  

---

### 2️⃣ Data Entry with Optimistic UI (All forms)

```dart
import '../utils/optimistic_ui_manager.dart';

class MyFormState extends State<MyForm> with OptimisticUIMixin {
  
  Future<void> _submit() async {
    final tempId = TempIdGenerator.generate('entry');
    
    await submitOptimistically(
      tempId: tempId,
      data: formData,
      apiCall: (data) => api.submit(data),
      onSuccess: () {
        showSnackBar('✓ Submitted successfully');
        Navigator.pop(context);
      },
      onError: (error) {
        showSnackBar('Failed: $error');
      },
    );
  }
}
```

**When to use:** Labour entry, material entry, photo upload  
**Time to implement:** 30-45 minutes  
**Impact:** 1-3 seconds wait → Instant  

---

### 3️⃣ List with Pagination (All list screens)

```dart
import '../utils/cached_screen_wrapper.dart';
import '../utils/prefetch_manager.dart';

class MyListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CachedListWrapper<MyItem>(
      cacheKey: 'my_list',
      pageSize: 20,
      fetchData: (page, size) => api.getList(page, size),
      skeletonBuilder: () => SkeletonLoader(itemCount: 5),
      builder: (context, items, loadMore) {
        return LazyLoadListView(
          itemCount: items.length,
          itemBuilder: (context, index) => ItemCard(items[index]),
          onLoadMore: loadMore,
          hasMore: items.length >= 20,
        );
      },
    );
  }
}
```

**When to use:** Bills, history, sites, users  
**Time to implement:** 25-35 minutes  
**Impact:** 1-2 seconds → < 100ms + infinite scroll  

---

## 📋 Quick Checklist

### Before You Start
- [ ] Import required utilities
- [ ] Identify screen type (dashboard/form/list)
- [ ] Note current loading time
- [ ] Choose cache duration

### Dashboard Optimization
- [ ] Wrap screen in `CachedScreenWrapper`
- [ ] Add `cacheKey` (unique per user/screen)
- [ ] Create skeleton loader
- [ ] Add pull-to-refresh
- [ ] Test: Load twice, second should be instant

### Form Optimization
- [ ] Add `OptimisticUIMixin` to state
- [ ] Replace submit with `submitOptimistically()`
- [ ] Show success immediately
- [ ] Handle errors with retry
- [ ] Test: Submit should show success instantly

### List Optimization
- [ ] Use `CachedListWrapper`
- [ ] Add pagination (20 items/page)
- [ ] Implement lazy loading
- [ ] Add pull-to-refresh
- [ ] Test: Navigate back, list should be instant

---

## 🎨 Loading Widget Reference

### Replace This:
```dart
CircularProgressIndicator()
```

### With This:

**For full screen:**
```dart
OptimizedLoading(message: 'Loading...')
```

**For lists:**
```dart
SkeletonLoader(itemCount: 3, height: 80)
```

**For cards:**
```dart
ShimmerLoading(
  isLoading: true,
  child: CardContent(),
)
```

---

## 🔑 Cache Keys Convention

**Pattern:** `{screen}_{role}_{id}_{filter}`

**Examples:**
```dart
'dashboard_site_engineer_${userId}'
'labour_history_${siteId}'
'bills_list_accountant_${userId}'
'site_detail_${siteId}'
'materials_${siteId}_${date}'
```

**Rules:**
- Use underscore separators
- Include user/site ID for isolation
- Add filters if data varies
- Keep short but descriptive

---

## ⏱️ Cache Duration Guide

```dart
// Real-time data (updates frequently)
Duration(minutes: 5)     // Labour entries, material usage

// Regular updates
Duration(minutes: 15)    // Dashboards, recent activity

// Semi-static data
Duration(minutes: 30)    // Site details, user lists

// Static data
Duration(hours: 1)       // Reports, analytics, materials catalog

// Very static
Duration(hours: 24)      // Areas, streets, roles
```

---

## 🐛 Common Mistakes

### ❌ DON'T:
```dart
// No unique cache key
cacheKey: 'dashboard'  // All users share same cache!

// Cache key without user context
cacheKey: 'site_list'  // Different users see same sites!

// Too long cache duration
Duration(days: 7)  // Data will be very stale

// No error handling
onError: null  // User sees nothing on failure
```

### ✅ DO:
```dart
// Unique per user
cacheKey: 'dashboard_$userId'

// Include context
cacheKey: 'site_list_${role}_${userId}'

// Appropriate duration
Duration(minutes: 15)

// Always handle errors
onError: (error) => showRetryDialog(error)
```

---

## 🔧 API Service Quick Reference

### GET (with cache)
```dart
final api = OptimizedApiService(baseUrl: AppConfig.baseUrl);

final data = await api.get(
  endpoint: '/api/dashboard/',
  cacheKey: 'dashboard_$userId',
  cacheDuration: Duration(minutes: 15),
);
```

### POST (optimistic)
```dart
await api.post(
  endpoint: '/api/submit/',
  body: formData,
  optimistic: true,  // Returns immediately
);
```

### POST (with retry)
```dart
await api.post(
  endpoint: '/api/submit/',
  body: formData,
  // Automatically retries 3 times on failure
);
```

---

## 📊 Performance Targets

| Operation | Target | Acceptable | Slow |
|-----------|--------|------------|------|
| **Cached screen** | < 100ms | < 300ms | > 500ms |
| **First load** | < 2s | < 3s | > 5s |
| **Form submit** | Instant | < 500ms | > 1s |
| **List scroll** | 60 FPS | 30 FPS | < 30 FPS |

**Measure with:**
```dart
final stopwatch = Stopwatch()..start();
// ... operation ...
print('Time: ${stopwatch.elapsedMilliseconds}ms');
```

---

## 🧪 Testing Commands

### Test Slow Network
```dart
// Add to debug build
if (kDebugMode) {
  await Future.delayed(Duration(seconds: 3));
}
```

### Test Offline Mode
```dart
// Turn on airplane mode
// Try to submit form
// Should queue and retry when online
```

### Test Cache
```dart
// 1. Load screen (should show skeleton)
// 2. Go back
// 3. Load screen again (should be instant)
```

---

## 🆘 Troubleshooting

### Screen not loading from cache?
```dart
// Check cache key matches
print('Cache key: $cacheKey');

// Check cache has data
print('Cached: ${cache.isCached(cacheKey)}');

// Force refresh
forceRefresh: true
```

### Optimistic UI not working?
```dart
// Check mixin is added
class MyState extends State<MyScreen> with OptimisticUIMixin

// Check tempId is unique
final tempId = TempIdGenerator.generate('entry');

// Check onSuccess is called
onSuccess: () => print('Success called')
```

### Too much memory usage?
```dart
// Reduce cache duration
cacheDuration: Duration(minutes: 5)

// Clear old cache
cache.clearExpired()

// Clear specific cache
cache.remove(cacheKey)
```

---

## 📞 Quick Help

**Problem:** First load is slow  
**Solution:** Add skeleton loader (normal for first load)

**Problem:** Cache never updates  
**Solution:** Check cacheDuration, add pull-to-refresh

**Problem:** Wrong data showing  
**Solution:** Check cacheKey includes userId/siteId

**Problem:** Form doesn't submit  
**Solution:** Check error handling, add retry logic

**Problem:** List doesn't paginate  
**Solution:** Use CachedListWrapper with onLoadMore

---

## 🎯 Priority Order

1. **Site Engineer Dashboard** - Most traffic
2. **Supervisor Dashboard** - Daily use
3. **Labour Entry** - Most frequent operation
4. **Architect Dashboard** - Client-facing
5. **Other dashboards** - Lower priority
6. **All forms** - Phase 2
7. **All lists** - Phase 3

---

## 📝 Before/After Template

```dart
// ❌ BEFORE (2-5 seconds, loading spinner)
class OldDashboard extends StatefulWidget {
  @override
  _OldDashboardState createState() => _OldDashboardState();
}

class _OldDashboardState extends State<OldDashboard> {
  bool _loading = true;
  var _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _data = await api.get();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return CircularProgressIndicator();
    return Content(_data);
  }
}

// ✅ AFTER (< 100ms instant, skeleton on first load)
class NewDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CachedScreenWrapper(
      cacheKey: 'dashboard_$userId',
      fetchData: () => api.get(),
      skeletonBuilder: () => SkeletonLoader(),
      builder: (context, data, refresh) => Content(data),
    );
  }
}
```

---

## 🎉 Success Indicators

- ✅ Second visit loads instantly
- ✅ No loading spinners on navigation
- ✅ Form submit shows success immediately
- ✅ Works offline (queues operations)
- ✅ Users say "app feels fast"

---

*Keep this reference handy while implementing optimizations!*  
*Estimated time per screen: 15-45 minutes*  
*Expected improvement: 10-50x faster*
