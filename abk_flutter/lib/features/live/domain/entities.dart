/// Live category (mode=packages).
class LiveCategory {
  final String id; // "-1" reserved for a client-side FAVORITE row
  final String name;
  final String? icon;
  final String? viewOrder;
  final int? channelCount;
  final int? categoryType;
  final int? parent;
  final bool isLocked;

  const LiveCategory({
    required this.id,
    required this.name,
    this.icon,
    this.viewOrder,
    this.channelCount,
    this.categoryType,
    this.parent,
    this.isLocked = false,
  });

  int get viewOrderInt => int.tryParse(viewOrder ?? '') ?? 0;
}

/// Live channel (mode=channels). `id` is the stream id used for EPG, favourites
/// and stream-URL resolution. `streamUrlTemplate` carries literal {user}/{pass}.
class LiveChannel {
  final int id;
  final String name;
  final int? categoryId;
  final String? icon;
  final int? viewOrder;
  final int tvArchive;
  final int hasEpg;
  final String? streamUrlTemplate;

  const LiveChannel({
    required this.id,
    required this.name,
    this.categoryId,
    this.icon,
    this.viewOrder,
    this.tvArchive = 0,
    this.hasEpg = 0,
    this.streamUrlTemplate,
  });

  bool get hasArchive => tvArchive != 0;
  bool get hasEpgData => hasEpg != 0;
}
