import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/strings.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/images.dart';
import '../../../core/config/qa_config.dart';
import '../../../core/di/providers.dart';
import 'auth_controller.dart';

/// Login / Account (Design §11). Username + password only; no server/host
/// field. Always dark. Cinematic split on desktop/TV.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _passFocus = FocusNode();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) return;
    ref.read(sessionControllerProvider.notifier).login(_user.text.trim(), _pass.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlwaysDark(
      child: Builder(builder: (context) {
        final wc = context.wc;
        final split = AbkBreakpoints.isDesktopClass(wc) || wc == WidthClass.tv;
        final form = _Form(
          user: _user, pass: _pass, passFocus: _passFocus, onSubmit: _submit,
        );
        return Scaffold(
          backgroundColor: context.c.background,
          body: split
              ? Row(children: [
                  SizedBox(width: 460, child: Center(child: form)),
                  Expanded(
                    child: Stack(fit: StackFit.expand, children: [
                      Container(color: context.c.surface),
                      const Positioned.fill(child: BackdropScrim(heightFactor: 1)),
                      Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const AbkLogo.mark(size: 104),
                          const SizedBox(height: AbkSpace.s20),
                          Text('ABK',
                              style: context.type.hero.copyWith(
                                  color: context.c.textPrimary, letterSpacing: 6)),
                        ]),
                      ),
                    ]),
                  ),
                ])
              : Center(child: SingleChildScrollView(child: form)),
        );
      }),
    );
  }
}

class _Form extends ConsumerWidget {
  final TextEditingController user, pass;
  final FocusNode passFocus;
  final VoidCallback onSubmit;
  const _Form({required this.user, required this.pass, required this.passFocus, required this.onSubmit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final auth = ref.watch(sessionControllerProvider);
    final authing = auth is AuthAuthenticating;
    final error = auth is AuthError ? auth : null;
    final qa = ref.watch(qaCredentialsProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Padding(
        padding: const EdgeInsets.all(AbkSpace.s24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const AbkLogo.chip(size: 48),
          const SizedBox(height: AbkSpace.s24),
          Text(context.tr('loginTitle'), style: context.type.pageTitle),
          const SizedBox(height: AbkSpace.s4),
          Text(context.tr('loginSubtitle'), style: context.type.bodySecondary),
          const SizedBox(height: AbkSpace.s24),
          if (error != null && error.kind == AuthErrorKind.network)
            _Banner(context.tr('connectionError'), c.error),
          AbkTextField(
            key: const Key('login_user'),
            controller: user,
            label: context.tr('username'),
            hint: context.tr('enterUsername'),
            readOnly: authing,
            onSubmitted: (_) => passFocus.requestFocus(),
          ),
          const SizedBox(height: AbkSpace.s16),
          PasswordField(
            key: const Key('login_pass'),
            controller: pass,
            focusNode: passFocus,
            label: context.tr('password'),
            hint: context.tr('enterPassword'),
            showLabel: context.tr('show'),
            hideLabel: context.tr('hide'),
            readOnly: authing,
            onSubmitted: (_) => onSubmit(),
          ),
          if (error != null && error.kind == AuthErrorKind.auth) ...[
            const SizedBox(height: AbkSpace.s12),
            Text(context.tr('invalidCredentials'), style: context.type.caption.copyWith(color: c.error)),
          ],
          const SizedBox(height: AbkSpace.s24),
          AbkButton(
            key: const Key('login_submit'),
            authing ? context.tr('signingIn') : context.tr('signIn'),
            loading: authing,
            expand: true,
            onPressed: authing ? null : onSubmit,
          ),
          if (qa != null) ...[
            const SizedBox(height: AbkSpace.s16),
            _QaAutofillCard(
              enabled: !authing,
              onTap: () {
                user.text = qa.username;
                pass.text = qa.password;
              },
            ),
          ],
        ]),
      ),
    );
  }
}

/// Dev/QA-only autofill convenience. Fills the username/password fields with the
/// authorized test account (from --dart-define); it never submits, validates, or
/// bypasses auth — the user still presses Login. Rendered only when QA
/// credentials are configured, so it is absent from production/release builds.
class _QaAutofillCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool enabled;
  const _QaAutofillCard({required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('qa_autofill'),
          onTap: enabled ? onTap : null,
          borderRadius: AbkRadius.brSm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AbkSpace.s12, vertical: AbkSpace.s12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: AbkRadius.brSm,
              border: Border.all(color: c.borderSubtle),
            ),
            child: Row(children: [
              Icon(Icons.science_outlined, size: 18, color: c.accentPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('qaAccount'), style: context.type.caption.copyWith(color: c.textPrimary)),
                  Text(context.tr('qaFillHint'), style: context.type.metadata.copyWith(color: c.textMuted)),
                ]),
              ),
              Icon(Icons.bolt_rounded, size: 16, color: c.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AbkSpace.s16),
        padding: const EdgeInsets.all(AbkSpace.s12),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14), borderRadius: AbkRadius.brSm),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: context.type.caption.copyWith(color: context.c.textPrimary))),
        ]),
      );
}
