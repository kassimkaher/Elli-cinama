import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/di/providers.dart';
import '../../core/i18n/strings.dart';
import '../../shared/state/states.dart';
import '../../shared/widgets/buttons.dart';
import '../favorites/parental_lock_repository.dart';

/// Central parental gate shared by every play path (live / movie / episode).
///
/// Content is PIN-gated only when a PIN is configured AND the content is locked
/// — either the backend flagged its category ([categoryLocked]) or the user
/// locally locked this item ([ParentalLockRepository.setLocked]).
///
/// Returns true when playback may proceed (not locked, or the PIN was verified);
/// false when the user cancelled or entry failed.
Future<bool> ensureUnlocked(
  BuildContext context,
  WidgetRef ref, {
  required String kind, // live | movie | series
  required String id,
  bool categoryLocked = false,
}) async {
  final repo = ref.read(parentalLockRepositoryProvider);
  if (!await repo.hasPin()) return true; // no PIN → nothing is enforced
  final locked = categoryLocked || await repo.isLocked(kind, id);
  if (!locked) return true;
  if (!context.mounted) return false;
  final ok = await showAbkDialog<bool>(
    context,
    title: context.tr('lockedContent'),
    content: _PinPrompt(repo: repo),
    actions: [
      AbkButton(context.tr('cancel'),
          kind: AbkButtonKind.ghost, onPressed: () => Navigator.of(context).pop(false)),
    ],
  );
  return ok ?? false;
}

class _PinPrompt extends StatefulWidget {
  final ParentalLockRepository repo;
  const _PinPrompt({required this.repo});
  @override
  State<_PinPrompt> createState() => _PinPromptState();
}

class _PinPromptState extends State<_PinPrompt> {
  String _v = '';
  bool _error = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(context.tr('lockedContentBody'), style: context.type.bodySecondary),
      const SizedBox(height: AbkSpace.s16),
      PinInput(
        value: _v,
        onChanged: (nv) async {
          setState(() {
            _v = nv;
            _error = false;
          });
          if (nv.length != 4) return;
          final navigator = Navigator.of(context);
          final good = await widget.repo.verify(nv);
          if (!mounted) return;
          if (good) {
            navigator.pop(true);
          } else {
            setState(() {
              _error = true;
              _v = '';
            });
          }
        },
      ),
      if (_error) ...[
        const SizedBox(height: AbkSpace.s8),
        Text(context.tr('wrongPin'), style: context.type.caption.copyWith(color: c.error)),
      ],
    ]);
  }
}
