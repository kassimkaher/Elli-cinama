import 'package:abk_player/core/network/request_builder.dart';
import 'package:abk_player/features/live/data/models.dart';
import 'package:abk_player/features/live/domain/entities.dart';
import 'package:abk_player/features/live/domain/usecases.dart';
import 'package:flutter_test/flutter_test.dart';

class _Creds implements CredentialSource {
  @override
  final String? username;
  @override
  final String? password;
  _Creds(this.username, this.password);
}

void main() {
  group('Live parsing', () {
    test('category maps fields and coerces isLocked', () {
      final c = LiveModels.categoryFromJson({
        'id': '5',
        'category_name': 'Sports',
        'category_icon': 'http://i/x.png',
        'view_order': '3',
        'ch_count': 42,
        'isLocked': 'true',
      });
      expect(c.id, '5');
      expect(c.name, 'Sports');
      expect(c.viewOrderInt, 3);
      expect(c.channelCount, 42);
      expect(c.isLocked, isTrue);
    });

    test('channel coerces id from string and keeps template', () {
      final ch = LiveModels.channelFromJson({
        'id': '308779',
        'stream_display_name': 'Channel 1',
        'category_id': '5',
        'tv_archive': 1,
        'has_epg': 0,
        'stream_url': 'http://h/{user}/{pass}/308779',
      });
      expect(ch.id, 308779);
      expect(ch.categoryId, 5);
      expect(ch.hasArchive, isTrue);
      expect(ch.hasEpgData, isFalse);
      expect(ch.streamUrlTemplate, contains('{user}'));
    });
  });

  group('ResolveLiveStreamUrl', () {
    test('literal {user}/{pass} substitution', () {
      final r = ResolveLiveStreamUrl(_Creds('alice', 'pw123'));
      const ch = LiveChannel(id: 1, name: 'c', streamUrlTemplate: 'http://h/{user}/{pass}/1');
      expect(r.call(ch), 'http://h/alice/pw123/1');
    });

    test('replacement is literal — regex-special credentials are safe', () {
      final r = ResolveLiveStreamUrl(_Creds(r'a$1\b', r'p&q'));
      const ch = LiveChannel(id: 1, name: 'c', streamUrlTemplate: 'http://h/{user}/{pass}/1');
      expect(r.call(ch), r'http://h/a$1\b/p&q/1');
    });

    test('null template returns null', () {
      final r = ResolveLiveStreamUrl(_Creds('u', 'p'));
      expect(r.call(const LiveChannel(id: 1, name: 'c')), isNull);
    });
  });
}
