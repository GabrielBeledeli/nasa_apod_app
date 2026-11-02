import 'dart:async';
import 'dart:convert';

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

/// Serviço responsável pelas requisições HTTP para a API NASA APOD.
class ApodService {
  static const String _baseUrl = 'https://api.nasa.gov/planetary/apod';
  static const String _apiKey = 'DEMO_KEY';
  static const Duration _requestTimeout = Duration(seconds: 20);

  const ApodService();

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

    final dateFormatter = DateFormat('yyyy-MM-dd');
    final formattedStart = dateFormatter.format(normalizedStart);
    final formattedEnd = dateFormatter.format(normalizedEnd);

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'api_key': _apiKey,
        'start_date': formattedStart,
        'end_date': formattedEnd,
      },
    );

    try {
      final response = await http.get(uri).timeout(_requestTimeout);

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
      return 'Acesso negado pela API da NASA (HTTP 403). Verifique a chave de autenticação.';
    }
    if (statusCode == 429) {
      return 'Limite temporário de requisições da chave DEMO_KEY atingido (HTTP 429). Aguarde alguns instantes e tente novamente.';
    }
    if (statusCode >= 500) {
      return 'Servidor da NASA temporariamente indisponível (HTTP $statusCode). Tente novamente mais tarde.';
    }
    return 'Falha ao consultar a API da NASA (HTTP $statusCode).';
  }
}

