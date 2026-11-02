import 'package:flutter/material.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

/// The browser only collects provider input. Resuming the owning API is the
/// sole source of a verified result; app lifecycle/deep-link events are not proof.
Future<VerifiedBankAccount?> showHostedBankLinkDialog(
  BuildContext context, {
  required HostedBankLinkClient client,
  required Future<bool> Function(Uri url) launch,
}) => showDialog<VerifiedBankAccount>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _HostedBankLinkDialog(client: client, launch: launch),
);

final class _HostedBankLinkDialog extends StatefulWidget {
  const _HostedBankLinkDialog({required this.client, required this.launch});
  final HostedBankLinkClient client;
  final Future<bool> Function(Uri) launch;
  @override
  State<_HostedBankLinkDialog> createState() => _HostedBankLinkDialogState();
}

final class _HostedBankLinkDialogState extends State<_HostedBankLinkDialog>
    with WidgetsBindingObserver {
  HostedBankLink? _link;
  bool _busy = true;
  bool _launched = false;
  String? _message;

  bool get _tamil => Localizations.localeOf(context).languageCode == 'ta';
  String _text(String en, String ta) => _tamil ? ta : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(initial: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _launched && !_busy) {
      _load();
    }
  }

  Future<void> _load({bool initial = false, bool restart = false}) async {
    if (!widget.client.isActive) return;
    if (!initial) {
      setState(() {
        _busy = true;
        _message = null;
      });
    }
    try {
      var value = restart ? null : (_link ?? await widget.client.current());
      if (value == null) {
        value = await widget.client.start();
      } else if (!value.terminal) {
        value = await widget.client.resume(value.attemptId);
      }
      if (!mounted || !widget.client.isActive) return;
      setState(() => _link = value);
    } on ApiAuthorizationFailure {
      if (mounted) {
        setState(
          () => _message = _text(
            'Sign in again before linking your bank account.',
            'வங்கிக் கணக்கை இணைக்கும் முன் மீண்டும் உள்நுழையவும்.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _text(
            'Bank verification could not be checked. Retry with an active connection. Your saved attempt can be resumed.',
            'வங்கி சரிபார்ப்பைச் சரிபார்க்க முடியவில்லை. இணைய இணைப்புடன் மீண்டும் முயற்சிக்கவும். சேமித்த முயற்சியைத் தொடரலாம்.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openProvider() async {
    final id = _link?.attemptId;
    if (_busy || id == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // Reissue and revalidate a short-lived URL immediately before launch.
      final value = await widget.client.resume(id);
      if (!mounted || !widget.client.isActive) return;
      setState(() => _link = value);
      if (value.launchUrl == null) return;
      _launched = true;
      if (!await widget.launch(value.launchUrl!)) {
        if (mounted) {
          setState(
            () => _message = _text(
              'The secure bank page could not open. Retry.',
              'பாதுகாப்பான வங்கிப் பக்கத்தைத் திறக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _text(
            'The bank provider is unavailable. Retry or resume later.',
            'வங்கி சேவை கிடைக்கவில்லை. மீண்டும் முயற்சிக்கவும் அல்லது பிறகு தொடரவும்.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final id = _link?.attemptId;
    if (_busy || id == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final value = await widget.client.cancel(id);
      if (!mounted || !widget.client.isActive) return;
      if (value.terminal) {
        Navigator.pop(context);
      } else {
        setState(() => _link = value);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _text(
            'Cancellation was not confirmed. Retry; closing keeps the attempt available to resume.',
            'ரத்து உறுதியாகவில்லை. மீண்டும் முயற்சிக்கவும்; மூடினால் பிறகு தொடரலாம்.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useVerified() async {
    if (_busy || _link == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final value = await widget.client.resume(_link!.attemptId);
      if (!mounted || !widget.client.isActive) return;
      if (value.status == 'VERIFIED' && value.account != null) {
        Navigator.pop(context, value.account);
      } else {
        setState(() => _link = value);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _text(
            'The verified result could not be refreshed. Retry.',
            'சரிபார்ப்பு முடிவைப் புதுப்பிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _link;
    final account = value?.account;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          _text('Verify bank account', 'வங்கிக் கணக்கைச் சரிபார்க்கவும்'),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(
                    'Enter your bank details only on the secure provider page. Return here to check the result. Verification does not approve your application.',
                    'பாதுகாப்பான சேவைப் பக்கத்தில் மட்டும் வங்கி விவரங்களை உள்ளிடவும். முடிவைப் பார்க்க இங்கு திரும்பவும். சரிபார்ப்பு உங்கள் விண்ணப்பத்தை அங்கீகரிக்காது.',
                  ),
                ),
                const SizedBox(height: 16),
                if (_busy)
                  const LinearProgressIndicator(
                    key: ValueKey('bank-link-progress'),
                  ),
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(switch (value.status) {
                      'VERIFIED' => _text(
                        'Bank verified',
                        'வங்கி சரிபார்க்கப்பட்டது',
                      ),
                      'DECLINED' => _text(
                        'The provider could not verify this account. You may retry.',
                        'இந்தக் கணக்கைச் சரிபார்க்க முடியவில்லை. மீண்டும் முயற்சிக்கலாம்.',
                      ),
                      'EXPIRED' => _text(
                        'This bank link expired. Start a new verification.',
                        'இந்த இணைப்பு காலாவதியானது. புதிதாகச் சரிபார்க்கவும்.',
                      ),
                      'CANCELLED' => _text(
                        'Bank verification cancelled.',
                        'வங்கி சரிபார்ப்பு ரத்து செய்யப்பட்டது.',
                      ),
                      'VERIFYING' => _text(
                        'The provider is checking your account.',
                        'சேவை உங்கள் கணக்கைச் சரிபார்க்கிறது.',
                      ),
                      _ => _text(
                        'Complete the secure bank page, then check the result.',
                        'பாதுகாப்பான வங்கிப் பக்கத்தை முடித்து முடிவைச் சரிபார்க்கவும்.',
                      ),
                    }),
                  ),
                if (account != null)
                  Text('${account.holderName}\n•••• ${account.last4}'),
                if (_message != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      key: const ValueKey('bank-link-message'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('bank-link-close'),
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(
              _text('Close and resume later', 'மூடிப் பிறகு தொடரவும்'),
            ),
          ),
          if (value != null && !value.terminal && value.status != 'VERIFIED')
            TextButton(
              key: const ValueKey('bank-link-cancel'),
              onPressed: _busy ? null : _cancel,
              child: Text(
                _text('Cancel verification', 'சரிபார்ப்பை ரத்து செய்'),
              ),
            ),
          if (value?.terminal == true)
            FilledButton(
              key: const ValueKey('bank-link-restart'),
              onPressed: _busy ? null : () => _load(restart: true),
              child: Text(_text('Start again', 'மீண்டும் தொடங்கு')),
            ),
          if (value?.launchUrl != null)
            FilledButton(
              key: const ValueKey('bank-link-open'),
              onPressed: _busy ? null : _openProvider,
              child: Text(
                _text('Open secure bank page', 'பாதுகாப்பான வங்கிப் பக்கம்'),
              ),
            ),
          if (account != null)
            FilledButton(
              key: const ValueKey('bank-link-use'),
              onPressed: _busy ? null : _useVerified,
              child: Text(
                _text('Use verified bank', 'சரிபார்த்த வங்கியைப் பயன்படுத்து'),
              ),
            ),
          if (account == null && value?.terminal != true)
            OutlinedButton(
              key: const ValueKey('bank-link-refresh'),
              onPressed: _busy ? null : () => _load(),
              child: Text(_text('Check result', 'முடிவைச் சரிபார்')),
            ),
        ],
      ),
    );
  }
}
