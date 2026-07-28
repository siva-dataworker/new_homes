// Supervisor Entry Provider
// State Management for Supervisor Dashboard
// Date: 2026-05-12

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/supervisor_entry_model.dart';
import '../services/construction_service.dart';
import '../utils/app_logger.dart';

class SupervisorEntryProvider with ChangeNotifier {
  final ConstructionService _constructionService = ConstructionService();

  // Current entry state
  DailyEntry? _currentEntry;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  // Session lock state
  bool _isSessionLocked = false;
  bool _canExit = true;

  // Getters
  DailyEntry? get currentEntry => _currentEntry;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  bool get isSessionLocked => _isSessionLocked;
  bool get canExit => _canExit;

  bool get hasLabourEntry => _currentEntry?.isLabourCompleted ?? false;
  bool get hasPhotos => _currentEntry?.isPhotosCompleted ?? false;
  bool get isMorningComplete => _currentEntry?.isMorningCompleted ?? false;
  bool get canAddEvening => _currentEntry?.canAddEvening ?? false;

  /// Initialize entry for a site
  Future<void> initializeEntry({
    required String siteId,
    required String siteName,
    required String siteLocation,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if entry already exists for today
      final today = DateTime.now();
      final result = await _constructionService.checkEntryLock(
        siteId: siteId,
        entryDate: _formatDate(today),
      );

      if (result['success']) {
        if (result['is_locked'] == true) {
          // Entry locked by another supervisor
          _currentEntry = DailyEntry(
            siteId: siteId,
            siteName: siteName,
            siteLocation: siteLocation,
            entryDate: today,
            isLockedByOther: true,
            lockedBySupervisor: result['locked_by'],
            status: EntryStatus.locked,
          );
        } else {
          // Load existing entry or create new
          await _loadExistingEntry(siteId, siteName, siteLocation, today);
        }
      }
    } catch (e) {
      _error = 'Failed to initialize entry: $e';
      AppLogger.d('❌ [PROVIDER] Error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load existing entry from server
  Future<void> _loadExistingEntry(
    String siteId,
    String siteName,
    String siteLocation,
    DateTime date,
  ) async {
    try {
      // TODO: Call API to get existing entry
      // For now, create new entry
      _currentEntry = DailyEntry(
        siteId: siteId,
        siteName: siteName,
        siteLocation: siteLocation,
        entryDate: date,
        status: EntryStatus.pending,
      );
    } catch (e) {
      AppLogger.d('❌ [PROVIDER] Error loading entry: $e');
      // Create new entry on error
      _currentEntry = DailyEntry(
        siteId: siteId,
        siteName: siteName,
        siteLocation: siteLocation,
        entryDate: date,
        status: EntryStatus.pending,
      );
    }
  }

  /// Start entry session (lock navigation)
  void startSession() {
    _isSessionLocked = true;
    _canExit = false;
    notifyListeners();
    AppLogger.d('🔒 [PROVIDER] Session locked');
  }

  /// End entry session (unlock navigation)
  void endSession() {
    _isSessionLocked = false;
    _canExit = true;
    notifyListeners();
    AppLogger.d('🔓 [PROVIDER] Session unlocked');
  }

  /// Check if can exit (both labour and photos completed)
  void updateExitPermission() {
    _canExit = _currentEntry?.canExit ?? false;
    notifyListeners();
  }

  /// Submit labour entry
  Future<bool> submitLabourEntry(LabourEntry labourEntry) async {
    if (_currentEntry == null) return false;

    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      // Submit each labour type
      final labourTypes = {
        'Mason': labourEntry.masonCount,
        'Helper': labourEntry.helperCount,
        'Carpenter': labourEntry.carpenterCount,
        'Electrician': labourEntry.electricianCount,
        'Painter': labourEntry.painterCount,
        'Other': labourEntry.otherCount,
      };

      int successCount = 0;
      for (final entry in labourTypes.entries) {
        if (entry.value > 0) {
          final result = await _constructionService.submitLabourCount(
            siteId: _currentEntry!.siteId,
            labourCount: entry.value,
            labourType: entry.key,
            customDateTime: DateTime.now(),
          );

          if (result['success'] == true) {
            successCount++;
          } else if (result['locked'] == true) {
            _error = result['error'];
            _currentEntry = _currentEntry!.copyWith(
              isLockedByOther: true,
              lockedBySupervisor: result['locked_by'],
              status: EntryStatus.locked,
            );
            return false;
          }
        }
      }

      if (successCount > 0) {
        // Update entry state
        _currentEntry = _currentEntry!.copyWith(
          labourEntry: labourEntry,
          entryTime: DateTime.now(),
          status: EntryStatus.laborAdded,
        );

        updateExitPermission();
        AppLogger.d(
          '✅ [PROVIDER] Labour entry saved: ${labourEntry.totalWorkers} workers',
        );
        return true;
      }

      return false;
    } catch (e) {
      _error = 'Failed to submit labour entry: $e';
      AppLogger.d('❌ [PROVIDER] Error: $_error');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Add photos - uploads local photo file paths to the server, then
  /// records the returned entry state locally.
  Future<bool> addPhotos(List<String> photoPaths) async {
    if (_currentEntry == null) return false;

    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _constructionService.uploadSupervisorPhotos(
        siteId: _currentEntry!.siteId,
        photos: photoPaths.map((path) => XFile(path)).toList(),
        timeOfDay: 'morning',
      );

      if (result['success'] != true) {
        _error = result['error']?.toString() ?? 'Failed to upload photos';
        return false;
      }

      _currentEntry = _currentEntry!.copyWith(
        morningPhotos: photoPaths,
        status: _currentEntry!.isLabourCompleted
            ? EntryStatus.completed
            : EntryStatus.photosAdded,
      );

      updateExitPermission();

      // If both labour and photos are complete, end session
      if (_currentEntry!.isMorningCompleted) {
        endSession();
      }

      return true;
    } catch (e) {
      _error = 'Failed to add photos: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Submit evening update
  Future<bool> submitEveningUpdate(EveningUpdate eveningUpdate) async {
    if (_currentEntry == null || !_currentEntry!.isMorningCompleted) {
      _error = 'Complete morning entry first';
      return false;
    }

    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      // Evening photos, uploaded via the same endpoint used for morning photos.
      if (eveningUpdate.photoUrls.isNotEmpty) {
        final photoResult = await _constructionService.uploadSupervisorPhotos(
          siteId: _currentEntry!.siteId,
          photos: eveningUpdate.photoUrls.map((path) => XFile(path)).toList(),
          timeOfDay: 'evening',
        );
        if (photoResult['success'] != true) {
          _error = photoResult['error']?.toString() ?? 'Failed to upload evening photos';
          return false;
        }
      }

      // Wage/OT/extra-expense total, recorded via the extra-cost endpoint
      // (there is no dedicated wage-report endpoint on the backend).
      if (eveningUpdate.totalAmount > 0) {
        final costResult = await _constructionService.submitExtraCost(
          siteId: _currentEntry!.siteId,
          amount: eveningUpdate.totalAmount,
          description: 'Evening update — wages: ${eveningUpdate.totalWageAmount}, '
              'OT: ${eveningUpdate.otAmount}, extra: ${eveningUpdate.extraExpense}',
        );
        if (costResult['success'] != true) {
          _error = costResult['error']?.toString() ?? 'Failed to submit evening update';
          return false;
        }
      }

      _currentEntry = _currentEntry!.copyWith(
        eveningUpdate: eveningUpdate,
        eveningUpdateTime: DateTime.now(),
        status: EntryStatus.eveningUpdated,
      );

      return true;
    } catch (e) {
      _error = 'Failed to submit evening update: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Add notes
  void addNotes(String notes) {
    if (_currentEntry != null) {
      _currentEntry = _currentEntry!.copyWith(notes: notes);
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider
  void reset() {
    _currentEntry = null;
    _isLoading = false;
    _isSubmitting = false;
    _error = null;
    _isSessionLocked = false;
    _canExit = true;
    notifyListeners();
  }

  /// Helper: Format date
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
