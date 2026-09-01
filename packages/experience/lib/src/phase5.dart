import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

enum Phase5Status { idle, loading, ready, submitting, failure }

final class Phase5Money {
  const Phase5Money({required this.amountMinor, required this.currency});
  factory Phase5Money.fromJson(Object? value) {
    final json = _object(value, 'money');
    return Phase5Money(
      amountMinor: _int(json, 'amount_minor'),
      currency: _string(json, 'currency'),
    );
  }
  final int amountMinor;
  final String currency;
  String display() => '$currency ${(amountMinor / 100).toStringAsFixed(2)}';
}

final class SocialEphemeral {
  const SocialEphemeral({
    required this.id,
    required this.kind,
    required this.caption,
    required this.status,
    required this.highlighted,
    required this.expiresAt,
    required this.allowedActions,
  });
  factory SocialEphemeral.fromJson(Object? value) {
    final json = _object(value, 'social ephemeral content');
    return SocialEphemeral(
      id: _string(json, 'id'),
      kind: _string(json, 'kind'),
      caption: _string(json, 'caption', allowEmpty: true),
      status: _string(json, 'status'),
      highlighted: _bool(json, 'highlighted'),
      expiresAt: _instant(json, 'expires_at'),
      allowedActions: _strings(json, 'allowed_actions').toSet(),
    );
  }
  final String id;
  final String kind;
  final String caption;
  final String status;
  final bool highlighted;
  final DateTime expiresAt;
  final Set<String> allowedActions;
}

final class SocialMediaJob {
  const SocialMediaJob({
    required this.id,
    required this.kind,
    required this.state,
    required this.scanStatus,
  });
  factory SocialMediaJob.fromJson(Object? value) {
    final json = _object(value, 'social media');
    return SocialMediaJob(
      id: _string(json, 'id'),
      kind: _string(json, 'kind'),
      state: _string(json, 'state'),
      scanStatus: _string(json, 'scan_status'),
    );
  }
  final String id;
  final String kind;
  final String state;
  final String scanStatus;
}

final class SocialConversation {
  const SocialConversation({
    required this.id,
    required this.participantIds,
    required this.status,
    required this.requestedBy,
    required this.allowedActions,
  });
  factory SocialConversation.fromJson(Object? value) {
    final json = _object(value, 'conversation');
    return SocialConversation(
      id: _string(json, 'id'),
      participantIds: _strings(json, 'participant_ids'),
      status: _string(json, 'status'),
      requestedBy: _string(json, 'requested_by'),
      allowedActions: _strings(json, 'allowed_actions').toSet(),
    );
  }
  final String id;
  final List<String> participantIds;
  final String status;
  final String requestedBy;
  final Set<String> allowedActions;
}

final class SocialMessage {
  const SocialMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.voiceMediaId,
    required this.status,
    required this.createdAt,
  });
  factory SocialMessage.fromJson(Object? value) {
    final json = _object(value, 'message');
    return SocialMessage(
      id: _string(json, 'id'),
      conversationId: _string(json, 'conversation_id'),
      senderId: _string(json, 'sender_id'),
      body: _optionalString(json, 'body'),
      voiceMediaId: _optionalString(json, 'voice_media_id'),
      status: _string(json, 'status'),
      createdAt: _instant(json, 'created_at'),
    );
  }
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String voiceMediaId;
  final String status;
  final DateTime createdAt;
}

final class SocialCall {
  const SocialCall({
    required this.id,
    required this.conversationId,
    required this.kind,
    required this.status,
    required this.signalCount,
    required this.expiresAt,
  });
  factory SocialCall.fromJson(Object? value) {
    final json = _object(value, 'social call');
    return SocialCall(
      id: _string(json, 'id'),
      conversationId: _string(json, 'conversation_id'),
      kind: _string(json, 'kind'),
      status: _string(json, 'status'),
      signalCount: _int(json, 'signal_count'),
      expiresAt: _instant(json, 'expires_at'),
    );
  }
  final String id, conversationId, kind, status;
  final int signalCount;
  final DateTime expiresAt;
}

final class HomeEstimate {
  const HomeEstimate({
    required this.version,
    required this.amount,
    required this.pricePerArea,
  });
  factory HomeEstimate.fromJson(Object? value) {
    final json = _object(value, 'home estimate');
    return HomeEstimate(
      version: _string(json, 'version'),
      amount: Phase5Money.fromJson(json['amount']),
      pricePerArea: Phase5Money.fromJson(json['price_per_area']),
    );
  }
  final String version;
  final Phase5Money amount;
  final Phase5Money pricePerArea;
}

