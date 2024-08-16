import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MaterialApp(home: CameraStreamingApp()));

class CameraStreamingApp extends StatefulWidget {
  @override
  _CameraStreamingAppState createState() => _CameraStreamingAppState();
}

class _CameraStreamingAppState extends State<CameraStreamingApp> {
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;
  late RTCPeerConnection _peerConnection;
  bool _renderersInitialized = false;

  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
    if (await Permission.camera.isGranted && await Permission.microphone.isGranted) {
      await _initializeRenderers();
      await _createPeerConnection();
    } else {
      _showPermissionAlert();
    }
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    setState(() {
      _renderersInitialized = true;
    });
  }

  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };
    _peerConnection = await createPeerConnection(configuration);

    _peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
      }
    };

    _peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null) {
        // You need to pass this candidate to the other device
        print('ICE Candidate: ${candidate.candidate}');
      }
    };

    final stream = await navigator.mediaDevices.getUserMedia({'video': true});
    _localRenderer.srcObject = stream;

    for (var track in stream.getTracks()) {
      _peerConnection.addTrack(track, stream);
    }
  }

  Future<void> _createOffer() async {
    final offer = await _peerConnection.createOffer();
    await _peerConnection.setLocalDescription(offer);
    print("Local SDP Offer: ${offer.sdp}");
    // You need to share this offer with the other device
  }

  Future<void> _createAnswer() async {
    final answer = await _peerConnection.createAnswer();
    await _peerConnection.setLocalDescription(answer);
    print("Local SDP Answer: ${answer.sdp}");
    // You need to share this answer with the other device
  }

  void _setRemoteDescription(String sdp, String type) async {
    RTCSessionDescription description = RTCSessionDescription(sdp, type);
    await _peerConnection.setRemoteDescription(description);
  }

  void _addIceCandidate(String candidate, String sdpMid, int sdpMlineIndex) async {
    RTCIceCandidate iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMlineIndex);
    await _peerConnection.addCandidate(iceCandidate);
  }

  void _showPermissionAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permissions required'),
        content: Text('Camera and microphone permissions are required to proceed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('P2P Camera Stream')),
      body: _renderersInitialized
          ? Column(
              children: [
                Expanded(child: RTCVideoView(_localRenderer)),
                Expanded(child: RTCVideoView(_remoteRenderer)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _createOffer,
                      child: Text('Create Offer'),
                    ),
                    ElevatedButton(
                      onPressed: _createAnswer,
                      child: Text('Create Answer'),
                    ),
                  ],
                ),
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
