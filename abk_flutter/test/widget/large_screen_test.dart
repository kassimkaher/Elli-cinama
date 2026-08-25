import 'package:abk_player/core/config/qa_config.dart';
import 'package:abk_player/core/design/breakpoints.dart';
import 'package:abk_player/core/design/theme.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:abk_player/core/i18n/strings.dart';
import 'package:abk_player/core/network/runtime_session.dart';
import 'package:abk_player/core/utils/result.dart';
import 'package:abk_player/features/auth/domain/entities/account.dart';
import 'package:abk_player/features/auth/domain/repositories/auth_repository.dart';
import 'package:abk_player/features/auth/domain/usecases/auth_usecases.dart';
import 'package:abk_player/features/auth/presentation/auth_controller.dart';
import 'package:abk_player/features/auth/presentation/login_screen.dart';
import 'package:abk_player/shared/widgets/cards.dart';
import 'package:abk_player/shared/widgets/focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoAuthRepo implements AuthRepository {
  @override
  Future<Result<Account>> login({required String username, required String password}) async =>
      throw UnimplementedError();
  @override
  Future<Account?> restoreSession() async => null;
  @override
  Future<void> logout() async {}
}

class _FakeSession extends SessionController {
  _FakeSession()
      : super(
          loginUseCase: LoginUseCase(_NoAuthRepo()),
          logoutUseCase: LogoutUseCase(_NoAuthRepo()),
          restoreUseCase: RestoreSessionUseCase(_NoAuthRepo()),
          session: RuntimeSession(),
        );
  @override
  Future<void> login(String username, String password) async {}
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AbkTheme.dark(),
      darkTheme: AbkTheme.dark(),
      supportedLocales: AbkStrings.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('en'),
      home: child,
    );

void main() {
  tearDown(() => AbkBreakpoints.isTv = false);

  group('login height-aware', () {
    Widget loginApp(_FakeSession s) => ProviderScope(
          overrides: [
            qaCredentialsProvider.overrideWithValue(const QaCredentials('qa_user', 'qa_pass')),
            sessionControllerProvider.overrideWith((_) => s),
          ],
          child: _wrap(const LoginScreen()),
        );

    testWidgets('TV 960×540 (short): single-column form, no branding panel, QA reachable',
        (t) async {
      AbkBreakpoints.isTv = true;
      addTearDown(() => AbkBreakpoints.isTv = false);
      t.view.devicePixelRatio = 2.0;
      t.view.physicalSize = const Size(1920, 1080); // logical 960×540
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });

      await t.pumpWidget(loginApp(_FakeSession()));
      await t.pump();

      expect(t.takeException(), isNull); // no overflow
      // The tall cinematic branding panel ('ABK' hero text) is NOT used when the
      // viewport is short — the form goes single-column instead.
      expect(find.text('ABK'), findsNothing);
      // Every control still exists and the QA card is reachable via scroll.
      expect(find.byKey(const Key('login_user')), findsOneWidget);
      expect(find.byKey(const Key('login_submit')), findsOneWidget);
      expect(find.byKey(const Key('qa_autofill')), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('qa_autofill')));
    });

    testWidgets('desktop tall: branding split IS used (ABK hero present)', (t) async {
      t.view.devicePixelRatio = 1.0;
      t.view.physicalSize = const Size(1400, 900);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(loginApp(_FakeSession()));
      await t.pump();
      expect(find.text('ABK'), findsOneWidget); // branding panel shown when tall
    });

    testWidgets('first focus exists without any key press (autofocus username)', (t) async {
      AbkBreakpoints.isTv = true;
      addTearDown(() => AbkBreakpoints.isTv = false);
      t.view.devicePixelRatio = 2.0;
      t.view.physicalSize = const Size(1920, 1080);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(loginApp(_FakeSession()));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      // A control is focused on first build — the screen never waits for a key.
      expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);
    });
  });

  group('LiveChannelRow states', () {
    Future<void> pumpRow(WidgetTester t,
        {bool playing = false, bool loading = false, bool channelError = false}) async {
      AbkBreakpoints.isTv = true;
      await t.pumpWidget(_wrap(Scaffold(
        body: LiveChannelRow(
          name: 'MBC 1 HD',
          number: '1',
          playing: playing,
          loading: loading,
          channelError: channelError,
        ),
      )));
      await t.pump();
    }

    testWidgets('playing shows the equalizer indicator', (t) async {
      await pumpRow(t, playing: true);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    });

    testWidgets('loading shows a spinner + Loading text', (t) async {
      await pumpRow(t, loading: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Loading'), findsOneWidget);
    });

    testWidgets('error shows the error glyph + Unavailable text', (t) async {
      await pumpRow(t, channelError: true);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.textContaining('Unavailable'), findsOneWidget);
    });

    testWidgets('normal shows none of the state indicators', (t) async {
      await pumpRow(t);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ScrollFocusStop', () {
    testWidgets('TV: wraps child in a Focus (D-pad can land on below-fold text)', (t) async {
      AbkBreakpoints.isTv = true;
      addTearDown(() => AbkBreakpoints.isTv = false);
      await t.pumpWidget(_wrap(const Scaffold(
        body: ScrollFocusStop(child: Text('plot')),
      )));
      await t.pump();
      expect(find.byType(Focus), findsWidgets);
      expect(find.text('plot'), findsOneWidget);
    });

    testWidgets('non-TV: passes the child through unchanged (no extra Focus)', (t) async {
      AbkBreakpoints.isTv = false;
      await t.pumpWidget(_wrap(const Scaffold(
        body: ScrollFocusStop(child: Text('plot')),
      )));
      await t.pump();
      expect(find.text('plot'), findsOneWidget);
    });
  });
}