final class HomeListing {
  const HomeListing({
    required this.id,
    required this.revision,
    required this.ownerId,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.locality,
    required this.latitude,
    required this.longitude,
    required this.areaSqFt,
    required this.bedrooms,
    required this.price,
    required this.amenities,
    required this.status,
    required this.kycVerified,
    required this.plan,
    required this.estimate,
    required this.allowedActions,
  });
  factory HomeListing.fromJson(Object? value) {
    final json = _object(value, 'home listing');
    return HomeListing(
      id: _string(json, 'id'),
      revision: _positive(json, 'revision'),
      ownerId: _string(json, 'owner_id'),
      title: _string(json, 'title'),
      propertyType: _string(json, 'property_type'),
      purpose: _string(json, 'purpose'),
      locality: _string(json, 'locality'),
      latitude: _number(json, 'latitude'),
      longitude: _number(json, 'longitude'),
      areaSqFt: _positive(json, 'area_sq_ft'),
      bedrooms: _int(json, 'bedrooms'),
      price: Phase5Money.fromJson(json['price']),
      amenities: _strings(json, 'amenities'),
      status: _string(json, 'status'),
      kycVerified: _bool(json, 'kyc_verified'),
      plan: _string(json, 'plan'),
      estimate: HomeEstimate.fromJson(json['estimate']),
      allowedActions: _strings(json, 'allowed_actions').toSet(),
    );
  }
  final String id,
      ownerId,
      title,
      propertyType,
      purpose,
      locality,
      status,
      plan;
  final int revision, areaSqFt, bedrooms;
  final double latitude, longitude;
  final Phase5Money price;
  final List<String> amenities;
  final bool kycVerified;
  final HomeEstimate estimate;
  final Set<String> allowedActions;
}

final class ClassifiedListing {
  const ClassifiedListing({
    required this.id,
    required this.revision,
    required this.ownerId,
    required this.category,
    required this.title,
    required this.description,
    required this.price,
    required this.locality,
    required this.status,
    required this.plan,
    required this.contactMasked,
    required this.contactRevealed,
    required this.whatsAppEnabled,
    required this.expiresAt,
    required this.reportCount,
    required this.allowedActions,
  });
  factory ClassifiedListing.fromJson(Object? value) {
    final json = _object(value, 'classified listing');
    return ClassifiedListing(
      id: _string(json, 'id'),
      revision: _positive(json, 'revision'),
      ownerId: _string(json, 'owner_id'),
      category: _string(json, 'category'),
      title: _string(json, 'title'),
      description: _string(json, 'description'),
      price: Phase5Money.fromJson(json['price']),
      locality: _string(json, 'locality'),
      status: _string(json, 'status'),
      plan: _string(json, 'plan'),
      contactMasked: _string(json, 'contact_masked'),
      contactRevealed: _optionalString(json, 'contact_revealed'),
      whatsAppEnabled: _bool(json, 'whatsapp_enabled'),
      expiresAt: _instant(json, 'expires_at'),
      reportCount: _int(json, 'report_count'),
      allowedActions: _strings(json, 'allowed_actions').toSet(),
    );
  }
  final String id,
      ownerId,
      category,
      title,
      description,
      locality,
      status,
      plan,
      contactMasked,
      contactRevealed;
  final int revision, reportCount;
  final Phase5Money price;
  final bool whatsAppEnabled;
  final DateTime expiresAt;
  final Set<String> allowedActions;
}

final class EmergencyLocation {
  const EmergencyLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.capturedAt,
  });
  factory EmergencyLocation.fromJson(Object? value) {
    final json = _object(value, 'emergency location');
    return EmergencyLocation(
      latitude: _number(json, 'latitude'),
      longitude: _number(json, 'longitude'),
      accuracyM: _number(json, 'accuracy_m'),
      capturedAt: _instant(json, 'captured_at'),
    );
  }
  final double latitude, longitude, accuracyM;
  final DateTime capturedAt;
  bool stale(DateTime now) =>
      now.toUtc().difference(capturedAt) > const Duration(minutes: 2);
}

