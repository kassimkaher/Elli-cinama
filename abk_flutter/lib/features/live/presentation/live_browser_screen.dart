import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/strings.dart';
import '../../../shared/state/states.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/images.dart';
import '../../../shared/widgets/layout.dart';
import '../../../core/di/providers.dart';
import '../../catalogue/catalogue_providers.dart';
import '../../player/player_screen.dart';
import '../../settings/parental_gate.dart';
import '../domain/entities.dart';

final _selCategoryProvider = StateProvider<int?>((_) => null);
final _selChannelProvider = StateProvider<LiveChannel?>((_) => null);
final _channelQueryProvider = StateProvider.autoDispose<String>((_) => '');

Future<void> playChannel(BuildContext context, WidgetRef ref, LiveChannel ch) async {
  final cats = ref.read(liveCategoriesProvider).valueOrNull;
  final catLocked =
      cats?.any((cat) => cat.id == '${ch.categoryId}' && cat.isLocked) ?? false;
  final allowed = await ensureUnlocked(context, ref,
      kind: 'live', id: '${ch.id}', categoryLocked: catLocked);
  if (!allowed) return;
  if (!context.mounted) return;
  final resolver = ref.read(resolveLiveStreamUrlProvider);
  final url = resolver.call(ch);
  if (url == null || url.isEmpty) {
    showAbkSnackbar(context, context.tr('streamFailed'));
    return;
  }
  // Sibling channels (same category) become the up/down switching playlist.
  final byCat = ref.read(channelsByCategoryProvider).valueOrNull;
  final siblings = (byCat?[ch.categoryId] ?? const <LiveChannel>[])
      .where((c) => (c.streamUrlTemplate ?? '').isNotEmpty)
      .toList();
  var items = siblings
      .map((c) => PlaybackItem(
            url: resolver.call(c) ?? '', title: c.name, subtitle: '${c.viewOrder ?? c.id}',
            live: true, streamId: c.id, resumeId: '${c.id}', kind: 'live', image: c.icon))
      .toList();
  var index = items.indexWhere((it) => it.resumeId == '${ch.id}');
  if (index < 0) {
    items = [
      PlaybackItem(url: url, title: ch.name, subtitle: '${ch.viewOrder ?? ch.id}',
          live: true, streamId: ch.id, resumeId: '${ch.id}', kind: 'live', image: ch.icon)
    ];
    index = 0;
  }
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(items: items, index: index)));
}

class LiveBrowserScreen extends ConsumerWidget {
  const LiveBrowserScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wc = context.wc;
    final cats = ref.watch(liveCategoriesProvider);
    final byCat = ref.watch(channelsByCategoryProvider);

    return cats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorBlock(onRetry: () => ref.invalidate(liveCategoriesProvider)),
      data: (categories) {
        final real = categories.where((c) => c.id != '-1').toList();
        if (AbkBreakpoints.isDesktopClass(wc)) {
          return _ThreePane(categories: real, byCat: byCat);
        }
        return _CategoryIndex(categories: real);
      },
    );
  }
}

class _CategoryIndex extends ConsumerWidget {
  final List<LiveCategory> categories;
  const _CategoryIndex({required this.categories});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoriteChannelsProvider);
    return ListView(padding: const EdgeInsets.all(AbkSpace.s16), children: [
      favs.maybeWhen(
        data: (list) => list.isEmpty
            ? const SizedBox.shrink()
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeader(context.tr('favorites')),
                PosterRail(
                  height: 64,
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => SizedBox(
                    width: 56,
                    child: AbkImage(
                      url: list[i].icon, fit: BoxFit.contain, radius: AbkRadius.brSm,
                      fallback: LogoFallback(list[i].name),
                    ),
                  ),
                ),
                const SizedBox(height: AbkSpace.s20),
              ]),
        orElse: () => const SizedBox.shrink(),
      ),
      SectionHeader('${context.tr('categories')} · ${categories.length}'),
      ...categories.map((cat) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: CategoryRailItem(
              name: cat.name,
              count: cat.channelCount,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _ChannelListScreen(category: cat))),
            ),
          )),
    ]);
  }
}

class _ChannelListScreen extends ConsumerWidget {
  final LiveCategory category;
  const _ChannelListScreen({required this.category});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byCat = ref.watch(channelsByCategoryProvider);
    final query = ref.watch(_channelQueryProvider).toLowerCase();
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        title: Text(category.name, style: context.type.sectionTitle),
      ),
      body: byCat.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBlock(onRetry: () => ref.invalidate(channelsByCategoryProvider)),
        data: (map) {
          var channels = map[int.tryParse(category.id)] ?? const [];
          if (query.isNotEmpty) {
            channels = channels.where((ch) => ch.name.toLowerCase().contains(query)).toList();
          }
          final hasPin = ref.watch(hasParentalPinProvider).valueOrNull ?? false;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(AbkSpace.s16),
              child: SearchField(
                controller: TextEditingController(text: ref.read(_channelQueryProvider)),
                hint: context.tr('searchChannels'),
                onChanged: (v) => ref.read(_channelQueryProvider.notifier).state = v,
                onClear: () => ref.read(_channelQueryProvider.notifier).state = '',
              ),
            ),
            Expanded(child: _ChannelList(channels: channels, locked: category.isLocked && hasPin)),
          ]);
        },
      ),
    );
  }
}

