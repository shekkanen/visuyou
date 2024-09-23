import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'qr_code_utils.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'voice_command_utils.dart';
import 'about_page.dart'; // Import the About page
import 'settings_page.dart'; // Import the Settings page
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Ensure plugin services are initialized
  final prefs = await SharedPreferences.getInstance();  // Load shared preferences
  final enableAudio = prefs.getBool('enableAudio') ?? false;  // Get audio setting
  final enableVoiceCommands = prefs.getBool('enableVoiceCommands') ?? true; // Get voice command setting

  runApp(MaterialApp(home: CameraStreamingApp(enableAudio: enableAudio, enableVoiceCommands: enableVoiceCommands)));  // Pass the settings to the app
}

class CameraStreamingApp extends StatefulWidget {
  final bool enableAudio;
  final bool enableVoiceCommands;
  const CameraStreamingApp({super.key, required this.enableAudio, required this.enableVoiceCommands});

  @override
  _CameraStreamingAppState createState() => _CameraStreamingAppState();
}

class _CameraStreamingAppState extends State<CameraStreamingApp> {
  late SharedPreferences prefs;
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
  final List<String> _viewModes = ['Full VR Mode', '50/50 VR Mode', 'PIP VR Mode', 'PIP VR Mode2'];

  late VoiceCommandUtils _voiceCommandUtils; // Add this line

  // Terms of Service Text
  final String _termsOfServiceText = '''
**Terms of Service**

_Last updated: October 1, 2023_

**1. Acceptance of Terms**

By downloading or using **VisuYou** ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App.

**2. Description of the App**

VisuYou allows users to engage in a peer-to-peer virtual reality experience using WebRTC technology. The App facilitates direct connections between devices without the use of a central server.

**3. Use of the App**

- **Compliance with Laws**: You agree to use the App in compliance with all applicable laws and regulations.
- **Age Requirement**: You must be at least 13 years old to use the App.
- **Prohibited Conduct**: You agree not to misuse the App, including but not limited to transmitting harmful content or interfering with other users' enjoyment of the App.

**4. Health and Safety Warning**

**WARNING:**

- **Risk of Injury**: Using virtual reality headsets may cause motion sickness, disorientation, dizziness, nausea, or other discomfort. If you experience any adverse symptoms, stop using the App immediately.
- **Physical Hazards**: Be aware of your surroundings. Using the App with a VR headset may impair your ability to perceive real-world environments, leading to potential accidents or injuries.
- **Supervision of Minors**: If minors use the App, they should do so under adult supervision.

**5. Disclaimer of Warranties**

The App is provided on an "AS IS" and "AS AVAILABLE" basis. We make no warranties, express or implied, regarding the App's operation or your use of it.

**6. Limitation of Liability**

To the fullest extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to physical injury, loss of data, or other intangible losses resulting from:

- Your access to or use of the App.
- Any conduct or content of any third party within the App.
- Unauthorized access, use, or alteration of your transmissions or content.

**7. Indemnification**

You agree to indemnify and hold harmless VisuYou and its affiliates from any claims, liabilities, damages, losses, and expenses arising out of your use of the App.

**8. Changes to the Terms**

We reserve the right to modify these Terms at any time. We will notify you of any changes by posting the new Terms within the App. Your continued use of the App after changes signifies your acceptance of the new Terms.

**9. Governing Law**

These Terms shall be governed by and construed in accordance with the laws of [Your Country/State], without regard to its conflict of law provisions.

**10. Contact Us**

If you have any questions about these Terms, please contact us at:

[Your Contact Information]
''';

