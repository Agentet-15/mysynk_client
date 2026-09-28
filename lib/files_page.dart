
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'mysynk_api.dart';
import 'server_config.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  MySynkApi? _api;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  String _currentPath = '/';
  bool _gridView = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final serverUrl = await ServerConfig.getServerUrl();

      _api = MySynkApi(
        baseUrl: serverUrl,
      );

      final items = await _api!.listFiles(_currentPath);

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar los archivos.';
      });
    }
  }

  Future<void> _openFolder(String path) async {
    setState(() {
      _currentPath = path;
      _loading = true;
      _error = null;
    });

    try {
      final items = await _api!.listFiles(path);

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'No se pudo abrir la carpeta.';
      });
    }
  }

  void _goBack() {
    if (_currentPath == '/') {
      Navigator.of(context).pop();
      return;
    }

    final parts = _currentPath
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      _openFolder('/');
      return;
    }

    parts.removeLast();

    final parentPath = parts.isEmpty
        ? '/'
        : '/${parts.join('/')}';

    _openFolder(parentPath);
  }

  bool _isImage(String name) {
    return RegExp(
      r'\.(avif|gif|jpe?g|png|webp)$',
      caseSensitive: false,
    ).hasMatch(name);
  }

  bool _isVideo(String name) {
    return RegExp(
      r'\.(m4v|mov|mp4|webm|ogv)$',
      caseSensitive: false,
    ).hasMatch(name);
  }

  String _formatSize(dynamic value) {
    final bytes = value is num ? value.toInt() : 0;

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _fileIcon(String name) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive_outlined;
      case 'txt':
      case 'md':
        return Icons.article_outlined;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'ogg':
        return Icons.audiotrack_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _previewUrl(String path) {
    final serverUrl = _api?.baseUrl ?? '';

    return '$serverUrl/api/v1/preview?path=${Uri.encodeComponent(path)}';
  }

  String _thumbnailUrl(String path) {
    final serverUrl = _api?.baseUrl ?? '';

    return '$serverUrl/api/v1/thumbnail?path=${Uri.encodeComponent(path)}';
  }

  void _openPreview(Map<String, dynamic> item) {
    final previewItems = _items.where((candidate) {
      final type = candidate['type']?.toString() ?? 'file';
      final name = candidate['name']?.toString() ?? '';

      return type == 'file' && (_isImage(name) || _isVideo(name));
    }).toList();

    final initialIndex = previewItems.indexWhere(
      (candidate) => candidate['path'] == item['path'],
    );

    if (initialIndex < 0) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _PreviewPage(
          items: previewItems,
          initialIndex: initialIndex,
          previewUrl: _previewUrl,
          isImage: _isImage,
          isVideo: _isVideo,
        ),
      ),
    );
  }

  void _openItem(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? 'file';
    final path = item['path']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Archivo';

    if (path.isEmpty) {
      return;
    }

    if (type == 'directory') {
      _openFolder(path);
      return;
    }

    if (_isImage(name) || _isVideo(name)) {
      _openPreview(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: const Text('Mis archivos'),
        actions: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.view_list),
                label: Text('Lista'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.grid_view),
                label: Text('Parrilla'),
              ),
            ],
            selected: {_gridView},
            onSelectionChanged: (selection) {
              setState(() {
                _gridView = selection.first;
              });
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadFiles,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadFiles,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFiles,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text('Esta carpeta está vacía.'),
            ),
          ],
        ),
      );
    }

    if (_gridView) {
      return _buildGrid();
    }

    return _buildList();
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];

          final name = item['name']?.toString() ?? 'Sin nombre';
          final type = item['type']?.toString() ?? 'file';
          final path = item['path']?.toString() ?? '';
          final size = item['size'];

          final isDirectory = type == 'directory';
          final isImage = _isImage(name);
          final isVideo = _isVideo(name);

          return ListTile(
            leading: SizedBox(
              width: 48,
              height: 48,
              child: isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _previewUrl(path),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image_outlined,
                          );
                        },
                      ),
                    )
                  : isVideo
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildVideoThumbnail(
                            path,
                            name,
                          ),
                        )
                      : Icon(
                          isDirectory
                              ? Icons.folder_outlined
                              : _fileIcon(name),
                        ),
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              isDirectory
                  ? 'Carpeta'
                  : '${_formatSize(size)} · Archivo',
            ),
            trailing: isDirectory
                ? const Icon(Icons.chevron_right)
                : (isImage || isVideo)
                    ? const Icon(Icons.visibility_outlined)
                    : null,
            onTap: () => _openItem(item),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];

          final name = item['name']?.toString() ?? 'Sin nombre';
          final type = item['type']?.toString() ?? 'file';
          final path = item['path']?.toString() ?? '';

          final isDirectory = type == 'directory';
          final isImage = _isImage(name);
          final isVideo = _isVideo(name);

          return Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openItem(item),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isImage)
                    Image.network(
                      _previewUrl(path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildGridFileIcon(
                          name,
                          isDirectory,
                        );
                      },
                    )
                  else if (isVideo)
                    Positioned.fill(
                      child: _buildVideoThumbnail(
                        path,
                        name,
                      ),
                    )
                  else
                    _buildGridFileIcon(
                      name,
                      isDirectory,
                    ),
                  if (!isImage && !isVideo && !isDirectory)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (isDirectory)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridFileIcon(
    String name,
    bool isDirectory,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDirectory
                ? Icons.folder_rounded
                : _fileIcon(name),
            size: 64,
          ),
          if (isDirectory) const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildVideoThumbnail(
    String path,
    String name,
  ) {
    return _VideoThumbnail(
      url: _thumbnailUrl(path),
    );
  }
}

