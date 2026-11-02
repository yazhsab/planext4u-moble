import 'dart:async';
import 'package:flutter/material.dart';
import 'profile_occupation.dart';

final class ProfileOccupationScreen extends StatefulWidget {
  const ProfileOccupationScreen({required this.controller, super.key});
  final ProfileOccupationController controller;
  @override
  State<ProfileOccupationScreen> createState() =>
      _ProfileOccupationScreenState();
}

class _ProfileOccupationScreenState extends State<ProfileOccupationScreen> {
  final _search = TextEditingController();
  String? _selected;
  int? _revision;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _search.text = widget.controller.state.search;
    _changed();
    unawaited(widget.controller.load());
  }

  void _changed() {
    final current = widget.controller.state.current;
    if (current != null && current.revision != _revision) {
      _revision = current.revision;
      _selected = current.occupation?.id;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.controller.save(_selected);
    if (!mounted) return;
    final tamil = Localizations.localeOf(context).languageCode == 'ta';
    final saved = widget.controller.state.saved;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? (tamil ? 'தொழில் சேமிக்கப்பட்டது.' : 'Occupation saved.')
              : (tamil
                    ? 'சேமிப்பை உறுதிப்படுத்த முடியவில்லை. புதுப்பித்து மீண்டும் முயலவும்.'
                    : 'Could not confirm the save. Refresh before trying again.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tamil = Localizations.localeOf(context).languageCode == 'ta';
    String text(String en, String ta) => tamil ? ta : en;
    final state = widget.controller.state;
    final current = state.current;
    final canSave =
        !state.busy &&
        !state.failed &&
        current != null &&
        _selected != current.occupation?.id &&
        (_selected == null ||
            (state.page?.items.any((item) => item.id == _selected) ?? false));
    return Scaffold(
      appBar: AppBar(title: Text(text('Occupation', 'தொழில்'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              text(
                'Choose your occupation',
                'உங்கள் தொழிலைத் தேர்ந்தெடுக்கவும்',
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (current != null)
              Card(
                child: ListTile(
                  title: Text(text('Saved occupation', 'சேமித்த தொழில்')),
                  subtitle: Text(
                    current.occupation?.label(tamil ? 'ta' : 'en') ??
                        text('Not selected', 'தேர்ந்தெடுக்கவில்லை'),
                  ),
                ),
              ),
            Text(
              text(
                'Your saved choice stays available if the list changes. You can change or remove it here.',
                'பட்டியல் மாறினாலும் உங்கள் சேமித்த தேர்வு இருக்கும். இங்கே அதை மாற்றலாம் அல்லது நீக்கலாம்.',
              ),
            ),
            const SizedBox(height: 16),
            Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _search,
                    maxLength: 128,
                    enabled: !state.busy,
                    decoration: InputDecoration(
                      labelText: text('Search occupations', 'தொழில்களைத் தேடு'),
                    ),
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => unawaited(
                      widget.controller.search(_search.text.trim()),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => unawaited(
                            widget.controller.search(_search.text.trim()),
                          ),
                    icon: const Icon(Icons.search),
                    label: Text(text('Search', 'தேடு')),
                  ),
                ],
              ),
            ),
            if (state.busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.failed)
              Card(
                child: ListTile(
                  title: Text(
                    text(
                      'Could not confirm the latest occupation',
                      'சமீபத்திய தொழில் விவரத்தை உறுதிப்படுத்த முடியவில்லை',
                    ),
                  ),
                  subtitle: Text(
                    text(
                      'Refresh before trying again. Your choice may have changed on another device.',
                      'மீண்டும் முயல்வதற்கு முன் புதுப்பிக்கவும். வேறு சாதனத்தில் உங்கள் தேர்வு மாறியிருக்கலாம்.',
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: state.busy ? null : widget.controller.load,
                    child: Text(text('Refresh', 'புதுப்பி')),
                  ),
                ),
              ),
            if (state.saved)
              Semantics(
                liveRegion: true,
                child: Text(
                  text('Occupation saved.', 'தொழில் சேமிக்கப்பட்டது.'),
                ),
              ),
            if (!state.busy && state.page?.items.isEmpty == true)
              Text(
                text(
                  'No matching occupations. Try another search.',
                  'பொருந்தும் தொழில்கள் இல்லை. வேறு பெயரைத் தேடவும்.',
                ),
              ),
            for (final item in state.page?.items ?? const <ProfileOccupation>[])
              ListTile(
                key: ValueKey('occupation-${item.id}'),
                leading: Icon(
                  _selected == item.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                selected: _selected == item.id,
                title: Text(item.label(tamil ? 'ta' : 'en')),
                onTap: state.busy || state.failed
                    ? null
                    : () => setState(() => _selected = item.id),
              ),
            if (state.page?.nextAfter case final after?)
              OutlinedButton(
                onPressed: state.busy
                    ? null
                    : () => unawaited(
                        widget.controller.search(state.search, after: after),
                      ),
                child: Text(text('Next page', 'அடுத்த பக்கம்')),
              ),
            TextButton(
              onPressed: state.busy
                  ? null
                  : () => unawaited(widget.controller.search(state.search)),
              child: Text(text('First page', 'முதல் பக்கம்')),
            ),
            if (current?.occupation != null)
              OutlinedButton.icon(
                onPressed: state.busy || state.failed
                    ? null
                    : () => setState(() => _selected = null),
                icon: const Icon(Icons.clear),
                label: Text(text('Remove occupation', 'தொழிலை நீக்கு')),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('save-profile-occupation'),
              onPressed: canSave ? _save : null,
              icon: const Icon(Icons.save_outlined),
              label: Text(text('Save occupation', 'தொழிலைச் சேமி')),
            ),
          ],
        ),
      ),
    );
  }
}
