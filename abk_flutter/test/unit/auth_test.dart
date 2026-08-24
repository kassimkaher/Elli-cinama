import 'package:abk_player/core/device/device_envelope.dart';
import 'package:abk_player/core/errors/failures.dart';
import 'package:abk_player/core/logging/redaction.dart';
import 'package:abk_player/core/network/request_builder.dart';
import 'package:abk_player/core/storage/secure_store.dart';
import 'package:abk_player/core/utils/result.dart';
import 'package:abk_player/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:abk_player/features/auth/data/datasources/session_local_datasource.dart';
import 'package:abk_player/features/auth/data/models/account_model.dart';
import 'package:abk_player/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _Creds implements CredentialSource {
  @override
  String? username;
  @override
  String? password;
}

void main() {
  group('AccountModel', () {
    test('maps fields and success flag', () {
      final a = AccountModel.fromJson({
        'status': 100,
        'message': 'Login Success.',
        'host': 'http://h:80',
        'player_api': 'http://h:80/',
        'username': 'srvU',
        'password': 'srvP',
        'user_agent': 'UA',
        'timezone': 'Europe/Berlin',
        'expire': '2027-01-11',
      });
      expect(a.isSuccess, isTrue);
      expect(a.host, 'http://h:80');
      expect(a.roles.playerApiPhp, 'http://h:80/player_api.php');
      expect(a.username, 'srvU');
    });

    test('status 101 is success; other/null is not', () {
      expect(AccountModel.fromJson({'status': 101, 'message': ''}).isSuccess, isTrue);
      expect(AccountModel.fromJson({'status': 0, 'message': ''}).isSuccess, isFalse);
      expect(AccountModel.fromJson({'message': ''}).isSuccess, isFalse);
    });
  });

  group('SessionLocalDataSource', () {
    test('save / load / clear round-trips via secure store', () async {
      final ds = SessionLocalDataSource(InMemorySecureStore());
      final a = AccountModel.fromJson({'status': 100, 'message': 'ok', 'username': 'u'});
      await ds.save(a);
      expect((await ds.load())!.username, 'u');
      await ds.clear();
      expect(await ds.load(), isNull);
    });
  });

  group('AuthRepositoryImpl', () {
    AuthRepositoryImpl build(dynamic response, {required SecureStore secure, required Redactor redactor}) {
      final client = contentClientWith((req) async => response);
      final remote = AuthRemoteDataSource(
        client: client,
        builder: ContentRequestBuilder(credentials: _Creds(), device: const DeviceEnvelope(mac: 'm', sn: 'm', model: 'g')),
      );
      return AuthRepositoryImpl(
        remote: remote,
        local: SessionLocalDataSource(secure),
        redactor: redactor,
      );
    }

    test('successful login persists session and registers secrets', () async {
      final secure = InMemorySecureStore();
      final redactor = Redactor();
      final repo = build(
        contentResponse({
          'status': 100,
          'message': 'Login Success.',
          'username': 'srvU',
          'password': 'srvP',
          'host': 'http://h:80',
          'player_api': 'http://h:80/',
          'user_agent': 'UA',
        }),
        secure: secure,
        redactor: redactor,
      );
      final res = await repo.login(username: 'inU', password: 'inP');
      expect(res, isA<Ok>());
      expect((res as Ok).value.username, 'srvU');
      // persisted
      expect(await secure.read('session_account_v1'), isNotNull);
      // secrets redacted
      expect(redactor.redact('leak srvP and inP'), 'leak *** and ***');
    });

    test('logical failure (bad status) maps to BackendLogicalFailure', () async {
      final repo = build(
        contentResponse({'status': 2, 'message': 'Wrong credentials'}),
        secure: InMemorySecureStore(),
        redactor: Redactor(),
      );
      final res = await repo.login(username: 'x', password: 'y');
      final f = (res as Err).failure;
      expect(f, isA<BackendLogicalFailure>());
      expect(f.message, 'Wrong credentials');
    });

    test('restoreSession returns persisted account', () async {
      final secure = InMemorySecureStore();
      final repo = build(contentResponse({'status': 100, 'message': 'ok'}),
          secure: secure, redactor: Redactor());
      await repo.login(username: 'a', password: 'b');
      final restored = await repo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.isSuccess, isTrue);
    });
  });
}