class _ChannelList extends ConsumerWidget {
  final List<LiveChannel> channels;
  final bool locked;
  const _ChannelList({required this.channels, this.locked = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localRevisionProvider);
    if (channels.isEmpty) {
      return EmptyStateBlock(icon: Icons.tv_off_rounded, title: context.tr('empty'));
    }
    final favRepo = ref.read(favoritesRepositoryProvider);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AbkSpace.s12),
      itemCount: channels.length,
      itemBuilder: (ctx, i) {
        final ch = channels[i];
        return FutureBuilder<bool>(
          future: favRepo.isFavorite('live', '${ch.id}'),
          builder: (ctx, snap) => LiveChannelRow(
            name: ch.name,
            number: '${ch.viewOrder ?? ch.id}',
            subtitle: null,
            logoUrl: ch.icon,
            locked: locked,
            archive: ch.hasArchive,
            favorite: snap.data ?? false,
            onTap: () => playChannel(ctx, ref, ch),
            onToggleFavorite: () async {
              await favRepo.toggle('live', '${ch.id}');
              ref.read(localRevisionProvider.notifier).state++;
            },
          ),
        );
      },
    );
  }
}

/// Desktop three-pane: categories · channels · preview (Design §30).
class _ThreePane extends ConsumerWidget {
  final List<LiveCategory> categories;
  final AsyncValue<Map<int, List<LiveChannel>>> byCat;
  const _ThreePane({required this.categories, required this.byCat});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final selCat = ref.watch(_selCategoryProvider) ?? (categories.isNotEmpty ? int.tryParse(categories.first.id) : null);
    final selCh = ref.watch(_selChannelProvider);
    final channels = byCat.maybeWhen(data: (m) => m[selCat] ?? const [], orElse: () => const []);
    final hasPin = ref.watch(hasParentalPinProvider).valueOrNull ?? false;
    final selCatLocked =
        hasPin && categories.any((cat) => int.tryParse(cat.id) == selCat && cat.isLocked);
    return Row(children: [
      SizedBox(
        width: 260,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(AbkSpace.s12),
            child: Text('${context.tr('categories')} · ${categories.length}', style: context.type.sectionTitle),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: categories.length,
              itemBuilder: (ctx, i) => CategoryRailItem(
                name: categories[i].name,
                count: categories[i].channelCount,
                selected: int.tryParse(categories[i].id) == selCat,
                onTap: () => ref.read(_selCategoryProvider.notifier).state = int.tryParse(categories[i].id),
              ),
            ),
          ),
        ]),
      ),
      Container(width: 1, color: c.divider),
      SizedBox(
        width: 360,
        child: channels.isEmpty
            ? EmptyStateBlock(icon: Icons.tv_off_rounded, title: context.tr('empty'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AbkSpace.s8, vertical: 8),
                itemCount: channels.length,
                itemBuilder: (ctx, i) {
                  final ch = channels[i];
                  return LiveChannelRow(
                    name: ch.name,
                    number: '${ch.viewOrder ?? ch.id}',
                    selected: selCh?.id == ch.id,
                    logoUrl: ch.icon,
                    locked: selCatLocked,
                    archive: ch.hasArchive,
                    onTap: () => ref.read(_selChannelProvider.notifier).state = ch,
                    onSecondary: () => playChannel(ctx, ref, ch),
                  );
                },
              ),
      ),
      Container(width: 1, color: c.divider),
      Expanded(child: _PreviewPane(channel: selCh)),
    ]);
  }
}
// (three-pane middle list is built inline above)

class _PreviewPane extends ConsumerWidget {
  final LiveChannel? channel;
  const _PreviewPane({required this.channel});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (channel == null) {
      return EmptyStateBlock(icon: Icons.preview_rounded, title: context.tr('preview'));
    }
    final ch = channel!;
    return Padding(
      padding: const EdgeInsets.all(AbkSpace.s24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(color: Colors.black, borderRadius: AbkRadius.brMd),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 90, height: 60, child: AbkImage(url: ch.icon, fit: BoxFit.contain, fallback: LogoFallback(ch.name))),
                const SizedBox(height: 12),
                Text('${context.tr('preview')} · ${ch.name}', style: context.type.caption.copyWith(color: Colors.white70)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: AbkSpace.s16),
        Text(ch.name, style: context.type.sectionTitle),
        Text('${ch.viewOrder ?? ch.id}', style: context.type.metadata),
        const SizedBox(height: AbkSpace.s16),
        AbkButton(context.tr('fullscreen'), icon: Icons.play_arrow_rounded, onPressed: () => playChannel(context, ref, ch)),
      ]),
    );
  }
}
