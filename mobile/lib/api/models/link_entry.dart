class LinkEntry {
  final String id;
  final String title;
  final String url;
  final String? category;
  final String? description;

  LinkEntry({
    required this.id,
    required this.title,
    required this.url,
    this.category,
    this.description,
  });

  factory LinkEntry.fromJson(Map<String, dynamic> j) => LinkEntry(
        id: j['_id'] as String,
        title: j['title'] as String,
        url: j['url'] as String,
        category: j['category'] as String?,
        description: j['description'] as String?,
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'url': url,
        if (category != null && category!.isNotEmpty) 'category': category,
        if (description != null && description!.isNotEmpty) 'description': description,
      };
}
