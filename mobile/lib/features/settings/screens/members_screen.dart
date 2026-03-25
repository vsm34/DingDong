import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_toast.dart';
import '../../../providers/providers.dart';

class _MemberInfo {
  final String uid;
  final String displayName;
  final String email;
  final String role;

  const _MemberInfo({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
  });
}

/// /settings/members — Manage device members (owner only).
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  List<_MemberInfo> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final device = ref.read(deviceProvider);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('deviceMembers')
          .where('deviceId', isEqualTo: device.deviceId)
          .get();

      final members = <_MemberInfo>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = data['uid'] as String;
        final role = data['role'] as String? ?? 'member';
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final userData = userDoc.data() ?? {};
          members.add(_MemberInfo(
            uid: uid,
            displayName: userData['displayName'] as String? ?? 'Unknown',
            email: userData['email'] as String? ?? '',
            role: role,
          ));
        } catch (_) {
          members.add(_MemberInfo(
            uid: uid,
            displayName: 'Unknown',
            email: '',
            role: role,
          ));
        }
      }
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String uid) async {
    final device = ref.read(deviceProvider);
    try {
      await FirebaseFirestore.instance
          .collection('deviceMembers')
          .doc('${device.deviceId}_$uid')
          .delete();
      await _loadMembers();
      if (mounted) DDToast.success(context, 'Member removed.');
    } catch (_) {
      if (mounted) DDToast.error(context, 'Failed to remove member.');
    }
  }

  void _showRemoveMemberSheet(BuildContext context, _MemberInfo member) {
    DDConfirmSheet.show(
      context: context,
      title: 'Remove Member',
      message:
          'Remove ${member.displayName} from this device? They will lose access immediately.',
      confirmLabel: 'Remove',
      isDestructive: true,
      onConfirm: () => _removeMember(member.uid),
    );
  }

  void _showInviteSheet(BuildContext context) {
    final emailCtrl = TextEditingController();
    var isInviting = false;
    DDBottomSheet.show<void>(
      context: context,
      title: 'Invite Member',
      child: StatefulBuilder(
        builder: (ctx, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DDTextField(
              label: 'Email Address',
              hint: 'member@example.com',
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: DDSpacing.lg),
            DDButton.primary(
              label: 'Send Invite',
              isLoading: isInviting,
              onPressed: isInviting
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim().toLowerCase();
                      if (email.isEmpty) return;
                      setSS(() => isInviting = true);
                      await _inviteMember(ctx, email);
                      if (ctx.mounted) setSS(() => isInviting = false);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _inviteMember(BuildContext ctx, String email) async {
    final device = ref.read(deviceProvider);
    String? errorMsg;
    String? successMsg;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        errorMsg =
            'No DingDong account found with that email. Ask them to sign up first.';
      } else {
        final uid = snap.docs.first.id;
        await FirebaseFirestore.instance
            .collection('deviceMembers')
            .doc('${device.deviceId}_$uid')
            .set({
          'deviceId': device.deviceId,
          'uid': uid,
          'role': 'member',
          'addedAt': FieldValue.serverTimestamp(),
        });
        successMsg = 'Member added successfully';
        await _loadMembers();
      }
    } catch (_) {
      errorMsg = 'Failed to add member.';
    }
    if (ctx.mounted) Navigator.of(ctx).pop();
    if (!mounted) return;
    if (errorMsg != null) DDToast.error(context, errorMsg);
    if (successMsg != null) DDToast.success(context, successMsg);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final device = ref.watch(deviceProvider);
    final isOwner = auth.user?.uid == device.ownerId;

    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF355E3B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Members', style: DDTypography.h3),
      ),
      body: _isLoading
          ? const Center(child: DDLoadingIndicator(size: DDLoadingSize.md))
          : Column(
              children: [
                if (isOwner)
                  Padding(
                    padding: const EdgeInsets.all(DDSpacing.xl),
                    child: DDButton.primary(
                      label: 'Invite Member',
                      leading: const Icon(Icons.person_add_outlined,
                          color: DDColors.white, size: 18),
                      onPressed: () => _showInviteSheet(context),
                    ),
                  ),
                Expanded(
                  child: _members.isEmpty
                      ? Center(
                          child: Text('No members yet.',
                              style: DDTypography.bodyM
                                  .copyWith(color: DDColors.textMuted)),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
                          itemCount: _members.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: DDColors.borderDefault,
                          ),
                          itemBuilder: (context, i) {
                            final member = _members[i];
                            final isOwnerRow = member.role == 'owner';
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: DDSpacing.md),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        DDColors.hunterGreen.withValues(alpha: 0.12),
                                    child: Text(
                                      member.displayName.isNotEmpty
                                          ? member.displayName[0].toUpperCase()
                                          : '?',
                                      style: DDTypography.label.copyWith(
                                          color: DDColors.hunterGreen),
                                    ),
                                  ),
                                  const SizedBox(width: DDSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(member.displayName,
                                            style: DDTypography.bodyM.copyWith(
                                                fontWeight: FontWeight.w600)),
                                        if (member.email.isNotEmpty)
                                          Text(member.email,
                                              style: DDTypography.caption.copyWith(
                                                  color: DDColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isOwnerRow
                                          ? DDColors.hunterGreen
                                              .withValues(alpha: 0.1)
                                          : DDColors.softGreenGray,
                                      borderRadius: BorderRadius.circular(
                                          DDSpacing.radiusFull),
                                    ),
                                    child: Text(
                                      isOwnerRow ? 'Owner' : 'Member',
                                      style: DDTypography.caption.copyWith(
                                        color: isOwnerRow
                                            ? DDColors.hunterGreen
                                            : DDColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  if (isOwner && !isOwnerRow) ...[
                                    const SizedBox(width: DDSpacing.sm),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: DDColors.error, size: 20),
                                      onPressed: () =>
                                          _showRemoveMemberSheet(context, member),
                                      tooltip: 'Remove member',
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
