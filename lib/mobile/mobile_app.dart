import 'package:flutter/material.dart';

import 'ui/remote_control.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Slider Remote Client',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const RemoteControl(),
    );
  }
}
