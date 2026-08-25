import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/player/playback_service.dart';
import '../../../core/player/video_player_playback_service.dart';
import '../../../shared/state/states.dart';
import '../../../shared/widgets/badges.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/focusable.dart';
import '../../../shared/widgets/images.dart';
import '../../../shared/widgets/layout.dart';
import '../../../core/di/providers.dart';
import '../../catalogue/catalogue_providers.dart';
import '../../epg/domain/entities.dart';
import '../../player/player_screen.dart';
import '../../settings/parental_gate.dart';
import '../../shell/adaptive_shell.dart';
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

// ---- Embedded large-screen Live preview ------------------------------------

/// Phase of the embedded preview session, published so channel rows can show a
/// distinct playing / loading / error state for the currently-previewed channel.
enum _PreviewPhase { idle, loading, playing, error, locked }

class _PreviewInfo {
  final int? channelId;
  final _PreviewPhase phase;
  const _PreviewInfo(this.channelId, this.phase);
}

final _previewProvider =
    StateProvider<_PreviewInfo>((_) => const _PreviewInfo(null, _PreviewPhase.idle));

/// Desktop/TV three-pane: categories · channels · REAL embedded preview player
/// (Design §30). Selecting a channel plays its actual stream in the preview;
/// fullscreen expands the SAME playback session (a layout toggle via a shared
/// GlobalKey — no route push, no reload); exit returns to the embedded box.
class _ThreePane extends ConsumerStatefulWidget {
  final List<LiveCategory> categories;
  final AsyncValue<Map<int, List<LiveChannel>>> byCat;
  const _ThreePane({required this.categories, required this.byCat});
  @override
  ConsumerState<_ThreePane> createState() => _ThreePaneState();
}

class _ThreePaneState extends ConsumerState<_ThreePane> {
  /// Expand to TRUE fullscreen: a route on the ROOT navigator, above the shell,
  /// so it covers the sidebar and everything except the video. It renders the
  /// SAME shared decode session (no reload, no stop) — the embedded pane below
  /// keeps owning it; exiting the route returns to the still-playing preview.
  void _openFullscreen(List<LiveChannel> siblings) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _LiveFullscreenScreen(siblings: siblings),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final categories = widget.categories;
    final selCat = ref.watch(_selCategoryProvider) ??
        (categories.isNotEmpty ? int.tryParse(categories.first.id) : null);
    final selCh = ref.watch(_selChannelProvider);
    final channels = widget.byCat
        .maybeWhen(data: (m) => m[selCat] ?? const [], orElse: () => const <LiveChannel>[]);
    final hasPin = ref.watch(hasParentalPinProvider).valueOrNull ?? false;
    final selCatLocked =
        hasPin && categories.any((cat) => int.tryParse(cat.id) == selCat && cat.isLocked);
    final preview = ref.watch(_previewProvider);

