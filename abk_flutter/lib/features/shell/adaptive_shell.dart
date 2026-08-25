import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/breakpoints.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import '../../shared/state/states.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/focusable.dart';
import '../auth/presentation/auth_controller.dart';
import '../../core/di/providers.dart';
import '../favorites/favorites_screen.dart';
import '../home/home_screen.dart';
import '../live/presentation/live_browser_screen.dart';
import '../movies/presentation/movies_screen.dart';
import '../search/search_screen.dart';
import '../series/presentation/series_screen.dart';
import '../settings/settings_screen.dart';

final shellIndexProvider = StateProvider<int>((_) => 0);

class _Dest {
  final IconData icon;
  final String labelKey;
  const _Dest(this.icon, this.labelKey);
}

const _destinations = [
  _Dest(Icons.home_rounded, 'home'),
  _Dest(Icons.live_tv_rounded, 'live'),
  _Dest(Icons.movie_rounded, 'movies'),
  _Dest(Icons.grid_view_rounded, 'series'),
  _Dest(Icons.favorite_rounded, 'favorites'),
  _Dest(Icons.settings_rounded, 'settings'),
];

class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({super.key});

  static const _screens = [
    HomeScreen(),
    LiveBrowserScreen(),
    MoviesScreen(),
    SeriesScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellIndexProvider);
    final wc = context.wc;
    final body = IndexedStack(index: index, children: _screens);

    void select(int i) => ref.read(shellIndexProvider.notifier).state = i;

    return Shortcuts(
      shortcuts: {
        for (var i = 0; i < 6; i++)
          SingleActivator(LogicalKeyboardKey(0x00000031 + i)): _JumpIntent(i),
        const SingleActivator(LogicalKeyboardKey.slash): const _SearchIntent(),
      },
      child: Actions(
        actions: {
          _JumpIntent: CallbackAction<_JumpIntent>(onInvoke: (i) {
            select(i.index);
            return null;
          }),
          _SearchIntent: CallbackAction<_SearchIntent>(onInvoke: (_) {
            _openSearch(context);
            return null;
          }),
        },
        child: Focus(
          // On TV the selected sidebar item autofocuses (visible first-frame
          // focus); elsewhere this wrapper holds focus so number/'/' shortcuts
          // work before the user touches anything.
          autofocus: !AbkBreakpoints.isTv,
          child: AbkBreakpoints.usesSidebar(wc)
              ? _DesktopScaffold(index: index, onSelect: select, onSearch: () => _openSearch(context), body: body)
              : _PhoneScaffold(index: index, onSelect: select, onSearch: () => _openSearch(context), body: body),
        ),
      ),
    );
  }
}

class _JumpIntent extends Intent {
  final int index;
  const _JumpIntent(this.index);
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

/// Phone / medium — bottom bar (Home/Live/Movies/Series/More) + app-bar search.
class _PhoneScaffold extends ConsumerWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final Widget body;
  const _PhoneScaffold({required this.index, required this.onSelect, required this.onSearch, required this.body});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    // Bottom bar slots: 0..3 direct, 4 = More.
    final barIndex = index <= 3 ? index : 4;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        titleSpacing: AbkSpace.s16,
        title: Text(context.tr(_destinations[index].labelKey), style: context.type.pageTitle),
        actions: [
          IconButton(onPressed: onSearch, icon: Icon(Icons.search_rounded, color: c.textPrimary)),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        backgroundColor: c.surface,
        indicatorColor: c.surfaceStrong,
        selectedIndex: barIndex,
        onDestinationSelected: (i) {
          if (i == 4) {
            _showMore(context, ref, onSelect);
          } else {
            onSelect(i);
          }
        },
        destinations: [
          for (var i = 0; i < 4; i++)
            NavigationDestination(icon: Icon(_destinations[i].icon), label: context.tr(_destinations[i].labelKey)),
          NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), label: context.tr('more')),
        ],
      ),
    );
  }

  void _showMore(BuildContext context, WidgetRef ref, ValueChanged<int> onSelect) {
    final account = ref.read(sessionControllerProvider);
    showAbkSheet(context, (ctx) {
      final c = ctx.c;
      final username = account is AuthAuthenticated ? account.account.username : null;
      final expire = account is AuthAuthenticated ? account.account.expire : null;
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (username != null)
            ListTile(
              leading: Icon(Icons.account_circle_rounded, color: c.accentPrimary),
              title: Text(username, style: ctx.type.cardTitle),
              subtitle: expire != null ? Text('${ctx.tr('expires')} $expire', style: ctx.type.caption) : null,
            ),
          ListTile(
            leading: Icon(Icons.favorite_rounded, color: c.textSecondary),
            title: Text(ctx.tr('favorites'), style: ctx.type.body),
            onTap: () { Navigator.pop(ctx); onSelect(4); },
          ),
          ListTile(
            leading: Icon(Icons.settings_rounded, color: c.textSecondary),
            title: Text(ctx.tr('settings'), style: ctx.type.body),
            onTap: () { Navigator.pop(ctx); onSelect(5); },
          ),
          const SizedBox(height: AbkSpace.s16),
        ]),
      );
    });
  }
}

