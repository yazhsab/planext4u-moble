import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_customer/webrtc_provider.dart';

void main() {
  test('ICE configuration accepts protected TURN credentials', () {
    final server = WebRtcIceServer(
      urls: [Uri.parse('turns:turn.planext4u.invalid:5349')],
      username: 'runtime-user',
      credential: 'protected-runtime-value',
    );

    expect(server.toConfiguration(), {
      'urls': ['turns:turn.planext4u.invalid:5349'],
      'username': 'runtime-user',
      'credential': 'protected-runtime-value',
    });
    final factory = createFlutterSocialRtcProviderFactory(iceServers: [server]);
    expect(factory(), isA<FlutterSocialRtcOfferProvider>());
    expect(factory(), isNot(same(factory())));
  });

  test('TURN without credentials and unsafe schemes fail closed', () {
    expect(
      () => WebRtcIceServer(
        urls: [Uri.parse('turn:turn.planext4u.invalid:3478')],
      ),
      throwsFormatException,
    );
    expect(
      () =>
          WebRtcIceServer(urls: [Uri.parse('https://turn.planext4u.invalid')]),
      throwsFormatException,
    );
    expect(
      () => createFlutterSocialRtcProviderFactory(iceServers: const []),
      throwsFormatException,
    );
  });
}