    final previewPane = _PreviewPane(
      channel: selCh,
      siblings: channels,
      locked: selCatLocked,
      onToggleFullscreen: () => _openFullscreen(channels),
      onSelect: (ch) => ref.read(_selChannelProvider.notifier).state = ch,
    );

    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      // Compress the two lists, never the preview → preview stays dominant.
      final catW = w < 1000 ? 184.0 : 220.0;
      final chW = (w * 0.30).clamp(256.0, 360.0);
      return Row(children: [
        SizedBox(width: catW, child: _categories(context, categories, selCat)),
        Container(width: 1, color: c.divider),
        SizedBox(
            width: chW,
            child: _channels(context, channels, selCh, selCatLocked, preview)),
        Container(width: 1, color: c.divider),
        Expanded(child: previewPane),
      ]);
    });
  }

  Widget _categories(BuildContext context, List<LiveCategory> categories, int? selCat) =>
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(AbkSpace.s12),
          child: Text('${context.tr('categories')} · ${categories.length}',
              style: context.type.sectionTitle),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: categories.length,
            itemBuilder: (ctx, i) => CategoryRailItem(
              name: categories[i].name,
              count: categories[i].channelCount,
              selected: int.tryParse(categories[i].id) == selCat,
              onTap: () =>
                  ref.read(_selCategoryProvider.notifier).state = int.tryParse(categories[i].id),
            ),
          ),
        ),
      ]);

  Widget _channels(BuildContext context, List<LiveChannel> channels, LiveChannel? selCh,
      bool locked, _PreviewInfo preview) {
    if (channels.isEmpty) {
      return EmptyStateBlock(icon: Icons.tv_off_rounded, title: context.tr('empty'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AbkSpace.s8, vertical: 8),
      itemCount: channels.length,
      itemBuilder: (ctx, i) {
        final ch = channels[i];
        final isPreviewCh = preview.channelId == ch.id;
        return LiveChannelRow(
          name: ch.name,
          number: '${ch.viewOrder ?? ch.id}',
          selected: selCh?.id == ch.id,
          playing: isPreviewCh && preview.phase == _PreviewPhase.playing,
          loading: isPreviewCh && preview.phase == _PreviewPhase.loading,
          channelError: isPreviewCh && preview.phase == _PreviewPhase.error,
          logoUrl: ch.icon,
          locked: locked,
          archive: ch.hasArchive,
          // Select = play in the embedded preview (no route push).
          onTap: () => ref.read(_selChannelProvider.notifier).state = ch,
          // Secondary (right-click / long-press) still opens the full player.
          onSecondary: () => playChannel(ctx, ref, ch),
        );
      },
    );
  }
}

