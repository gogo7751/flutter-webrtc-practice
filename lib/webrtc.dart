import 'dart:core';
import 'dart:convert';
import 'package:web_rtc_flutter/websocket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCPage extends StatefulWidget {
  final String host;
  final String selfId;
  final String remoteId;
  @override
  _WebRTCPageState createState() => _WebRTCPageState();
  const WebRTCPage(
      {super.key,
      required this.host,
      required this.selfId,
      required this.remoteId});
}

class _WebRTCPageState extends State<WebRTCPage> {
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  late RTCPeerConnection _peerConnection;
  SimpleWebSocket? _socket;

  @override
  void initState() {
    super.initState();
    initRenderers();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _createPeerConnection();
    await _getUserMedia();
    await connect();
  }

  @override
  void dispose() {
    super.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  Future<void> connect() async {
    var url = 'https://${widget.host}:8086/ws';
    _socket = SimpleWebSocket(url);

    // print('connect to $url');

    _socket?.onOpen = () {
      var request = Map();
      request["type"] = 'new';
      request["data"] = {
        'name': "test",
        'id': widget.selfId,
      };

      _socket?.send(JsonEncoder().convert(request));
    };

    _socket?.onMessage = (message) {
      Map<String, dynamic> data = jsonDecode(message);
      if (data['type'] == 'offer') {
        RTCSessionDescription description = RTCSessionDescription(
          data['data']['description']['sdp'],
          data['data']['description']['type'],
        );
        _peerConnection.setRemoteDescription(description);
      }
    };

    _socket?.onClose = (int? code, String? reason) {
      // print('Closed by server [$code => $reason]!');
    };

    await _socket?.connect();
  }

  // Create an offer and send it to the remote peer
  _createOffer() async {
    RTCSessionDescription description = await _peerConnection.createOffer();
    await _peerConnection.setLocalDescription(description);
    var request = {};
    request["type"] = 'offer';
    request["data"] = {
      'to': widget.remoteId,
      'from': widget.selfId,
      'description': {'sdp': description.sdp, 'type': description.type},
      'session_id': "111111",
      'media': 'video',
    };
    _socket?.send(const JsonEncoder().convert(request));
  }

  // Create an answer to the received offer and send it back to the remote peer
  _createAnswer() async {
    RTCSessionDescription description = await _peerConnection.createAnswer();
    await _peerConnection.setLocalDescription(description);

    var request = {};
    request["type"] = 'answer';
    request["data"] = {
      'to': widget.remoteId,
      'from': widget.selfId,
      'description': {'sdp': description.sdp, 'type': description.type},
      'session_id': "111111",
    };
    _socket?.send(const JsonEncoder().convert(request));
  }

  // Set up the peer connection with ICE servers and media constraints
  _createPeerConnection() async {
    // Initialize the PeerConnection object
    Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    _peerConnection = await createPeerConnection(configuration);

    // Listen for remote stream and add it to the remote renderer
    _peerConnection.onAddStream = (MediaStream stream) {
      setState(() {
        _remoteStream = stream;
      });
      _remoteRenderer.srcObject = _remoteStream;
    };

    // Add the local stream to the peer connection
    if (_localStream != null) {
      _localStream?.getTracks().forEach((track) {
        _peerConnection.addTrack(track, _localStream!);
      });
    }

    // Listen for ICE candidates and send them to the remote peer
    _peerConnection.onIceCandidate = (RTCIceCandidate candidate) async {
      var request = {};
      request["type"] = 'candidate';
      request["data"] = {
        'to': widget.remoteId,
        'from': widget.selfId,
        'candidate': {
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        },
        'session_id': "111111",
      };
      await Future.delayed(const Duration(seconds: 1),
          () => _socket?.send(const JsonEncoder().convert(request)));
    };
  }

  // Initialize the local media stream
  _getUserMedia() async {
    MediaStream stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      },
    });
    _localRenderer.srcObject = stream;
    setState(() {
      _localStream = stream;
    });
  }

  // Disconnect the peer connection and dispose of the local stream
  _hangUp() async {
    await _peerConnection.close();
    Navigator.pop(context);
    setState(() {
      // _localStream = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC Example'),
      ),
      body: Center(
        child: Column(
          children: [
// Display the local stream using the local renderer
            SizedBox(
              height: 200,
              child: RTCVideoView(_localRenderer),
            ),
// Display the remote stream using the remote renderer
            SizedBox(
              height: 200,
              child: RTCVideoView(_remoteRenderer),
            ),
// Add buttons for creating an offer, creating an answer, and hanging up
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _createOffer,
                  child: const Text('Create Offer'),
                ),
                ElevatedButton(
                  onPressed: _createAnswer,
                  child: const Text('Create Answer'),
                ),
                ElevatedButton(
                  onPressed: _hangUp,
                  child: const Text('Hang Up'),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getUserMedia,
        tooltip: 'Get User Media',
        child: const Icon(Icons.videocam),
      ),
    );
  }
}
