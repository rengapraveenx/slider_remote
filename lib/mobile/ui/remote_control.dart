import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _channel?.sink.close();
    super.dispose();
  }

  void _connect() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    _connectToIp(ip);
  }

  void _connectToIp(String ip) {
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

    return Scaffold(
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
                      "Swipe Left for NEXT\nSwipe Right for PREV",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      _channel?.sink.close(status.normalClosure);
                      setState(() {
                        _isConnected = false;
                      });
                    },
                    child: const Text(
                      "Disconnect",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
