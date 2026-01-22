import 'dart:math';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:utopia_music/models/song.dart';

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
    String path = join(await getDatabasesPath(), 'utopia_music.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE playlist(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
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
  }

  Future<void> clearPlaylist() async {
    final db = await database;
    await db.delete('playlist');
  }

  // Save a new playlist. Generates shuffle order automatically.
  Future<void> savePlaylist(List<Song> songs) async {
    final db = await database;
    
    // Generate shuffle indices
    List<int> shuffleIndices = List.generate(songs.length, (index) => index);
    shuffleIndices.shuffle();

    await db.transaction((txn) async {
      await txn.delete('playlist');
      
      for (int i = 0; i < songs.length; i++) {
        final song = songs[i];
        await txn.insert('playlist', {
          'title': song.title,
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

  // Insert song. If afterSong is provided, inserts after it in the current mode's order.
  // In the other mode's order, it appends to the end.
  Future<void> insertSong(Song song, {Song? afterSong, required bool isShuffleMode}) async {
    final db = await database;
    
    // 1. Remove if exists (to handle "move")
    await removeSong(song.bvid, song.cid);
    
    // 2. Determine positions
    int sequenceOrder;
    int shuffleOrder;
    
    // Get max orders
    final List<Map<String, dynamic>> maxResult = await db.rawQuery(
      'SELECT MAX(sequence_order) as max_seq, MAX(shuffle_order) as max_shuf FROM playlist'
    );
    int maxSeq = (maxResult.first['max_seq'] as int?) ?? -1;
    int maxShuf = (maxResult.first['max_shuf'] as int?) ?? -1;

    if (afterSong == null) {
        // Append to end
        sequenceOrder = maxSeq + 1;
        shuffleOrder = maxShuf + 1;
    } else {
        // Get afterSong orders
        final List<Map<String, dynamic>> currentResult = await db.query(
            'playlist',
            columns: ['sequence_order', 'shuffle_order'],
            where: 'bvid = ? AND cid = ?',
            whereArgs: [afterSong.bvid, afterSong.cid],
        );
        
        if (currentResult.isEmpty) {
            // Fallback to append
            sequenceOrder = maxSeq + 1;
            shuffleOrder = maxShuf + 1;
        } else {
            int currentSeq = currentResult.first['sequence_order'] as int;
            int currentShuf = currentResult.first['shuffle_order'] as int;
            
            if (isShuffleMode) {
                // Insert after in shuffle order
                shuffleOrder = currentShuf + 1;
                // Shift others
                await db.rawUpdate(
                    'UPDATE playlist SET shuffle_order = shuffle_order + 1 WHERE shuffle_order >= ?',
                    [shuffleOrder]
                );
                // Append to sequence
                sequenceOrder = maxSeq + 1;
            } else {
                // Insert after in sequence order
                sequenceOrder = currentSeq + 1;
                // Shift others
                await db.rawUpdate(
                    'UPDATE playlist SET sequence_order = sequence_order + 1 WHERE sequence_order >= ?',
                    [sequenceOrder]
                );
                // Append to shuffle
                shuffleOrder = maxShuf + 1;
            }
        }
    }

    await db.insert('playlist', {
      'title': song.title,
      'artist': song.artist,
      'coverUrl': song.coverUrl,
      'lyrics': song.lyrics,
      'colorValue': song.colorValue,
      'bvid': song.bvid,
      'cid': song.cid,
      'sequence_order': sequenceOrder,
      'shuffle_order': shuffleOrder,
    });
  }
  
  Future<void> addSongToEnd(Song song) async {
     await insertSong(song, afterSong: null, isShuffleMode: false);
  }
}
