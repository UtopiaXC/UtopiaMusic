class SegmentItemModel {
  final String? cid;
  final String category;
  final String? actionType;
  final List<int> segment; // in milliseconds
  final String uuid;
  final num? videoDuration; // in milliseconds
  final int? votes;

  SegmentItemModel({
    this.cid,
    required this.category,
    this.actionType,
    required this.segment,
    required this.uuid,
    this.videoDuration,
    this.votes,
  });

  factory SegmentItemModel.fromJson(Map<String, dynamic> json) =>
      SegmentItemModel(
        cid: json["cid"]?.toString(),
        category: json["category"] as String,
        actionType: json["actionType"] as String?,
        segment: (json["segment"] as List)
            .map((e) => ((e as num) * 1000).round())
            .toList(),
        uuid: (json["UUID"] ?? json["uuid"] ?? '') as String,
        videoDuration: json["videoDuration"] == null
            ? null
            : (json["videoDuration"] as num) * 1000,
        votes: json["votes"] as int?,
      );

  Map<String, dynamic> toJson() => {
        "cid": cid,
        "category": category,
        "actionType": actionType,
        "segment": segment.map((e) => e / 1000.0).toList(),
        "UUID": uuid,
        "videoDuration": videoDuration != null ? videoDuration! / 1000.0 : null,
        "votes": votes,
      };
}
