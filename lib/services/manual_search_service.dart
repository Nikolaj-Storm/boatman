import 'package:http/http.dart' as http;
import 'package:boatman/models/boat_profile.dart';

/// Searches the web for equipment manuals in Shore mode.
/// Downloads and prepares content for local import into the knowledge base.
///
/// All downloaded content is stored locally — nothing leaves the device after download.
class ManualSearchService {

  /// Generate search queries based on the user's boat profile
  List<ManualSearchSuggestion> getSuggestions(BoatProfile boat) {
    final suggestions = <ManualSearchSuggestion>[];

    // Engine manual
    if (boat.engineMake != null) {
      final engineQuery = [boat.engineMake, boat.engineModel, 'service manual PDF']
          .where((s) => s != null)
          .join(' ');
      suggestions.add(ManualSearchSuggestion(
        title: '${boat.engineMake} ${boat.engineModel ?? ""} Service Manual',
        query: engineQuery,
        category: 'diesel',
        icon: 'engineering',
      ));

      suggestions.add(ManualSearchSuggestion(
        title: '${boat.engineMake} ${boat.engineModel ?? ""} Parts List',
        query: '${boat.engineMake} ${boat.engineModel ?? ""} parts diagram PDF',
        category: 'diesel',
        icon: 'engineering',
      ));
    }

    // Boat owner's manual
    if (boat.make != null) {
      final boatQuery = [boat.make, boat.model, boat.year, 'owners manual PDF']
          .where((s) => s != null)
          .join(' ');
      suggestions.add(ManualSearchSuggestion(
        title: '${boat.make} ${boat.model ?? ""} Owner\'s Manual',
        query: boatQuery,
        category: 'general',
        icon: 'sailing',
      ));
    }

    // Autopilot
    if (boat.autopilotMake != null) {
      suggestions.add(ManualSearchSuggestion(
        title: '${boat.autopilotMake} ${boat.autopilotModel ?? ""} Manual',
        query: '${boat.autopilotMake} ${boat.autopilotModel ?? ""} installation manual PDF',
        category: 'electrical',
        icon: 'navigation',
      ));
    }

    // Chartplotter
    if (boat.chartplotterMake != null) {
      suggestions.add(ManualSearchSuggestion(
        title: '${boat.chartplotterMake} ${boat.chartplotterModel ?? ""} Manual',
        query: '${boat.chartplotterMake} ${boat.chartplotterModel ?? ""} user manual PDF',
        category: 'electrical',
        icon: 'monitor',
      ));
    }

    // VHF
    if (boat.vhfMake != null) {
      suggestions.add(ManualSearchSuggestion(
        title: '${boat.vhfMake} ${boat.vhfModel ?? ""} Manual',
        query: '${boat.vhfMake} ${boat.vhfModel ?? ""} VHF radio manual PDF',
        category: 'electrical',
        icon: 'radio',
      ));
    }

    return suggestions;
  }

  /// Search the web for manual PDFs/content using a query.
  /// Uses DuckDuckGo HTML endpoint (no API key needed).
  Future<List<ManualSearchResult>> search(String query) async {
    try {
      // Use DuckDuckGo lite (no JS needed, no API key)
      final uri = Uri.https('html.duckduckgo.com', '/html/', {'q': query});
      final response = await http.get(uri, headers: {
        'User-Agent': 'Boatman/0.1 (offline-marine-assistant)',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return [];
      }

      return _parseDuckDuckGoResults(response.body);
    } catch (e) {
      return [];
    }
  }

  /// Fetch a web page and extract its text content for import
  Future<String?> fetchPageText(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Boatman/0.1 (offline-marine-assistant)',
      }).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      // Strip HTML tags for a rough text extraction
      return _htmlToText(response.body);
    } catch (e) {
      return null;
    }
  }

  /// Download a file (PDF, etc.) and return its bytes
  Future<List<int>?> downloadFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Boatman/0.1 (offline-marine-assistant)',
      }).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (e) {
      return null;
    }
  }

  /// Parse DuckDuckGo HTML results
  List<ManualSearchResult> _parseDuckDuckGoResults(String html) {
    final results = <ManualSearchResult>[];

    // DuckDuckGo lite wraps results in <a class="result__a"> tags
    final linkPattern = RegExp(
      r'<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    final snippetPattern = RegExp(
      r'<a[^>]*class="result__snippet"[^>]*>(.*?)</a>',
      dotAll: true,
    );

    final links = linkPattern.allMatches(html).toList();
    final snippets = snippetPattern.allMatches(html).toList();

    for (int i = 0; i < links.length && i < 10; i++) {
      var url = links[i].group(1) ?? '';
      final title = _stripHtml(links[i].group(2) ?? '');
      final snippet = i < snippets.length ? _stripHtml(snippets[i].group(1) ?? '') : '';

      // DuckDuckGo wraps URLs in a redirect — extract the actual URL
      if (url.contains('uddg=')) {
        final uddg = Uri.parse(url).queryParameters['uddg'];
        if (uddg != null) url = Uri.decodeComponent(uddg);
      }

      if (url.isNotEmpty && title.isNotEmpty) {
        results.add(ManualSearchResult(
          title: title,
          url: url,
          snippet: snippet,
          isPdf: url.toLowerCase().endsWith('.pdf'),
        ));
      }
    }

    return results;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String _htmlToText(String html) {
    // Remove script and style blocks
    var text = html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');

    // Convert some HTML elements to text equivalents
    text = text
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</?p[^>]*>'), '\n')
        .replaceAll(RegExp(r'</?h[1-6][^>]*>'), '\n')
        .replaceAll(RegExp(r'</?li[^>]*>'), '\n- ')
        .replaceAll(RegExp(r'</?div[^>]*>'), '\n')
        .replaceAll(RegExp(r'</?tr[^>]*>'), '\n')
        .replaceAll(RegExp(r'</?td[^>]*>'), ' | ');

    // Strip remaining tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode HTML entities
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    // Clean up whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r' {2,}'), ' ');

    return text.trim();
  }
}

class ManualSearchSuggestion {
  final String title;
  final String query;
  final String category;
  final String icon;

  const ManualSearchSuggestion({
    required this.title,
    required this.query,
    required this.category,
    required this.icon,
  });
}

class ManualSearchResult {
  final String title;
  final String url;
  final String snippet;
  final bool isPdf;

  const ManualSearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    required this.isPdf,
  });
}
