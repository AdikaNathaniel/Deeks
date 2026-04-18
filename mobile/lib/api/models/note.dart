class Note {
  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final String? sourceImageRef;

  Note({
    required this.id,
    required this.title,
    required this.body,
    this.tags = const [],
    this.sourceImageRef,
  });

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['_id'] as String,
        title: j['title'] as String,
        body: (j['body'] as String?) ?? '',
        tags: ((j['tags'] as List?) ?? []).cast<String>(),
        sourceImageRef: j['sourceImageRef'] as String?,
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'body': body,
        if (tags.isNotEmpty) 'tags': tags,
        if (sourceImageRef != null) 'sourceImageRef': sourceImageRef,
      };
}