final class EmergencyAssistance {
  const EmergencyAssistance({
    required this.id,
    required this.revision,
    required this.category,
    required this.description,
    required this.priority,
    required this.status,
    required this.assignedResponder,
    required this.locationConsent,
    required this.location,
    required this.escalationLevel,
    required this.slaDeadline,
    required this.allowedActions,
  });
  factory EmergencyAssistance.fromJson(Object? value) {
    final json = _object(value, 'emergency assistance');
    return EmergencyAssistance(
      id: _string(json, 'id'),
      revision: _positive(json, 'revision'),
      category: _string(json, 'category'),
      description: _string(json, 'description'),
      priority: _string(json, 'priority'),
      status: _string(json, 'status'),
      assignedResponder: _optionalString(json, 'assigned_responder'),
      locationConsent: _bool(json, 'location_consent'),
      location: json['current_location'] == null
          ? null
          : EmergencyLocation.fromJson(json['current_location']),
      escalationLevel: _int(json, 'escalation_level'),
      slaDeadline: _instant(json, 'sla_deadline'),
      allowedActions: _strings(json, 'allowed_actions').toSet(),
    );
  }
  final String id, category, description, priority, status, assignedResponder;
  final int revision, escalationLevel;
  final bool locationConsent;
  final EmergencyLocation? location;
  final DateTime slaDeadline;
  final Set<String> allowedActions;
}

final class EmergencyMessage {
  const EmergencyMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.body,
    required this.status,
    required this.createdAt,
  });
  factory EmergencyMessage.fromJson(Object? value) {
    final json = _object(value, 'emergency message');
    return EmergencyMessage(
      id: _string(json, 'id'),
      requestId: _string(json, 'request_id'),
      senderId: _string(json, 'sender_id'),
      body: _string(json, 'body'),
      status: _string(json, 'status'),
      createdAt: _instant(json, 'created_at'),
    );
  }
  final String id, requestId, senderId, body, status;
  final DateTime createdAt;
}

final class AccountDataExport {
  const AccountDataExport({
    required this.generatedAt,
    required this.identityId,
    required this.sessionCount,
    required this.consentCount,
  });
  factory AccountDataExport.fromJson(Object? value) {
    final json = _object(value, 'account data export');
    return AccountDataExport(
      generatedAt: _instant(json, 'generated_at'),
      identityId: _string(json, 'identity_id'),
      sessionCount: _list(json, 'sessions').length,
      consentCount: _list(json, 'consents').length,
    );
  }
  final DateTime generatedAt;
  final String identityId;
  final int sessionCount, consentCount;
}

final class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.effectiveAt,
  });
  factory AccountDeletionRequest.fromJson(Object? value) {
    final json = _object(value, 'account deletion request');
    return AccountDeletionRequest(
      id: _string(json, 'id'),
      status: _string(json, 'status'),
      requestedAt: _instant(json, 'requested_at'),
      effectiveAt: _instant(json, 'effective_at'),
    );
  }
  final String id, status;
  final DateTime requestedAt, effectiveAt;
}

abstract interface class AccountPrivacyRemote {
  Future<AccountDataExport> exportAccountData();
  Future<AccountDeletionRequest> requestAccountDeletion(String reason);
}

abstract interface class Phase5Remote implements AccountPrivacyRemote {
  Future<List<SocialEphemeral>> ephemeral();
  Future<SocialMediaJob> createMedia(String assetId, String kind);
  Future<SocialEphemeral> createEphemeral(
    String kind,
    String mediaJobId,
    String caption,
  );
  Future<SocialEphemeral> setHighlight(String id, bool active);
  Future<void> createCollection(String name);
  Future<List<SocialConversation>> conversations();
  Future<SocialConversation> openConversation(String profileId);
  Future<SocialConversation> acceptConversation(String id);
  Future<List<SocialMessage>> messages(String conversationId);
  Future<SocialMessage> sendMessage(
    String conversationId,
    String body, {
    String? voiceMediaId,
  });
  Future<void> setPresence(String state);
  Future<SocialCall> createCall(String conversationId, String kind);
  Future<SocialCall> signalCall(String callId, String type, String payload);
  Future<List<HomeListing>> homes({
    String query = '',
    String locality = '',
    String propertyType = '',
    String purpose = '',
  });
  Future<HomeListing> createHome(Map<String, Object?> input);
  Future<HomeListing> publishHome(HomeListing listing);
  Future<void> inquireHome(String id, String message);
  Future<void> scheduleVisit(String id, DateTime scheduledAt);
  Future<HomeListing> upgradeHome(String id, String plan);
  Future<List<ClassifiedListing>> classifieds({
    String query = '',
    String category = '',
    String locality = '',
  });
  Future<ClassifiedListing> createClassified(Map<String, Object?> input);
  Future<ClassifiedListing> revealContact(String id, String channel);
  Future<ClassifiedListing> reportClassified(String id, String reason);
  Future<ClassifiedListing> repostClassified(String id);
  Future<ClassifiedListing> upgradeClassified(String id, String plan);
  Future<List<EmergencyAssistance>> emergencies();
  Future<EmergencyAssistance> createEmergency({
    required String category,
    required String description,
    required String priority,
    required double latitude,
    required double longitude,
    required double accuracyM,
  });
  Future<EmergencyAssistance> updateEmergencyLocation(
    String id, {
    required bool consent,
    double? latitude,
    double? longitude,
    double? accuracyM,
  });
  Future<List<EmergencyMessage>> emergencyMessages(String id);
  Future<EmergencyMessage> sendEmergencyMessage(String id, String body);
}

