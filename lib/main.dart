import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'qr_code_utils.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'voice_command_utils.dart';
import 'about_page.dart'; // Import the About page
import 'settings_page.dart'; // Import the Settings page

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
  bool _connecting = false; // Track connection status

  String _connectionCode = '';
  final List<RTCIceCandidate> _gatheredIceCandidates = [];

  // Dropdown menu related
  String _selectedViewMode = 'Full VR Mode'; // Default selected mode
  final List<String> _viewModes = ['Full VR Mode', '50/50 VR Mode', 'PIP VR Mode'];

  late VoiceCommandUtils _voiceCommandUtils; // Add this line
  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    _requestPermissions();
    _voiceCommandUtils = VoiceCommandUtils(onCommandRecognized: handleVoiceCommand);
    _voiceCommandUtils.initSpeech(); // Initialize speech recognition
      SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]); // Force portrait mode initially
  
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
      _showErrorAlert('Failed to initialize video renderers. Please restart the app.');
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
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          setState(() {
            _connecting = false;
          });
          _showInfoSnackBar('Connected successfully!');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          setState(() {
            _connecting = false;
          });
          _showErrorSnackBar('Connection failed. Please try again.');
        }
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

      // Enumerate cameras and get the device ID of the back camera
      final mediaDevices = await navigator.mediaDevices.enumerateDevices();
      String? backCameraId;

      for (var device in mediaDevices) {
        if (device.kind == 'videoinput' && device.label.toLowerCase().contains('back')) {
          backCameraId = device.deviceId;
          break;
        }
      }

      if (backCameraId != null) {
        // Get video stream from back camera using the device ID
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'deviceId': backCameraId,  // Pass the device ID directly as a string
          },
        });
        _localRenderer.srcObject = stream;

        for (var track in stream.getTracks()) {
          await _peerConnection!.addTrack(track, stream);
        }
      } else {
        print('Back camera not found');
        _showErrorSnackBar('Back camera not found. Using default camera.');

        // Fallback to default camera if back camera is not found
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': true,
        });
        _localRenderer.srcObject = stream;

        for (var track in stream.getTracks()) {
          await _peerConnection!.addTrack(track, stream);
        }
      }
    } catch (e) {
      print('Failed to create PeerConnection: $e');
      _showErrorAlert('Failed to create a connection. Please try again.');
    }
  }

  Future<void> _createOffer() async {
    if (_peerConnection == null) {
      print("PeerConnection is not initialized");
      return;
    }

    try {
      setState(() {
        _connecting = true;
      });

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      print("Local SDP Offer: ${offer.sdp}");

      _isOfferer = true; // Mark this device as the offerer

      await _displayQRCode(offer.sdp!, 'offer');
    } catch (e) {
      setState(() {
        _connecting = false;
      });
      print('Failed to create offer: $e');
      _showErrorAlert('Failed to create an offer. Please try again.');
    }
  }

  Future<void> _createAnswer() async {
    if (_peerConnection == null) {
      print("PeerConnection is not initialized");
      return;
    }

    try {
      setState(() {
        _connecting = true;
      });

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      print("Local SDP Answer: ${answer.sdp}");

      await _displayQRCode(answer.sdp!, 'answer');
    } catch (e) {
      setState(() {
        _connecting = false;
      });
      print('Failed to create answer: $e');
      _showErrorAlert('Failed to create an answer. Please try again.');
    }
  }

  Future<void> _onOfferReceived(String sdp) async {
    if (_peerConnection == null) {
      print("PeerConnection is not initialized");
      return;
    }

    try {
      setState(() {
        _connecting = true;
      });

      final description = RTCSessionDescription(sdp, 'offer');
      await _peerConnection!.setRemoteDescription(description);
      print("Remote SDP set as Offer");
      await _createAnswer();
    } catch (e) {
      setState(() {
        _connecting = false;
      });
      print('Failed to handle received offer: $e');
      _showErrorAlert('Failed to process the offer. Please try again.');
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
      _showErrorAlert('Failed to process the answer. Please try again.');
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
      _showErrorAlert('Failed to add ICE candidate. Please try again.');
    }
  }

