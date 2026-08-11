import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared_widgets/empty_state.dart';

final _notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.notifications);
  return (resp.data as List).cast<Map<String, dynamic>>();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(_notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final dio = ref.read(dioClientProvider);
              await dio.patch(ApiEndpoints.readAll);
              ref.invalidate(_notificationsProvider);
            },
            child: const Text('Mark All Read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications',
            );
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (_, i) => _NotifTile(
              notif: notifications[i],
              onTap: () async {
                if (!(notifications[i]['is_read'] as bool? ?? false)) {
                  final dio = ref.read(dioClientProvider);
                  await dio.patch(ApiEndpoints.markRead(notifications[i]['id'] as String));
                  ref.invalidate(_notificationsProvider);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif, required this.onTap});
  final Map<String, dynamic> notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notif['is_read'] as bool? ?? false;
    final channel = notif['channel'] as String? ?? 'push';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isRead
            ? AppColors.divider
            : AppColors.primary.withValues(alpha: 0.12),
        child: Icon(
          channel == 'sms' ? Icons.sms_outlined : Icons.notifications_outlined,
          color: isRead ? AppColors.textSecondary : AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        notif['title'] as String? ?? '',
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      subtitle: Text(notif['body'] as String? ?? '',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      tileColor: isRead ? null : AppColors.primary.withValues(alpha: 0.04),
      onTap: onTap,
    );
  }
}
