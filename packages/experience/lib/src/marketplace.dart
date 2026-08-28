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
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
    this.suggestions = const [],
    this.suggesting = false,
  });

  final MarketplaceStatus status;
  final String query;
  final List<CatalogItem> results;
  final List<CatalogCategory> categories;
  final String? selectedCategoryId;
  final CatalogItem? selectedItem;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;
  final List<DiscoverySuggestion> suggestions;
  final bool suggesting;
}

final class MarketplaceController extends ChangeNotifier {
  MarketplaceController({required CatalogRemote remote}) : _remote = remote;

  final CatalogRemote _remote;
  MarketplaceState _state = const MarketplaceState(
    status: MarketplaceStatus.idle,
  );
  MarketplaceState get state => _state;
  final List<String> _recentQueries = [];
  int _suggestionEpoch = 0;
  List<String> get recentQueries => List.unmodifiable(_recentQueries);

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
        nextCursor: _state.nextCursor,
        hasMore: _state.hasMore,
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
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
      if (normalized.isNotEmpty) {
        _recentQueries.remove(normalized);
        _recentQueries.insert(0, normalized);
        if (_recentQueries.length > 5) _recentQueries.removeLast();
      }
    } catch (_) {
      _set(
        MarketplaceState(
          status: MarketplaceStatus.failure,
          query: normalized,
          results: _state.results,
          categories: _state.categories,
          selectedCategoryId: _state.selectedCategoryId,
          selectedItem: _state.selectedItem,
          nextCursor: _state.nextCursor,
          hasMore: _state.hasMore,
        ),
      );
    }
  }

  Future<void> suggest(String query) async {
    final remote = _remote;
    if (remote is! DiscoverySuggestionRemote) return;
    final suggestionRemote = remote as DiscoverySuggestionRemote;
    final epoch = ++_suggestionEpoch;
    _set(
      MarketplaceState(
        status: _state.status,
        query: _state.query,
        results: _state.results,
        categories: _state.categories,
        selectedCategoryId: _state.selectedCategoryId,
        selectedItem: _state.selectedItem,
        nextCursor: _state.nextCursor,
        hasMore: _state.hasMore,
        loadingMore: _state.loadingMore,
        suggestions: _state.suggestions,
        suggesting: true,
      ),
    );
    try {
      final values = await suggestionRemote.suggestions(query.trim());
      if (epoch != _suggestionEpoch) return;
      _set(
        MarketplaceState(
          status: _state.status,
          query: _state.query,
          results: _state.results,
          categories: _state.categories,
          selectedCategoryId: _state.selectedCategoryId,
          selectedItem: _state.selectedItem,
          nextCursor: _state.nextCursor,
          hasMore: _state.hasMore,
          loadingMore: _state.loadingMore,
          suggestions: values,
        ),
      );
    } catch (_) {
      if (epoch != _suggestionEpoch) return;
      _set(
        MarketplaceState(
          status: _state.status,
          query: _state.query,
          results: _state.results,
          categories: _state.categories,
          selectedCategoryId: _state.selectedCategoryId,
          selectedItem: _state.selectedItem,
          nextCursor: _state.nextCursor,
          hasMore: _state.hasMore,
          loadingMore: _state.loadingMore,
        ),
      );
    }
  }

  void clearRecentQueries() {
    _recentQueries.clear();
    notifyListeners();
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
        nextCursor: _state.nextCursor,
        hasMore: _state.hasMore,
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
        nextCursor: _state.nextCursor,
        hasMore: _state.hasMore,
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
          nextCursor: _state.nextCursor,
          hasMore: _state.hasMore,
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
          nextCursor: _state.nextCursor,
          hasMore: _state.hasMore,
        ),
      );
    }
  }

  Future<void> askQuestion(String itemId, String question) async {
    final remote = _remote;
    if (remote is! CatalogQuestionRemote) {
      throw UnsupportedError('Customer questions are unavailable.');
    }
    await (remote as CatalogQuestionRemote).askQuestion(
      itemId: itemId,
      question: question.trim(),
    );
    await openItem(itemId);
  }

  Future<void> loadMore() async {
    if (!_state.hasMore || _state.nextCursor == null || _state.loadingMore) {
      return;
    }
    _set(
      MarketplaceState(
        status: _state.status,
        query: _state.query,
        results: _state.results,
        categories: _state.categories,
        selectedCategoryId: _state.selectedCategoryId,
        selectedItem: _state.selectedItem,
        nextCursor: _state.nextCursor,
        hasMore: _state.hasMore,
        loadingMore: true,
      ),
    );
    try {
      final page = _state.query.isEmpty
          ? await _remote.items(
              categoryId: _state.selectedCategoryId,
              cursor: _state.nextCursor,
            )
          : await _remote.search(
              query: _state.query,
              categoryId: _state.selectedCategoryId,
              cursor: _state.nextCursor,
            );
      final merged = <String, CatalogItem>{
        for (final value in _state.results) value.id: value,
        for (final value in page.items) value.id: value,
      }.values.toList(growable: false);
      _set(
        MarketplaceState(
          status: merged.isEmpty
              ? MarketplaceStatus.empty
              : MarketplaceStatus.ready,
          query: _state.query,
          results: merged,
          categories: _state.categories,
          selectedCategoryId: _state.selectedCategoryId,
          selectedItem: _state.selectedItem,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
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
          selectedItem: _state.selectedItem,
          nextCursor: _state.nextCursor,
          hasMore: _state.hasMore,
        ),
      );
    }
  }

  void _set(MarketplaceState value) {
    _state = value;
    notifyListeners();
  }
}
