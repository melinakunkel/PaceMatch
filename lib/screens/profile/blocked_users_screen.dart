import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/profile.dart';
import '../../services/block_service.dart';
import '../../theme/app_theme.dart';

/// Manage the accounts the current user has blocked — reachable from
/// Settings. Blocking is one-directional and silent (see BlockService): the
/// blocked person is never told, and only shows up here for the blocker.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _blockService = BlockService();
  late Future<List<Profile>> _future = _blockService.getBlockedProfiles();
  final Set<String> _unblocking = {};

  Future<void> _unblock(Profile profile) async {
    setState(() => _unblocking.add(profile.id));
    try {
      await _blockService.unblockUser(profile.id);
      if (!mounted) return;
      setState(() {
        _future = _blockService.getBlockedProfiles();
        _unblocking.remove(profile.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _unblocking.remove(profile.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('blockedUsers.unblockFailed', {'error': '$e'})),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t('blockedUsers.title')),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Profile>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final blocked = snapshot.data ?? [];
            if (blocked.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    t('blockedUsers.empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: blocked.length,
              itemBuilder: (context, i) {
                final profile = blocked[i];
                final busy = _unblocking.contains(profile.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.secondaryLight,
                          backgroundImage: profile.avatarUrl != null
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: profile.avatarUrl != null
                              ? null
                              : Text(
                                  profile.fullName.isNotEmpty
                                      ? profile.fullName[0].toUpperCase()
                                      : '?',
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            profile.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: busy ? null : () => _unblock(profile),
                          child: busy
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(t('blockedUsers.unblock')),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
