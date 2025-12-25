import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../server/server.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _server = SlideServer();
  String? _serverIp;
  int _clientCount = 0;

  String? _pdfPath;
  final PdfViewerController _pdfController = PdfViewerController();

  // Controls Logic
  bool _showControls = false;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _initServer();
  }

  Future<void> _initServer() async {
    final ip = await _server.getLocalIp();
    setState(() {
      _serverIp = ip;
    });
    await _server.start();
    _server.clientCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _clientCount = count;
        });
      }
    });

    _server.commandStream.listen((command) {
      if (!mounted || _pdfPath == null) return;
      if (command == 'next') _nextSlide();
      if (command == 'prev') _prevSlide();
    });
  }

  void _nextSlide() {
    if (_pdfPath == null) return;
    // Check if controller is ready
    try {
      if (_pdfController.pages.isEmpty) return;
      final current = _pdfController.pageNumber ?? 0;
      if (current < _pdfController.pages.length) {
        _pdfController.goToPage(pageNumber: current + 1);
      }
    } catch (_) {}
  }

  void _prevSlide() {
    if (_pdfPath == null) return;
    try {
      if (_pdfController.pages.isEmpty) return;
      final current = _pdfController.pageNumber ?? 0;
      if (current > 1) {
        _pdfController.goToPage(pageNumber: current - 1);
      }
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _pdfPath = result.files.single.path;
      });
    }
  }

  void _activateControls() {
    setState(() {
      _showControls = true;
    });
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _closePresentation() {
    setState(() {
      _pdfPath = null;
    });
  }

  PdfPageLayout _layoutHorizontal(List<PdfPage> pages, PdfViewerParams params) {
    final height =
        pages.fold(0.0, (h, p) => max(h, p.height)) + params.margin * 2;
    final pageLayouts = <Rect>[];
    double x = params.margin;
    for (var page in pages) {
      pageLayouts.add(
        Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height),
      );
      x += page.width + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(x, height),
    );
  }

  @override
  void dispose() {
    _server.stop();
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pdfPath != null) {
      return _buildPresentation();
    }
    return _buildLobby();
  }

  Widget _buildLobby() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slider Remote Host'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Server Info Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.wifi,
                        size: 48,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Server Running',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Divider(height: 32),
                      _buildStatusRow('IP Address', _serverIp ?? 'Loading...'),
                      _buildStatusRow('Connected Devices', '$_clientCount'),
                      if (_serverIp != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _serverIp!,
                            version: QrVersions.auto,
                            size: 150.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan to Connect',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // File Picker Area
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Load PDF Presentation'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPresentation() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _closePresentation,
          const SingleActivator(LogicalKeyboardKey.arrowRight): _nextSlide,
          const SingleActivator(LogicalKeyboardKey.arrowDown): _nextSlide,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _prevSlide,
          const SingleActivator(LogicalKeyboardKey.arrowUp): _prevSlide,
        },
        child: Focus(
          autofocus: true,
          child: MouseRegion(
            onHover: (_) => _activateControls(),
            child: Stack(
              children: [
                // PDF Viewer
                Positioned.fill(
                  child: PdfViewer.file(
                    _pdfPath!,
                    controller: _pdfController,
                    params: PdfViewerParams(
                      margin: 0,
                      backgroundColor: Colors.black,
                      layoutPages: _layoutHorizontal,
                      scrollPhysics: const PageScrollPhysics(),
                    ),
                  ),
                ),

                // Overlay Controls
                if (_showControls) ...[
                  // Close Button
                  Positioned(
                    top: 20,
                    right: 20,
                    child: IconButton(
                      onPressed: _closePresentation,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 32,
                      ),
                      tooltip: 'Close Presentation (Esc)',
                    ),
                  ),

                  // Previous Button (Left)
                  Positioned(
                    left: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton.filled(
                        onPressed: _prevSlide,
                        iconSize: 48,
                        icon: const Icon(Icons.arrow_back_ios_new),
                      ),
                    ),
                  ),

                  // Next Button (Right)
                  Positioned(
                    right: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton.filled(
                        onPressed: _nextSlide,
                        iconSize: 48,
                        icon: const Icon(Icons.arrow_forward_ios),
                      ),
                    ),
                  ),

                  // Page Info (Bottom)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AnimatedBuilder(
                          animation: _pdfController,
                          builder: (context, _) {
                            int pageCount = 0;
                            int currentPage = 0;
                            try {
                              pageCount = _pdfController.pages.length;
                              currentPage = _pdfController.pageNumber ?? 0;
                            } catch (_) {
                              // Controller might not be ready yet
                              return const SizedBox.shrink();
                            }
                            return Text(
                              '$currentPage / $pageCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
