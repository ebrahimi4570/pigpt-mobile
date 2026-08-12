import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/brand.dart';
import '../../core/deep_links.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/ui.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.mode = 'login'});
  final String mode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _register;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  bool _google = false;

  @override
  void initState() {
    super.initState();
    _register = widget.mode == 'register';
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    try {
      final m = await ref.read(authControllerProvider.notifier).fetchMethods();
      if (mounted) setState(() => _google = m.google);
    } catch (_) {}
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_register) {
        await auth.register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
          phone: _phone.text,
        );
      } else {
        await auth.login(_email.text, _password.text);
      }
      if (!mounted) return;
      final status = ref.read(authControllerProvider).status;
      if (status == AuthStatus.signedIn) {
        context.go('/chat');
      } else if (status == AuthStatus.needsVerification) {
        context.go('/auth/verify');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleLogin() async {
    final uri = Uri.parse(googleOAuthStartUrl());
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1A2E), PigptColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const PigptMark(size: 72)
                          .animate()
                          .fadeIn(duration: 450.ms)
                          .slideY(begin: -0.15, end: 0),
                      const SizedBox(height: 16),
                      Text(
                        PigptBrand.webDisplay,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        PigptBrand.taglineFa,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: PigptColors.inkMuted,
                            ),
                      ),
                      const SizedBox(height: 28),
                      SoftCard(
                        child: Column(
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('ورود')),
                                ButtonSegment(value: true, label: Text('ثبت‌نام')),
                              ],
                              selected: {_register},
                              onSelectionChanged: (s) =>
                                  setState(() => _register = s.first),
                            ),
                            const SizedBox(height: 16),
                            if (_register) ...[
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'نام نمایشی',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'تلفن (اختیاری)',
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'ایمیل',
                              ),
                              validator: (v) {
                                if (v == null || !v.contains('@')) {
                                  return 'ایمیل معتبر وارد کنید';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'رمز عبور',
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.length < 6) {
                                  return 'حداقل ۶ کاراکتر';
                                }
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: const TextStyle(color: PigptColors.danger),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(_register ? 'ایجاد حساب' : 'ورود'),
                            ),
                            if (_google) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _googleLogin,
                                icon: const Icon(Icons.g_mobiledata_rounded),
                                label: const Text('ورود با گوگل'),
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06, end: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.token});
  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  String? _msg;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.token != null && widget.token!.isNotEmpty) {
      _verify(widget.token!);
    }
  }

  Future<void> _verify(String token) async {
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(token);
      if (mounted) context.go('/chat');
    } on ApiException catch (e) {
      setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authControllerProvider).user?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('تأیید ایمیل')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PigptMark(size: 56),
            const SizedBox(height: 16),
            Text(
              'برای ادامه، ایمیل خود را تأیید کنید.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (email != null) ...[
              const SizedBox(height: 8),
              Text(email, textDirection: TextDirection.ltr),
            ],
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!, style: const TextStyle(color: PigptColors.danger)),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await ref
                            .read(authControllerProvider.notifier)
                            .resendVerification();
                        setState(() => _msg = 'ایمیل تأیید دوباره ارسال شد');
                      } on ApiException catch (e) {
                        setState(() => _msg = e.message);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('ارسال مجدد لینک تأیید'),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
  }
}
