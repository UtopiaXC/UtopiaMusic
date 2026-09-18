class UserInfo {
  final int viewCount;
  final double minutesSaved;
  final int segmentCount;

  const UserInfo({
    required this.viewCount,
    required this.minutesSaved,
    required this.segmentCount,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        minutesSaved: (json['minutesSaved'] as num?)?.toDouble() ?? 0.0,
        segmentCount: (json['segmentCount'] as num?)?.toInt() ?? 0,
      );

  @override
  String toString() {
    int totalMinutes = minutesSaved.round();
    String formattedTime;
    if (totalMinutes < 60) {
      formattedTime = '$totalMinutes 分钟';
    } else {
      int hours = totalMinutes ~/ 60;
      int mins = totalMinutes % 60;
      formattedTime = '$hours 小时 $mins 分钟';
    }

    return '您提交了 $segmentCount 个片段\n'
        '您为大家跳过了 $viewCount 次片段\n'
        '(节省了 $formattedTime 的生命)';
  }
}
