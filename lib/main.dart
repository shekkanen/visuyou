import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'dart:convert';
import 'package:archive/archive.dart';

void main() => runApp(const MaterialApp(home: CameraStreamingApp()));

class CameraStreamingApp extends StatefulWidget {
  const CameraStreamingApp({super.key});

  @override
  _CameraStreamingAppState createState() => _CameraStreamingAppState();
}

class _CameraStreamingAppState extends State<CameraStreamingApp> {
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;
  RTCPeerConnection? _peerConnection;
  bool _renderersInitialized = false;
  bool _isOfferer = false; // Track if the device is the offerer

  String _connectionCode = '';
  final List<RTCIceCandidate> _gatheredIceCandidates = [];

  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      await Permission.camera.request();
    }

    if (await Permission.camera.isGranted) {
      await _initializeRenderers();
      await _createPeerConnection();
    } else {
      _showPermissionAlert();
    }
  }

  Future<void> _initializeRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      setState(() {
        _renderersInitialized = true;
      });
    } catch (e) {
      print('Failed to initialize renderers: $e');
      _showErrorAlert('Failed to initialize renderers');
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('ICE Connection State: $state');
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('Peer Connection State: $state');
      };

      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        print('Signaling State: $state');
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('Received track: ${event.track.kind}');
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
          });
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          print('ICE Candidate: ${candidate.candidate}');
          _gatheredIceCandidates.add(candidate); // Collect ICE candidates
        }
      };

      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        print('ICE Gathering State: $state');
      };

      final stream = await navigator.mediaDevices.getUserMedia({'video': true});
      _localRenderer.srcObject = stream;

      for (var track in stream.getTracks()) {
        await _peerConnection!.addTrack(track, stream);
      }
    } catch (e) {
      print('Failed to create PeerConnection: $e');
      _showErrorAlert('Failed to create PeerConnection');
    }
  }

  Future<void> _createOffer() async {
    if (_peerConnection == null) {
      print("PeerConnection is not initialized");
      return;
    }

    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      print("Local SDP Offer: ${offer.sdp}");

      _isOfferer = true; // Mark this device as the offerer

      await _displayQRCode(offer.sdp!, 'offer');
    } catch (e) {
      print('Failed to create offer: $e');
      _showErrorAlert('Failed to create offer');
    }
  }

  Future<void> _createAnswer() async {
    if (_peerConnection == null) {
      print("PeerConnection is not initialized");
      return;
    }

    try {
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      print("Local SDP Answer: ${answer.sdp}");

      await _displayQRCode(answer.sdp!, 'answer');
    } catch (e) {
      print('Failed to create answer: $e');
      _showErrorAlert('Failed to create answer');
    }
  }

  Future<void> _onOfferReceived(String sdp) async {
    if (_peerConnection == null) {
      print("PeerConnection is not initialized");
      return;
    }

    try {
      final description = RTCSessionDescription(sdp, 'offer');
      await _peerConnection!.setRemoteDescription(description);
      print("Remote SDP set as Offer");
      await _createAnswer();
    } catch (e) {
      print('Failed to handle received offer: $e');
      _showErrorAlert('Failed to handle received offer');
    }
  }

  Future<void> _onAnswerReceived(String sdp) async {
    if (_peerConnection == null) {
      print("PeerConnection is not initialized");
      return;
    }

    try {
      final description = RTCSessionDescription(sdp, 'answer');
      await _peerConnection!.setRemoteDescription(description);
      print("Remote SDP set as Answer");

      if (_isOfferer) {
        // Once the answer is received, send the collected ICE candidates
        for (RTCIceCandidate candidate in _gatheredIceCandidates) {
          await _displayQRCode(candidate.candidate!, 'ice');
        }
      }
    } catch (e) {
      print('Failed to handle received answer: $e');
      _showErrorAlert('Failed to handle received answer');
    }
  }

  Future<void> _addIceCandidate(String candidate) async {
    if (_peerConnection == null) {
      print("PeerConnection is not initialized");
      return;
    }

    try {
      RTCIceCandidate iceCandidate = RTCIceCandidate(candidate, '', 0);
      await _peerConnection!.addCandidate(iceCandidate);
      print("Added ICE Candidate: $candidate");
    } catch (e) {
      print('Failed to add ICE candidate: $e');
      _showErrorAlert('Failed to add ICE candidate');
    }
  }

  Future<void> _displayQRCode(String data, String type) async {
    try {
      String compressedData = _compressData(data);
      setState(() {
        _connectionCode = jsonEncode({'type': type, 'data': compressedData});
        print("Generated QR Code Data: $_connectionCode");
      });
    } catch (e) {
      print("Error generating QR code: $e");
      _showErrorAlert("Error generating QR code");
    }
  }

  Future<void> _scanQRCode() async {
    try {
      String scannedData = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Cancel", true, ScanMode.QR);

      if (scannedData != '-1') {
        _processScannedData(scannedData);
      } else {
        print("QR scan was cancelled or failed");
      }
    } catch (e) {
      print("Error scanning QR code: $e");
      _showErrorAlert("Error scanning QR code");
    }
  }

  void _processScannedData(String scannedData) async {
    try {
      final Map<String, dynamic> receivedData = jsonDecode(scannedData);
      print("Decoded Data: $receivedData");
      final String type = receivedData['type'];
      final String compressedData = receivedData['data'];
      final String data = _decompressData(compressedData);
      print("Type: $type, Data: $data");

      if (type == 'offer') {
        await _onOfferReceived(data);
      } else if (type == 'answer') {
        await _onAnswerReceived(data);
      } else if (type == 'ice') {
        await _addIceCandidate(data);
      } else {
        print("Unknown type: $type");
      }
    } catch (e) {
      print("Failed to decode QR code data: $e");
      _showErrorAlert("Failed to decode QR code data");
    }
  }

  void _showPermissionAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions required'),
        content: const Text('Camera permissions are required to proceed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
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
    _peerConnection?.dispose();
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

// Compress the data
String _compressData(String data) {
  try {
    List<int> stringBytes = utf8.encode(data);
    List<int> compressedBytes = GZipEncoder().encode(stringBytes) as List<int>;
    return base64Encode(compressedBytes);
  } catch (e) {
    print('Failed to compress data: $e');
    throw Exception('Failed to compress data');
  }
}

// Decompress the data
String _decompressData(String compressedData) {
  try {
    List<int> compressedBytes = base64Decode(compressedData);
    List<int> decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
    return utf8.decode(decompressedBytes);
  } catch (e) {
    print('Failed to decompress data: $e');
    throw Exception('Failed to decompress data');
  }
}
