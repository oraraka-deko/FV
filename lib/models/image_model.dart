class ImageModel {
  final int? id;
  final String filePath;
  final int width;
  final int height;
  final int fileSize;
  final DateTime dateAdded;
  final DateTime? dateModified;
  final String? thumbnailPath;

  ImageModel({
    this.id,
    required this.filePath,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.dateAdded,
    this.dateModified,
    this.thumbnailPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_path': filePath,
      'width': width,
      'height': height,
      'file_size': fileSize,
      'date_added': dateAdded.millisecondsSinceEpoch,
      'date_modified': dateModified?.millisecondsSinceEpoch,
      'thumbnail_path': thumbnailPath,
    };
  }

  factory ImageModel.fromMap(Map<String, dynamic> map) {
    return ImageModel(
      id: map['id'] as int?,
      filePath: map['file_path'] as String,
      width: map['width'] as int,
      height: map['height'] as int,
      fileSize: map['file_size'] as int,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(map['date_added'] as int),
      dateModified: map['date_modified'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date_modified'] as int)
          : null,
      thumbnailPath: map['thumbnail_path'] as String?,
    );
  }
}
