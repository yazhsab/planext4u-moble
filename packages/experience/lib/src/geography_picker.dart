import 'dart:async';
import 'package:flutter/material.dart';
import 'geography.dart';

String geographyText(BuildContext context, String english, String tamil) =>
    Localizations.localeOf(context).languageCode == 'ta' ? tamil : english;

final class GeographyPicker extends StatefulWidget {
  const GeographyPicker({required this.controller, super.key});
  final GeographyController controller;
  @override
  State<GeographyPicker> createState() => _GeographyPickerState();
}

final class _GeographyPickerState extends State<GeographyPicker> {
  final _query = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.status == GeographyStatus.idle) {
      unawaited(widget.controller.load());
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _query.dispose();
    super.dispose();
  }

  Future<void> _choose(GeographyReference value) async {
    _query.clear();
    final accepted = await widget.controller.choose(value);
    if (mounted && accepted && widget.controller.selection != null) {
      Navigator.pop(context, widget.controller.selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        locale = Localizations.localeOf(context).languageCode;
    final names = locale == 'ta'
        ? ['நாடு', 'மாநிலம்', 'மாவட்டம்', 'நகரம்', 'பகுதி']
        : ['Country', 'State', 'District', 'City', 'Area'];
    final level = names[geographyKinds.indexOf(c.kind)];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          geographyText(
            context,
            'Choose address area',
            'முகவரிப் பகுதியைத் தேர்ந்தெடுக்கவும்',
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              geographyText(
                context,
                'Choose $level',
                '$level தேர்ந்தெடுக்கவும்',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (c.path.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: c.path
                    .map((e) => Chip(label: Text(e.label(locale))))
                    .toList(),
              ),
              TextButton.icon(
                onPressed: c.status == GeographyStatus.loading
                    ? null
                    : () {
                        _query.clear();
                        unawaited(c.back());
                      },
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  geographyText(
                    context,
                    'Change parent',
                    'முந்தைய தேர்வை மாற்றவும்',
                  ),
                ),
              ),
            ],
            TextField(
              controller: _query,
              maxLength: 128,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: geographyText(
                  context,
                  'Search this level',
                  'இந்த நிலையில் தேடவும்',
                ),
                suffixIcon: IconButton(
                  tooltip: geographyText(context, 'Search', 'தேடு'),
                  onPressed: c.status == GeographyStatus.loading
                      ? null
                      : () => unawaited(c.load(query: _query.text.trim())),
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (value) => unawaited(c.load(query: value.trim())),
            ),
            if (c.status == GeographyStatus.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (c.status == GeographyStatus.failure) ...[
              Text(
                geographyText(
                  context,
                  'The geography directory is unavailable. Try again.',
                  'பகுதி விவரங்களைப் பெற முடியவில்லை. மீண்டும் முயலவும்.',
                ),
              ),
              FilledButton(
                onPressed: c.retry,
                child: Text(
                  geographyText(context, 'Try again', 'மீண்டும் முயலவும்'),
                ),
              ),
            ],
            if (c.status == GeographyStatus.ready &&
                c.page?.items.isEmpty == true)
              Text(
                geographyText(
                  context,
                  'No active records. Try another search or ask support to configure this area.',
                  'செயலில் உள்ள விவரங்கள் இல்லை. வேறு சொல்லைத் தேடவும் அல்லது உதவியை அணுகவும்.',
                ),
              ),
            for (final item in c.page?.items ?? const <GeographyReference>[])
              ListTile(
                key: ValueKey('geography-${item.id}'),
                title: Text(item.label(locale)),
                subtitle: Text(item.code),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => unawaited(_choose(item)),
              ),
            if (c.page?.nextAfter != null)
              OutlinedButton(
                onPressed: c.next,
                child: Text(
                  geographyText(context, 'Next results', 'அடுத்த முடிவுகள்'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
