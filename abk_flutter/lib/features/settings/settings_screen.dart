import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_prefs.dart';
import '../../core/design/breakpoints.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/di/providers.dart';
import '../../core/i18n/strings.dart';
import '../../shared/state/states.dart';
import '../../shared/widgets/buttons.dart';
import '../auth/presentation/auth_controller.dart';
import '../catalogue/catalogue_providers.dart';
import 'parental_lock.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final auth = ref.watch(sessionControllerProvider);
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final username = auth is AuthAuthenticated ? auth.account.username : null;
    final expire = auth is AuthAuthenticated ? auth.account.expire : null;
    final m = AbkBreakpoints.contentMargin(context.wc);

    return ListView(padding: EdgeInsets.symmetric(horizontal: m, vertical: AbkSpace.s16), children: [
      _Group(context.tr('account'), [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.account_circle_rounded, color: c.accentPrimary),
          title: Text(username ?? '—', style: context.type.body),
          subtitle: expire != null ? Text('${context.tr('expires')} $expire', style: context.type.caption) : null,
        ),
      ]),
      _Group(context.tr('appearance'), [
        _Segmented<ThemeMode>(
          value: mode,
          onChanged: (v) => ref.read(themeModeProvider.notifier).set(v),
          options: [
            (ThemeMode.system, context.tr('system')),
            (ThemeMode.dark, context.tr('dark')),
            (ThemeMode.light, context.tr('light')),
          ],
        ),
      ]),
      _Group(context.tr('language'), [
        _Segmented<String>(
          value: locale.languageCode,
          onChanged: (v) => ref.read(localeProvider.notifier).set(Locale(v)),
          options: [('ar', context.tr('arabic')), ('en', context.tr('english'))],
        ),
      ]),
      _Group(context.tr('parentalLock'), [
        ParentalLockTile(),
      ]),
      _Group(context.tr('dataCache'), [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cached_rounded, color: c.textSecondary),
          title: Text(context.tr('clearCache'), style: context.type.body),
          onTap: () {
            ref.invalidate(moviesProvider);
            ref.invalidate(seriesListProvider);
            ref.invalidate(liveChannelsProvider);
            ref.invalidate(liveCategoriesProvider);
            showAbkSnackbar(context, context.tr('cacheCleared'));
          },
        ),
      ]),
      _Group(context.tr('about'), [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline_rounded, color: c.textSecondary),
          title: Text('ABK', style: context.type.body),
          subtitle: Text('v1.0.0', style: context.type.caption),
        ),
      ]),
      const SizedBox(height: AbkSpace.s16),
      AbkButton(
        context.tr('logout'),
        kind: AbkButtonKind.destructive,
        icon: Icons.logout_rounded,
        onPressed: () async {
          await ref.read(sessionControllerProvider.notifier).logout();
          ref.read(appReadyProvider.notifier).state = false;
        },
      ),
      const SizedBox(height: AbkSpace.s40),
    ]);
  }
}

/// Reset when logging out so the launch moment replays on next login.
final appReadyProvider = StateProvider<bool>((_) => false);

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group(this.title, this.children);
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: AbkSpace.s20, bottom: AbkSpace.s8),
        child: Text(title.toUpperCase(),
            style: context.type.navLabel.copyWith(color: context.c.textMuted)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: AbkSpace.s16, vertical: 4),
        decoration: BoxDecoration(
            color: context.c.surface, borderRadius: AbkRadius.brMd,
            border: Border.all(color: context.c.borderSubtle)),
        child: Material(
          type: MaterialType.transparency,
          child: Column(children: children),
        ),
      ),
    ]);
  }
}

class _Segmented<T> extends StatelessWidget {
  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, String)> options;
  const _Segmented({required this.value, required this.onChanged, required this.options});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AbkSpace.s8),
      child: Row(children: [
        for (final (v, label) in options)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == value ? c.accentPrimary : c.surfaceElevated,
                  borderRadius: AbkRadius.brSm,
                ),
                child: Text(label,
                    style: context.type.button.copyWith(color: v == value ? c.background : c.textSecondary)),
              ),
            ),
          ),
      ]),
    );
  }
}
