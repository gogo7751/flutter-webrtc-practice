import 'package:flutter/material.dart';
import 'package:web_rtc_flutter/webrtc.dart';

class Home extends StatelessWidget {
  final _ip = TextEditingController();
  final _selfId = TextEditingController();
  final _remoteId = TextEditingController();

  Home({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Flutter-WebRTC'),
        ),
        body: Column(
          children: [
            TextFormField(
              controller: _ip,
              decoration: const InputDecoration(
                labelText: 'Enter server IP',
              ),
            ),
            TextFormField(
              controller: _selfId,
              decoration: const InputDecoration(
                labelText: 'Enter self ID',
              ),
            ),
            TextFormField(
              controller: _remoteId,
              decoration: const InputDecoration(
                labelText: 'Enter remote ID',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text('Connect'),
              onPressed: () {
                final host = _ip.text;
                final selfId = _selfId.text;
                final remoteId = _remoteId.text;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebRTCPage(
                      host: host,
                      selfId: selfId,
                      remoteId: remoteId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
