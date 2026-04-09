import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/database_service.dart';

/// Handles importing user manuals (PDF, TXT, MD) into the local knowledge base.
/// All data stays on-device in SQLite.
class ManualImportService {
  static const _uuid = Uuid();

  /// Pick a file from the device and import it into the knowledge base.
  /// Returns the number of chunks created, or -1 on cancellation.
  Future<ManualImportResult> pickAndImport({
    required DatabaseService db,
    required String category,
    String? equipmentName,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'text'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return ManualImportResult(success: false, message: 'Cancelled');
    }

    final file = result.files.first;
    final fileName = file.name;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      return ManualImportResult(success: false, message: 'File is empty');
    }

    // Extract text based on file type
    String text;
    final ext = p.extension(fileName).toLowerCase();

    if (ext == '.txt' || ext == '.md' || ext == '.text') {
      text = String.fromCharCodes(bytes);
    } else if (ext == '.pdf') {
      // Basic PDF text extraction — extract readable text from PDF bytes
      text = _extractTextFromPdf(bytes);
      if (text.trim().isEmpty) {
        return ManualImportResult(
          success: false,
          message: 'Could not extract text from PDF. '
              'Scanned PDFs (images) are not yet supported. '
              'Try a text-based PDF or copy-paste content into a .txt file.',
        );
      }
    } else {
      return ManualImportResult(
        success: false,
        message: 'Unsupported file type: $ext',
      );
    }

    // Save a local copy of the file for reference
    final appDir = await getApplicationDocumentsDirectory();
    final manualsDir = Directory(p.join(appDir.path, 'manuals'));
    if (!await manualsDir.exists()) {
      await manualsDir.create(recursive: true);
    }
    final savedFile = File(p.join(manualsDir.path, fileName));
    await savedFile.writeAsBytes(bytes);

    // Generate a source ID
    final sourceId = 'manual_${fileName.replaceAll(RegExp(r'[^\w]'), '_').toLowerCase()}';
    final displayName = equipmentName ?? fileName.replaceAll(RegExp(r'\.\w+$'), '');

    // Delete any existing chunks from this source (re-import)
    await db.deleteChunksBySource(sourceId);

    // Chunk the text and save
    final chunks = _chunkText(text, sourceId, category, displayName);
    await db.saveChunks(chunks);

    // Save manual metadata
    await db.saveManualMeta(ManualMeta(
      sourceId: sourceId,
      fileName: fileName,
      displayName: displayName,
      category: category,
      chunkCount: chunks.length,
      importedAt: DateTime.now(),
      filePath: savedFile.path,
    ));

