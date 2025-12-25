import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

class RemoteControl extends StatefulWidget {
  const RemoteControl({super.key});

  @override
  State<RemoteControl> createState() => _RemoteControlState();
}

class _RemoteControlState extends State<RemoteControl> {
  final TextEditingController _ipController = TextEditingController();
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String _statusMessage = "Enter Host IP or Scan QR";

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    // Ensure all orientations are allowed
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _channel?.sink.close();
    super.dispose();
  }

  bool _isValidIp(String ip) {
    if (ip.isEmpty) return false;
    // Basic IPv4 format check: x.x.x.x where x is 0-255
    final regex = RegExp(
      r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return regex.hasMatch(ip);
  }

  void _connect() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _statusMessage = "Please enter an IP address";
      });
      return;
    }

    if (!_isValidIp(ip)) {
      setState(() {
        _statusMessage = "Invalid IP address format";
      });
      return;
    }

    _connectToIp(ip);
  }

  void _connectToIp(String ip) {
    if (!_isValidIp(ip)) {
      setState(() {
        _statusMessage = "Invalid QR Code format";
      });
      return;
    }

    try {
      final wsUrl = Uri.parse('ws://$ip:8080');
      setState(() {
        _statusMessage = "Connecting to $ip...";
      });

      _channel = WebSocketChannel.connect(wsUrl);

      // Listen to stream to verify connection works (though mostly we send)
      _channel!.stream.listen(
        (message) {
          // Optional: Server could confirm connection
        },
        onError: (error) {
          setState(() {
            _isConnected = false;
            _statusMessage = "Connection Error: $error";
          });
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _statusMessage = "Disconnected";
            });
          }
        },
      );

      setState(() {
        _isConnected = true;
        _statusMessage = "Connected to $ip";
      });
      // Save IP for convenience? (Optional)
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
      });
    }
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScanScreen()),
    );

    if (result != null && result.isNotEmpty) {
      _ipController.text = result;
      _connectToIp(result);
    }
  }

  void _sendCommand(String cmd) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(cmd);
      // Visual feedback could be added here
    }
  }

  void _showFeedback(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 300),
        behavior: SnackBarBehavior.floating,
        width: 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Slider Remote')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusMessage.contains("Error")
                      ? Colors.red
                      : Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Host IP Address',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. 192.168.1.5',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _connect,
                icon: const Icon(Icons.link),
                label: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Connect'),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _scanQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Scan QR Code'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _channel?.sink.close(status.normalClosure);
        setState(() {
          _isConnected = false;
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              // Swipe Right -> Previous
              _sendCommand("prev");
              _showFeedback(context, "Previous");
            } else if (details.primaryVelocity! < 0) {
              // Swipe Left -> Next
              _sendCommand("next");
              _showFeedback(context, "Next");
            }
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              // Swipe Down -> Previous
              _sendCommand("prev");
              _showFeedback(context, "Previous");
            } else if (details.primaryVelocity! < 0) {
              // Swipe Up -> Next
              _sendCommand("next");
              _showFeedback(context, "Next");
            }
          },
          child: Container(
            color: Colors.transparent, // Hit test needs color
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Colors.white24,
                        size: 100,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Swipe LEFT or UP for NEXT\nSwipe RIGHT or DOWN for PREV",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "(Back to Disconnect)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QrScanScreen extends StatelessWidget {
  const QrScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              break; // Return the first valid code
            }
          }
        },
      ),
    );
  }
}
