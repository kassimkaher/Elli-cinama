import 'package:abk_player/features/movies/data/models.dart';
import 'package:abk_player/features/movies/domain/entities.dart';
import 'package:abk_player/features/movies/domain/usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Movie parsing', () {
    test('list item maps fields', () {
      final m = MovieModels.listItemFromJson({
        'id': '900',
        'stream_display_name': 'The Film',
        'category_id': '3',
        'year': '2024',
      });
      expect(m.id, '900');
      expect(m.name, 'The Film');
      expect(m.year, '2024');
    });

    test('movies_info stream_url is parsed as a quality OBJECT', () {
      final info = MovieModels.infoFromJson({
        'id': '900',
        'title': 'The Film',
        'stream_url': {'480p': '', '720p': 'http://h/720', '1080p': '', '4k': ''},
      });
      expect(info.streamUrl.p720, 'http://h/720');
      expect(info.streamUrl.p480, '');
    });
  });

  group('Quality selection', () {
    test('prefers 4k, then 1080p, 720p, 480p; skips empty', () {
      const q = StreamQualities(p480: 'u480', p720: 'u720', p1080: '', p4k: '');
      expect(q.best, 'u720');
      const q2 = StreamQualities(p480: 'u480', p720: 'u720', p1080: 'u1080', p4k: 'u4k');
      expect(q2.best, 'u4k');
      const q3 = StreamQualities(p480: '', p720: '', p1080: '', p4k: '');
      expect(q3.best, isNull);
    });

    test('SelectMovieQuality returns best verbatim', () {
      const info = MovieInfo(
        id: '1',
        title: 't',
        streamUrl: StreamQualities(p480: 'u480', p1080: 'u1080'),
      );
      expect(SelectMovieQuality().call(info), 'u1080');
    });
  });
}