/// The real embedded preview player. Owns the shared [PlaybackService] decode
/// session while the Live tab is visible and switches channels in-place
/// (debounced). Fullscreen is a separate root route rendering the SAME session,
/// so it never reloads the stream and this pane keeps owning it.
class _PreviewPane extends ConsumerStatefulWidget {
  final LiveChannel? channel;
  final List<LiveChannel> siblings;
  final bool locked;
  final VoidCallback onToggleFullscreen;
  final ValueChanged<LiveChannel> onSelect;
  const _PreviewPane({
    required this.channel,
    required this.siblings,
    required this.locked,
    required this.onToggleFullscreen,
    required this.onSelect,
  });
  @override
  ConsumerState<_PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends ConsumerState<_PreviewPane> with WidgetsBindingObserver {
  late final PlaybackService _svc = ref.read(playbackServiceProvider);
  StreamSubscription<PlaybackState>? _sub;
  PlaybackState _state = PlaybackState.idle;
  int? _loadedId;
  int _gen = 0;
  Timer? _debounce;
  bool _failed = false;
  List<EpgListing> _epg = const [];
  final FocusNode _fsFocus = FocusNode(debugLabel: 'live.preview.playPause');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _svc.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      _publish();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  @override
  void didUpdateWidget(covariant _PreviewPane old) {
    super.didUpdateWidget(old);
    if (old.channel?.id != widget.channel?.id || old.locked != widget.locked) _sync();
  }

  /// Reconcile the decode session with the selected channel (debounced so
  /// surfing several channels issues exactly one load).
  void _sync() {
    final ch = widget.channel;
    if (ch == null || widget.locked) {
      if (_loadedId != null) {
        _gen++;
        _loadedId = null;
        _failed = false;
        _svc.stop();
      }
      _publish();
      return;
    }
    if (ch.id == _loadedId && !_failed) return;
    _loadedId = ch.id;
    _failed = false;
    _publish(); // reflect "loading" on the row immediately
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) _load(ch);
    });
  }

  Future<void> _load(LiveChannel ch) async {
    final gen = ++_gen;
    setState(() => _epg = const []);
    final url = ref.read(resolveLiveStreamUrlProvider).call(ch);
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _failed = true);
      _publish();
      return;
    }
    try {
      final src = ref.read(playbackSourceFactoryProvider).fromUrl(url, title: ch.name);
      await _svc.load(src).timeout(const Duration(seconds: 25));
      if (gen != _gen) return;
      await _svc.play();
      if (gen != _gen) return;
      if (mounted) setState(() => _failed = false);
      ref.read(shortEpgProvider(ch.id).future).then((l) {
        if (mounted && gen == _gen) setState(() => _epg = l);
      }).ignore();
    } catch (_) {
      if (gen != _gen) return;
      if (mounted) setState(() => _failed = true);
    }
    _publish();
  }

  _PreviewPhase get _phase {
    if (widget.locked) return _PreviewPhase.locked;
    if (widget.channel == null) return _PreviewPhase.idle;
    if (_failed || _state.status == PlaybackStatus.error) return _PreviewPhase.error;
    if (_state.status == PlaybackStatus.playing) return _PreviewPhase.playing;
    return _PreviewPhase.loading;
  }

  void _publish() {
    final info = _PreviewInfo(widget.channel?.id, _phase);
    // Not during build (called from listeners/timers) → safe to write.
    ref.read(_previewProvider.notifier).state = info;
  }

  int get _index => widget.siblings.indexWhere((c) => c.id == widget.channel?.id);
  void _go(int delta) {
    final i = _index;
    if (i < 0) return;
    final n = i + delta;
    if (n < 0 || n >= widget.siblings.length) return;
    widget.onSelect(widget.siblings[n]);
  }

  bool get _hasPrev => _index > 0;
  bool get _hasNext => _index >= 0 && _index < widget.siblings.length - 1;

  void _togglePlay() {
    _state.status == PlaybackStatus.playing ? _svc.pause() : _svc.play();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) _svc.pause();
  }

  @override
  void dispose() {
    _gen++;
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _debounce?.cancel();
    _fsFocus.dispose();
    _svc.stop(); // release the shared session on leaving Live large-screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No background audio: stop when the Live tab is not the visible tab; resume
    // (reload the selected channel) when it becomes visible again.
    ref.listen<int>(shellIndexProvider, (prev, next) {
      if (next != 1) {
        _gen++;
        _loadedId = null;
        _svc.stop();
        _publish();
      } else if (mounted) {
        _sync();
      }
    });

    final ch = widget.channel;
    if (ch == null) {
      return EmptyStateBlock(icon: Icons.preview_rounded, title: context.tr('preview'));
    }
    if (widget.locked) {
      return _lockedPlaceholder(context, ch);
    }
    final surface = _surfaceStack(context, ch);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbkSpace.s24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: AbkRadius.brMd,
          child: AspectRatio(aspectRatio: 16 / 9, child: surface),
        ),
        const SizedBox(height: AbkSpace.s16),
        _meta(context, ch),
      ]),
    );
  }

  Widget _lockedPlaceholder(BuildContext context, LiveChannel ch) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(AbkSpace.s24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(color: Colors.black, borderRadius: AbkRadius.brMd),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_rounded, size: 40, color: c.textMuted),
                const SizedBox(height: 12),
                Text(ch.name, style: context.type.caption.copyWith(color: Colors.white70)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: AbkSpace.s16),
        AbkButton(context.tr('play'),
            icon: Icons.lock_open_rounded, onPressed: () => playChannel(context, ref, ch)),
      ]),
    );
  }

  Widget _videoSurface(LiveChannel ch) {
    final svc = _svc;
    if (svc is VideoPlayerPlaybackService) {
      final ctrl = svc.controller;
      if (ctrl != null && ctrl.value.isInitialized && _state.status == PlaybackStatus.playing) {
        return Center(
          child: AspectRatio(
            aspectRatio: ctrl.value.aspectRatio == 0 ? 16 / 9 : ctrl.value.aspectRatio,
            child: VideoPlayer(ctrl),
          ),
        );
      }
    }
    // Not yet decoding → channel identity on black.
    return Center(
      child: SizedBox(
        width: 96, height: 64,
        child: AbkImage(url: ch.icon, fit: BoxFit.contain, fallback: LogoFallback(ch.name)),
      ),
    );
  }

  Widget _surfaceStack(BuildContext context, LiveChannel ch) {
    final c = context.c;
    final phase = _phase;
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black),
      _videoSurface(ch),
      if (phase == _PreviewPhase.loading)
        Center(child: CircularProgressIndicator(color: c.accentPrimary)),
      if (phase == _PreviewPhase.error)
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, color: c.error, size: 32),
            const SizedBox(height: 8),
            AbkButton(context.tr('retry'),
                kind: AbkButtonKind.ghost, onPressed: () => _load(ch)),
          ]),
        ),
      // Top gradient + channel identity + LIVE badge.
      Positioned(
        top: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent]),
          ),
          child: Row(children: [
            const LiveBadge(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(ch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.cardTitle.copyWith(color: Colors.white)),
            ),
          ]),
        ),
      ),
      // Bottom control row (pinned — the surface is small / focus-navigable).
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]),
          ),
          child: Row(children: [
            _pvBtn(
              icon: _state.status == PlaybackStatus.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              tooltip: context.tr(_state.status == PlaybackStatus.playing ? 'pause' : 'play'),
              focusNode: _fsFocus,
              onTap: _togglePlay,
            ),
            if (widget.siblings.length > 1) ...[
              _pvBtn(
                  icon: Icons.skip_previous_rounded,
                  tooltip: context.tr('prevChannel'),
                  onTap: _hasPrev ? () => _go(-1) : null),
              _pvBtn(
                  icon: Icons.skip_next_rounded,
                  tooltip: context.tr('nextChannel'),
                  onTap: _hasNext ? () => _go(1) : null),
            ],
            const Spacer(),
            _pvBtn(
              icon: Icons.fullscreen_rounded,
              tooltip: context.tr('fullscreen'),
              onTap: widget.onToggleFullscreen,
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _pvBtn(
          {required IconData icon,
          required String tooltip,
          VoidCallback? onTap,
          FocusNode? focusNode}) =>
      _liveCtrlBtn(icon: icon, tooltip: tooltip, onTap: onTap, focusNode: focusNode);

  Widget _meta(BuildContext context, LiveChannel ch) {
    final c = context.c;
    final now = _epg.isNotEmpty ? _epg[0].title : null;
    final next = _epg.length > 1 ? _epg[1].title : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(ch.name, style: context.type.sectionTitle),
      Text('${ch.viewOrder ?? ch.id}', style: context.type.metadata),
      if (now != null) ...[
        const SizedBox(height: AbkSpace.s12),
        Text('${context.tr('liveBadge')}: $now',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.body.copyWith(color: c.accentPrimary)),
      ],
      if (next != null)
        Text('› $next',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(color: c.textMuted)),
    ]);
  }
}

