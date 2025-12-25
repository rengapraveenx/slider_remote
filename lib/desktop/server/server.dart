import 'dart:async';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SlideServer {
  HttpServer? _server;
  final _commandController = StreamController<String>.broadcast();
  final _clientCountController = StreamController<int>.broadcast();
  int _clientCount = 0;

  Stream<String> get commandStream => _commandController.stream;
  Stream<int> get clientCountStream => _clientCountController.stream;

  Future<String?> getLocalIp() async {
    final info = NetworkInfo();
    return await info.getWifiIP();
  }

  Future<void> start() async {
    final handler = webSocketHandler((
      WebSocketChannel webSocket,
      String? protocol,
    ) {
      _clientCount++;
      _clientCountController.add(_clientCount);

      webSocket.stream.listen(
        (message) {
          _commandController.add(message.toString());
        },
        onDone: () {
          _clientCount--;
          _clientCountController.add(_clientCount);
        },
      );
    });

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
    print('Serving at ws://${_server!.address.host}:${_server!.port}');
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}
