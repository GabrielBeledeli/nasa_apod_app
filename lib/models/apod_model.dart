/// Modelo de dados que representa um item retornado pela API NASA APOD
/// (Astronomy Picture of the Day).
class ApodModel {
  final String date;
  final String title;
  final String explanation;
  final String url;
  final String mediaType;
  final String? copyright;

  const ApodModel({
    required this.date,
    required this.title,
    required this.explanation,
    required this.url,
    required this.mediaType,
    this.copyright,
  });

  /// Cria uma instância de [ApodModel] a partir de um mapa JSON,
  /// aplicando tratamento defensivo contra campos nulos ou malformados.
  factory ApodModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString().trim();
    final rawTitle = json['title']?.toString().trim();
    final rawExplanation = json['explanation']?.toString().trim();
    final rawUrl = json['url']?.toString().trim();
    final rawHdUrl = json['hdurl']?.toString().trim();
    final rawMediaType = json['media_type']?.toString().trim().toLowerCase();
    final rawCopyright = json['copyright']?.toString().trim();

    return ApodModel(
      date: (rawDate != null && rawDate.isNotEmpty) ? rawDate : '',
      title: (rawTitle != null && rawTitle.isNotEmpty)
          ? rawTitle
          : 'Sem título',
      explanation: (rawExplanation != null && rawExplanation.isNotEmpty)
          ? rawExplanation
          : 'Sem descrição disponível.',
      url: (rawUrl != null && rawUrl.isNotEmpty)
          ? rawUrl
          : (rawHdUrl != null && rawHdUrl.isNotEmpty ? rawHdUrl : ''),
      mediaType: (rawMediaType != null && rawMediaType.isNotEmpty)
          ? rawMediaType
          : 'image',
      copyright: (rawCopyright != null && rawCopyright.isNotEmpty)
          ? rawCopyright
          : null,
    );
  }
}

