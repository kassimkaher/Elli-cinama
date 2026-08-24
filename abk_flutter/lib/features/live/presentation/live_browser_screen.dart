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
import '../../favorites/playback_history_repository.dart';
import '../../player/player_screen.dart';
import '../domain/entities.dart';

final _selCategoryProvider = StateProvider<int?>((_) => null);
final _selChannelProvider = StateProvider<LiveChannel?>((_) => null);
final _channelQueryProvider = StateProvider.autoDispose<String>((_) => '');

Future<void> playChannel(BuildContext context, WidgetRef ref, LiveChannel ch) async {
  final locked = await ref.read(parentalLockRepositoryProvider).isLocked('live', '${ch.id}');
  if (locked && context.mounted) {
    final ok = await _promptPin(context, ref);
    if (!ok) return;
  }
  if (!context.mounted) return;
  final url = ref.read(resolveLiveStreamUrlProvider).call(ch);
  if (url == null || url.isEmpty) {
    showAbkSnackbar(context, context.tr('streamFailed'));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlayerScreen(
      url: url,
      title: ch.name,
      subtitle: '${ch.viewOrder ?? ch.id}',
      live: true,
      history: PlaybackEntry(
        id: '${ch.id}', kind: 'live', title: ch.name, subtitle: '${ch.viewOrder ?? ch.id}',
        image: ch.icon, updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    ),
  ));
}

Future<bool> _promptPin(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(parentalLockRepositoryProvider);
  if (!await repo.hasPin()) return true; // no pin set → not enforced
  if (!context.mounted) return false;
  final controller = ValueNotifier('');
  final ok = await showAbkDialog<bool>(context,
      title: context.tr('lockedContent'),
      content: StatefulBuilder(builder: (ctx, setState) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.tr('lockedContentBody'), style: ctx.type.bodySecondary),
          const SizedBox(height: AbkSpace.s16),
          _PinRow(onChanged: (v) async {
            controller.value = v;
            if (v.length == 4) {
              final good = await repo.verify(v);
              if (good && ctx.mounted) Navigator.pop(ctx, true);
            }
          }),
        ]);
      }),
      actions: [AbkButton(context.tr('cancel'), kind: AbkButtonKind.ghost, onPressed: () => Navigator.pop(context, false))]);
  return ok ?? false;
}

class _PinRow extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _PinRow({required this.onChanged});
  @override
  State<_PinRow> createState() => _PinRowState();
}

class _PinRowState extends State<_PinRow> {
  String v = '';
  @override
  Widget build(BuildContext context) => PinInput(value: v, onChanged: (nv) {
        setState(() => v = nv);
        widget.onChanged(nv);
      });
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
            Expanded(child: _ChannelList(channels: channels)),
          ]);
        },
      ),
    );
  }
}

class _ChannelList extends ConsumerWidget {
  final List<LiveChannel> channels;
  const _ChannelList({required this.channels});
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