class _PreviewPage extends StatefulWidget {
  const _PreviewPage({
    required this.items,
    required this.initialIndex,
    required this.previewUrl,
    required this.isImage,
    required this.isVideo,
  });

  final List<Map<String, dynamic>> items;
  final int initialIndex;
  final String Function(String path) previewUrl;
  final bool Function(String name) isImage;
  final bool Function(String name) isVideo;

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;

    _pageController = PageController(
      initialPage: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex <= 0) {
      return;
    }

    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goToNext() {
    if (_currentIndex >= widget.items.length - 1) {
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    final name = item['name']?.toString() ?? 'Archivo';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1} / ${widget.items.length}',
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final currentItem = widget.items[index];
              final currentName =
                  currentItem['name']?.toString() ?? 'Archivo';
              final path = currentItem['path']?.toString() ?? '';
              final url = widget.previewUrl(path);

              if (widget.isVideo(currentName)) {
                return _VideoPreview(
                  url: url,
                );
              }

              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder:
                        (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          'No se pudo cargar la vista previa.',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          if (_currentIndex > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: _PreviewNavigationButton(
                icon: Icons.chevron_left,
                onPressed: _goToPrevious,
              ),
            ),
          if (_currentIndex < widget.items.length - 1)
            Align(
              alignment: Alignment.centerRight,
              child: _PreviewNavigationButton(
                icon: Icons.chevron_right,
                onPressed: _goToNext,
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewNavigationButton extends StatelessWidget {
  const _PreviewNavigationButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: Colors.white,
            size: 34,
          ),
        ),
      ),
    );
  }
}


class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({
    required this.url,
  });

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.video_file_outlined,
            color: Colors.white70,
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}


class _VideoPreview extends StatefulWidget {
  const _VideoPreview({
    required this.url,
  });

  final String url;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  String? _error;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initialize(widget.url);
  }

  @override
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _initialize(widget.url);
    }
  }

  Future<void> _initialize(String url) async {
    final previousController = _controller;

    setState(() {
      _controller = null;
      _error = null;
      _initializing = true;
    });

    await previousController?.dispose();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
    );

    try {
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      _initializing = false;

      setState(() {});

      await controller.play();
    } catch (error) {
      await controller.dispose();

      if (!mounted) {
        return;
      }

      setState(() {
        _error = _friendlyVideoError(error);
        _initializing = false;
      });
    }
  }

  String _friendlyVideoError(Object error) {
    final message = error.toString();

    if (message.contains('Source error') ||
        message.contains('ExoPlaybackException')) {
      return 'El servidor no pudo entregar este video para reproducción.';
    }

    if (message.contains('HTTP')) {
      return 'No se pudo descargar el video desde el servidor.';
    }

    return 'No se pudo reproducir este video.';
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }

      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _initialize(widget.url),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Video no disponible.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final aspectRatio =
        controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9;

    return Center(
      child: GestureDetector(
        onTap: _togglePlayback,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              if (!controller.value.isPlaying)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
