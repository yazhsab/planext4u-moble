import 'package:flutter/foundation.dart';

import 'catalog.dart';

enum MarketplaceStatus { idle, loading, ready, empty, failure }

final class MarketplaceState {
  const MarketplaceState({
    required this.status,
    this.query = '',
    this.results = const [],
    this.selectedItem,
  });

  final MarketplaceStatus status;
  final String query;
  final List<CatalogItem> results;
  final CatalogItem? selectedItem;
}

final class MarketplaceController extends ChangeNotifier {
  MarketplaceController({required CatalogRemote remote}) : _remote = remote;

  final CatalogRemote _remote;
  MarketplaceState _state = const MarketplaceState(
    status: MarketplaceStatus.idle,
  );
  MarketplaceState get state => _state;

  Future<void> discover([String query = '']) async {
    final normalized = query.trim();
    _set(
      MarketplaceState(
        status: MarketplaceStatus.loading,
        query: normalized,
        results: _state.results,
        selectedItem: _state.selectedItem,
      ),
    );
    try {
      final page = normalized.isEmpty
          ? await _remote.items()
          : await _remote.search(query: normalized);
      _set(
        MarketplaceState(
          status: page.items.isEmpty
              ? MarketplaceStatus.empty
              : MarketplaceStatus.ready,
          query: normalized,
          results: page.items,
          selectedItem: _state.selectedItem,
        ),
      );
    } catch (_) {
      _set(
        MarketplaceState(
          status: MarketplaceStatus.failure,
          query: normalized,
          results: _state.results,
          selectedItem: _state.selectedItem,
        ),
      );
    }
  }

  Future<void> openItem(String id) async {
    _set(
      MarketplaceState(
        status: MarketplaceStatus.loading,
        query: _state.query,
        results: _state.results,
      ),
    );
    try {
      _set(
        MarketplaceState(
          status: MarketplaceStatus.ready,
          query: _state.query,
          results: _state.results,
          selectedItem: await _remote.item(id),
        ),
      );
    } catch (_) {
      _set(
        MarketplaceState(
          status: MarketplaceStatus.failure,
          query: _state.query,
          results: _state.results,
        ),
      );
    }
  }

  void _set(MarketplaceState value) {
    _state = value;
    notifyListeners();
  }
}
