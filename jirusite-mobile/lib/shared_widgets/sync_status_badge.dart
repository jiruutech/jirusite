import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/sync/sync_engine.dart';

/// Small persistent badge shown in the app bar.
/// Displays: ✓ Synced | ⏳ N pending | ↑ Syncing... | ⚠ Conflict
///
/// The pulse animation runs ONLY while actively syncing and stops on idle.
class SyncStatusBadge extends ConsumerStatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  ConsumerState<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends ConsumerState<SyncStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _updateAnimation(SyncStatus status) {
    if (status == SyncStatus.syncing) {
      if (!_pulseCtrl.isAnimating) {
        _pulseCtrl.repeat(reverse: true);
      }
    } else {
      if (_pulseCtrl.isAnimating) {
        _pulseCtrl.stop();
        _pulseCtrl.value = 1.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    final pending = ref.watch(pendingCountProvider);

    _updateAnimation(status);

    final color = _statusColor(status, pending);
    final isSyncing = status == SyncStatus.syncing;

    return GestureDetector(
      onTap: () => _onTap(context, ref),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Opacity(
          opacity: isSyncing ? _pulseAnim.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            constraints: const BoxConstraints(minHeight: 28),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: color.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon(status, pending), size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  _label(status, pending),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(SyncStatus status, int pending) {
    if (status == SyncStatus.syncing) return AppColors.chalk;
    if (pending > 0) return AppColors.syncPending;
    if (status == SyncStatus.error) return AppColors.syncConflict;
    return AppColors.syncSynced;
  }

  IconData _icon(SyncStatus status, int pending) {
    if (status == SyncStatus.syncing) return Icons.sync;
    if (pending > 0) return Icons.schedule;
    if (status == SyncStatus.error) return Icons.warning_amber;
    return Icons.check_circle_outline;
  }

  String _label(SyncStatus status, int pending) {
    if (status == SyncStatus.syncing) return 'Syncing...';
    if (pending > 0) return '$pending pending';
    return 'Synced';
  }

  void _onTap(BuildContext context, WidgetRef ref) {
    ref.read(syncEngineProvider).sync();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Sync triggered'),
          duration: Duration(seconds: 2)),
    );
  }
}
