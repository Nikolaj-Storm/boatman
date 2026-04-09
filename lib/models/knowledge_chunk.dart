class KnowledgeChunk {
  final String id;
  final String sourceId; // skill pack name or manual filename
  final String sourceType; // 'skill_pack' or 'manual'
  final String category; // 'diesel', 'electrical', 'plumbing', 'seamanship', 'fiberglass', 'rigging', 'general'
  final String title; // section heading
  final String content; // the actual text chunk
  final int chunkIndex; // order within source
  final String tags; // comma-separated sub-topic tags for fine-grained routing
  final List<double>? embedding; // vector embedding for RAG

  KnowledgeChunk({
    required this.id,
    required this.sourceId,
    required this.sourceType,
    required this.category,
    required this.title,
    required this.content,
    required this.chunkIndex,
    this.tags = '',
    this.embedding,
  });

  List<String> get tagList =>
      tags.isEmpty ? [] : tags.split(',').map((t) => t.trim()).toList();

  bool hasTag(String tag) => tagList.contains(tag);

  bool hasAnyTag(List<String> checkTags) =>
      checkTags.any((t) => tagList.contains(t));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_id': sourceId,
      'source_type': sourceType,
      'category': category,
      'title': title,
      'content': content,
      'chunk_index': chunkIndex,
      'tags': tags,
    };
  }

  factory KnowledgeChunk.fromMap(Map<String, dynamic> map) {
    return KnowledgeChunk(
      id: map['id'] as String,
      sourceId: map['source_id'] as String,
      sourceType: map['source_type'] as String,
      category: map['category'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      chunkIndex: map['chunk_index'] as int,
      tags: map['tags'] as String? ?? '',
    );
  }
}

class SkillPack {
  final String id;
  final String name;
  final String description;
  final String category;
  final String filename;
  final int chunkCount;
  final bool isLoaded;

  SkillPack({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.filename,
    this.chunkCount = 0,
    this.isLoaded = false,
  });
}