/// Shared focusable player control button (embedded preview + fullscreen).
Widget _liveCtrlBtn(
    {required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    FocusNode? focusNode,
    bool autofocus = false,
    double size = 28}) {
  final enabled = onTap != null;
  return AbkFocusable(
    onTap: onTap,
    disabled: !enabled,
    focusNode: focusNode,
    autofocus: autofocus,
    radius: AbkRadius.brMd,
    semanticLabel: tooltip,
    builder: (ctx, states) {
      final focused = states.contains(WidgetState.focused);
      return Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: focused ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: AbkRadius.brMd,
        ),
        child: Icon(icon, size: size, color: enabled ? Colors.white : Colors.white30),
      );
    },
  );
}

/// TRUE fullscreen for the Live preview: a root route (above the shell, so no
/// sidebar/menu — only the video). Renders the SAME shared decode session, so
/// entering/exiting never reloads the stream. Prev/Next drive [_selChannelProvider]
/// (the embedded pane performs the actual in-place switch); Back exits.
class _LiveFullscreenScreen extends ConsumerStatefulWidget {
  final List<LiveChannel> siblings;
  const _LiveFullscreenScreen({required this.siblings});
  @override
  ConsumerState<_LiveFullscreenScreen> createState() => _LiveFullscreenScreenState();
}

class _LiveFullscreenScreenState extends ConsumerState<_LiveFullscreenScreen> {
  late final PlaybackService _svc = ref.read(playbackServiceProvider);
  StreamSubscription<PlaybackState>? _sub;
  PlaybackState _state = PlaybackState.idle;
  bool _controls = true;
  Timer? _hide;
  final FocusNode _focus = FocusNode(debugLabel: 'live.fs');
  final FocusNode _playFocus = FocusNode(debugLabel: 'live.fs.play');