Future<void> _displayQRCode(String data, String type) async {
  await QRCodeUtils.displayQRCode(context, data, type, (String qrCodeData) {
    setState(() {
      _connectionCode = qrCodeData;
    });
  });
}

Future<void> _scanQRCode() async {
  await QRCodeUtils.scanQRCode(context, _processScannedData);
}

void _processScannedData(String type, String data) async {
  if (type == 'offer') {
    await _onOfferReceived(data);
  } else if (type == 'answer') {
    await _onAnswerReceived(data);
  } else if (type == 'ice') {
    await _addIceCandidate(data);
  } else {
    print("Unknown type: $type");
  }
}

void handleVoiceCommand(String command) {
  if (command == 'next') {
    int currentIndex = _viewModes.indexOf(_selectedViewMode);
    int nextIndex = (currentIndex + 1) % _viewModes.length;
    String nextMode = _viewModes[nextIndex];
    setState(() {
      _selectedViewMode = nextMode;
    });
    switchViewMode(nextMode);
  }
}

void switchViewMode(String mode) {
  if (mode.contains('VR Mode')) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  } else {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  switch (mode) {
    case 'Full VR Mode':
      _enterFullVRMode();
      break;
    case '50/50 VR Mode':
      _enter50_50VRMode();
      break;
    case 'PIP VR Mode':
      _enterPiPMode();
      break;
  }
}

void _enterFullVRMode() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FullVRVideoView(remoteRenderer: _remoteRenderer),
    ),
  ).then((_) {
    // This will reset the orientation when the VR view is popped from the navigation stack.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  });
}

void _enter50_50VRMode() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => VR50_50VideoView(
        localRenderer: _localRenderer,
        remoteRenderer: _remoteRenderer,
      ),
    ),
  ).then((_) {
    // Reset orientation when the VR view is popped from the navigation stack.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  });
}


void _enterPiPMode() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PiPVideoView(
        mainRenderer: _remoteRenderer, // Assuming remoteRenderer as main view
        pipRenderer: _localRenderer, // Assuming localRenderer as PiP view
      ),
    ),
  ).then((_) {
    // Reset orientation when the PiP view is popped from the navigation stack.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  });
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

  void _showErrorSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showInfoSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]); // Reset to dynamic orientation on dispose
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/visuyou_logo.png',
                height: 24.0,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8.0),
              const Text(
                'VisuYou',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
            const SizedBox(height: 4.0),
          const Text(
            'True P2P VR Experience',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w300,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _navigateToSettingsPage(context),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _navigateToAboutPage(context),
        ),
        DropdownButton<String>(
          value: _selectedViewMode,
          dropdownColor: Colors.black87,
          style: const TextStyle(color: Colors.white),
          underline: Container(),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          items: _viewModes.map((String mode) {
            return DropdownMenuItem<String>(
              value: mode,
              child: Text(mode),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedViewMode = newValue!;
                // Add logic to handle view mode change here
                if (_selectedViewMode == 'Full VR Mode') {
                  _enterFullVRMode();
                } else if (_selectedViewMode == '50/50 VR Mode') {
                  _enter50_50VRMode();
                } else if (_selectedViewMode == 'PIP VR Mode') {
                  _enterPiPMode();
                }
            });
          },
        ),
          const SizedBox(width: 12), // Add some padding to the right
      ],
    ),
      body: _renderersInitialized
          ? Column(
              children: [
                Expanded(child: RTCVideoView(_localRenderer)),
                Expanded(child: RTCVideoView(_remoteRenderer)),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _connectionCode.isNotEmpty
                      ? QRCodeUtils.buildQRCodeWidget(_connectionCode)
                      : _connecting
                          ? const CircularProgressIndicator()
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
  
void _navigateToSettingsPage(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const SettingsPage()),
  );
}

