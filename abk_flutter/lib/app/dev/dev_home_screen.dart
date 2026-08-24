import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/utils/result.dart';
import '../../features/auth/presentation/auth_controller.dart';

/// TEMPORARY engineering UI — validates the data layer end to end. Not product
/// design; the real UI comes from Cloud Design. Intentionally unstyled.
class DevHomeScreen extends ConsumerStatefulWidget {
  const DevHomeScreen({super.key});
  @override
  ConsumerState<DevHomeScreen> createState() => _DevHomeScreenState();
}

class _DevHomeScreenState extends ConsumerState<DevHomeScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _log = <String>[];
  bool _busy = false;

  void _out(String line) => setState(() => _log.insert(0, line));

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      _out('$label …');
      _out('$label → ${await action()}');
    } catch (e) {
      _out('$label ✗ $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(sessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ABK Foundation — dev')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusLine(auth),
            const SizedBox(height: 8),
            if (auth is! AuthAuthenticated) _loginForm(auth) else _dashboard(),
            const Divider(height: 24),
            const Text('Log', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView(
                children: _log
                    .map((l) => Text(l, style: const TextStyle(fontSize: 12)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusLine(AuthState auth) {
    final text = switch (auth) {
      AuthLoggedOut() => 'Logged out',
      AuthAuthenticating() => 'Authenticating…',
      AuthAuthenticated(:final account) =>
        'Authenticated (status=${account.status}) — ${account.message}',
      AuthError(:final failure, :final kind) => 'Error [$kind]: ${failure.message}',
    };
    return Text(text);
  }

  Widget _loginForm(AuthState auth) {
    return Column(
      children: [
        TextField(controller: _user, decoration: const InputDecoration(labelText: 'Username')),
        TextField(
          controller: _pass,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: (_busy || auth is AuthAuthenticating)
              ? null
              : () => ref
                  .read(sessionControllerProvider.notifier)
                  .login(_user.text.trim(), _pass.text),
          child: const Text('Login'),
        ),
      ],
    );
  }

  Widget _dashboard() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _btn('Live', () async {
          final cats = await ref.read(getLiveCategoriesProvider).call();
          final chans = await ref.read(getLiveChannelsProvider).call();
          return 'cats=${_count(cats)} channels=${_count(chans)}';
        }),
        _btn('Movies', () async {
          final c = await ref.read(getMovieCategoriesProvider).call();
          final l = await ref.read(getMoviesProvider).call();
          return 'cats=${_count(c)} movies=${_count(l)}';
        }),
        _btn('Series', () async {
          final c = await ref.read(getSeriesCategoriesProvider).call();
          final l = await ref.read(getSeriesProvider).call();
          return 'cats=${_count(c)} series=${_count(l)}';
        }),
        _btn('Play 1st channel (smoke)', () async {
          final chans = await ref.read(getLiveChannelsProvider).call();
          if (chans is! Ok) return 'channels failed';
          final list = (chans as Ok).value as List;
          if (list.isEmpty) return 'no channels';
          final ch = list.first;
          final url = ref.read(resolveLiveStreamUrlProvider).call(ch);
          if (url == null) return 'no stream_url';
          final src = ref.read(playbackSourceFactoryProvider).fromUrl(url, title: ch.name);
          await ref.read(playbackServiceProvider).load(src);
          await ref.read(playbackServiceProvider).play();
          return 'loaded (${src.container.name}) state=${ref.read(playbackServiceProvider).state.status.name}';
        }),
        _btn('EPG (1st channel)', () async {
          final chans = await ref.read(getLiveChannelsProvider).call();
          if (chans is! Ok) return 'channels failed';
          final list = (chans as Ok).value as List;
          if (list.isEmpty) return 'no channels';
          final res = await ref.read(getShortEpgProvider).call(list.first.id as int);
          return res.fold((l) => 'listings=${l.length}', (f) => 'fail: ${f.message}');
        }),
        OutlinedButton(
          onPressed: _busy ? null : () => ref.read(sessionControllerProvider.notifier).logout(),
          child: const Text('Logout'),
        ),
      ],
    );
  }

  Widget _btn(String label, Future<String> Function() action) =>
      FilledButton.tonal(onPressed: _busy ? null : () => _run(label, action), child: Text(label));

  String _count(Object result) => result is Ok ? '${(result.value as List).length}' : 'ERR';
}