  @override
  void initState() {
    super.initState();
    _state = _svc.state;
    _sub = _svc.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    // Immersive → hide any system bars so it is video-only.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _bump();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hide?.cancel();
    _focus.dispose();
    _playFocus.dispose();
    // NOTE: does NOT stop the shared service — the embedded pane still owns it,
    // so returning to Live shows the same channel still playing.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _bump() {
    setState(() => _controls = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controls = false);
    });
  }

  LiveChannel? get _ch => ref.read(_selChannelProvider);
  int get _index => widget.siblings.indexWhere((c) => c.id == _ch?.id);
  bool get _hasPrev => _index > 0;
  bool get _hasNext => _index >= 0 && _index < widget.siblings.length - 1;
  void _go(int d) {
    final i = _index;
    if (i < 0) return;
    final n = i + d;
    if (n < 0 || n >= widget.siblings.length) return;
    ref.read(_selChannelProvider.notifier).state = widget.siblings[n];
    _bump();
  }

  void _togglePlay() {
    _state.status == PlaybackStatus.playing ? _svc.pause() : _svc.play();
    _bump();
  }

  Widget _surface(LiveChannel? ch) {
    final svc = _svc;
    if (svc is VideoPlayerPlaybackService) {
      final ctrl = svc.controller;
      if (ctrl != null && ctrl.value.isInitialized && _state.status == PlaybackStatus.playing) {
        return Center(
          child: AspectRatio(
            aspectRatio: ctrl.value.aspectRatio == 0 ? 16 / 9 : ctrl.value.aspectRatio,
            child: VideoPlayer(ctrl),
          ),
        );
      }
    }
    return Center(
      child: ch == null
          ? const SizedBox.shrink()
          : SizedBox(
              width: 120, height: 80,
              child: AbkImage(url: ch.icon, fit: BoxFit.contain, fallback: LogoFallback(ch.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ch = ref.watch(_selChannelProvider);
    final preview = ref.watch(_previewProvider);
    final loading = preview.phase == _PreviewPhase.loading;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        // Any key re-reveals the controls (then they auto-hide again).
        onKeyEvent: (node, e) {
          if (e is KeyDownEvent && !_controls) {
            _bump();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _playFocus.requestFocus();
            });
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          onHover: (_) => _bump(),
          child: Stack(fit: StackFit.expand, children: [
            _surface(ch),
            if (loading) Center(child: CircularProgressIndicator(color: c.accentPrimary)),
            AnimatedOpacity(
              opacity: _controls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controls,
                child: ExcludeFocus(
                  excluding: !_controls,
                  child: Column(children: [
                    // Top: back + channel identity.
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(children: [
                          _liveCtrlBtn(
                              icon: Icons.arrow_back_rounded,
                              tooltip: context.tr('back'),
                              onTap: () => Navigator.of(context).maybePop()),
                          const SizedBox(width: 4),
                          const LiveBadge(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(ch?.name ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.type.cardTitle.copyWith(color: Colors.white)),
                          ),
                        ]),
                      ),
                    ),
                    const Spacer(),
                    // Bottom: transport controls.
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(children: [
                          _liveCtrlBtn(
                            icon: _state.status == PlaybackStatus.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            tooltip: context.tr(
                                _state.status == PlaybackStatus.playing ? 'pause' : 'play'),
                            focusNode: _playFocus,
                            autofocus: true,
                            onTap: _togglePlay,
                          ),
                          if (widget.siblings.length > 1) ...[
                            _liveCtrlBtn(
                                icon: Icons.skip_previous_rounded,
                                tooltip: context.tr('prevChannel'),
                                onTap: _hasPrev ? () => _go(-1) : null),
                            _liveCtrlBtn(
                                icon: Icons.skip_next_rounded,
                                tooltip: context.tr('nextChannel'),
                                onTap: _hasNext ? () => _go(1) : null),
                          ],
                          const Spacer(),
                          _liveCtrlBtn(
                              icon: Icons.fullscreen_exit_rounded,
                              tooltip: context.tr('exitFullscreen'),
                              onTap: () => Navigator.of(context).maybePop()),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
