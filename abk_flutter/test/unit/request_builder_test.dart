import 'package:abk_player/core/device/device_envelope.dart';
import 'package:abk_player/core/network/request_builder.dart';
import 'package:flutter_test/flutter_test.dart';

class _Creds implements CredentialSource {
  @override
  final String? username;
  @override
  final String? password;
  _Creds(this.username, this.password);
}

void main() {
  const device = DeviceEnvelope(mac: '02:aa:bb', sn: '02:aa:bb', model: 'gen');

  test('buildLogin has the confirmed envelope', () {
    final b = ContentRequestBuilder(credentials: _Creds(null, null), device: device);
    final p = b.buildLogin(username: 'U', password: 'P');
    expect(p['code'], '00000000');
    expect(p['user'], 'U');
    expect(p['pass'], 'P');
    expect(p['mac'], '02:aa:bb');
    expect(p['sn'], '02:aa:bb');
    expect(p['model'], 'gen');
    expect(p['group'], 0);
    expect(p['mode'], 'login');
  });

  test('build uses session credentials and merges extra', () {
    final b = ContentRequestBuilder(credentials: _Creds('SU', 'SP'), device: device);
    final p = b.build('movies_info', extra: {'movie_id': '42'});
    expect(p['user'], 'SU');
    expect(p['pass'], 'SP');
    expect(p['mode'], 'movies_info');
    expect(p['movie_id'], '42');
    expect(p['group'], 0);
  });
}
