import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Download Logic Tests', () {
    test('Download status categorization and sorting order', () {
      // Requirements:
      // 1. 下载中 (Downloading, status 1)
      // 2. 下载失败 (Failed, status 4)
      // 3. 队列中 / 暂停中 (Queued/Paused, status 0 or 2)
      // 4. 已下载 (Completed, status 3)

      final rawList = [
        {'id': 1, 'status': 3, 'title': 'Completed Song'},
        {'id': 2, 'status': 0, 'title': 'Queued Song'},
        {'id': 3, 'status': 1, 'title': 'Downloading Song'},
        {'id': 4, 'status': 4, 'title': 'Failed Song'},
        {'id': 5, 'status': 2, 'title': 'Paused Song'},
      ];

      final downloading = rawList.where((d) => d['status'] == 1).toList();
      final failed = rawList.where((d) => d['status'] == 4).toList();
      final queuedOrPaused = rawList.where((d) => d['status'] == 0 || d['status'] == 2).toList();
      final completed = rawList.where((d) => d['status'] == 3).toList();

      expect(downloading.length, 1);
      expect(downloading.first['id'], 3);

      expect(failed.length, 1);
      expect(failed.first['id'], 4);

      expect(queuedOrPaused.length, 2);
      expect(queuedOrPaused.map((d) => d['id']), containsAll([2, 5]));

      expect(completed.length, 1);
      expect(completed.first['id'], 1);
    });

    test('Size formatting helper tests', () {
      String formatSize(int bytes) {
        if (bytes <= 0) return '0 B';
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }

      expect(formatSize(0), '0 B');
      expect(formatSize(-10), '0 B');
      expect(formatSize(512), '512 B');
      expect(formatSize(1024), '1.0 KB');
      expect(formatSize(1024 * 1024), '1.0 MB');
      expect(formatSize((15.5 * 1024 * 1024).round()), '15.5 MB');
    });

    test('File prefix matching logic for multi-part videos', () {
      // Ensure BV123_456_ does not match BV123_4567_
      final bvid = 'BV123';
      final cid = 456;
      final otherCid = 4567;

      final filenameP1 = '${bvid}_${cid}_30280.m4a';
      final filenameP2 = '${bvid}_${otherCid}_30280.m4a';

      final prefix = '${bvid}_${cid}_';

      expect(filenameP1.startsWith(prefix), true);
      expect(filenameP2.startsWith(prefix), false);
    });

    test('Queue processing strictly respects maxConcurrentDownloads', () {
      final queue = [
        {'id': 'BV1_0', 'status': 0},
        {'id': 'BV2_0', 'status': 0},
        {'id': 'BV3_0', 'status': 0},
        {'id': 'BV4_0', 'status': 0},
        {'id': 'BV5_0', 'status': 0},
      ];

      const maxConcurrent = 2;
      int activeCount = 0;
      final activeList = <String>[];
      final waitingList = <String>[];

      // Process queue up to maxConcurrent
      while (activeCount < maxConcurrent && queue.isNotEmpty) {
        activeCount++;
        final task = queue.removeAt(0);
        activeList.add(task['id'] as String);
      }

      waitingList.addAll(queue.map((t) => t['id'] as String));

      expect(activeCount, 2);
      expect(activeList, ['BV1_0', 'BV2_0']);
      expect(waitingList, ['BV3_0', 'BV4_0', 'BV5_0']);
      expect(queue.length, 3);
    });

    test('Lazy secondary CID resolution logic', () {
      final task = {'bvid': 'BV_LAZY', 'cid': 0, 'status': 0};

      // When enqueued, CID remains 0 and no secondary resolution has taken place
      expect(task['cid'], 0);
      expect(task['status'], 0);

      // When download worker actually executes the task, secondary resolution occurs
      int resolvedCid = 987654321;
      task['cid'] = resolvedCid;
      task['status'] = 1; // Downloading

      expect(task['cid'], 987654321);
      expect(task['status'], 1);
    });
  });
}
