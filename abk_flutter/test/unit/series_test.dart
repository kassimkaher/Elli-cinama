import 'package:abk_player/features/series/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('series list item maps catid/backdrop-as-string', () {
    final s = SeriesModels.listItemFromJson({
      'id': '77',
      'title': 'My Show',
      'catid': '9',
      'backdrop': 'http://h/b.jpg',
      'view_order': 2,
    });
    expect(s.id, '77');
    expect(s.categoryId, '9');
    expect(s.backdrop, 'http://h/b.jpg');
    expect(s.viewOrder, 2);
  });

  test('series_info parses info + seasons + episodes; backdrop as list', () {
    final info = SeriesModels.infoFromJson({
      'info': {
        'title': 'My Show',
        'plot': 'p',
        'backdrop': ['http://h/1.jpg', 'http://h/2.jpg'],
      },
      'seasons': [
        {
          'season_num': 1,
          'episodes': [
            {'episode_num': '1', 'episode_name': 'Pilot', 'stream_url': 'http://h/e1'},
            {'episode_num': '2', 'episode_name': 'Ep2', 'stream_url': 'http://h/e2'},
          ],
        },
      ],
    });
    expect(info.info!.title, 'My Show');
    expect(info.info!.backdrops.length, 2);
    expect(info.seasons.length, 1);
    expect(info.seasons.first.seasonNum, 1);
    expect(info.seasons.first.episodes.length, 2);
    expect(info.seasons.first.episodes.first.streamUrl, 'http://h/e1');
  });

  test('empty seasons is tolerated', () {
    final info = SeriesModels.infoFromJson({'info': {'title': 't'}});
    expect(info.seasons, isEmpty);
    expect(info.info!.title, 't');
  });
}
