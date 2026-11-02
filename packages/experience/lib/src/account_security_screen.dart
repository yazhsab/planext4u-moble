import 'package:flutter/material.dart';

import 'account_security.dart';

final class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({required this.controller, super.key});
  final AccountSecurityController controller;

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen>
    with WidgetsBindingObserver {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  SignInMethod _method = SignInMethod.password;
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Native Google/phone flows can temporarily inactivate the app. Fully
    // hiding it locks the local grant and clears typed credentials.
    if ((state == AppLifecycleState.hidden && !widget.controller.busy) ||
        state == AppLifecycleState.detached) {
      widget.controller.lock();
      _clearSecrets();
    }
  }

  void _clearSecrets() {
    _password.clear();
    _code.clear();
    _codeSent = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_changed);
    widget.controller.lock();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final methods = controller.verified?.methods;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign-in methods')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Verify an existing sign-in method, then add another method to the same account. A method already used by another account cannot be merged.',
            ),
            const SizedBox(height: 16),
            if (methods != null)
              Text('Connected: ${methods.map(_label).join(', ')}'),
            if (controller.message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(controller.message!),
                ),
              ),
            DropdownButtonFormField<SignInMethod>(
              initialValue: _method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sign-in method'),
              items: const [
                DropdownMenuItem(
                  value: SignInMethod.password,
                  child: Text('Email and password'),
                ),
                DropdownMenuItem(
                  value: SignInMethod.google,
                  child: Text('Google'),
                ),
                DropdownMenuItem(
                  value: SignInMethod.phone,
                  child: Text('Phone verification code'),
                ),
              ],
              onChanged: controller.busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _method = value;
                        _clearSecrets();
                      });
                    },
            ),
            if (_method == SignInMethod.password) ...[
              TextField(
                key: const ValueKey('account-security-email'),
                controller: _email,
                enabled: !controller.busy,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                key: const ValueKey('account-security-password'),
                controller: _password,
                enabled: !controller.busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                maxLength: 4096,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  counterText: '',
                ),
              ),
            ],
            if (_method == SignInMethod.phone) ...[
              TextField(
                controller: _phone,
                enabled: !controller.busy,
                maxLength: 16,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone with country code',
                ),
                onChanged: (_) => setState(() {
                  _codeSent = false;
                  _code.clear();
                }),
              ),
              OutlinedButton(
                onPressed: controller.busy
                    ? null
                    : () async {
                        final success = await controller.requestPhoneCode(
                          _phone.text,
                        );
                        if (mounted) {
                          setState(() {
                            _codeSent = success;
                          });
                        }
                      },
                child: const Text('Send verification code'),
              ),
              TextField(
                controller: _code,
                enabled: !controller.busy && _codeSent,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  helperText:
                      'Leave empty if Android verified your number automatically.',
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  controller.busy || _method == SignInMethod.phone && !_codeSent
                  ? null
                  : () => _submit(false),
              child: const Text('Verify existing method'),
            ),
            OutlinedButton(
              onPressed:
                  controller.busy ||
                      !controller.unlocked ||
                      _method == SignInMethod.phone && !_codeSent
                  ? null
                  : () => _submit(true),
              child: const Text('Add this method'),
            ),
            TextButton(
              onPressed: controller.busy ? null : controller.refresh,
              child: const Text('Refresh connected methods'),
            ),
            if (methods?.contains('password') == true &&
                controller.verified?.emailVerified == false)
              TextButton(
                onPressed: controller.busy
                    ? null
                    : controller.sendEmailVerification,
                child: const Text('Send email verification'),
              ),
            if (controller.busy)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(bool link) async {
    final password = _password.text;
    final code = _code.text;
    _clearSecrets();
    if (link) {
      await widget.controller.link(
        _method,
        email: _email.text,
        password: password,
        code: code,
      );
    } else {
      await widget.controller.unlock(
        _method,
        email: _email.text,
        password: password,
        code: code,
      );
    }
  }
}

String _label(String value) => switch (value) {
  'password' => 'Email and password',
  'phone' => 'Phone',
  'google.com' => 'Google',
  'apple.com' => 'Apple',
  _ => value,
};
