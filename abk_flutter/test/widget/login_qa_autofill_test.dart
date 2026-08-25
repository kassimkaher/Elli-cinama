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

/// Records login() calls instead of hitting the network, so we can assert the
/// QA card never auto-submits and that the Login button still works.
class _FakeSession extends SessionController {
  int loginCalls = 0;
  String? lastUser, lastPass;
  _FakeSession()
      : super(
          loginUseCase: LoginUseCase(_NoAuthRepo()),
          logoutUseCase: LogoutUseCase(_NoAuthRepo()),
          restoreUseCase: RestoreSessionUseCase(_NoAuthRepo()),
          session: RuntimeSession(),
        );
  @override
  Future<void> login(String username, String password) async {
    loginCalls++;
    lastUser = username;
    lastPass = password;
  }
}

Widget _harness(_FakeSession session, {QaCredentials? qa}) => ProviderScope(
      overrides: [
        qaCredentialsProvider.overrideWithValue(qa),
        sessionControllerProvider.overrideWith((ref) => session),
      ],
      child: MaterialApp(
        theme: AbkTheme.dark(),
        darkTheme: AbkTheme.dark(),
        supportedLocales: AbkStrings.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const LoginScreen(),
      ),
    );

List<EditableText> _edits(WidgetTester t) => t.widgetList<EditableText>(find.byType(EditableText)).toList();

void main() {
  const key = Key('qa_autofill');

  testWidgets('TV projector (960×540, dpr2): login fits, no clip, QA fills via display', (t) async {
    AbkBreakpoints.isTv = true;
    addTearDown(() => AbkBreakpoints.isTv = false);
    t.view.devicePixelRatio = 2.0; // Nebula projector: density 320
    t.view.physicalSize = const Size(1920, 1080); // → logical 960×540
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });

    final s = _FakeSession();
    await t.pumpWidget(_harness(s, qa: const QaCredentials('qa_user', 'qa_pass')));
    await t.pump();

    // No RenderFlex overflow at the low TV height (form scrolls instead).
    expect(t.takeException(), isNull);

    // Every login control exists and is reachable (the scroll view holds them).
    expect(find.byKey(const Key('login_user')), findsOneWidget);
    expect(find.byKey(const Key('login_pass')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byKey(key), findsOneWidget);

    // The QA card is reachable (below the fold) via the scroll view, and
    // activating it fills the fields without auto-submitting.
    await t.ensureVisible(find.byKey(key));
    await t.tap(find.byKey(key));
    await t.pump();
    expect(s.loginCalls, 0, reason: 'QA autofill must not sign in');

    // Filled values reach login: pressing Login submits the QA credentials.
    await t.ensureVisible(find.byKey(const Key('login_submit')));
    await t.tap(find.byKey(const Key('login_submit')));
    await t.pump();
    expect(s.loginCalls, 1);
    expect(s.lastUser, 'qa_user');
    expect(s.lastPass, 'qa_pass');
  });

  testWidgets('QA card is hidden in production configuration (no QA creds)', (t) async {
    await t.pumpWidget(_harness(_FakeSession(), qa: null));
    expect(find.byKey(key), findsNothing);
  });

  testWidgets('QA card appears in QA/dev configuration', (t) async {
    await t.pumpWidget(_harness(_FakeSession(), qa: const QaCredentials('u123', 'p456')));
    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('tapping QA card fills username + password and does NOT auto-login', (t) async {
    final s = _FakeSession();
    await t.pumpWidget(_harness(s, qa: const QaCredentials('qa_user', 'qa_pass')));

    await t.tap(find.byKey(key));
    await t.pump();

    final edits = _edits(t);
    expect(edits.any((e) => e.controller.text == 'qa_user'), isTrue, reason: 'username filled');
    expect(edits.any((e) => e.controller.text == 'qa_pass'), isTrue, reason: 'password filled');
    expect(s.loginCalls, 0, reason: 'autofill must not submit');
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('populated values remain editable, and Login still works', (t) async {
    final s = _FakeSession();
    await t.pumpWidget(_harness(s, qa: const QaCredentials('qa_user', 'qa_pass')));

    await t.tap(find.byKey(key));
    await t.pump();

    // Edit the populated username (fields not locked).
    await t.enterText(find.byType(EditableText).first, 'edited_user');
    await t.pump();
    expect(_edits(t).any((e) => e.controller.text == 'edited_user'), isTrue);

    // Normal login flow unchanged: pressing Login submits explicitly.
    await t.tap(find.byKey(const Key('login_submit')));
    await t.pump();
    expect(s.loginCalls, 1);
    expect(s.lastUser, 'edited_user');
    expect(s.lastPass, 'qa_pass');
  });
}