final class Phase5Api implements Phase5Remote {
  const Phase5Api(this._client);
  final ApiClient _client;
  Future<T> _get<T>(
    String operation,
    String path,
    T Function(Object?) decode, {
    Map<String, List<String>> query = const {},
  }) async => (await _client.send(
    ApiRequest.get(operation: operation, path: path, query: query),
    decode,
  )).value;
  Future<T> _command<T>(
    String operation,
    String method,
    String path,
    Object? body,
    T Function(Object?) decode, {
    Map<String, String> headers = const {},
  }) async => (await _client.send(
    ApiRequest.command(
      operation: operation,
      method: method,
      path: path,
      body: body,
      headers: headers,
    ),
    decode,
  )).value;
  List<T> _items<T>(Object? value, T Function(Object?) decode) {
    final json = _object(value, 'page');
    return _list(json, 'items').map(decode).toList(growable: false);
  }

  @override
  Future<List<SocialEphemeral>> ephemeral() => _get(
    'social.ephemeral',
    '/v1/social/ephemeral',
    (v) => _items(v, SocialEphemeral.fromJson),
  );
  @override
  Future<SocialMediaJob> createMedia(String assetId, String kind) => _command(
    'social.create_media',
    'POST',
    '/v1/social/media',
    {'asset_id': assetId, 'kind': kind},
    SocialMediaJob.fromJson,
  );
  @override
  Future<SocialEphemeral> createEphemeral(
    String kind,
    String mediaJobId,
    String caption,
  ) => _command(
    'social.create_ephemeral',
    'POST',
    '/v1/social/ephemeral',
    {'kind': kind, 'media_job_id': mediaJobId, 'caption': caption},
    SocialEphemeral.fromJson,
  );
  @override
  Future<SocialEphemeral> setHighlight(String id, bool active) => _command(
    'social.set_highlight',
    'PUT',
    '/v1/social/ephemeral/${Uri.encodeComponent(id)}/highlight',
    {'active': active},
    SocialEphemeral.fromJson,
  );
  @override
  Future<void> createCollection(String name) => _command(
    'social.create_collection',
    'POST',
    '/v1/social/collections',
    {'name': name},
    (_) {},
  );
  @override
  Future<List<SocialConversation>> conversations() => _get(
    'social.conversations',
    '/v1/social/conversations',
    (v) => _items(v, SocialConversation.fromJson),
  );
  @override
  Future<SocialConversation> openConversation(String profileId) => _command(
    'social.open_conversation',
    'POST',
    '/v1/social/conversations',
    {'profile_id': profileId},
    SocialConversation.fromJson,
  );
  @override
  Future<SocialConversation> acceptConversation(String id) => _command(
    'social.accept_conversation',
    'POST',
    '/v1/social/conversations/${Uri.encodeComponent(id)}/accept',
    null,
    SocialConversation.fromJson,
  );
  @override
  Future<List<SocialMessage>> messages(String id) => _get(
    'social.messages',
    '/v1/social/conversations/${Uri.encodeComponent(id)}/messages',
    (v) => _items(v, SocialMessage.fromJson),
  );
  @override
  Future<SocialMessage> sendMessage(
    String id,
    String body, {
    String? voiceMediaId,
  }) => _command(
    'social.send_message',
    'POST',
    '/v1/social/conversations/${Uri.encodeComponent(id)}/messages',
    {
      'body': body,
      if (voiceMediaId?.isNotEmpty == true) 'voice_media_id': voiceMediaId,
    },
    SocialMessage.fromJson,
  );
  @override
  Future<void> setPresence(String state) => _command(
    'social.set_presence',
    'PUT',
    '/v1/social/presence',
    {'state': state},
    (_) {},
  );
  @override
  Future<SocialCall> createCall(String id, String kind) => _command(
    'social.create_call',
    'POST',
    '/v1/social/conversations/${Uri.encodeComponent(id)}/calls',
    {'kind': kind},
    SocialCall.fromJson,
  );
  @override
  Future<SocialCall> signalCall(String id, String type, String payload) =>
      _command(
        'social.signal_call',
        'POST',
        '/v1/social/calls/${Uri.encodeComponent(id)}/signals',
        {'type': type, 'payload': payload},
        SocialCall.fromJson,
      );
  @override
  Future<List<HomeListing>> homes({
    String query = '',
    String locality = '',
    String propertyType = '',
    String purpose = '',
  }) => _get(
    'homes.search',
    '/v1/homes/listings',
    (v) => _items(v, HomeListing.fromJson),
    query: {
      if (query.isNotEmpty) 'q': [query],
      if (locality.isNotEmpty) 'locality': [locality],
      if (propertyType.isNotEmpty) 'property_type': [propertyType],
      if (purpose.isNotEmpty) 'purpose': [purpose],
    },
  );
  @override
  Future<HomeListing> createHome(Map<String, Object?> input) => _command(
    'homes.create',
    'POST',
    '/v1/homes/listings',
    input,
    HomeListing.fromJson,
  );
  @override
  Future<HomeListing> publishHome(HomeListing listing) => _command(
    'homes.publish',
    'POST',
    '/v1/homes/listings/${Uri.encodeComponent(listing.id)}/publish',
    null,
    HomeListing.fromJson,
    headers: {'If-Match': '"${listing.revision}"'},
  );
  @override
  Future<void> inquireHome(String id, String message) => _command(
    'homes.inquire',
    'POST',
    '/v1/homes/listings/${Uri.encodeComponent(id)}/inquiries',
    {'message': message},
    (_) {},
  );
  @override
  Future<void> scheduleVisit(String id, DateTime scheduledAt) => _command(
    'homes.schedule_visit',
    'POST',
    '/v1/homes/listings/${Uri.encodeComponent(id)}/visits',
    {'scheduled_at': scheduledAt.toUtc().toIso8601String()},
    (_) {},
  );
  @override
  Future<HomeListing> upgradeHome(String id, String plan) => _command(
    'homes.upgrade',
    'POST',
    '/v1/homes/listings/${Uri.encodeComponent(id)}/upgrade',
    {'plan': plan},
    HomeListing.fromJson,
  );
  @override
  Future<List<ClassifiedListing>> classifieds({
    String query = '',
    String category = '',
    String locality = '',
  }) => _get(
    'classifieds.browse',
    '/v1/classifieds/listings',
    (v) => _items(v, ClassifiedListing.fromJson),
    query: {
      if (query.isNotEmpty) 'q': [query],
      if (category.isNotEmpty) 'category': [category],
      if (locality.isNotEmpty) 'locality': [locality],
    },
  );
  @override
  Future<ClassifiedListing> createClassified(Map<String, Object?> input) =>
      _command(
        'classifieds.create',
        'POST',
        '/v1/classifieds/listings',
        input,
        ClassifiedListing.fromJson,
      );
  @override
  Future<ClassifiedListing> revealContact(String id, String channel) =>
      _command(
        'classifieds.contact',
        'POST',
        '/v1/classifieds/listings/${Uri.encodeComponent(id)}/contact',
        {'channel': channel, 'consent': true},
        ClassifiedListing.fromJson,
      );
  @override
  Future<ClassifiedListing> reportClassified(String id, String reason) =>
      _command(
        'classifieds.report',
        'POST',
        '/v1/classifieds/listings/${Uri.encodeComponent(id)}/reports',
        {'reason': reason, 'details': 'Reported from customer mobile'},
        ClassifiedListing.fromJson,
      );
  @override
  Future<ClassifiedListing> repostClassified(String id) => _command(
    'classifieds.repost',
    'POST',
    '/v1/classifieds/listings/${Uri.encodeComponent(id)}/repost',
    null,
    ClassifiedListing.fromJson,
  );
  @override
  Future<ClassifiedListing> upgradeClassified(String id, String plan) =>
      _command(
        'classifieds.upgrade',
        'POST',
        '/v1/classifieds/listings/${Uri.encodeComponent(id)}/upgrade',
        {'plan': plan},
        ClassifiedListing.fromJson,
      );
  @override
  Future<List<EmergencyAssistance>> emergencies() => _get(
    'emergency.list',
    '/v1/emergency/requests',
    (v) => _items(v, EmergencyAssistance.fromJson),
  );
  @override
  Future<EmergencyAssistance> createEmergency({
    required String category,
    required String description,
    required String priority,
    required double latitude,
    required double longitude,
    required double accuracyM,
  }) => _command(
    'emergency.create',
    'POST',
    '/v1/emergency/requests',
    {
      'category': category,
      'description': description,
      'priority': priority,
      'location_consent': true,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyM,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      },
    },
    EmergencyAssistance.fromJson,
  );
  @override
  Future<EmergencyAssistance> updateEmergencyLocation(
    String id, {
    required bool consent,
    double? latitude,
    double? longitude,
    double? accuracyM,
  }) => _command(
    'emergency.update_location',
    'PUT',
    '/v1/emergency/requests/${Uri.encodeComponent(id)}/location',
    {
      'consent': consent,
      'location': {
        'latitude': latitude ?? 0,
        'longitude': longitude ?? 0,
        'accuracy_m': accuracyM ?? 1,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      },
    },
    EmergencyAssistance.fromJson,
  );

  @override
  Future<List<EmergencyMessage>> emergencyMessages(String id) => _get(
    'emergency.communications',
    '/v1/emergency/requests/${Uri.encodeComponent(id)}/communications',
    (value) => _items(value, EmergencyMessage.fromJson),
  );

  @override
  Future<EmergencyMessage> sendEmergencyMessage(String id, String body) =>
      _command(
        'emergency.send_communication',
        'POST',
        '/v1/emergency/requests/${Uri.encodeComponent(id)}/communications',
        {'body': body.trim()},
        EmergencyMessage.fromJson,
      );

  @override
  Future<AccountDataExport> exportAccountData() => _get(
    'identity.export_account_data',
    '/v1/me/data-export',
    AccountDataExport.fromJson,
  );

  @override
  Future<AccountDeletionRequest> requestAccountDeletion(String reason) =>
      _command(
        'identity.request_account_deletion',
        'POST',
        '/v1/me/deletion-requests',
        {'confirmation': 'DELETE MY ACCOUNT', 'reason': reason.trim()},
        AccountDeletionRequest.fromJson,
      );
}