  @override
  void initState() {
    super.initState();
    _initializePreferences(); // Initialize preferences
    _checkFirstLaunch(); // Check if the user has accepted the terms
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    _requestPermissions();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]); // Force portrait mode initially
  }

  Future<void> _initializePreferences() async {
    prefs = await SharedPreferences.getInstance();
    // No need to retrieve settings here; we'll get them in _requestPermissions()
  }

  Future<void> _requestPermissions() async {
    var cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      await Permission.camera.request();
    }

    // Check if either enableAudio or enableVoiceCommands is true
    bool enableAudio = prefs.getBool('enableAudio') ?? false;
    bool enableVoiceCommands = prefs.getBool('enableVoiceCommands') ?? true;

    if (enableAudio || enableVoiceCommands) {
      var microphoneStatus = await Permission.microphone.status;
      if (microphoneStatus.isDenied) {
        await Permission.microphone.request();
      }
    }

    bool microphoneGranted = !enableAudio && !enableVoiceCommands || await Permission.microphone.isGranted;

    if (await Permission.camera.isGranted && microphoneGranted) {
      await _initializeRenderers();
      await _createPeerConnection();

      if (enableVoiceCommands) {
        _voiceCommandUtils = VoiceCommandUtils(onCommandRecognized: handleVoiceCommand);
        _voiceCommandUtils.initSpeech();
      }
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
      if (kDebugMode) {
        print('Failed to initialize renderers: $e');
      }
      _showErrorAlert('Failed to initialize video renderers. Please restart the app.');
    }
  }

  Future<void> _createPeerConnection() async {
    if (prefs == null) {
      if (kDebugMode) {
        print("SharedPreferences is not initialized");
      }
      return;
    }

    bool enableAudio = prefs.getBool('enableAudio') ?? false;

    try {
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        if (kDebugMode) {
          print('ICE Connection State: $state');
        }
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
        if (kDebugMode) {
          print('Peer Connection State: $state');
        }
      };

      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        if (kDebugMode) {
          print('Signaling State: $state');
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (kDebugMode) {
          print('Received track: ${event.track.kind}');
        }
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
          });
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          if (kDebugMode) {
            print('ICE Candidate: ${candidate.candidate}');
          }
          // Automatically send the ICE candidate to the remote peer
          _peerConnection!.addCandidate(candidate);        }
      };

_peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
  if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
    if (_isOfferer) {
      _createOffer();
    } else {
      _createAnswer();
    }
  }
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
          'audio': enableAudio, // Enable audio based on the setting
          'video': {
            'deviceId': backCameraId,  // Pass the device ID directly as a string
          },
        });
        _localRenderer.srcObject = stream;

        for (var track in stream.getTracks()) {
          await _peerConnection!.addTrack(track, stream);
        }
      } else {
        if (kDebugMode) {
          print('Back camera not found');
        }
        _showErrorSnackBar('Back camera not found. Using default camera.');

        // Fallback to default camera if back camera is not found
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': enableAudio,
          'video': true,
        });
        _localRenderer.srcObject = stream;

        for (var track in stream.getTracks()) {
          await _peerConnection!.addTrack(track, stream);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create PeerConnection: $e');
      }
      _showErrorAlert('Failed to create a connection. Please try again.');
    }
  }

  Future<void> _createOffer() async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      setState(() {
        _connecting = true;
      });

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      if (kDebugMode) {
        print("Local SDP Offer: ${offer.sdp}");
      }

      _isOfferer = true; // Mark this device as the offerer

      await _displayQRCode(offer.sdp!, 'offer');
    } catch (e) {
      setState(() {
        _connecting = false;
      });
      if (kDebugMode) {
        print('Failed to create offer: $e');
      }
      _showErrorAlert('Failed to create an offer. Please try again.');
    }
  }

  Future<void> _createAnswer() async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      setState(() {
        _connecting = true;
      });

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      if (kDebugMode) {
        print("Local SDP Answer: ${answer.sdp}");
      }

      await _displayQRCode(answer.sdp!, 'answer');
    } catch (e) {
      setState(() {
        _connecting = false;
      });
      if (kDebugMode) {
        print('Failed to create answer: $e');
      }
      _showErrorAlert('Failed to create an answer. Please try again.');
    }
  }

  Future<void> _onOfferReceived(String sdp) async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      setState(() {
        _connecting = true;
      });

      final description = RTCSessionDescription(sdp, 'offer');
      await _peerConnection!.setRemoteDescription(description);
      if (kDebugMode) {
        print("Remote SDP set as Offer");
      }
      await _createAnswer();
    } catch (e) {
      setState(() {
        _connecting = false;
      });
      if (kDebugMode) {
        print('Failed to handle received offer: $e');
      }
      _showErrorAlert('Failed to process the offer. Please try again.');
    }
  }

  Future<void> _onAnswerReceived(String sdp) async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      final description = RTCSessionDescription(sdp, 'answer');
      await _peerConnection!.setRemoteDescription(description);
      if (kDebugMode) {
        print("Remote SDP set as Answer");
      }

      if (_isOfferer) {
        // Once the answer is received, send the collected ICE candidates
        for (RTCIceCandidate candidate in _gatheredIceCandidates) {
          await _displayQRCode(candidate.candidate!, 'ice');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to handle received answer: $e');
      }
      _showErrorAlert('Failed to process the answer. Please try again.');
    }
  }

  Future<void> _addIceCandidate(String candidate) async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      RTCIceCandidate iceCandidate = RTCIceCandidate(candidate, '', 0);
      await _peerConnection!.addCandidate(iceCandidate);
      if (kDebugMode) {
        print("Added ICE Candidate: $candidate");
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to add ICE candidate: $e');
      }
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
      if (kDebugMode) {
        print("Unknown type: $type");
      }
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
      case 'PIP VR Mode2':
        _enterPiPMode2();
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

  void _enterPiPMode2() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PiPVideoView(
          mainRenderer: _localRenderer, // Assuming remoteRenderer as main view
          pipRenderer: _remoteRenderer, // Assuming localRenderer as PiP view
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

void _checkFirstLaunch() async {
  prefs = await SharedPreferences.getInstance();
  bool acceptedTerms = prefs.getBool('acceptedTerms') ?? false;
  if (!acceptedTerms) {
    _showTermsAcceptance();
  }
}

void _showTermsAcceptance() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Terms of Service'),
      content: SingleChildScrollView(
        child: Text(_termsOfServiceText), // Ensure _termsOfServiceText is accessible here
      ),
      actions: [
        TextButton(
          onPressed: () {
            // User declines, exit the app
            Navigator.of(context).pop();
            SystemNavigator.pop();
          },
          child: const Text('Decline'),
        ),
        TextButton(
          onPressed: () {
            // User accepts
            prefs.setBool('acceptedTerms', true);
            Navigator.of(context).pop();
          },
          child: const Text('Accept'),
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
                height: 36.0, // Increased logo size
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: const Text(
                  'VisuYou',
                  style: TextStyle(
                    fontSize: 22.0, // Larger font size for better readability
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis, // Prevent overflow, but ellipsis should not be needed
                  maxLines: 1, // Prevent the title from taking too much space
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          FittedBox(
            fit: BoxFit.scaleDown, // Scale down the subtitle to fit properly
            child: const Text(
              'True P2P VR Experience',
              style: TextStyle(
                fontSize: 16.0, // Slightly larger subtitle font
                fontWeight: FontWeight.w300,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, size: 28), // Increased icon size
          onPressed: () => _navigateToSettingsPage(context),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, size: 28), // Increased icon size
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
              if (_selectedViewMode == 'Full VR Mode') {
                _enterFullVRMode();
              } else if (_selectedViewMode == '50/50 VR Mode') {
                _enter50_50VRMode();
              } else if (_selectedViewMode == 'PIP VR Mode') {
                _enterPiPMode();
              } else if (_selectedViewMode == 'PIP VR Mode2') {
                _enterPiPMode2();
              }
            });
          },
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: _renderersInitialized
        ? Column(
            children: [
              Expanded(child: RTCVideoView(_localRenderer)),
              Expanded(child: RTCVideoView(_remoteRenderer)),
              Padding(
                padding: const EdgeInsets.all(12.0), // Increased padding
                child: _connectionCode.isNotEmpty
                    ? QRCodeUtils.buildQRCodeWidget(_connectionCode)
                    : _connecting
                        ? const CircularProgressIndicator()
                        : const Text(
                            'No data to display',
                            style: TextStyle(fontSize: 16), // Increased text size
                          ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0), // Added padding for buttons
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0), // Larger button size
                        textStyle: const TextStyle(fontSize: 18), // Larger text size
                      ),
                      onPressed: _createOffer,
                      child: const Text('Create Offer'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0), // Larger button size
                        textStyle: const TextStyle(fontSize: 18), // Larger text size
                      ),
                      onPressed: _scanQRCode,
                      child: const Text('Scan QR Code'),
                    ),
                  ],
                ),
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
