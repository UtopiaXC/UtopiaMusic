import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:utopia_music/models/song.dart';

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
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path = join(await getDatabasesPath(), 'utopia_music.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Upgrade playlist table
      await db.execute('ALTER TABLE playlist ADD COLUMN origin_title TEXT');
      // Initialize origin_title with title for existing rows
      await db.execute('UPDATE playlist SET origin_title = title');

      // Create new tables
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
    }
  }

  // --- Current Playlist Methods ---

  Future<void> clearPlaylist() async {
    final db = await database;
    await db.delete('playlist');
  }

  Future<void> savePlaylist(List<Song> songs) async {
    final db = await database;
    List<int> shuffleIndices = List.generate(songs.length, (index) => index);
    shuffleIndices.shuffle();

    await db.transaction((txn) async {
      await txn.delete('playlist');

      for (int i = 0; i < songs.length; i++) {
        final song = songs[i];
        await txn.insert('playlist', {
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
    });
  }

  Future<List<Song>> getPlaylist({bool shuffle = false}) async {
    final db = await database;
    final String orderBy = shuffle ? 'shuffle_order ASC' : 'sequence_order ASC';

    final List<Map<String, dynamic>> maps = await db.query(
      'playlist',
      orderBy: orderBy,
    );

    return List.generate(maps.length, (i) {
      return Song(
        title: maps[i]['title'],
        originTitle: maps[i]['origin_title'],
        artist: maps[i]['artist'],
        coverUrl: maps[i]['coverUrl'],
        lyrics: maps[i]['lyrics'],
        colorValue: maps[i]['colorValue'],
        bvid: maps[i]['bvid'],
        cid: maps[i]['cid'],
      );
    });
  }

  Future<void> removeSong(String bvid, int cid) async {
    final db = await database;
    await db.delete('playlist', where: 'bvid = ? AND cid = ?', whereArgs: [bvid, cid]);
  }

  Future<void> insertSong(Song song, {Song? afterSong, required bool isShuffleMode}) async {
    final db = await database;

    // 【修复】使用事务包裹所有数据库操作，防止并发导致的顺序错乱
    await db.transaction((txn) async {
      // 1. 如果歌曲已存在，先删除（在事务中执行）
      await txn.delete('playlist', where: 'bvid = ? AND cid = ?', whereArgs: [song.bvid, song.cid]);

      int sequenceOrder;
      int shuffleOrder;

      // 2. 获取当前最大序号
      final List<Map<String, dynamic>> maxResult = await txn.rawQuery(
          'SELECT MAX(sequence_order) as max_seq, MAX(shuffle_order) as max_shuf FROM playlist'
      );
      int maxSeq = (maxResult.first['max_seq'] as int?) ?? -1;
      int maxShuf = (maxResult.first['max_shuf'] as int?) ?? -1;

      if (afterSong == null) {
        sequenceOrder = maxSeq + 1;
        shuffleOrder = maxShuf + 1;
      } else {
        final List<Map<String, dynamic>> currentResult = await txn.query(
          'playlist',
          columns: ['sequence_order', 'shuffle_order'],
          where: 'bvid = ? AND cid = ?',
          whereArgs: [afterSong.bvid, afterSong.cid],
        );

        if (currentResult.isEmpty) {
          sequenceOrder = maxSeq + 1;
          shuffleOrder = maxShuf + 1;
        } else {
          int currentSeq = currentResult.first['sequence_order'] as int;
          int currentShuf = currentResult.first['shuffle_order'] as int;

          if (isShuffleMode) {
            // 乱序模式插入逻辑
            shuffleOrder = currentShuf + 1;
            await txn.rawUpdate(
                'UPDATE playlist SET shuffle_order = shuffle_order + 1 WHERE shuffle_order >= ?',
                [shuffleOrder]
            );
            sequenceOrder = maxSeq + 1;
          } else {
            // 顺序模式插入逻辑
            sequenceOrder = currentSeq + 1;
            await txn.rawUpdate(
                'UPDATE playlist SET sequence_order = sequence_order + 1 WHERE sequence_order >= ?',
                [sequenceOrder]
            );
            shuffleOrder = maxShuf + 1;
          }
        }
      }

      // 3. 插入新歌曲
      await txn.insert('playlist', {
        'title': song.title,
        'origin_title': song.originTitle,
        'artist': song.artist,
        'coverUrl': song.coverUrl,
        'lyrics': song.lyrics,
        'colorValue': song.colorValue,
        'bvid': song.bvid,
        'cid': song.cid,
        'sequence_order': sequenceOrder,
        'shuffle_order': shuffleOrder,
      });
    });
  }

  Future<void> addSongToEnd(Song song) async {
    await insertSong(song, afterSong: null, isShuffleMode: false);
  }

  // --- Local Playlist Methods ---

  Future<int> createLocalPlaylist(String title, String description) async {
    final db = await database;
    return await db.insert('local_playlists', {
      'title': title,
      'description': description,
      'create_time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteLocalPlaylist(int id) async {
    final db = await database;
    await db.delete('local_playlists', where: 'id = ?', whereArgs: [id]);
    // Cascade delete should handle songs, but just in case or if not supported
    await db.delete('local_playlist_songs', where: 'playlist_id = ?', whereArgs: [id]);
  }

  Future<void> updateLocalPlaylist(int id, String title, String description) async {
    final db = await database;
    await db.update(
      'local_playlists',
      {'title': title, 'description': description},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LocalPlaylist>> getLocalPlaylists() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_playlists',
      orderBy: 'create_time DESC',
    );

    List<LocalPlaylist> playlists = [];
    for (var map in maps) {
      final int id = map['id'];
      // Get song count and first song cover
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
          [id]
      );
      final int count = Sqflite.firstIntValue(countResult) ?? 0;

      String? coverUrl;
      if (songs.isNotEmpty) {
        coverUrl = songs.first['cover_url'];
      }

      playlists.add(LocalPlaylist(
        id: id,
        title: map['title'],
        description: map['description'],
        coverUrl: coverUrl,
        songCount: count,
      ));
    }
    return playlists;
  }

  Future<void> addSongToLocalPlaylist(int playlistId, Song song) async {
    final db = await database;

    // Get max sort order
    final List<Map<String, dynamic>> maxResult = await db.rawQuery(
        'SELECT MAX(sort_order) as max_order FROM local_playlist_songs WHERE playlist_id = ?',
        [playlistId]
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

  Future<void> removeSongFromLocalPlaylist(int playlistId, String bvid, int cid) async {
    final db = await database;
    await db.delete(
      'local_playlist_songs',
      where: 'playlist_id = ? AND bvid = ? AND cid = ?',
      whereArgs: [playlistId, bvid, cid],
    );
  }

  Future<List<Song>> getLocalPlaylistSongs(int playlistId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'sort_order ASC',
    );

    return List.generate(maps.length, (i) {
      return Song(
        title: maps[i]['title'],
        originTitle: maps[i]['origin_title'],
        artist: maps[i]['artist'],
        coverUrl: maps[i]['cover_url'],
        lyrics: maps[i]['lyrics'],
        colorValue: maps[i]['color_value'],
        bvid: maps[i]['bvid'],
        cid: maps[i]['cid'],
      );
    });
  }

  Future<void> updateLocalPlaylistSongOrder(int playlistId, int oldIndex, int newIndex) async {
    final db = await database;
    final songs = await getLocalPlaylistSongs(playlistId);
    if (oldIndex < 0 || oldIndex >= songs.length || newIndex < 0 || newIndex >= songs.length) return;

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

  Future<void> updateLocalPlaylistSongTitle(int playlistId, String bvid, int cid, String newTitle) async {
    final db = await database;
    await db.update(
      'local_playlist_songs',
      {'title': newTitle},
      where: 'playlist_id = ? AND bvid = ? AND cid = ?',
      whereArgs: [playlistId, bvid, cid],
    );
  }

  Future<void> resetLocalPlaylistSongTitle(int playlistId, String bvid, int cid) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE local_playlist_songs SET title = origin_title WHERE playlist_id = ? AND bvid = ? AND cid = ?',
        [playlistId, bvid, cid]
    );
  }
}