final class Phase5State {
  const Phase5State({
    this.status = Phase5Status.idle,
    this.stories = const [],
    this.conversations = const [],
    this.homes = const [],
    this.classifieds = const [],
    this.emergencies = const [],
    this.message,
  });
  final Phase5Status status;
  final List<SocialEphemeral> stories;
  final List<SocialConversation> conversations;
  final List<HomeListing> homes;
  final List<ClassifiedListing> classifieds;
  final List<EmergencyAssistance> emergencies;
  final String? message;
  bool get busy =>
      status == Phase5Status.loading || status == Phase5Status.submitting;
  Phase5State copyWith({
    Phase5Status? status,
    List<SocialEphemeral>? stories,
    List<SocialConversation>? conversations,
    List<HomeListing>? homes,
    List<ClassifiedListing>? classifieds,
    List<EmergencyAssistance>? emergencies,
    String? message,
    bool clearMessage = false,
  }) => Phase5State(
    status: status ?? this.status,
    stories: stories ?? this.stories,
    conversations: conversations ?? this.conversations,
    homes: homes ?? this.homes,
    classifieds: classifieds ?? this.classifieds,
    emergencies: emergencies ?? this.emergencies,
    message: clearMessage ? null : message ?? this.message,
  );
}

final class Phase5Controller extends ChangeNotifier {
  Phase5Controller({required Phase5Remote remote}) : _remote = remote;
  final Phase5Remote _remote;
  Phase5State _state = const Phase5State();
  Phase5State get state => _state;
  Future<void> load() async {
    if (_state.busy) return;
    _set(_state.copyWith(status: Phase5Status.loading, clearMessage: true));
    try {
      final values = await Future.wait<Object>([
        _remote.ephemeral(),
        _remote.conversations(),
        _remote.homes(),
        _remote.classifieds(),
        _remote.emergencies(),
      ]);
      _set(
        _state.copyWith(
          status: Phase5Status.ready,
          stories: List.unmodifiable(values[0] as List<SocialEphemeral>),
          conversations: List.unmodifiable(
            values[1] as List<SocialConversation>,
          ),
          homes: List.unmodifiable(values[2] as List<HomeListing>),
          classifieds: List.unmodifiable(values[3] as List<ClassifiedListing>),
          emergencies: List.unmodifiable(
            values[4] as List<EmergencyAssistance>,
          ),
        ),
      );
      await _remote.setPresence('ONLINE');
    } catch (error) {
      _fail(error, 'Community services could not be loaded.');
    }
  }