/// Expanded / desktop — labelled sidebar (Settings pinned bottom) + top search.
class _DesktopScaffold extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final Widget body;
  const _DesktopScaffold({required this.index, required this.onSelect, required this.onSearch, required this.body});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final labelled = MediaQuery.sizeOf(context).width >= AbkBreakpoints.desktop;
    // TV: below the desktop width the rail is a compact icon column (72); when
    // labels do appear (very wide TVs) keep it to 220, not a 320 column that
    // steals width from content.
    final width = labelled ? (AbkBreakpoints.isTv ? 220.0 : 232.0) : 72.0;
    return Scaffold(
      body: Row(children: [
        Container(
          width: width,
          color: c.surface,
          child: SafeArea(
            child: Column(children: [
              const SizedBox(height: AbkSpace.s16),
              _Brand(labelled: labelled),
              const SizedBox(height: AbkSpace.s16),
              _SidebarSearch(labelled: labelled, onSearch: onSearch),
              const SizedBox(height: AbkSpace.s8),
              Expanded(
                child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: [
                  for (var i = 0; i < 5; i++)
                    _SidebarItem(
                        dest: _destinations[i],
                        selected: index == i,
                        labelled: labelled,
                        // TV: land a VISIBLE initial focus on the current tab so
                        // the first frame shows focus without a remote key press.
                        autofocus: AbkBreakpoints.isTv && index == i,
                        onTap: () => onSelect(i)),
                ]),
              ),
              _SidebarItem(
                  dest: _destinations[5],
                  selected: index == 5,
                  labelled: labelled,
                  autofocus: AbkBreakpoints.isTv && index == 5,
                  onTap: () => onSelect(5)),
              const SizedBox(height: AbkSpace.s16),
            ]),
          ),
        ),
        Container(width: 1, color: c.divider),
        Expanded(child: body),
      ]),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool labelled;
  const _Brand({required this.labelled});
  @override
  Widget build(BuildContext context) {
    const mark = AbkLogo.chip(size: 34);
    if (!labelled) return mark;
    return Row(children: [
      const SizedBox(width: 12),
      mark,
      const SizedBox(width: 10),
      Text('ABK', style: context.type.sectionTitle),
    ]);
  }
}

class _SidebarSearch extends StatelessWidget {
  final bool labelled;
  final VoidCallback onSearch;
  const _SidebarSearch({required this.labelled, required this.onSearch});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: AbkRadius.brPill,
        onTap: onSearch,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: c.surfaceElevated, borderRadius: AbkRadius.brPill, border: Border.all(color: c.borderSubtle)),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 18, color: c.textMuted),
            if (labelled) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.tr('search'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.body.copyWith(color: c.textMuted)),
              ),
              if (!AbkBreakpoints.isTv) Text('/', style: context.type.metadata),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _Dest dest;
  final bool selected, labelled, autofocus;
  final VoidCallback onTap;
  const _SidebarItem(
      {required this.dest,
      required this.selected,
      required this.labelled,
      required this.onTap,
      this.autofocus = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AbkFocusable(
        onTap: onTap,
        selected: selected,
        autofocus: autofocus,
        radius: AbkRadius.brSm,
        semanticLabel: context.tr(dest.labelKey),
        builder: (ctx, states) {
          final active = selected || states.contains(WidgetState.focused);
          return Container(
            padding: EdgeInsets.symmetric(horizontal: labelled ? 12 : 0, vertical: 11),
            decoration: BoxDecoration(
                color: active ? c.surfaceStrong : Colors.transparent,
                borderRadius: AbkRadius.brSm),
            child: Row(
              mainAxisAlignment:
                  labelled ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(dest.icon,
                    size: 20, color: active ? c.accentPrimary : c.textSecondary),
                if (labelled) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(context.tr(dest.labelKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.body.copyWith(
                            color: active ? c.textPrimary : c.textSecondary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
