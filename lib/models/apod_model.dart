/// Modelo de dados que representa um item retornado pela nova API oficial
/// NASA APOD WordPress (`https://science.nasa.gov/wp-json/wp/v2/apod-basic/`).
class ApodModel {
  final String date;
  final String title;
  final String explanation;
  final String url;
  final String mediaType;
  final String? copyright;
  final String? thumbnailUrl;

  const ApodModel({
    required this.date,
    required this.title,
    required this.explanation,
    required this.url,
    required this.mediaType,
    this.copyright,
    this.thumbnailUrl,
  });

  /// Indica se a URL aponta para um arquivo de vídeo direto (`.mp4`, `.webm`, `.mov`, `.m4v`)
  /// reproduzível nativamente dentro do card.
  bool get isDirectVideo {
    if (mediaType != 'video' || url.isEmpty) {
      return false;
    }
    final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.webm') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v');
  }

  /// Cria uma instância de [ApodModel] a partir de um mapa JSON,
  /// tratando defensivamente campos nulos, tags HTML, imagens e vídeos.
  factory ApodModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString().trim();
    final rawTitle = _cleanHtmlText(json['title']?.toString());
    final rawExplanation = _cleanExplanationHtml(
      json['explanation']?.toString(),
    );
    final rawUrl = json['url']?.toString().trim();
    final rawHdUrl = json['hdurl']?.toString().trim();
    final rawPermalink = json['permalink']?.toString().trim();
    final rawBasicHtml = json['basic_html']?.toString();
    final rawMediaType = json['media_type']?.toString().trim().toLowerCase();

    final copyrightSource = json['copyright']?.toString().trim();
    final creditSource = json['credit']?.toString().trim();
    final cleanedCopyright = _cleanHtmlText(
      (copyrightSource != null && copyrightSource.isNotEmpty)
          ? copyrightSource
          : creditSource,
    );

    final resolvedMediaType =
        (rawMediaType != null && rawMediaType.isNotEmpty)
        ? rawMediaType
        : 'image';

    final resolvedUrl = _resolveMediaUrl(
      rawUrl: rawUrl,
      rawHdUrl: rawHdUrl,
      rawPermalink: rawPermalink,
      rawBasicHtml: rawBasicHtml,
      mediaType: resolvedMediaType,
    );

    final resolvedThumbnail = resolvedMediaType == 'video'
        ? _resolveVideoThumbnail(rawHdUrl)
        : null;

    return ApodModel(
      date: (rawDate != null && rawDate.isNotEmpty) ? rawDate : '',
      title: rawTitle.isNotEmpty ? rawTitle : 'Sem título',
      explanation: rawExplanation.isNotEmpty
          ? rawExplanation
          : 'Sem descrição disponível.',
      url: resolvedUrl,
      mediaType: resolvedMediaType,
      copyright: cleanedCopyright.isNotEmpty ? cleanedCopyright : null,
      thumbnailUrl: resolvedThumbnail,
    );
  }

  static String _resolveMediaUrl({
    required String? rawUrl,
    required String? rawHdUrl,
    required String? rawPermalink,
    required String? rawBasicHtml,
    required String mediaType,
  }) {
    if (mediaType == 'video') {
      final extractedVideo = _extractVideoUrl(
        rawUrl: rawUrl,
        rawBasicHtml: rawBasicHtml,
      );
      if (extractedVideo.isNotEmpty) {
        return extractedVideo;
      }
      final fallbackLink = (rawUrl != null && rawUrl.isNotEmpty)
          ? rawUrl
          : (rawPermalink ?? '');
      return _ensureHttps(fallbackLink);
    }

    String candidate = '';
    if (_isDirectImageAsset(rawUrl)) {
      candidate = rawUrl!;
    } else if (rawHdUrl != null && rawHdUrl.isNotEmpty) {
      candidate = rawHdUrl;
    } else if (rawUrl != null && rawUrl.isNotEmpty) {
      candidate = rawUrl;
    }

    if (candidate.isEmpty) {
      return '';
    }

    return _optimizeCdnImageUrl(_ensureHttps(candidate));
  }

  /// Extrai o arquivo real de vídeo (`.mp4` em `<source>` ou `<video>`) ou
  /// o link embarcado (`<iframe>` do YouTube/Vimeo) a partir do `basic_html`.
  static String _extractVideoUrl({
    required String? rawUrl,
    required String? rawBasicHtml,
  }) {
    if (rawUrl != null && rawUrl.isNotEmpty) {
      final lowerUrl = rawUrl.toLowerCase();
      if (lowerUrl.endsWith('.mp4') ||
          lowerUrl.contains('youtube.com/') ||
          lowerUrl.contains('youtu.be/') ||
          lowerUrl.contains('vimeo.com/')) {
        return _normalizeExternalVideoUrl(_ensureHttps(rawUrl));
      }
    }

    if (rawBasicHtml == null || rawBasicHtml.isEmpty) {
      return '';
    }

    final sourceMatch = RegExp(
      r'''<(?:source|video)[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(rawBasicHtml);
    if (sourceMatch != null) {
      final src = sourceMatch.group(1)?.trim() ?? '';
      if (src.isNotEmpty) {
        return _ensureHttps(src);
      }
    }

    final iframeMatch = RegExp(
      r'''<(?:iframe|embed)[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(rawBasicHtml);
    if (iframeMatch != null) {
      final src = iframeMatch.group(1)?.trim() ?? '';
      if (src.isNotEmpty) {
        return _normalizeExternalVideoUrl(_ensureHttps(src));
      }
    }

    return '';
  }

  /// Converte links `/embed/VIDEO_ID` do YouTube para `watch?v=VIDEO_ID`
  /// para abrir diretamente no app do YouTube ou navegador.
  static String _normalizeExternalVideoUrl(String url) {
    final ytEmbedMatch = RegExp(
      r'youtube\.com/embed/([a-zA-Z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(url);
    if (ytEmbedMatch != null) {
      final videoId = ytEmbedMatch.group(1);
      if (videoId != null && videoId.isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$videoId';
      }
    }
    return url;
  }

  static String? _resolveVideoThumbnail(String? rawHdUrl) {
    if (rawHdUrl == null || rawHdUrl.isEmpty) {
      return null;
    }
    if (!_isDirectImageAsset(rawHdUrl)) {
      return null;
    }
    return _optimizeCdnImageUrl(_ensureHttps(rawHdUrl));
  }

  static String _optimizeCdnImageUrl(String httpsUrl) {
    if (httpsUrl.contains('assets.science.nasa.gov/dynamicimage/')) {
      final parsedUri = Uri.tryParse(httpsUrl);
      if (parsedUri != null) {
        return parsedUri
            .replace(
              queryParameters: {
                'w': '900',
                'fit': 'clip',
              },
            )
            .toString();
      }
    }
    return httpsUrl;
  }

  static bool _isDirectImageAsset(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    final lower = value.toLowerCase();
    if (lower.contains('assets.science.nasa.gov')) {
      return true;
    }
    final path = Uri.tryParse(lower)?.path ?? lower;
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }

  static String _ensureHttps(String url) {
    if (url.isEmpty) {
      return '';
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  /// Remove rodapés promocionais ("Tomorrow's picture:"), prefixo "Explanation:"
  /// e tags HTML retornadas pelo endpoint WordPress da NASA.
  static String _cleanExplanationHtml(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '';
    }
    final withoutTomorrow = raw.replaceAll(
      RegExp(
        r"<br\s*/?>\s*<br\s*/?>\s*<(strong|b)>\s*Tomorrow'?s picture:.*$",
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    final cleaned = _cleanHtmlText(withoutTomorrow);
    return cleaned
        .replaceFirst(RegExp(r'^Explanation:\s*', caseSensitive: false), '')
        .trim();
  }

  /// Remove tags HTML e decodifica entidades comuns mantendo texto limpo.
  static String _cleanHtmlText(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '';
    }
    var text = raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('\u00a0', ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#038;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#8217;', '’')
        .replaceAll('&#8216;', '‘')
        .replaceAll('&#8220;', '“')
        .replaceAll('&#8221;', '”')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
