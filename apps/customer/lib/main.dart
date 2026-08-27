import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  runApp(CustomerApp(config: AppConfig.fromCompileTime()));
}

class CustomerApp extends StatefulWidget {
  const CustomerApp({
    required this.config,
    this.catalogController,
    this.initialUri,
    super.key,
  });

  final AppConfig config;
  final CatalogController? catalogController;
  final Uri? initialUri;

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  late final bool _ownsController = widget.catalogController == null;
  late final CatalogController _catalog =
      widget.catalogController ??
      CatalogController(
        remote: _AuthenticatedSessionRequiredRemote(),
        cache: MemoryCustomerHomeCache(),
      );

  @override
  void dispose() {
    if (_ownsController) _catalog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.initialUri == null
        ? null
        : CustomerDeepLink.parse(widget.initialUri!);
    final destination = link is CustomerCatalogLink || link is CustomerItemLink
        ? CustomerDestination.explore
        : CustomerDestination.home;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Planext4u Customer',
      theme: Planext4uTheme.light,
      darkTheme: Planext4uTheme.dark,
      themeMode: ThemeMode.system,
      supportedLocales: Planext4uLocalizations.supportedLocales,
      localizationsDelegates: const [
        Planext4uLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Semantics(
        label:
            'Planext4u ${widget.config.environmentLabel} customer application',
        child: CustomerHomeScreen(
          controller: _catalog,
          initialDestination: destination,
        ),
      ),
    );
  }
}

final class _AuthenticatedSessionRequiredRemote implements CatalogRemote {
  Never _required() => throw const ApiAuthenticationFailure(
    code: 'AUTHENTICATION_REQUIRED',
    message: 'Sign in to continue.',
    correlationId: 'local-auth-boundary',
  );

  @override
  Future<CatalogPage<CatalogCategory>> categories() async => _required();

  @override
  Future<CustomerHomeProjection> home() async => _required();

  @override
  Future<CatalogItem> item(String id) async => _required();

  @override
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => _required();

  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? cursor,
    int limit = 20,
  }) async => _required();
}
