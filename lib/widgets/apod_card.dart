import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/apod_model.dart';

/// Card visual para exibição de um item astronômico da NASA APOD.
class ApodCard extends StatefulWidget {
  final ApodModel apod;

  const ApodCard({
    super.key,
    required this.apod,
  });

  @override
  State<ApodCard> createState() => _ApodCardState();
}

class _ApodCardState extends State<ApodCard> {
  bool _isExpanded = false;

  /// Formata a data ISO (`YYYY-MM-DD`) para o padrão brasileiro (`DD/MM/AAAA`).
  String _formatDate(String rawDate) {
    final parsedDate = DateTime.tryParse(rawDate);
    if (parsedDate == null) {
      return rawDate.isNotEmpty ? rawDate : 'Data indisponível';
    }
    return DateFormat('dd/MM/yyyy').format(parsedDate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final apod = widget.apod;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMediaSection(context, apod, colorScheme, textTheme),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(apod.date),
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (apod.copyright != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '© ${apod.copyright}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  apod.title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: Text(
                    apod.explanation,
                    maxLines: _isExpanded ? null : 3,
                    overflow: _isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.88),
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                    label: Text(_isExpanded ? 'Ver menos' : 'Ver mais'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(
    BuildContext context,
    ApodModel apod,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (apod.mediaType == 'video') {
      return _buildFallbackContainer(
        colorScheme: colorScheme,
        textTheme: textTheme,
        icon: Icons.play_circle_outline_rounded,
        title: 'Conteúdo em Vídeo',
        subtitle:
            'A publicação astronômica deste dia é um vídeo e não pode ser exibida como imagem.',
        extraInfo: apod.url.isNotEmpty ? apod.url : null,
      );
    }

    if (apod.mediaType != 'image' || apod.url.isEmpty) {
      return _buildFallbackContainer(
        colorScheme: colorScheme,
        textTheme: textTheme,
        icon: Icons.public_outlined,
        title: 'Mídia Alternativa',
        subtitle:
            'Este registro da NASA não possui uma imagem estática disponível para visualização.',
        extraInfo: apod.url.isNotEmpty ? apod.url : null,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 200,
        maxHeight: 360,
      ),
      child: Image.network(
        apod.url,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          final expectedBytes = loadingProgress.expectedTotalBytes;
          final loadedBytes = loadingProgress.cumulativeBytesLoaded;
          final progress = (expectedBytes != null && expectedBytes > 0)
              ? loadedBytes / expectedBytes
              : null;

          return Container(
            height: 230,
            width: double.infinity,
            color: colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Text(
                  'Carregando imagem...',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackContainer(
            colorScheme: colorScheme,
            textTheme: textTheme,
            icon: Icons.broken_image_outlined,
            title: 'Falha ao carregar imagem',
            subtitle:
                'Não foi possível baixar a fotografia astronômica deste registro.',
          );
        },
      ),
    );
  }

  Widget _buildFallbackContainer({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required IconData icon,
    required String title,
    required String subtitle,
    String? extraInfo,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (extraInfo != null) ...[
            const SizedBox(height: 10),
            Text(
              extraInfo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

