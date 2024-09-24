// lib/main.dart
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
  WidgetsFlutterBinding.ensureInitialized(); // Ensure plugin services are initialized
  final prefs = await SharedPreferences.getInstance(); // Load shared preferences
  final enableAudio = prefs.getBool('enableAudio') ?? false; // Get audio setting
  final enableVoiceCommands = prefs.getBool('enableVoiceCommands') ?? true; // Get voice command setting

  runApp(MaterialApp(
    home: CameraStreamingApp(enableAudio: enableAudio, enableVoiceCommands: enableVoiceCommands),
    debugShowCheckedModeBanner: false,
  )); // Pass the settings to the app
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
      cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _showPermissionAlert();
        return;
      }
    }

    // Check if either enableAudio or enableVoiceCommands is true
    bool enableAudio = widget.enableAudio;
    bool enableVoiceCommands = widget.enableVoiceCommands;

    if (enableAudio || enableVoiceCommands) {
      var microphoneStatus = await Permission.microphone.status;
      if (microphoneStatus.isDenied) {
        microphoneStatus = await Permission.microphone.request();
        if (!microphoneStatus.isGranted) {
          _showPermissionAlert();
          return;
        }
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

    bool enableAudio = widget.enableAudio;

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
          _gatheredIceCandidates.add(candidate);
        }
      };

      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        if (kDebugMode) {
          print('ICE Gathering State: $state');
        }
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          _sendQRCode();
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

  /// Sends the QR code containing SDP and ICE candidates.
  Future<void> _sendQRCode() async {
    if (_peerConnection == null) {
      if (kDebugMode) {
        print("PeerConnection is not initialized");
      }
      return;
    }

    try {
      RTCSessionDescription? localDescription = await _peerConnection!.getLocalDescription();
      if (localDescription == null) {
        if (kDebugMode) {
          print("Local description is not set");
        }
        return;
      }

      // Prepare ICE candidates as a list of maps
      List<Map<String, dynamic>> iceCandidates = _gatheredIceCandidates.map((candidate) {
        return {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        };
      }).toList();

      // Determine type based on whether this device is the offerer
      String type = _isOfferer ? 'offer' : 'answer';

      await QRCodeUtils.displayQRCode(
        context,
        type,
        localDescription.sdp ?? '',
        iceCandidates,
        (String qrCodeData) {
          setState(() {
            _connectionCode = qrCodeData;
            _connecting = false;
          });
        },
      );

      if (kDebugMode) {
        print("QR Code sent with type: $type");
      }

      // Clear the gathered ICE candidates after sending
      _gatheredIceCandidates.clear();
    } catch (e) {
      if (kDebugMode) {
        print("Failed to send QR Code: $e");
      }
      _showErrorAlert('Failed to send QR code. Please try again.');
    }
  }

  /// Creates an SDP offer.
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
        _isOfferer = true; // Mark this device as the offerer
      });

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      if (kDebugMode) {
        print("Local SDP Offer: ${offer.sdp}");
      }

      // The QR code will be sent automatically once ICE gathering is complete
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

  /// Creates an SDP answer.
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
        _isOfferer = false; // This device is the answerer
      });

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      if (kDebugMode) {
        print("Local SDP Answer: ${answer.sdp}");
      }

      // The QR code will be sent automatically once ICE gathering is complete
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

  /// Handles receiving an SDP offer.
  Future<void> _onOfferReceived(String sdp, List<Map<String, dynamic>> iceCandidates) async {
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

      // Add ICE candidates received from the offer
      for (var candidate in iceCandidates) {
        RTCIceCandidate iceCandidate = RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(iceCandidate);
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

  /// Handles receiving an SDP answer.
  Future<void> _onAnswerReceived(String sdp, List<Map<String, dynamic>> iceCandidates) async {
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

      // Add ICE candidates received from the answer
      for (var candidate in iceCandidates) {
        RTCIceCandidate iceCandidate = RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(iceCandidate);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to handle received answer: $e');
      }
      _showErrorAlert('Failed to process the answer. Please try again.');
    }
  }

  /// Scans a QR code and processes the data.
  Future<void> _scanQRCode() async {
    await QRCodeUtils.scanQRCode(context, _processScannedData);
  }

  /// Processes the scanned QR code data.
  void _processScannedData(String type, String sdp, List<Map<String, dynamic>> iceCandidates) async {
    if (type == 'offer') {
      await _onOfferReceived(sdp, iceCandidates);
    } else if (type == 'answer') {
      await _onAnswerReceived(sdp, iceCandidates);
    } else {
      if (kDebugMode) {
        print("Unknown type: $type");
      }
      _showErrorAlert('Unknown QR code type. Please try again.');
    }
  }

  /// Handles recognized voice commands.
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

  /// Switches the view mode based on the selected mode.
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

  /// Enters Full VR Mode.
  void _enterFullVRMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullVRVideoView(remoteRenderer: _remoteRenderer),
      ),
    ).then((_) {
      // This will reset the orientation when the VR view is popped from the navigation stack.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  /// Enters 50/50 VR Mode.
  void _enter50_50VRMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  /// Enters Picture-in-Picture VR Mode.
  void _enterPiPMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  /// Enters the second Picture-in-Picture VR Mode.
  void _enterPiPMode2() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PiPVideoView(
          mainRenderer: _localRenderer, // Assuming localRenderer as main view
          pipRenderer: _remoteRenderer, // Assuming remoteRenderer as PiP view
        ),
      ),
    ).then((_) {
      // Reset orientation when the PiP view is popped from the navigation stack.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  /// Shows an alert dialog if permissions are not granted.
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

  /// Shows an error alert dialog.
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

  /// Shows an error snackbar.
  void _showErrorSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Shows an informational snackbar.
  void _showInfoSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Checks if it's the first launch and shows Terms of Service if needed.
  void _checkFirstLaunch() async {
    prefs = await SharedPreferences.getInstance();
    bool acceptedTerms = prefs.getBool('acceptedTerms') ?? false;
    if (!acceptedTerms) {
      _showTermsAcceptance();
    }
  }

  /// Displays the Terms of Service acceptance dialog.
  void _showTermsAcceptance() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: SingleChildScrollView(
          child: Text(_termsOfServiceText),
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
              if (newValue == null) return;
              setState(() {
                _selectedViewMode = newValue;
              });
              switchViewMode(newValue);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _renderersInitialized
          ? Column(
              children: [
                Expanded(
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                  ),
                ),
                Expanded(
                  child: RTCVideoView(
                    _remoteRenderer,
                  ),
                ),
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
                        onPressed: _isOfferer || _connecting ? null : _createOffer,
                        child: const Text('Create Offer'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0), // Larger button size
                          textStyle: const TextStyle(fontSize: 18), // Larger text size
                        ),
                        onPressed: _connecting ? null : _scanQRCode,
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

  /// Navigates to the Settings page.
  void _navigateToSettingsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  /// Navigates to the About page.
  void _navigateToAboutPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutPage()),
    );
  }
}

// VR Video View Classes

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
            final pipSize = constraints.maxWidth / 5; // Adjust the size of the PiP view here

            return Row(
              children: [
                // Main View
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
                // Secondary View
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