  Future<void> createCollection(String name) =>
      _mutate(() => _remote.createCollection(name), 'Collection created.');
  Future<SocialConversation?> openConversation(String profileId) async {
    SocialConversation? result;
    await _mutate(
      () async {
        result = await _remote.openConversation(profileId);
        return result;
      },
      'Message request created.',
      reload: true,
    );
    return result;
  }

  Future<List<SocialMessage>> messages(String id) => _remote.messages(id);
  Future<void> sendMessage(String id, String body, {String? voiceMediaId}) =>
      _mutate(
        () => _remote.sendMessage(id, body, voiceMediaId: voiceMediaId),
        'Message delivered.',
      );
  Future<void> acceptConversation(String id) => _mutate(
    () => _remote.acceptConversation(id),
    'Message request accepted.',
    reload: true,
  );
  Future<SocialCall?> createCall(String id, String kind) async {
    SocialCall? call;
    await _mutate(() async {
      call = await _remote.createCall(id, kind);
      return call;
    }, '$kind call started.');
    return call;
  }

  Future<SocialCall?> signalCall(
    String callId,
    String type, {
    String payload = '',
  }) async {
    SocialCall? call;
    await _mutate(() async {
      call = await _remote.signalCall(callId, type, payload);
      return call;
    }, type == 'END' ? 'Call ended.' : 'Call signalling updated.');
    return call;
  }