    return ManualImportResult(
      success: true,
      message: 'Imported "$displayName" — ${chunks.length} sections indexed',
      chunkCount: chunks.length,
      sourceId: sourceId,
    );
  }

  /// Import raw text directly (e.g., from copy-paste or web fetch)
  Future<ManualImportResult> importText({
    required DatabaseService db,
    required String text,
    required String displayName,
    required String category,
  }) async {
    if (text.trim().isEmpty) {
      return ManualImportResult(success: false, message: 'No text to import');
    }

    final sourceId = 'manual_${displayName.replaceAll(RegExp(r'[^\w]'), '_').toLowerCase()}_${_uuid.v4().substring(0, 8)}';

    await db.deleteChunksBySource(sourceId);

    final chunks = _chunkText(text, sourceId, category, displayName);
    await db.saveChunks(chunks);

    await db.saveManualMeta(ManualMeta(
      sourceId: sourceId,
      fileName: '$displayName.txt',
      displayName: displayName,
      category: category,
      chunkCount: chunks.length,
      importedAt: DateTime.now(),
      filePath: null,
    ));

    return ManualImportResult(
      success: true,
      message: 'Imported "$displayName" — ${chunks.length} sections indexed',
      chunkCount: chunks.length,
      sourceId: sourceId,
    );
  }

  /// Delete an imported manual and its chunks
  Future<void> deleteManual(DatabaseService db, String sourceId) async {
    // Delete chunks
    await db.deleteChunksBySource(sourceId);
    // Delete metadata
    await db.deleteManualMeta(sourceId);
    // Try to delete the file too
    final meta = await db.getManualMeta(sourceId);
    if (meta?.filePath != null) {
      final file = File(meta!.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Basic PDF text extraction — handles simple text-based PDFs
  /// For scanned PDFs, OCR would be needed (future enhancement)
  String _extractTextFromPdf(List<int> bytes) {
    // Simple PDF text extraction by finding text streams
    // This handles most text-based PDFs (not scanned/image PDFs)
    final content = String.fromCharCodes(bytes, 0, bytes.length);
    final textBuffer = StringBuffer();

    // Extract text between BT (begin text) and ET (end text) operators
    final btEtPattern = RegExp(r'BT\s*(.*?)\s*ET', dotAll: true);
    for (final match in btEtPattern.allMatches(content)) {
      final block = match.group(1) ?? '';
      // Extract text from Tj and TJ operators
      final tjPattern = RegExp(r'\((.*?)\)\s*Tj', dotAll: true);
      for (final tm in tjPattern.allMatches(block)) {
        textBuffer.write(_decodePdfString(tm.group(1) ?? ''));
        textBuffer.write(' ');
      }
      // TJ array operator
      final tjArrayPattern = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
      for (final tm in tjArrayPattern.allMatches(block)) {
        final inner = tm.group(1) ?? '';
        final innerTj = RegExp(r'\((.*?)\)');
        for (final it in innerTj.allMatches(inner)) {
          textBuffer.write(_decodePdfString(it.group(1) ?? ''));
        }
        textBuffer.write(' ');
      }
    }

    // Clean up the extracted text
    var text = textBuffer.toString();
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), ''); // Remove non-printable
    return text.trim();
  }

  /// Decode PDF string escapes
  String _decodePdfString(String s) {
    return s
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\\', '\\')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')');
  }

  /// Chunk text intelligently by paragraphs and headings
  List<KnowledgeChunk> _chunkText(
    String text,
    String sourceId,
    String category,
    String displayName,
  ) {
    final chunks = <KnowledgeChunk>[];
    final lines = text.split('\n');

    String currentTitle = displayName;
    final currentContent = StringBuffer();
    int chunkIndex = 0;

    for (final line in lines) {
      // Detect headings (markdown or ALL CAPS lines)
      if (line.startsWith('## ') || line.startsWith('### ') || line.startsWith('# ')) {
        _flushChunk(chunks, currentTitle, currentContent, sourceId, category, chunkIndex);
        if (currentContent.toString().trim().isNotEmpty) chunkIndex++;
        currentTitle = line.replaceFirst(RegExp(r'^#+\s*'), '');
        currentContent.clear();
      } else if (line.length > 5 && line.length < 80 &&
                 line == line.toUpperCase() && line.contains(RegExp(r'[A-Z]'))) {
        // ALL CAPS heading (common in technical manuals)
        _flushChunk(chunks, currentTitle, currentContent, sourceId, category, chunkIndex);
        if (currentContent.toString().trim().isNotEmpty) chunkIndex++;
        currentTitle = _titleCase(line);
        currentContent.clear();
      } else {
        currentContent.writeln(line);
      }
    }

    // Final chunk
    _flushChunk(chunks, currentTitle, currentContent, sourceId, category, chunkIndex);

    // Split any oversized chunks
    final refined = <KnowledgeChunk>[];
    int finalIdx = 0;
    for (final chunk in chunks) {
      if (chunk.content.length > 1500) {
        refined.addAll(_splitChunk(chunk, sourceId, category, finalIdx));
        finalIdx += refined.length;
      } else {
        refined.add(KnowledgeChunk(
          id: chunk.id,
          sourceId: chunk.sourceId,
          sourceType: chunk.sourceType,
          category: chunk.category,
          title: chunk.title,
          content: chunk.content,
          chunkIndex: finalIdx++,
          tags: chunk.tags,
        ));
      }
    }

    return refined;
  }

  void _flushChunk(
    List<KnowledgeChunk> chunks,
    String title,
    StringBuffer content,
    String sourceId,
    String category,
    int index,
  ) {
    final text = content.toString().trim();
    if (text.isEmpty) return;
    chunks.add(KnowledgeChunk(
      id: _uuid.v4(),
      sourceId: sourceId,
      sourceType: 'manual',
      category: category,
      title: title,
      content: text,
      chunkIndex: index,
    ));
  }

  List<KnowledgeChunk> _splitChunk(
    KnowledgeChunk chunk,
    String sourceId,
    String category,
    int startIndex,
  ) {
    final paragraphs = chunk.content.split('\n\n');
    final result = <KnowledgeChunk>[];
    final buffer = StringBuffer();
    int part = 1;

    for (final para in paragraphs) {
      if (buffer.length + para.length > 1200 && buffer.isNotEmpty) {
        result.add(KnowledgeChunk(
          id: _uuid.v4(),
          sourceId: sourceId,
          sourceType: 'manual',
          category: category,
          title: '${chunk.title} (Part $part)',
          content: buffer.toString().trim(),
          chunkIndex: startIndex + result.length,
        ));
        buffer.clear();
        part++;
      }
      buffer.writeln(para);
      buffer.writeln();
    }

    if (buffer.toString().trim().isNotEmpty) {
      result.add(KnowledgeChunk(
        id: _uuid.v4(),
        sourceId: sourceId,
        sourceType: 'manual',
        category: category,
        title: '${chunk.title} (Part $part)',
        content: buffer.toString().trim(),
        chunkIndex: startIndex + result.length,
      ));
    }

    return result;
  }

  String _titleCase(String s) {
    return s.toLowerCase().split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

class ManualImportResult {
  final bool success;
  final String message;
  final int chunkCount;
  final String? sourceId;

  const ManualImportResult({
    required this.success,
    required this.message,
    this.chunkCount = 0,
    this.sourceId,
  });
}

class ManualMeta {
  final String sourceId;
  final String fileName;
  final String displayName;
  final String category;
  final int chunkCount;
  final DateTime importedAt;
  final String? filePath;

  ManualMeta({
    required this.sourceId,
    required this.fileName,
    required this.displayName,
    required this.category,
    required this.chunkCount,
    required this.importedAt,
    this.filePath,
  });

  Map<String, dynamic> toMap() => {
    'source_id': sourceId,
    'file_name': fileName,
    'display_name': displayName,
    'category': category,
    'chunk_count': chunkCount,
    'imported_at': importedAt.toIso8601String(),
    'file_path': filePath,
  };

  factory ManualMeta.fromMap(Map<String, dynamic> map) => ManualMeta(
    sourceId: map['source_id'] as String,
    fileName: map['file_name'] as String,
    displayName: map['display_name'] as String,
    category: map['category'] as String,
    chunkCount: map['chunk_count'] as int,
    importedAt: DateTime.parse(map['imported_at'] as String),
    filePath: map['file_path'] as String?,
  );
}
