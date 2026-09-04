import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('POD camera cancellation does not upload evidence', () async {
    final source = _PhotoSource();
    final uploader = _EvidenceUploader();
    final coordinator = RiderPodCaptureCoordinator(
      photoSource: source,
      uploader: uploader,
    );

    expect(await coordinator.capturePhoto(_task()), isNull);
    expect(uploader.uploads, isEmpty);

    source.evidence = RiderPodBinaryEvidence(
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
    );
    expect(
      await coordinator.capturePhoto(_task()),
      'asset-private-blurred-photo-001',
    );
    expect(uploader.uploads.single.kind, RiderPodEvidenceKind.blurredPhoto);
  });

  test('POD coordinator rejects unsafe binary evidence and references', () {
    final source = _PhotoSource(
      evidence: RiderPodBinaryEvidence(
        bytes: Uint8List.fromList([1]),
        contentType: 'image/gif',
      ),
    );
    final uploader = _EvidenceUploader();
    final coordinator = RiderPodCaptureCoordinator(
      photoSource: source,
      uploader: uploader,
    );

    expect(coordinator.capturePhoto(_task()), throwsFormatException);
    expect(
      coordinator.uploadSignature(_task(), Uint8List(0)),
      throwsFormatException,
    );

    source.evidence = RiderPodBinaryEvidence(
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/png',
    );
    uploader.reference = 'https://public.example/proof.png';
    expect(coordinator.capturePhoto(_task()), throwsFormatException);
  });

  test(
    'rider completion supports every backend evidence combination',
    () async {
      final remote = _PodRemote();
      final controller = RiderOperationsController(remote);

      await controller.complete(
        _task(id: 'pod-otp', requiredEvidence: const {'PHOTO', 'OTP'}),
        otp: '123456',
        blurredPhotoAssetId: 'asset-private-photo-otp',
      );
      await controller.complete(
        _task(
          id: 'pod-signature',
          requiredEvidence: const {'PHOTO', 'SIGNATURE'},
        ),
        otp: '',
        blurredPhotoAssetId: 'asset-private-photo-signature',
        signatureAssetId: 'asset-private-signature',
      );
      await controller.complete(
        _task(
          id: 'pod-all',
          requiredEvidence: const {'PHOTO', 'OTP', 'SIGNATURE'},
        ),
        otp: '654321',
        blurredPhotoAssetId: 'asset-private-photo-all',
        signatureAssetId: 'asset-private-signature-all',
      );

      expect(remote.completions, hasLength(3));
      expect(remote.completions[1].otp, isEmpty);
      expect(remote.completions[1].signatureAssetId, isNotEmpty);
      expect(
        () => controller.complete(
          _task(id: 'pod-extra', requiredEvidence: const {'PHOTO', 'OTP'}),
          otp: '123456',
          blurredPhotoAssetId: 'asset-private-photo-extra',
          signatureAssetId: 'asset-private-signature-extra',
        ),
        throwsFormatException,
      );
      expect(
        () => controller.complete(
          _task(id: 'pod-unsupported', requiredEvidence: const {'PHOTO'}),
          otp: '',
          blurredPhotoAssetId: 'asset-private-photo-only',
        ),
        throwsFormatException,
      );
      expect(
        () => controller.complete(
          _task(
            id: 'pod-unknown',
            requiredEvidence: const {'PHOTO', 'OTP', 'VIDEO'},
          ),
          otp: '123456',
          blurredPhotoAssetId: 'asset-private-photo-unknown',
        ),
        throwsFormatException,
      );
      controller.dispose();
    },
  );

  test(
    'duplicate completion for one task revision is submitted once',
    () async {
      final task = _task(id: 'pod-duplicate');
      final remote = _PodRemote(tasksValue: [task])
        ..completionGate = Completer();
      final controller = RiderOperationsController(remote);
      await controller.load();
      await controller.refreshTasks();

      final first = controller.complete(
        task,
        otp: '123456',
        blurredPhotoAssetId: 'asset-private-photo-duplicate',
      );
      final duplicate = controller.complete(
        task,
        otp: '123456',
        blurredPhotoAssetId: 'asset-private-photo-duplicate',
      );
      await duplicate;
      expect(remote.completions, hasLength(1));

      remote.completionGate!.complete();
      await first;
      expect(remote.completions, hasLength(1));
      expect(controller.state.tasks.single.status, 'DELIVERED');
      expect(
        () => controller.complete(
          task,
          otp: '123456',
          blurredPhotoAssetId: 'asset-private-photo-duplicate',
        ),
        throwsStateError,
      );
      controller.dispose();
    },
  );

  test('rider completion API sends the exact signature contract', () async {
    final transport = _PodTransport();
    final api = RiderOperationsApi(
      ApiClient(
        baseUrl: Uri.parse('https://api.planext4u.test'),
        transport: transport,
        authSession: const _StaticAuthSession(),
        retryBudget: const ApiRetryBudget(maxAttempts: 1),
        correlationIdFactory: () => 'corr-rider-pod-test',
      ),
    );
    final task = _task(
      id: 'pod-contract',
      requiredEvidence: const {'PHOTO', 'SIGNATURE'},
    );

    await api.complete(
      task,
      otp: '',
      blurredPhotoAssetId: 'asset-private-blurred-contract',
      signatureAssetId: 'asset-private-signature-contract',
    );

    final request = transport.requests.single;
    expect(request.url.path, '/v1/rider/tasks/pod-contract/completion');
    expect(request.headers['If-Match'], '"4"');
    expect(request.headers['Idempotency-Key'], isNotEmpty);
    expect(jsonDecode(utf8.decode(request.body!)), {
      'blurred_photo_asset_id': 'asset-private-blurred-contract',
      'signature_asset_id': 'asset-private-signature-contract',
    });
  });

  testWidgets('cancelled photo keeps POD submission disabled', (tester) async {
    final task = _task(id: 'pod-cancelled');
    final remote = _PodRemote(tasksValue: [task]);
    final controller = RiderOperationsController(remote);
    await controller.load();
    await controller.refreshTasks();
    await _pumpAssignments(
      tester,
      controller,
      onCapturePhoto: (_) async => null,
    );

    await tester.tap(find.byKey(const ValueKey('complete-pod-cancelled')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delivery-otp')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('capture-pod-photo')));
    await tester.pumpAndSettle();

    expect(find.text('Photo capture cancelled.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('submit-pod')))
          .onPressed,
      isNull,
    );
    expect(remote.completions, isEmpty);
    controller.dispose();
  });

  testWidgets('drawn signature and photo complete POD exactly once', (
    tester,
  ) async {
    final task = _task(
      id: 'pod-signature-ui',
      requiredEvidence: const {'PHOTO', 'SIGNATURE'},
    );
    final remote = _PodRemote(tasksValue: [task]);
    final controller = RiderOperationsController(remote);
    await controller.load();
    await controller.refreshTasks();
    Uint8List? signaturePng;
    await _pumpAssignments(
      tester,
      controller,
      onCapturePhoto: (_) async => 'asset-private-blurred-ui',
      onCaptureSignature: (_, bytes) async {
        signaturePng = bytes;
        return 'asset-private-signature-ui';
      },
    );

    await tester.tap(find.byKey(const ValueKey('complete-pod-signature-ui')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('capture-pod-photo')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('pod-signature-pad')),
      const Offset(100, 40),
    );
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('capture-pod-signature')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('capture-pod-signature')));
    await tester.pump();
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 50 && signaturePng == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(signaturePng, isNotNull);
    expect(signaturePng, hasLength(greaterThan(8)));
    expect(signaturePng!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    await tester.tap(find.byKey(const ValueKey('submit-pod')));
    await tester.pumpAndSettle();

    expect(remote.completions, hasLength(1));
    expect(remote.completions.single.otp, isEmpty);
    expect(
      remote.completions.single.signatureAssetId,
      'asset-private-signature-ui',
    );
    expect(controller.state.tasks.single.status, 'DELIVERED');
    controller.dispose();
  });
}

Future<void> _pumpAssignments(
  WidgetTester tester,
  RiderOperationsController controller, {
  RiderEvidenceCapture? onCapturePhoto,
  RiderSignatureEvidenceUpload? onCaptureSignature,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RiderOperationsView(
          controller: controller,
          destination: const RoleDestination(
            id: 'assignments',
            label: 'Tasks',
            icon: Icons.route_outlined,
            capability: RoleCapability.riderAssignments,
          ),
          onCapturePhoto: onCapturePhoto,
          onCaptureSignature: onCaptureSignature,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RiderTask _task({
  String id = 'pod-task',
  Set<String> requiredEvidence = const {'PHOTO', 'OTP'},
}) => RiderTask(
  id: id,
  revision: 4,
  orderId: 'order-$id',
  orderType: 'PRODUCT',
  status: 'PICKED_UP',
  pickupLabel: 'Verified merchant',
  dropoffLabel: 'Protected recipient',
  distanceMeters: 2200,
  earning: const CatalogMoney(amountMinor: 7000, currency: 'INR'),
  offerExpiresAt: null,
  allowedActions: const {'COMPLETE'},
  podAssetId: '',
  requiredEvidence: requiredEvidence,
);

final class _PhotoSource implements RiderPodPhotoSource {
  _PhotoSource({this.evidence});

  RiderPodBinaryEvidence? evidence;

  @override
  Future<RiderPodBinaryEvidence?> capture(RiderTask task) async => evidence;
}

final class _EvidenceUploader implements RiderPodEvidenceUploader {
  String reference = 'asset-private-blurred-photo-001';
  final uploads =
      <
        ({
          RiderTask task,
          RiderPodEvidenceKind kind,
          RiderPodBinaryEvidence evidence,
        })
      >[];

  @override
  Future<String> upload({
    required RiderTask task,
    required RiderPodEvidenceKind kind,
    required RiderPodBinaryEvidence evidence,
  }) async {
    uploads.add((task: task, kind: kind, evidence: evidence));
    return reference;
  }
}

final class _PodCompletion {
  const _PodCompletion({
    required this.task,
    required this.otp,
    required this.blurredPhotoAssetId,
    required this.signatureAssetId,
  });

  final RiderTask task;
  final String otp;
  final String blurredPhotoAssetId;
  final String signatureAssetId;
}

final class _PodRemote implements RiderOperationsRemote {
  _PodRemote({this.tasksValue = const []});

  final List<RiderTask> tasksValue;
  final completions = <_PodCompletion>[];
  Completer<void>? completionGate;

  @override
  Future<RiderProfile> profile() async => const RiderProfile(
    id: 'rider-pod-001',
    revision: 2,
    status: 'APPROVED',
    fullName: 'Ravi Rider',
    vehicleNumber: 'TN01AB1234',
    bankStatus: 'VERIFIED',
    zones: ['600001'],
    maxConcurrent: 2,
    allowedActions: {'START_DUTY'},
  );

  @override
  Future<RiderDuty> duty() async => throw StateError('off duty');
  @override
  Future<List<RiderTask>> offers() async => const [];
  @override
  Future<List<RiderTask>> tasks() async => tasksValue;

  @override
  Future<RiderTask> complete(
    RiderTask task, {
    required String otp,
    required String blurredPhotoAssetId,
    String signatureAssetId = '',
  }) async {
    completions.add(
      _PodCompletion(
        task: task,
        otp: otp,
        blurredPhotoAssetId: blurredPhotoAssetId,
        signatureAssetId: signatureAssetId,
      ),
    );
    await completionGate?.future;
    return RiderTask(
      id: task.id,
      revision: task.revision + 1,
      orderId: task.orderId,
      orderType: task.orderType,
      status: 'DELIVERED',
      pickupLabel: task.pickupLabel,
      dropoffLabel: task.dropoffLabel,
      distanceMeters: task.distanceMeters,
      earning: task.earning,
      offerExpiresAt: null,
      allowedActions: const {},
      podAssetId: blurredPhotoAssetId,
      requiredEvidence: task.requiredEvidence,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _StaticAuthSession implements ApiAuthSession {
  const _StaticAuthSession();

  @override
  Future<String?> accessToken() async => 'rider-access-token';
  @override
  Future<bool> refresh() async => false;
}

final class _PodTransport implements ApiTransport {
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: const {'X-Correlation-ID': 'corr-rider-pod-server'},
      body: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'id': 'pod-contract',
            'revision': 5,
            'order_id': 'order-pod-contract',
            'order_type': 'PRODUCT',
            'status': 'DELIVERED',
            'pickup': {'label': 'Verified merchant'},
            'dropoff': {'label': 'Protected recipient'},
            'distance_meters': 2200,
            'earning': {'amount_minor': 7000, 'currency': 'INR'},
            'allowed_actions': <String>[],
            'pod_blurred_asset_id': 'asset-private-blurred-contract',
            'required_evidence': ['PHOTO', 'SIGNATURE'],
          }),
        ),
      ),
    );
  }
}
