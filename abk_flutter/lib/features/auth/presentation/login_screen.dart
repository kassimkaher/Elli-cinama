import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/qa_config.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/i18n/strings.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/focusable.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/images.dart';
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
    ref
        .read(sessionControllerProvider.notifier)
        .login(_user.text.trim(), _pass.text);
  }

  /// Centres the child when it fits and scrolls it (D-pad focus auto-reveals
  /// each control) when the viewport is short — so nothing is ever clipped on a
  /// low-logical-height TV/projector (e.g. 960×540 at dpr 2.0).
  Widget _scrollCenter(Widget child) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlwaysDark(
      child: Builder(
        builder: (context) {
          final wc = context.wc;
          final largeScreen =
              AbkBreakpoints.isDesktopClass(wc) || wc == WidthClass.tv;
          return Scaffold(
            backgroundColor: context.c.background,
            body: SafeArea(
              // Height-aware: adapt to BOTH width and available height, not width
              // alone. A wide-but-short viewport (e.g. a TV at 960×540 logical)
              // must NOT keep the tall side-by-side branding split — it starves
              // the form and pushes the QA card off-screen.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tallEnough = constraints.maxHeight >= 620;
                  final split = largeScreen && tallEnough;
                  // Compact vertical rhythm whenever height is tight or on TV.
                  final compact = !tallEnough || AbkBreakpoints.isTv;
                  final form = _Form(
                    user: _user,
                    pass: _pass,
                    passFocus: _passFocus,
                    onSubmit: _submit,
                    dense: largeScreen || compact,
                    compact: compact,
                  );
                  if (!split) return _scrollCenter(form);
                  return Row(
                    children: [
                      // Form column: min(46%, 460) so the branding panel keeps
                      // room on narrow logical widths.
                      SizedBox(
                        width: (MediaQuery.sizeOf(context).width * 0.46)
                            .clamp(360.0, 460.0),
                        child: _scrollCenter(form),
                      ),
                      Expanded(child: _BrandingPanel()),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Full-height cinematic branding panel — shown only on tall large-screen
/// layouts (desktop / TV with enough height). On short viewports the form goes
/// full-width instead, with a small inline lockup carrying the brand.
class _BrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Container(color: context.c.surface),
          const Positioned.fill(child: BackdropScrim(heightFactor: 1)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AbkLogo.mark(size: 96),
                const SizedBox(height: AbkSpace.s16),
                Text('ABK',
                    style: context.type.hero.copyWith(
                        color: context.c.textPrimary, letterSpacing: 6)),
              ],
            ),
          ),
        ],
      );
}

class _Form extends ConsumerWidget {
  final TextEditingController user, pass;
  final FocusNode passFocus;
  final VoidCallback onSubmit;
  final bool dense;
  final bool compact;
  const _Form({
    required this.user,
    required this.pass,
    required this.passFocus,
    required this.onSubmit,
    this.dense = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final auth = ref.watch(sessionControllerProvider);
    final authing = auth is AuthAuthenticating;
    final error = auth is AuthError ? auth : null;
    final qa = ref.watch(qaCredentialsProvider);

    // Compact vertical rhythm so the whole form fits a low logical height. When
    // `compact` (short/height-constrained, e.g. TV 540) the branding panel is
    // gone, so a small inline logo carries the brand and the subtitle is dropped.
    final gapLg = compact ? AbkSpace.s12 : (dense ? AbkSpace.s16 : AbkSpace.s24);
    final gapField = compact ? AbkSpace.s12 : AbkSpace.s16;
    final logo = compact ? 32.0 : (dense ? 56.0 : 100.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 400 : 380),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AbkSpace.s24, vertical: dense ? AbkSpace.s16 : AbkSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: AbkLogo.chip(size: logo)),
            // Tighter logo→title gap on the compact TV form.
            SizedBox(height: compact ? AbkSpace.s8 : gapLg),
            Text(context.tr('loginTitle'),
                style: compact ? context.type.sectionTitle : context.type.pageTitle),
            if (!compact) ...[
              const SizedBox(height: AbkSpace.s4),
              Text(context.tr('loginSubtitle'), style: context.type.bodySecondary),
            ],
            SizedBox(height: gapLg),
            if (error != null && error.kind == AuthErrorKind.network)
              _Banner(context.tr('connectionError'), c.error),
            AbkTextField(
              key: const Key('login_user'),
              controller: user,
              label: context.tr('username'),
              hint: context.tr('enterUsername'),
              readOnly: authing,
              dense: compact,
              autofocus: true, // visible initial focus on first frame (TV)
              onSubmitted: (_) => passFocus.requestFocus(),
            ),
            SizedBox(height: gapField),
            PasswordField(
              key: const Key('login_pass'),
              controller: pass,
              focusNode: passFocus,
              label: context.tr('password'),
              hint: context.tr('enterPassword'),
              showLabel: context.tr('show'),
              hideLabel: context.tr('hide'),
              readOnly: authing,
              dense: compact,
              onSubmitted: (_) => onSubmit(),
            ),
            if (error != null && error.kind == AuthErrorKind.auth) ...[
              const SizedBox(height: AbkSpace.s12),
              Text(
                context.tr('invalidCredentials'),
                style: context.type.caption.copyWith(color: c.error),
              ),
            ],
            SizedBox(height: gapLg),
            AbkButton(
              key: const Key('login_submit'),
              authing ? context.tr('signingIn') : context.tr('signIn'),
              loading: authing,
              expand: true,
              dense: compact,
              onPressed: authing ? null : onSubmit,
            ),
            if (qa != null) ...[
              SizedBox(height: compact ? AbkSpace.s8 : gapField),
              _QaAutofillCard(
                enabled: !authing,
                dense: compact,
                onTap: () {
                  user.text = qa.username;
                  pass.text = qa.password;
                  // After filling, move focus to Login (the control just above)
                  // so the remote user can press SELECT to sign in.
                  FocusScope.of(context).previousFocus();
                },
              ),
            ],
          ],
        ),
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
  final bool dense;
  const _QaAutofillCard({required this.onTap, this.enabled = true, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      // AbkFocusable → reachable by D-pad, activates on SELECT/OK/Enter, shows
      // the standard focus ring, and auto-scrolls into view when focused.
      child: AbkFocusable(
        key: const Key('qa_autofill'),
        onTap: enabled ? onTap : null,
        disabled: !enabled,
        radius: AbkRadius.brSm,
        semanticLabel: context.tr('qaAccount'),
        builder: (ctx, states) {
          final focused = states.contains(WidgetState.focused);
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: AbkSpace.s12,
              vertical: dense ? AbkSpace.s8 : AbkSpace.s12,
            ),
            decoration: BoxDecoration(
              color: focused ? c.surfaceStrong : c.surface,
              borderRadius: AbkRadius.brSm,
              border: Border.all(color: focused ? c.accentPrimary : c.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined, size: 18, color: c.accentPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('qaAccount'),
                          style: context.type.caption.copyWith(color: c.textPrimary)),
                      Text(context.tr('qaFillHint'),
                          style: context.type.metadata.copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.bolt_rounded, size: 16, color: c.textMuted),
              ],
            ),
          );
        },
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
      color: color.withValues(alpha: 0.14),
      borderRadius: AbkRadius.brSm,
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: context.type.caption.copyWith(color: context.c.textPrimary),
          ),
        ),
      ],
    ),
  );
}
