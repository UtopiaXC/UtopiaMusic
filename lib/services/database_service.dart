import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:utopia_music/models/song.dart';
import 'package:path_provider/path_provider.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "DATABASE_SERVICE";

class LocalPlaylist {
  final int id;
  final String title;
  final String description;
  final String? coverUrl;
  final int songCount;

  LocalPlaylist({
    required this.id,
    required this.title,
    required this.description,
    this.coverUrl,
    this.songCount = 0,
  });
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    Log.v(_tag, "database");
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Log.v(_tag, "_initDatabase");
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path = join(await getDatabasesPath(), 'utopia_music.db');
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final Directory appSupportDir = await getApplicationSupportDirectory();
      if (!await appSupportDir.exists()) {
        await appSupportDir.create(recursive: true);
      }
      path = join(appSupportDir.path, 'utopia_music.db');
    } else {
      path = join(await getDatabasesPath(), 'utopia_music.db');
    }
    return await openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    Log.v(_tag, "_onCreate, version: $version");
    await db.execute('''
      CREATE TABLE playlist(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        origin_title TEXT,
        artist TEXT,
        coverUrl TEXT,
        lyrics TEXT,
        colorValue INTEGER,
        bvid TEXT,
        cid INTEGER,
        sequence_order INTEGER,
        shuffle_order INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE local_playlists(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        create_time INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE local_playlist_songs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER,
        title TEXT,
        origin_title TEXT,
        artist TEXT,
        cover_url TEXT,
        lyrics TEXT,
        color_value INTEGER,
        bvid TEXT,
        cid INTEGER,
        sort_order INTEGER,
        FOREIGN KEY(playlist_id) REFERENCES local_playlists(id) ON DELETE CASCADE
      )
    ''');

    await _createCacheMetaTable(db);
    await _createDownloadsTable(db);
    await _createListCacheTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Log.v(_tag, "_onUpgrade, oldVersion: $oldVersion, newVersion: $newVersion");
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE playlist ADD COLUMN origin_title TEXT');
      await db.execute('UPDATE playlist SET origin_title = title');
    }
    if (oldVersion < 3) {
      await _createCacheMetaTable(db);
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE cache_meta ADD COLUMN file_size INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE cache_meta ADD COLUMN status INTEGER DEFAULT 1',
        );
      } catch (_) {}
    }
    if (oldVersion < 5) {
      await _createDownloadsTable(db);
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE cache_meta ADD COLUMN total_size INTEGER DEFAULT 0',
        );
        await db.execute('ALTER TABLE cache_meta ADD COLUMN session_id TEXT');

        await db.execute('DELETE FROM cache_meta');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      await _createListCacheTable(db);
    }
  }

  Future<void> _createCacheMetaTable(DatabaseExecutor db) async {
    Log.v(_tag, "_createCacheMetaTable");
    await db.execute('''
      CREATE TABLE cache_meta(
        key TEXT PRIMARY KEY, 
        bvid TEXT,
        cid INTEGER,
        quality INTEGER,
        hit_count INTEGER DEFAULT 1,
        last_access_time INTEGER,
        file_size INTEGER DEFAULT 0,
        total_size INTEGER DEFAULT 0,
        status INTEGER DEFAULT 1,
        session_id TEXT
      )
    ''');
  }

  Future<void> _createDownloadsTable(DatabaseExecutor db) async {
    Log.v(_tag, "_createDownloadsTable");
    await db.execute('''
      CREATE TABLE downloads(
        id TEXT PRIMARY KEY, 
        bvid TEXT,
        cid INTEGER,
        title TEXT,
        artist TEXT,
        cover_url TEXT,
        save_path TEXT,
        quality INTEGER,
        progress REAL DEFAULT 0.0,
        status INTEGER DEFAULT 0, 
        create_time INTEGER
      )
    ''');
  }

  Future<void> _createListCacheTable(DatabaseExecutor db) async {
    Log.v(_tag, "_createListCacheTable");
    await db.execute('''
      CREATE TABLE list_cache(
        cache_key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        access_count INTEGER DEFAULT 1,
        last_access INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        size_bytes INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> saveListCache(String key, String jsonData) async {
    Log.v(_tag, "saveListCache, key: $key");
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final sizeBytes = jsonData.length * 2;

    await db.insert('list_cache', {
      'cache_key': key,
      'data': jsonData,
      'access_count': 1,
      'last_access': now,
      'created_at': now,
      'size_bytes': sizeBytes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getListCache(String key) async {
    Log.v(_tag, "getListCache, key: $key");
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final result = await db.query(
      'list_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    if (result.isEmpty) return null;
    await db.rawUpdate(
      'UPDATE list_cache SET access_count = access_count + 1, last_access = ? WHERE cache_key = ?',
      [now, key],
    );

    return result.first['data'] as String?;
  }

  Future<void> deleteListCache(String key) async {
    Log.v(_tag, "deleteListCache, key: $key");
    final db = await database;
    await db.delete('list_cache', where: 'cache_key = ?', whereArgs: [key]);
  }

  Future<int> getListCacheSize() async {
    Log.v(_tag, "getListCacheSize");
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(size_bytes) as total FROM list_cache',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<void> clearListCache() async {
    Log.v(_tag, "clearListCache");
    final db = await database;
    await db.delete('list_cache');
  }

  Future<void> cleanupListCacheLFU(int bytesToFree) async {
    Log.v(_tag, "cleanupListCacheLFU, bytesToFree: $bytesToFree");
    final db = await database;

    final entries = await db.query(
      'list_cache',
      orderBy: 'access_count ASC, last_access ASC',
    );

    int freedBytes = 0;
    final keysToRemove = <String>[];

    for (var entry in entries) {
      if (freedBytes >= bytesToFree) break;
      keysToRemove.add(entry['cache_key'] as String);
      freedBytes += (entry['size_bytes'] as int?) ?? 0;
    }

    for (var key in keysToRemove) {
      await db.delete('list_cache', where: 'cache_key = ?', whereArgs: [key]);
    }

    Log.v(
      _tag,
      "LFU cleanup: removed ${keysToRemove.length} entries, freed $freedBytes bytes",
    );
  }

  Future<List<Song>> getPlaylist({bool isShuffleMode = false}) async {
    Log.v(_tag, "getPlaylist, isShuffleMode: $isShuffleMode");
    final db = await database;
    final String orderBy = isShuffleMode
        ? 'shuffle_order ASC'
        : 'sequence_order ASC';
    final List<Map<String, dynamic>> maps = await db.query(
      'playlist',
      orderBy: orderBy,
    );
    return List.generate(
      maps.length,
      (i) => Song(
        title: maps[i]['title'],
        originTitle: maps[i]['origin_title'],
        artist: maps[i]['artist'],
        coverUrl: maps[i]['coverUrl'],
        lyrics: maps[i]['lyrics'],
        colorValue: maps[i]['colorValue'],
        bvid: maps[i]['bvid'],
        cid: maps[i]['cid'],
      ),
    );
  }

  Future<void> replacePlaylist(List<Song> songs) async {
    Log.v(_tag, "replacePlaylist, songs: $songs");
    final db = await database;
    List<int> shuffleIndices = List.generate(songs.length, (index) => index);
    shuffleIndices.shuffle(Random());
    await db.transaction((txn) async {
      await txn.delete('playlist');
      final batch = txn.batch();
      for (int i = 0; i < songs.length; i++) {
        final song = songs[i];
        batch.insert('playlist', {
          'title': song.title,
          'origin_title': song.originTitle,
          'artist': song.artist,
          'coverUrl': song.coverUrl,
          'lyrics': song.lyrics,
          'colorValue': song.colorValue,
          'bvid': song.bvid,
          'cid': song.cid,
          'sequence_order': i,
          'shuffle_order': shuffleIndices[i],
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertSong(Song song, {Song? afterSong}) async {
    Log.v(_tag, "insertSong, song: $song, afterSong: $afterSong");
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'playlist',
        columns: ['id'],
        where: 'bvid = ? AND cid = ?',
        whereArgs: [song.bvid, song.cid],
      );
      if (existing.isNotEmpty) {
        await txn.delete(
          'playlist',
          where: 'bvid = ? AND cid = ?',
          whereArgs: [song.bvid, song.cid],
        );
      }
      final maxRes = await txn.rawQuery(
        'SELECT MAX(sequence_order) as max_seq, MAX(shuffle_order) as max_shuf FROM playlist',
      );
      int maxSeq = (maxRes.first['max_seq'] as int?) ?? -1;
      int maxShuf = (maxRes.first['max_shuf'] as int?) ?? -1;
      int newSeqOrder, newShufOrder;

      if (afterSong == null) {
        newSeqOrder = maxSeq + 1;
        newShufOrder = maxShuf + 1;
      } else {
        final currentRes = await txn.query(
          'playlist',
          columns: ['sequence_order', 'shuffle_order'],
          where: 'bvid = ? AND cid = ?',
          whereArgs: [afterSong.bvid, afterSong.cid],
        );
        if (currentRes.isEmpty) {
          newSeqOrder = maxSeq + 1;
          newShufOrder = maxShuf + 1;
        } else {
          final curSeq = currentRes.first['sequence_order'] as int;
          final curShuf = currentRes.first['shuffle_order'] as int;
          newSeqOrder = curSeq + 1;
          newShufOrder = curShuf + 1;
          await txn.rawUpdate(
            'UPDATE playlist SET sequence_order = sequence_order + 1 WHERE sequence_order > ?',
            [curSeq],
          );
          await txn.rawUpdate(
            'UPDATE playlist SET shuffle_order = shuffle_order + 1 WHERE shuffle_order > ?',
            [curShuf],
          );
        }
      }
      await txn.insert('playlist', {
        'title': song.title,
        'origin_title': song.originTitle,
        'artist': song.artist,
        'coverUrl': song.coverUrl,
        'lyrics': song.lyrics,
        'colorValue': song.colorValue,
        'bvid': song.bvid,
        'cid': song.cid,
        'sequence_order': newSeqOrder,
        'shuffle_order': newShufOrder,
      });
    });
  }

  Future<void> removeSong(String bvid, int cid) async {
    Log.v(_tag, "removeSong, bvid: $bvid, cid: $cid");
    final db = await database;
    await db.delete(
      'playlist',
      where: 'bvid = ? AND cid = ?',
      whereArgs: [bvid, cid],
    );
  }

  Future<void> reorderPlaylist(
    int oldIndex,
    int newIndex,
    bool isShuffleMode,
  ) async {
    Log.v(
      _tag,
      "reorderPlaylist, oldIndex: $oldIndex, newIndex: $newIndex, isShuffleMode: $isShuffleMode",
    );
    final db = await database;
    final column = isShuffleMode ? 'shuffle_order' : 'sequence_order';
    final List<Map<String, dynamic>> maps = await db.query(
      'playlist',
      columns: ['id', column],
      orderBy: '$column ASC',
    );
    if (oldIndex < 0 ||
        oldIndex >= maps.length ||
        newIndex < 0 ||
        newIndex >= maps.length)
      return;
    List<int> orderedIds = maps.map((m) => m['id'] as int).toList();
    final int removedId = orderedIds.removeAt(oldIndex);
    orderedIds.insert(newIndex, removedId);
    await db.transaction((txn) async {
      final batch = txn.batch();
      int start = min(oldIndex, newIndex);
      int end = max(oldIndex, newIndex);
      for (int i = start; i <= end; i++) {
        batch.update(
          'playlist',
          {column: i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> clearPlaylist() async {
    Log.v(_tag, "clearPlaylist");
    final db = await database;
    await db.delete('playlist');
  }

  Future<void> recordCacheAccess(
    String bvid,
    int cid,
    int quality, {
    int fileSize = 0,
    int totalSize = 0,
    int? status,
    String? sessionId,
  }) async {
    Log.v(
      _tag,
      "recordCacheAccess, bvid: $bvid, cid: $cid, quality: $quality, fileSize: $fileSize, totalSize: $totalSize, status: $status, sessionId: $sessionId",
    );
    final db = await database;
    final key = '${bvid}_${cid}_$quality';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final List<Map<String, dynamic>> res = await txn.query(
        'cache_meta',
        columns: ['hit_count'],
        where: 'key = ?',
        whereArgs: [key],
      );

      if (res.isEmpty) {
        await txn.insert('cache_meta', {
          'key': key,
          'bvid': bvid,
          'cid': cid,
          'quality': quality,
          'hit_count': 1,
          'last_access_time': now,
          'file_size': fileSize,
          'total_size': totalSize,
          'status': status ?? 2,
          'session_id': sessionId,
        });
      } else {
        String sql =
            'UPDATE cache_meta SET hit_count = hit_count + 1, last_access_time = ?';
        List<dynamic> args = [now];

        if (fileSize > 0) {
          sql += ', file_size = ?';
          args.add(fileSize);
        }
        if (totalSize > 0) {
          sql += ', total_size = ?';
          args.add(totalSize);
        }
        if (status != null) {
          sql += ', status = ?';
          args.add(status);
        }
        if (sessionId != null) {
          sql += ', session_id = ?';
          args.add(sessionId);
        }

        sql += ' WHERE key = ?';
        args.add(key);

        await txn.rawUpdate(sql, args);
      }
    });
  }

  Future<Map<String, dynamic>?> getCacheMeta(
    String bvid,
    int cid,
    int quality,
  ) async {
    Log.v(_tag, "getCacheMeta, bvid: $bvid, cid: $cid, quality: $quality");
    final db = await database;
    final key = '${bvid}_${cid}_$quality';
    final res = await db.query(
      'cache_meta',
      where: 'key = ?',
      whereArgs: [key],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getCompletedCacheMeta() async {
    Log.v(_tag, "getCompletedCacheMeta");
    final db = await database;
    return await db.query('cache_meta', where: 'status = ?', whereArgs: [1]);
  }

  Future<void> removeCacheMeta(String key) async {
    Log.v(_tag, "removeCacheMeta, key: $key");
    final db = await database;
    await db.delete('cache_meta', where: 'key = ?', whereArgs: [key]);
  }

  Future<void> clearCacheMetaTable() async {
    Log.v(_tag, "clearCacheMetaTable");
    final db = await database;
    await db.delete('cache_meta');
  }

  Future<int> createLocalPlaylist(String title, String description) async {
    Log.v(
      _tag,
      "createLocalPlaylist, title: $title, description: $description",
    );
    final db = await database;
    return await db.insert('local_playlists', {
      'title': title,
      'description': description,
      'create_time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteLocalPlaylist(int id) async {
    Log.v(_tag, "deleteLocalPlaylist, id: $id");
    final db = await database;
    await db.delete('local_playlists', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'local_playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLocalPlaylist(
    int id,
    String title,
    String description,
  ) async {
    Log.v(
      _tag,
      "updateLocalPlaylist, id: $id, title: $title, description: $description",
    );
    final db = await database;
    await db.update(
      'local_playlists',
      {'title': title, 'description': description},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LocalPlaylist>> getLocalPlaylists() async {
    Log.v(_tag, "getLocalPlaylists");
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_playlists',
      orderBy: 'create_time DESC',
    );
    List<LocalPlaylist> playlists = [];
    for (var map in maps) {
      final int id = map['id'];
      final List<Map<String, dynamic>> songs = await db.query(
        'local_playlist_songs',
        columns: ['cover_url'],
        where: 'playlist_id = ?',
        whereArgs: [id],
        orderBy: 'sort_order ASC',
        limit: 1,
      );
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM local_playlist_songs WHERE playlist_id = ?',
        [id],
      );
      final int count = Sqflite.firstIntValue(countResult) ?? 0;
      playlists.add(
        LocalPlaylist(
          id: id,
          title: map['title'],
          description: map['description'],
          coverUrl: songs.isNotEmpty ? songs.first['cover_url'] : null,
          songCount: count,
        ),
      );
    }
    return playlists;
  }

  Future<void> addSongToLocalPlaylist(int playlistId, Song song) async {
    Log.v(_tag, "addSongToLocalPlaylist, playlistId: $playlistId, song: $song");
    final db = await database;
    final List<Map<String, dynamic>> maxResult = await db.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM local_playlist_songs WHERE playlist_id = ?',
      [playlistId],
    );
    int maxOrder = (maxResult.first['max_order'] as int?) ?? -1;
    await db.insert('local_playlist_songs', {
      'playlist_id': playlistId,
      'title': song.title,
      'origin_title': song.originTitle,
      'artist': song.artist,
      'cover_url': song.coverUrl,
      'lyrics': song.lyrics,
      'color_value': song.colorValue,
      'bvid': song.bvid,
      'cid': song.cid,
      'sort_order': maxOrder + 1,
    });
  }

  Future<void> removeSongFromLocalPlaylist(
    int playlistId,
    String bvid,
    int cid,
  ) async {
    Log.v(
      _tag,
      "removeSongFromLocalPlaylist, playlistId: $playlistId, bvid: $bvid, cid: $cid",
    );
    final db = await database;
    await db.delete(
      'local_playlist_songs',
      where: 'playlist_id = ? AND bvid = ? AND cid = ?',
      whereArgs: [playlistId, bvid, cid],
    );
  }

  Future<List<Song>> getLocalPlaylistSongs(int playlistId) async {
    Log.v(_tag, "getLocalPlaylistSongs, playlistId: $playlistId");
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'sort_order ASC',
    );
    return List.generate(
      maps.length,
      (i) => Song(
        title: maps[i]['title'],
        originTitle: maps[i]['origin_title'],
        artist: maps[i]['artist'],
        coverUrl: maps[i]['cover_url'],
        lyrics: maps[i]['lyrics'],
        colorValue: maps[i]['color_value'],
        bvid: maps[i]['bvid'],
        cid: maps[i]['cid'],
      ),
    );
  }

  Future<void> updateLocalPlaylistSongOrder(
    int playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    Log.v(
      _tag,
      "updateLocalPlaylistSongOrder, playlistId: $playlistId, oldIndex: $oldIndex, newIndex: $newIndex",
    );
    final db = await database;
    final songs = await getLocalPlaylistSongs(playlistId);
    if (oldIndex < 0 ||
        oldIndex >= songs.length ||
        newIndex < 0 ||
        newIndex >= songs.length)
      return;
    final song = songs.removeAt(oldIndex);
    songs.insert(newIndex, song);
    await db.transaction((txn) async {
      for (int i = 0; i < songs.length; i++) {
        await txn.update(
          'local_playlist_songs',
          {'sort_order': i},
          where: 'playlist_id = ? AND bvid = ? AND cid = ?',
          whereArgs: [playlistId, songs[i].bvid, songs[i].cid],
        );
      }
    });
  }

  Future<void> updateLocalPlaylistSongTitle(
    int playlistId,
    String bvid,
    int cid,
    String newTitle,
  ) async {
    Log.v(
      _tag,
      "updateLocalPlaylistSongTitle, playlistId: $playlistId, bvid: $bvid, cid: $cid, newTitle: $newTitle",
    );
    final db = await database;
    await db.update(
      'local_playlist_songs',
      {'title': newTitle},
      where: 'playlist_id = ? AND bvid = ? AND cid = ?',
      whereArgs: [playlistId, bvid, cid],
    );
  }

  Future<void> resetLocalPlaylistSongTitle(
    int playlistId,
    String bvid,
    int cid,
  ) async {
    Log.v(
      _tag,
      "resetLocalPlaylistSongTitle, playlistId: $playlistId, bvid: $bvid, cid: $cid",
    );
    final db = await database;
    await db.rawUpdate(
      'UPDATE local_playlist_songs SET title = origin_title WHERE playlist_id = ? AND bvid = ? AND cid = ?',
      [playlistId, bvid, cid],
    );
  }

  Future<void> insertDownload(Song song, String savePath, int quality) async {
    Log.v(
      _tag,
      "insertDownload, song: $song, savePath: $savePath, quality: $quality",
    );
    final db = await database;
    final id = '${song.bvid}_${song.cid}';

    await db.insert('downloads', {
      'id': id,
      'bvid': song.bvid,
      'cid': song.cid,
      'title': song.title,
      'artist': song.artist,
      'cover_url': song.coverUrl,
      'save_path': savePath,
      'quality': quality,
      'progress': 0.0,
      'status': 0,
      'create_time': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateDownloadStatus(
    String bvid,
    int cid,
    int status, {
    double? progress,
  }) async {
    Log.v(
      _tag,
      "updateDownloadStatus, bvid: $bvid, cid: $cid, status: $status, progress: $progress",
    );
    final db = await database;
    final id = '${bvid}_${cid}';
    final Map<String, dynamic> values = {'status': status};
    if (progress != null) {
      values['progress'] = progress;
    }
    await db.update('downloads', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllDownloads() async {
    Log.v(_tag, "getAllDownloads");
    final db = await database;
    return await db.query('downloads', orderBy: 'create_time DESC');
  }

  Future<Map<String, dynamic>?> getDownload(String bvid, int cid) async {
    Log.v(_tag, "getDownload, bvid: $bvid, cid: $cid");
    final db = await database;
    final id = '${bvid}_${cid}';
    final res = await db.query('downloads', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> deleteDownload(String bvid, int cid) async {
    Log.v(_tag, "deleteDownload, bvid: $bvid, cid: $cid");
    final db = await database;
    final id = '${bvid}_${cid}';
    await db.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isDownloaded(String bvid, int cid) async {
    Log.v(_tag, "isDownloaded, bvid: $bvid, cid: $cid");
    final db = await database;
    final id = '${bvid}_${cid}';
    final List<Map<String, dynamic>> res = await db.query(
      'downloads',
      columns: ['status'],
      where: 'id = ? AND status = 3',
      whereArgs: [id],
    );
    return res.isNotEmpty;
  }

  Future<List<String>> getDownloadedIds(List<String> ids) async {
    Log.v(_tag, "getDownloadedIds, ids: $ids");
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final List<Map<String, dynamic>> res = await db.query(
      'downloads',
      columns: ['id'],
      where: 'id IN ($placeholders) AND status = 3',
      whereArgs: ids,
    );
    return res.map((e) => e['id'] as String).toList();
  }

  Future<Map<String, dynamic>?> getCompletedDownload(
    String bvid,
    int cid,
  ) async {
    Log.v(_tag, "getCompletedDownload, bvid: $bvid, cid: $cid");
    final db = await database;
    final id = '${bvid}_${cid}';
    final List<Map<String, dynamic>> res = await db.query(
      'downloads',
      where: 'id = ? AND status = 3',
      whereArgs: [id],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> clearStaticCacheMeta() async {
    Log.v(_tag, "clearStaticCacheMeta");
    final db = await database;
    await db.delete('cache_meta', where: 'status = ?', whereArgs: [1]);
  }

  Future<void> updateCid(String bvid, int newCid) async {
    Log.v(_tag, "updateCid, bvid: $bvid, newCid: $newCid");
    final db = await database;
    try {
      await db.update(
        'playlist',
        {'cid': newCid},
        where: 'bvid = ?',
        whereArgs: [bvid],
      );
      await db.update(
        'local_playlist_songs',
        {'cid': newCid},
        where: 'bvid = ?',
        whereArgs: [bvid],
      );
      Log.i(_tag, 'DatabaseService: Updated CID for $bvid to $newCid');
    } catch (e) {
      Log.e(_tag, 'Failed to update CID', e);
    }
  }

  Future<void> deleteDatabaseFile() async {
    Log.v(_tag, "deleteDatabaseFile");
    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
      }
      String path = join(await getDatabasesPath(), 'utopia_music.db');
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      Log.i(_tag, 'Database file deleted.');
    } catch (e) {
      Log.e(_tag, "Error deleting database", e);
    }
  }
}