  Future<void> createStory({
    required String assetId,
    required String kind,
    required String caption,
  }) async {
    if (_state.busy) return;
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._:-]{7,159}$').hasMatch(assetId)) {
      _fail(
        const FormatException('Media asset reference is invalid.'),
        'Select media from the private upload provider before publishing.',
      );
      return;
    }
    _set(_state.copyWith(status: Phase5Status.submitting, clearMessage: true));
    try {
      final media = await _remote.createMedia(assetId, kind);
      if (media.state == 'READY') {
        await _remote.createEphemeral(kind, media.id, caption);
        _set(
          _state.copyWith(
            status: Phase5Status.ready,
            message: '$kind published.',
          ),
        );
        await load();
      } else {
        _set(
          _state.copyWith(
            status: Phase5Status.ready,
            message:
                'Media submitted to the safety pipeline. Publish unlocks after the scan completes.',
          ),
        );
      }
    } catch (error) {
      _fail(error, 'Media could not be submitted.');
    }
  }

  Future<void> setHighlight(SocialEphemeral item, bool active) => _mutate(
    () => _remote.setHighlight(item.id, active),
    active ? 'Added to highlights.' : 'Removed from highlights.',
    reload: true,
  );
  Future<void> inquireHome(String id, String message) => _mutate(
    () => _remote.inquireHome(id, message),
    'Inquiry sent to the verified owner.',
  );
  Future<void> scheduleVisit(String id, DateTime when) =>
      _mutate(() => _remote.scheduleVisit(id, when), 'Visit requested.');
  Future<void> upgradeHome(String id, String plan) => _mutate(
    () => _remote.upgradeHome(id, plan),
    'Home listing upgraded.',
    reload: true,
  );
  Future<void> createHome(Map<String, Object?> input) async {
    HomeListing? created;
    await _mutate(() async {
      created = await _remote.createHome(input);
      return created;
    }, 'Home listing saved as a KYC-gated draft.');
    if (created != null) {
      _set(
        _state.copyWith(homes: List.unmodifiable([created!, ..._state.homes])),
      );
    }
  }

  Future<void> publishHome(HomeListing listing) => _mutate(
    () => _remote.publishHome(listing),
    'Home listing published.',
    reload: true,
  );
  Future<ClassifiedListing?> revealContact(String id, String channel) async {
    ClassifiedListing? value;
    await _mutate(() async {
      value = await _remote.revealContact(id, channel);
      return value;
    }, 'Contact revealed with your consent.');
    return value;
  }

  Future<void> reportClassified(String id) => _mutate(
    () => _remote.reportClassified(id, 'SCAM'),
    'Report sent for moderation.',
    reload: true,
  );
  Future<void> createClassified(Map<String, Object?> input) async {
    ClassifiedListing? created;
    await _mutate(() async {
      created = await _remote.createClassified(input);
      return created;
    }, 'Classified submitted for publication.');
    if (created != null) {
      _set(
        _state.copyWith(
          classifieds: List.unmodifiable([created!, ..._state.classifieds]),
        ),
      );
    }
  }

  Future<void> repostClassified(String id) => _mutate(
    () => _remote.repostClassified(id),
    'Classified reposted.',
    reload: true,
  );
  Future<void> upgradeClassified(String id, String plan) => _mutate(
    () => _remote.upgradeClassified(id, plan),
    'Classified upgraded.',
    reload: true,
  );
  Future<void> createEmergency({
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required double accuracyM,
  }) => _mutate(
    () => _remote.createEmergency(
      category: category,
      description: description,
      priority: 'CRITICAL',
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracyM,
    ),
    'Emergency request sent. Keep your phone available.',
    reload: true,
  );
  Future<void> revokeEmergencyLocation(String id) => _mutate(
    () => _remote.updateEmergencyLocation(id, consent: false),
    'Live location sharing stopped.',
    reload: true,
  );
  Future<List<EmergencyMessage>> emergencyMessages(String id) =>
      _remote.emergencyMessages(id);
  Future<void> sendEmergencyMessage(String id, String body) => _mutate(
    () => _remote.sendEmergencyMessage(id, body),
    'Update sent to the emergency response team.',
  );
  Future<AccountDataExport?> exportAccountData() async {
    AccountDataExport? value;
    await _mutate(() async {
      value = await _remote.exportAccountData();
      return value;
    }, 'Account data export generated.');
    return value;
  }

  Future<AccountDeletionRequest?> requestAccountDeletion(String reason) async {
    AccountDeletionRequest? value;
    await _mutate(() async {
      value = await _remote.requestAccountDeletion(reason);
      return value;
    }, 'Account deletion scheduled.');
    return value;
  }

  Future<void> _mutate(
    Future<Object?> Function() command,
    String success, {
    bool reload = false,
  }) async {
    if (_state.busy) return;
    _set(_state.copyWith(status: Phase5Status.submitting, clearMessage: true));
    try {
      await command();
      _set(_state.copyWith(status: Phase5Status.ready, message: success));
      if (reload) await load();
    } catch (error) {
      _fail(error, 'The action could not be completed.');
    }
  }

  void clearMessage() => _set(_state.copyWith(clearMessage: true));
  void _fail(Object error, String fallback) => _set(
    _state.copyWith(
      status: Phase5Status.failure,
      message: error is ApiFailure ? error.message : fallback,
    ),
  );
  void _set(Phase5State value) {
    _state = value;
    notifyListeners();
  }
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}

String _string(
  Map<String, Object?> json,
  String key, {
  bool allowEmpty = false,
}) {
  final value = json[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException('$key must be a string.');
  }
  return value;
}

String _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return '';
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('$key must be a non-negative integer.');
  }
  return value;
}

int _positive(Map<String, Object?> json, String key) {
  final value = _int(json, key);
  if (value < 1) throw FormatException('$key must be positive.');
  return value;
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key must be a number.');
  return value.toDouble();
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key must be a list.');
  return value;
}

List<String> _strings(Map<String, Object?> json, String key) {
  final value = _list(json, key);
  if (value.any((item) => item is! String)) {
    throw FormatException('$key must contain strings.');
  }
  return List.unmodifiable(value.cast<String>());
}

DateTime _instant(Map<String, Object?> json, String key) {
  final value = DateTime.tryParse(_string(json, key));
  if (value == null || !value.isUtc) throw FormatException('$key must be UTC.');
  return value;
}
