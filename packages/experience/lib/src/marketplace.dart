import 'package:flutter/foundation.dart';

import 'catalog.dart';

enum MarketplaceStatus { idle, loading, ready, empty, failure }

final class MarketplaceState {
  const MarketplaceState({
    required this.status,
    this.query = '',
    this.results = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.selectedItem,
  });

  final MarketplaceStatus status;
  final String query;
  final List<CatalogItem> results;
  final List<CatalogCategory> categories;
  final String? selectedCategoryId;
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
        categories: _state.categories,
        selectedCategoryId: _state.selectedCategoryId,
        selectedItem: _state.selectedItem,
      ),
    );
    try {
      final values = await Future.wait<Object>([
        if (_state.categories.isEmpty)
          _remote.categories()
        else
          Future<CatalogPage<CatalogCategory>>.value(
            CatalogPage(
              items: _state.categories,
              hasMore: false,
              projectionStatus: ProjectionStatus.fresh,
              generatedAt: DateTime.now().toUtc(),
            ),
          ),
        normalized.isEmpty
            ? _remote.items(categoryId: _state.selectedCategoryId)
            : _remote.search(
                query: normalized,
                categoryId: _state.selectedCategoryId,
              ),
      ]);
      final categories = values[0] as CatalogPage<CatalogCategory>;
      final page = values[1] as CatalogPage<CatalogItem>;
      _set(
        MarketplaceState(
          status: page.items.isEmpty
              ? MarketplaceStatus.empty
              : MarketplaceStatus.ready,
          query: normalized,
          results: page.items,
          categories: categories.items,
          selectedCategoryId: _state.selectedCategoryId,
          selectedItem: _state.selectedItem,
        ),
      );
    } catch (_) {
      _set(
        MarketplaceState(
          status: MarketplaceStatus.failure,
          query: normalized,
          results: _state.results,
          categories: _state.categories,
          selectedCategoryId: _state.selectedCategoryId,
          selectedItem: _state.selectedItem,
        ),
      );
    }
  }

  Future<void> selectCategory(String? categoryId) async {
    _set(
      MarketplaceState(
        status: _state.status,
        query: _state.query,
        results: _state.results,
        categories: _state.categories,
        selectedCategoryId: categoryId,
        selectedItem: _state.selectedItem,
      ),
    );
    await discover(_state.query);
  }

  Future<void> openItem(String id) async {
    _set(
      MarketplaceState(
        status: MarketplaceStatus.loading,
        query: _state.query,
        results: _state.results,
        categories: _state.categories,
        selectedCategoryId: _state.selectedCategoryId,
      ),
    );
    try {
      _set(
        MarketplaceState(
          status: MarketplaceStatus.ready,
          query: _state.query,
          results: _state.results,
          categories: _state.categories,
          selectedCategoryId: _state.selectedCategoryId,
          selectedItem: await _remote.item(id),
        ),
      );
    } catch (_) {
      _set(
        MarketplaceState(
          status: MarketplaceStatus.failure,
          query: _state.query,
          results: _state.results,
          categories: _state.categories,
          selectedCategoryId: _state.selectedCategoryId,
        ),
      );
    }
  }

  void _set(MarketplaceState value) {
    _state = value;
    notifyListeners();
  }
}
