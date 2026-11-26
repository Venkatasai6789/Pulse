import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/api_service.dart';
import '../data/firestore_api_service.dart';
import '../theme/app_theme.dart';

/// Shows a subtle "Syncing…" / "Saved" pill when offline writes or
/// online mutations are syncing with Cloud Firestore.
class SyncIndicator extends StatefulWidget {
  const SyncIndicator({super.key});

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator> {
  Timer? _dismissTimer;
  bool _showSaved = false;
  SyncStatus _lastStatus = SyncStatus.saved;

  @override
  Widget build(BuildContext context) {
    final apiService = context.watch<ApiService?>();
    if (apiService is! FirestoreApiService) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<SyncStatus>(
      valueListenable: apiService.syncStatus,
      builder: (context, status, _) {
        if (status == SyncStatus.syncing) {
          _dismissTimer?.cancel();
          _showSaved = false;
          _lastStatus = SyncStatus.syncing;
          return _buildPill(
            icon: const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            label: 'Syncing…',
            backgroundColor: AppColors.forest.withValues(alpha: 0.9),
          );
        } else if (_lastStatus == SyncStatus.syncing && status == SyncStatus.saved) {
          _lastStatus = SyncStatus.saved;
          _showSaved = true;
          _dismissTimer?.cancel();
          _dismissTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showSaved = false;
              });
            }
          });
        }

        if (_showSaved) {
          return _buildPill(
            icon: const Icon(Icons.check_circle_outline, size: 14, color: AppColors.leafLight),
            label: 'Saved',
            backgroundColor: AppColors.forest.withValues(alpha: 0.9),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPill({
    required Widget icon,
    required String label,
    required Color backgroundColor,
  }) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}
