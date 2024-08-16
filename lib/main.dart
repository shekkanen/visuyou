import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'dart:convert';

void main() => runApp(const MaterialApp(home: CameraStreamingApp()));

class CameraStreamingApp extends StatefulWidget {
  const CameraStreamingApp({super.key});

  @override
  _CameraStreamingAppState createState() => _CameraStreamingAppState();
}

class _CameraStreamingAppState extends State<CameraStreamingApp> {
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;
  late RTCPeerConnection _peerConnection;
  bool _renderersInitialized = false;

  String _connectionCode = '';

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
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    };

    _peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        print('ICE Candidate: ${candidate.candidate}');
        _addIceCandidateToQRCode(candidate);
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

    _displayQRCode(offer.sdp!, 'offer');
  }

  Future<void> _createAnswer() async {
    final answer = await _peerConnection.createAnswer();
    await _peerConnection.setLocalDescription(answer);
    print("Local SDP Answer: ${answer.sdp}");

    _displayQRCode(answer.sdp!, 'answer');
  }

  void _onOfferReceived(String sdp) async {
    final description = RTCSessionDescription(sdp, 'offer');
    await _peerConnection.setRemoteDescription(description);
    await _createAnswer();
  }

  void _onAnswerReceived(String sdp) async {
    final description = RTCSessionDescription(sdp, 'answer');
    await _peerConnection.setRemoteDescription(description);
  }

  void _addIceCandidateToQRCode(RTCIceCandidate candidate) {
    _displayQRCode(candidate.candidate!, 'ice');
  }

  void _addIceCandidate(String candidate) async {
    RTCIceCandidate iceCandidate = RTCIceCandidate(candidate, '', 0);
    await _peerConnection.addCandidate(iceCandidate);
  }

  void _displayQRCode(String data, String type) {
    setState(() {
      _connectionCode = jsonEncode({'type': type, 'data': data});
    });
  }

  Future<void> _scanQRCode() async {
    String scannedData = await FlutterBarcodeScanner.scanBarcode(
        "#ff6666", "Cancel", true, ScanMode.QR);
    if (scannedData != '-1') {
      final Map<String, dynamic> receivedData = jsonDecode(scannedData);
      final String type = receivedData['type'];
      final String data = receivedData['data'];

      if (type == 'offer') {
        _onOfferReceived(data);
      } else if (type == 'answer') {
        _onAnswerReceived(data);
      } else if (type == 'ice') {
        _addIceCandidate(data);
      }
    }
  }

  void _showPermissionAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions required'),
        content: const Text('Camera and microphone permissions are required to proceed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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
      appBar: AppBar(title: const Text('P2P Camera Stream with QR Code')),
      body: _renderersInitialized
          ? Column(
              children: [
                Expanded(child: RTCVideoView(_localRenderer)),
                Expanded(child: RTCVideoView(_remoteRenderer)),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _connectionCode.isNotEmpty
                      ? SizedBox(
                          width: 200.0,
                          height: 200.0,
                          child: QrImageView(
                            data: _connectionCode,
                            version: QrVersions.auto,
                            size: 200.0,
                          ),
                        )
                      : const Text('No data to display'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _createOffer,
                      child: const Text('Create Offer'),
                    ),
                    ElevatedButton(
                      onPressed: _scanQRCode,
                      child: const Text('Scan QR Code'),
                    ),
                  ],
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
