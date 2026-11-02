import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/apod_model.dart';

/// Exceção customizada para falhas descritivas na comunicação com a API APOD.
class ApodException implements Exception {
  final String message;

  const ApodException(this.message);

  @override
  String toString() => message;
}

/// Serviço responsável pelas requisições HTTP para a API oficial NASA APOD.
class ApodService {
  static const String _baseUrl =
      'https://science.nasa.gov/wp-json/wp/v2/apod-basic/';
  static const String _defaultApiKey = 'DEMO_KEY';

  /// Filtra os campos necessários da resposta, incluindo `basic_html`
  /// para extração de streams `.mp4` e embeds de vídeo.
  static const String _responseFields =
      'date,title,media_type,explanation,copyright,credit,url,hdurl,permalink,basic_html';

  const ApodService();

  /// Resolve a chave da API carregada do `.env` na raiz (via `flutter_dotenv`),
  /// utilizando `DEMO_KEY` como fallback padrão.
  String _resolveApiKey() {
    const definedKey = String.fromEnvironment('NASA_API_KEY');
    if (definedKey.trim().isNotEmpty) {
      return definedKey.trim();
    }

    try {
      final envKey = dotenv.maybeGet('NASA_API_KEY')?.trim();
      if (envKey != null &&
          envKey.isNotEmpty &&
          envKey != 'SUA_CHAVE_AQUI') {
        return envKey;
      }
    } catch (_) {
      // dotenv não inicializado -> utiliza DEMO_KEY.
    }

    return _defaultApiKey;
  }

  /// Busca a lista de registros astronômicos no intervalo entre [startDate] e [endDate],
  /// retornando os itens ordenados da data mais recente para a mais antiga.
  Future<List<ApodModel>> fetchApodRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    if (normalizedStart.isAfter(normalizedEnd)) {
      throw const ApodException(
        'A data inicial não pode ser posterior à data final.',
      );
    }

    // Caso o intervalo atravesse a virada de século (1999 -> 2000), divide em
    // duas consultas devido ao formato yyMMdd exigido por date_from/date_to.
    if (normalizedStart.year < 2000 && normalizedEnd.year >= 2000) {
      final twentiethCentury = await _fetchSingleRange(
        startDate: normalizedStart,
        endDate: DateTime(1999, 12, 31),
      );
      final twentyFirstCentury = await _fetchSingleRange(
        startDate: DateTime(2000, 1, 1),
        endDate: normalizedEnd,
      );
      final combined = [...twentyFirstCentury, ...twentiethCentury];
      combined.sort((a, b) => b.date.compareTo(a.date));
      return combined;
    }

    return _fetchSingleRange(
      startDate: normalizedStart,
      endDate: normalizedEnd,
    );
  }

  Future<List<ApodModel>> _fetchSingleRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final apiKey = _resolveApiKey();
    final keySource = apiKey == _defaultApiKey ? 'DEMO_KEY' : '.env';

    final dateFormatter = DateFormat('yyMMdd');
    final formattedFrom = dateFormatter.format(startDate);
    final formattedTo = dateFormatter.format(endDate);

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'api_key': apiKey,
        'date_from': formattedFrom,
        'date_to': formattedTo,
        'per_page': '25',
        '_fields': _responseFields,
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      final rateLimitRemaining =
          response.headers['x-rate-limit-remaining'] ??
          response.headers['x-ratelimit-remaining'] ??
          'não informado';
      debugPrint(
        'NASA APOD API ($keySource) -> statusCode: ${response.statusCode} | '
        'x-rate-limit-remaining: $rateLimitRemaining',
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final dynamic decodedJson = jsonDecode(decodedBody);

        final List<ApodModel> apodList;
        if (decodedJson is List) {
          apodList = decodedJson
              .whereType<Map<String, dynamic>>()
              .map(ApodModel.fromJson)
              .toList();
        } else if (decodedJson is Map<String, dynamic>) {
          apodList = [ApodModel.fromJson(decodedJson)];
        } else {
          throw const FormatException(
            'Formato de resposta inesperado da API.',
          );
        }

        apodList.sort((a, b) => b.date.compareTo(a.date));
        return apodList;
      }

      throw ApodException(_mapStatusCodeToMessage(response.statusCode));
    } on ApodException {
      rethrow;
    } on TimeoutException {
      throw const ApodException(
        'Tempo limite esgotado ao conectar com a NASA. Verifique sua conexão e tente novamente.',
      );
    } on http.ClientException {
      throw const ApodException(
        'Sem conexão ou falha de rede ao acessar a API da NASA. Verifique sua internet e tente novamente.',
      );
    } on FormatException {
      throw const ApodException(
        'Erro ao decodificar os dados retornados pela API da NASA.',
      );
    } catch (_) {
      throw const ApodException(
        'Não foi possível carregar as imagens astronômicas. Verifique sua conexão e tente novamente.',
      );
    }
  }

  String _mapStatusCodeToMessage(int statusCode) {
    if (statusCode == 400) {
      return 'Intervalo de datas inválido para a API da NASA (HTTP 400). Selecione datas entre 16/06/1995 e a data atual.';
    }
    if (statusCode == 403) {
      return 'Acesso negado pela API da NASA (HTTP 403). Verifique a chave de autenticação configurada no arquivo .env.';
    }
    if (statusCode == 429) {
      return 'Limite de requisições atingido (HTTP 429). Gere uma chave gratuita em api.nasa.gov e configure no arquivo .env.';
    }
    if (statusCode >= 500) {
      return 'Servidor da NASA temporariamente indisponível (HTTP $statusCode). Tente novamente mais tarde.';
    }
    return 'Falha ao consultar a API da NASA (HTTP $statusCode).';
  }
}
