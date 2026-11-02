import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/apod_model.dart';
import '../services/apod_service.dart';
import '../widgets/apod_card.dart';

/// Tela principal do aplicativo que exibe o feed cronológico da NASA APOD
/// com suporte a paginação manual e filtro por data.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  /// Data histórica do primeiro registro oficial publicado pela NASA APOD.
  static final DateTime _minApodDate = DateTime(1995, 6, 16);

  /// Quantidade de dias buscados por lote (data referência + 6 dias anteriores = 7 dias).
  static const int _daysPerBatch = 7;

  final ApodService _apodService = const ApodService();
  final List<ApodModel> _apodItems = [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  DateTime? _oldestLoadedDate;
  late DateTime _anchorDate;

  @override
  void initState() {
    super.initState();
    _anchorDate = _todayDate();
    _fetchInitialBatch(endDate: _anchorDate);
  }

  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _clampToMinDate(DateTime date) {
    if (date.isBefore(_minApodDate)) {
      return _minApodDate;
    }
    return date;
  }

  bool get _isFilteredByPastDate {
    final today = _todayDate();
    return _anchorDate.year != today.year ||
        _anchorDate.month != today.month ||
        _anchorDate.day != today.day;
  }

  bool get _hasReachedMinDate {
    if (_oldestLoadedDate == null) {
      return false;
    }
    return !_oldestLoadedDate!.isAfter(_minApodDate);
  }

  /// Carrega o lote inicial de 4 dias (data final até 3 dias atrás) encerrando em [endDate].
  Future<void> _fetchInitialBatch({required DateTime endDate}) async {
    if (_isLoading) {
      return;
    }

    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);
    final calculatedStart = DateTime(
      normalizedEnd.year,
      normalizedEnd.month,
      normalizedEnd.day - (_daysPerBatch - 1),
    );
    final normalizedStart = _clampToMinDate(calculatedStart);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _anchorDate = normalizedEnd;
    });

    try {
      List<ApodModel> items;
      DateTime effectiveStart = normalizedStart;

      try {
        items = await _apodService.fetchApodRange(
          startDate: normalizedStart,
          endDate: normalizedEnd,
        );
      } on ApodException catch (e) {
        // Caso o fuso local já tenha virado o dia antes da publicação da NASA (EST),
        // recua automaticamente 1 dia para evitar falha HTTP 400 perto da meia-noite.
        final isToday = normalizedEnd == _todayDate();
        if (isToday && e.message.contains('HTTP 400')) {
          final yesterday = DateTime(
            normalizedEnd.year,
            normalizedEnd.month,
            normalizedEnd.day - 1,
          );
          effectiveStart = _clampToMinDate(
            DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day - (_daysPerBatch - 1),
            ),
          );
          items = await _apodService.fetchApodRange(
            startDate: effectiveStart,
            endDate: yesterday,
          );
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      setState(() {
        _apodItems
          ..clear()
          ..addAll(items);
        _oldestLoadedDate = _resolveOldestDate(items, effectiveStart);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Busca os próximos 7 dias antecedentes ao item mais antigo exibido e anexa ao feed.
  Future<void> _fetchPreviousBatch() async {
    if (_isLoading || _isLoadingMore || _hasReachedMinDate) {
      return;
    }

    final currentOldest = _oldestLoadedDate;
    if (currentOldest == null) {
      return;
    }

    final nextEndDate = DateTime(
      currentOldest.year,
      currentOldest.month,
      currentOldest.day - 1,
    );

    if (nextEndDate.isBefore(_minApodDate)) {
      return;
    }

    final nextStartDate = _clampToMinDate(
      DateTime(
        nextEndDate.year,
        nextEndDate.month,
        nextEndDate.day - (_daysPerBatch - 1),
      ),
    );

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreItems = await _apodService.fetchApodRange(
        startDate: nextStartDate,
        endDate: nextEndDate,
      );

      if (!mounted) return;

      final existingDates = _apodItems.map((item) => item.date).toSet();
      final uniqueNewItems = moreItems
          .where((item) => !existingDates.contains(item.date))
          .toList();

      setState(() {
        _apodItems.addAll(uniqueNewItems);
        _oldestLoadedDate = _resolveOldestDate(moreItems, nextStartDate);
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Tentar novamente',
            onPressed: _fetchPreviousBatch,
          ),
        ),
      );
    }
  }

  DateTime _resolveOldestDate(List<ApodModel> batch, DateTime fallbackStart) {
    if (batch.isEmpty) {
      return fallbackStart;
    }
    final parsedLast = DateTime.tryParse(batch.last.date);
    if (parsedLast != null && parsedLast.isBefore(fallbackStart)) {
      return DateTime(parsedLast.year, parsedLast.month, parsedLast.day);
    }
    return fallbackStart;
  }

  /// Abre o seletor de data para saltar diretamente para uma data específica do passado.
  Future<void> _selectDateFromPicker() async {
    final today = _todayDate();
    final initialPickerDate = _anchorDate.isAfter(today)
        ? today
        : (_anchorDate.isBefore(_minApodDate) ? _minApodDate : _anchorDate);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialPickerDate,
      firstDate: _minApodDate,
      lastDate: today,
      helpText: 'Selecionar data limite do feed',
      cancelText: 'Cancelar',
      confirmText: 'Carregar',
      fieldLabelText: 'Data',
      errorFormatText: 'Formato de data inválido',
      errorInvalidText: 'Escolha entre 16/06/1995 e hoje',
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    await _fetchInitialBatch(endDate: pickedDate);
  }

  @override
  Widget build(BuildContext context) {
    final formattedAnchor = DateFormat('dd/MM/yyyy').format(_anchorDate);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NASA APOD',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_isFilteredByPastDate)
              Text(
                'A partir de $formattedAnchor',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        actions: [
          if (_isFilteredByPastDate)
            IconButton(
              onPressed: _isLoading
                  ? null
                  : () => _fetchInitialBatch(endDate: _todayDate()),
              tooltip: 'Voltar para hoje',
              icon: const Icon(Icons.today_outlined),
            ),
          IconButton(
            onPressed: _isLoading ? null : _selectDateFromPicker,
            tooltip: 'Selecionar data no calendário',
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Buscando imagens astronômicas da NASA...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(context, _errorMessage!);
    }

    if (_apodItems.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () => _fetchInitialBatch(endDate: _anchorDate),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _apodItems.length + 1,
        itemBuilder: (context, index) {
          if (index < _apodItems.length) {
            final item = _apodItems[index];
            return ApodCard(
              key: ValueKey('${item.date}_${item.url}'),
              apod: item,
            );
          }

          return _buildFooter(context);
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Carregando registros anteriores...'),
            ],
          ),
        ),
      );
    }

    if (_hasReachedMinDate) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Text(
          'Você chegou ao primeiro registro histórico da NASA APOD (16/06/1995).',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: _fetchPreviousBatch,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.history_rounded),
          label: const Text('Carregar fotos anteriores'),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Falha ao carregar o feed',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _fetchInitialBatch(endDate: _anchorDate),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              'Nenhuma foto encontrada para este período.',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _fetchInitialBatch(endDate: _todayDate()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Recarregar'),
            ),
          ],
        ),
      ),
    );
  }
}