void _navigateToAboutPage(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const AboutPage()),
  );
}




// Move the VRVideoView class to the top level
class FullVRVideoView extends StatelessWidget {
  final RTCVideoRenderer remoteRenderer;

  const FullVRVideoView({Key? key, required this.remoteRenderer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hide the system UI when entering VR mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Restore the system UI when exiting VR mode
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          Navigator.pop(context);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final halfWidth = constraints.maxWidth / 2;
            return Row(
              children: [
                // Left Eye View
                SizedBox(
                  width: halfWidth,
                  height: constraints.maxHeight,
                  child: RTCVideoView(
                    remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure video fills the box
                  ),
                ),
                // Right Eye View
                SizedBox(
                  width: halfWidth,
                  height: constraints.maxHeight,
                  child: RTCVideoView(
                    remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure video fills the box
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


class VR50_50VideoView extends StatelessWidget {
  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;

  const VR50_50VideoView({
    Key? key,
    required this.localRenderer,
    required this.remoteRenderer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hide the system UI when entering VR mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Restore the system UI when exiting VR mode
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          Navigator.pop(context);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final quarterWidth = constraints.maxWidth / 4;
            return Row(
              children: [
                // Left Eye View
                SizedBox(
                  width: quarterWidth * 2,
                  height: constraints.maxHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: quarterWidth,
                        height: constraints.maxHeight,
                        child: RTCVideoView(
                          localRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure video fills the box
                        ),
                      ),
                      SizedBox(
                        width: quarterWidth,
                        height: constraints.maxHeight,
                        child: RTCVideoView(
                          remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure video fills the box
                        ),
                      ),
                    ],
                  ),
                ),
                // Right Eye View
                SizedBox(
                  width: quarterWidth * 2,
                  height: constraints.maxHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: quarterWidth,
                        height: constraints.maxHeight,
                        child: RTCVideoView(
                          localRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure video fills the box
                        ),
                      ),
                      SizedBox(
                        width: quarterWidth,
                        height: constraints.maxHeight,
                        child: RTCVideoView(
                          remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure video fills the box
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// PiP Mode implementation for VR headset
class PiPVideoView extends StatelessWidget {
  final RTCVideoRenderer mainRenderer;
  final RTCVideoRenderer pipRenderer;

  const PiPVideoView({
    Key? key,
    required this.mainRenderer,
    required this.pipRenderer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hide the system UI when entering VR mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Restore the system UI when exiting VR mode
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          Navigator.pop(context);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final halfWidth = constraints.maxWidth / 2;
            final pipSize = constraints.maxWidth / 5;  // Adjust the size of the PiP view here

            return Row(
              children: [
                // Left Eye View
                SizedBox(
                  width: halfWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      RTCVideoView(
                        mainRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure main video fills the box
                      ),
                      Positioned(
                        right: 20.0,
                        bottom: 20.0,
                        width: pipSize,
                        height: pipSize,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2), // Frame around the PiP view
                          ),
                          child: RTCVideoView(
                            pipRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure PiP video fills the box
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right Eye View
                SizedBox(
                  width: halfWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      RTCVideoView(
                        mainRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure main video fills the box
                      ),
                      Positioned(
                        right: 20.0,
                        bottom: 20.0,
                        width: pipSize,
                        height: pipSize,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2), // Frame around the PiP view
                          ),
                          child: RTCVideoView(
                            pipRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure PiP video fills the box
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}



String _compressData(String data) {
  try {
    List<int> stringBytes = utf8.encode(data);
    List<int> compressedBytes =
        GZipEncoder().encode(stringBytes) as List<int>;
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
    List<int> decompressedBytes =
        GZipDecoder().decodeBytes(compressedBytes);
    return utf8.decode(decompressedBytes);
  } catch (e) {
    print('Failed to decompress data: $e');
    throw Exception('Failed to decompress data');
  }
}
