import '../../../core/utils/json_utils.dart';
import '../domain/entities.dart';

class LiveModels {
  static LiveCategory categoryFromJson(Map json) {
    final m = asMap(json);
    return LiveCategory(
      id: asString(m['id']),
      name: asString(m['category_name']),
      icon: asStringOrNull(m['category_icon']),
      viewOrder: asStringOrNull(m['view_order']),
      channelCount: asIntOrNull(m['ch_count']),
      categoryType: asIntOrNull(m['category_type']),
      parent: asIntOrNull(m['parent']),
      isLocked: asBoolOrNull(m['isLocked']) ?? false,
    );
  }

  static LiveChannel channelFromJson(Map json) {
    final m = asMap(json);
    return LiveChannel(
      id: asInt(m['id']),
      name: asString(m['stream_display_name']),
      categoryId: asIntOrNull(m['category_id']),
      icon: asStringOrNull(m['stream_icon']),
      viewOrder: asIntOrNull(m['view_order']),
      tvArchive: asInt(m['tv_archive']),
      hasEpg: asInt(m['has_epg']),
      streamUrlTemplate: asStringOrNull(m['stream_url']),
    );
  }
}
