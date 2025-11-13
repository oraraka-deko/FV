import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/image_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('images.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE images (
        id $idType,
        file_path $textType,
        width $intType,
        height $intType,
        file_size $intType,
        date_added $intType,
        date_modified INTEGER,
        thumbnail_path TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_file_path ON images(file_path)
    ''');

    await db.execute('''
      CREATE INDEX idx_date_added ON images(date_added)
    ''');

    // Create FTS5 virtual table for search
    await db.execute('''
      CREATE VIRTUAL TABLE images_fts USING fts5(
        file_path,
        content='images',
        content_rowid='id'
      )
    ''');

    // Triggers to keep FTS table in sync
    await db.execute('''
      CREATE TRIGGER images_ai AFTER INSERT ON images BEGIN
        INSERT INTO images_fts(rowid, file_path) VALUES (new.id, new.file_path);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER images_ad AFTER DELETE ON images BEGIN
        INSERT INTO images_fts(images_fts, rowid, file_path) VALUES('delete', old.id, old.file_path);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER images_au AFTER UPDATE ON images BEGIN
        INSERT INTO images_fts(images_fts, rowid, file_path) VALUES('delete', old.id, old.file_path);
        INSERT INTO images_fts(rowid, file_path) VALUES (new.id, new.file_path);
      END
    ''');
  }

  Future<int> insertImage(ImageModel image) async {
    final db = await instance.database;
    return await db.insert('images', image.toMap());
  }

  Future<List<int>> insertImageBatch(List<ImageModel> images) async {
    final db = await instance.database;
    final batch = db.batch();
    
    for (final image in images) {
      batch.insert('images', image.toMap());
    }
    
    final results = await batch.commit();
    return results.cast<int>();
  }

  Future<List<ImageModel>> getImages({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await instance.database;
    final result = await db.query(
      'images',
      orderBy: 'date_added DESC',
      limit: limit,
      offset: offset,
    );

    return result.map((map) => ImageModel.fromMap(map)).toList();
  }

  Future<ImageModel?> getImageByPath(String path) async {
    final db = await instance.database;
    final result = await db.query(
      'images',
      where: 'file_path = ?',
      whereArgs: [path],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return ImageModel.fromMap(result.first);
  }

  Future<int> updateThumbnailPath(int id, String thumbnailPath) async {
    final db = await instance.database;
    return await db.update(
      'images',
      {'thumbnail_path': thumbnailPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ImageModel>> searchImages(String query) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT images.* FROM images
      INNER JOIN images_fts ON images.id = images_fts.rowid
      WHERE images_fts MATCH ?
      ORDER BY date_added DESC
    ''', [query]);

    return result.map((map) => ImageModel.fromMap(map)).toList();
  }

  Future<int> getImageCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM images');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteImage(int id) async {
    final db = await instance.database;
    await db.delete(
      'images',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
