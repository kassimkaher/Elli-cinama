import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/di/providers.dart';
import '../../core/i18n/strings.dart';
import '../../shared/state/states.dart';
import '../../shared/widgets/buttons.dart';

class ParentalLockTile extends ConsumerStatefulWidget {
  const ParentalLockTile({super.key});
  @override
  ConsumerState<ParentalLockTile> createState() => _ParentalLockTileState();
}

class _ParentalLockTileState extends ConsumerState<ParentalLockTile> {
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final has = await ref.read(parentalLockRepositoryProvider).hasPin();
    if (mounted) setState(() => _hasPin = has);
  }

  Future<void> _managePin() async {
    var pin = '';
    final repo = ref.read(parentalLockRepositoryProvider);
    await showAbkDialog<void>(context,
        title: _hasPin ? context.tr('setPin') : context.tr('setPin'),
        content: StatefulBuilder(builder: (ctx, setLocal) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            PinInput(value: pin, onChanged: (v) => setLocal(() => pin = v)),
            const SizedBox(height: AbkSpace.s16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (_hasPin)
                AbkButton(context.tr('clearCache'), kind: AbkButtonKind.ghost, onPressed: () async {
                  await repo.clearPin();
                  if (ctx.mounted) Navigator.pop(ctx);
                  _refresh();
                }),
              const SizedBox(width: 8),
              AbkButton(context.tr('ok'), onPressed: pin.length == 4
                  ? () async {
                      await repo.setPin(pin);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _refresh();
                    }
                  : null),
            ]),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_hasPin ? Icons.lock_rounded : Icons.lock_open_rounded, color: c.textSecondary),
      title: Text(context.tr('parentalLock'), style: context.type.body),
      subtitle: Text(_hasPin ? context.tr('setPin') : context.tr('setPin'), style: context.type.caption),
      trailing: Icon(context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: c.textMuted),
      onTap: _managePin,
    );
  }
}
