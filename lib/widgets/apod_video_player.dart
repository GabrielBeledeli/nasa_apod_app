import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/apod_model.dart';

/// Componente dedicado para reprodução de vídeos da NASA APOD:
/// - Reproduz vídeos `.mp4` nativamente dentro do card sob demanda (ao tocar em Play).
/// - Exibe a miniatura oficial da NASA como capa e abre vídeos externos (ex: YouTube)
///   no aplicativo nativo ou navegador via `url_launcher`.
class ApodVideoPlayer extends StatefulWidget {
  final ApodModel apod;

  const ApodVideoPlayer({
    super.key,
    required this.apod,
  });

  @override
  State<ApodVideoPlayer> createState() => _ApodVideoPlayerState();
}

class _ApodVideoPlayerState extends State<ApodVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _hasPlayerError = false;
  bool _isMuted = false;

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdated);
    _controller?.dispose();
    super.dispose();
  }

  void _onControllerUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startInlinePlayback() async {
    if (_isInitializing || widget.apod.url.isEmpty) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _hasPlayerError = false;
    });

    final uri = Uri.tryParse(widget.apod.url);
    if (uri == null) {
      setState(() {
        _isInitializing = false;
        _hasPlayerError = true;
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;

    try {
      await controller.initialize();
      controller.addListener(_onControllerUpdated);
      await controller.setLooping(true);
      await controller.play();

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      debugPrint('Erro ao inicializar VideoPlayer (${widget.apod.url}): $e');
      await controller.dispose();
      _controller = null;

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _hasPlayerError = true;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0.0 : 1.0);
    if (mounted) {
      setState(() {
        _isMuted = nextMuted;
      });
    }
  }

  Future<void> _openExternalVideo() async {
    final rawUrl = widget.apod.url;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Falha ao abrir link externo ($rawUrl): $e');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o vídeo externamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final controller = _controller;

    if (controller != null && controller.value.isInitialized) {
      return _buildActivePlayer(controller, colorScheme);
    }

    return _buildCoverPreview(colorScheme, textTheme);
  }

  Widget _buildActivePlayer(
    VideoPlayerController controller,
    ColorScheme colorScheme,
  ) {
    final aspectRatio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : (16 / 9);
    final isPlaying = controller.value.isPlaying;

    return Container(
      color: Colors.black,
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _togglePlayPause,
                  child: AnimatedOpacity(
                    opacity: isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControlIconButton(
                    icon: _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    tooltip: _isMuted ? 'Ativar áudio' : 'Silenciar',
                    onPressed: _toggleMute,
                  ),
                  const SizedBox(width: 8),
                  _buildControlIconButton(
                    icon: Icons.open_in_new_rounded,
                    tooltip: 'Abrir externamente',
                    onPressed: _openExternalVideo,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.only(top: 8),
                colors: VideoProgressColors(
                  playedColor: colorScheme.primary,
                  bufferedColor: Colors.white.withValues(alpha: 0.35),
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        color: Colors.white,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }

  Widget _buildCoverPreview(ColorScheme colorScheme, TextTheme textTheme) {
    final isDirectMp4 = widget.apod.isDirectVideo;
    final thumbnailUrl = widget.apod.thumbnailUrl;
    final canPlayInline = isDirectMp4 && !_hasPlayerError;

    return GestureDetector(
      onTap: _isInitializing
          ? null
          : (canPlayInline ? _startInlinePlayback : _openExternalVideo),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 220,
          maxHeight: 320,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              Image.network(
                thumbnailUrl,
                width: double.infinity,
                height: 250,
                cacheWidth: 800,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    width: double.infinity,
                    color: colorScheme.surfaceContainerHighest,
                  );
                },
              )
            else
              Container(
                height: 250,
                width: double.infinity,
                color: colorScheme.surfaceContainerHighest,
              ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      canPlayInline
                          ? Icons.videocam_rounded
                          : Icons.ondemand_video_rounded,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      canPlayInline ? 'VÍDEO NASA' : 'VÍDEO EXTERNO',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isInitializing)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Carregando vídeo...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        canPlayInline
                            ? Icons.play_arrow_rounded
                            : Icons.open_in_new_rounded,
                        size: 40,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _hasPlayerError
                          ? 'Toque para abrir o vídeo no navegador'
                          : (canPlayInline
                                ? 'Toque para reproduzir o vídeo'
                                : 'Toque para assistir no YouTube / Navegador'),
                      textAlign: TextAlign.center,
                      style: textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

