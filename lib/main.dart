// lib/main.dart
// Copyright © 2024 Sami Hekkanen. All rights reserved.

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
import 'policies.dart'; // Import the privacy policy and terms of service text
import 'package:provider/provider.dart'; // Import provider
import 'settings_model.dart'; // Import settings model
import 'dart:async'; // Import for async functions

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure plugin services are initialized

  runApp(
    ChangeNotifierProvider(
      create: (context) => SettingsModel(),
      child: MaterialApp(
        title: 'VisuYou',
        theme: ThemeData(primaryColor: Colors.black),
        home: const CameraStreamingApp(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

class CameraStreamingApp extends StatefulWidget {
  const CameraStreamingApp({super.key});

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

  MediaStream? _remoteStream;

  // Dropdown menu related
  String _selectedViewMode = 'Full VR Mode'; // Default selected mode
  final List<String> _viewModes = [
    'Full VR Mode',
    '50/50 VR Mode',
    'PIP VR Mode',
    'PIP VR Mode2'
  ];
  Map<String, String> _previousVoiceCommands = {};
  VoiceCommandUtils? _voiceCommandUtils; // Modified to be nullable
  late SettingsModel _settingsModel; // Add this line

  // Added member variables for audio control
  MediaStream? _localStream;
  MediaStreamTrack? _audioTrack;
  RTCRtpSender? _audioSender;

  @override
  void initState() {
    super.initState();
    _initializePreferences(); // Initialize preferences
    _checkFirstLaunch(); // Check if the user has accepted the terms
    _requestPermissions();

    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();

    // Initialize _settingsModel and add listener
    _settingsModel = Provider.of<SettingsModel>(context, listen: false);
    _settingsModel.addListener(_onSettingsChanged);

    // Wait for settings to load before proceeding
    _settingsModel.settingsLoaded.then((_) {
      _requestPermissions(); // Proceed with the rest after settings are loaded

      // Initialize previous voice commands after _settingsModel is initialized
      _previousVoiceCommands = {
        'viewNextWord': _settingsModel.viewNextWord,
        'viewBackWord': _settingsModel.viewBackWord,
        'micEnabledWord': _settingsModel.micEnabledWord,
        'micDisableWord': _settingsModel.micDisableWord,
        'speakerEnabledWord': _settingsModel.speakerEnabledWord,
        'speakerDisableWord': _settingsModel.speakerDisableWord,
        'fullVrModeWord': _settingsModel.fullVrModeWord,
        'vr50_50ModeWord': _settingsModel.vr50_50ModeWord,
        'pipVrModeWord': _settingsModel.pipVrModeWord,
        'pipVrMode2Word': _settingsModel.pipVrMode2Word,
      };

      // Manually trigger the settings changed handler
      _onSettingsChanged();
    });

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

      var microphoneStatus = await Permission.microphone.status;
      if (microphoneStatus.isDenied) {
        microphoneStatus = await Permission.microphone.request();
        if (!microphoneStatus.isGranted) {
          _showPermissionAlert();
          return;
        }
    }


    if (await Permission.camera.isGranted && await Permission.microphone.isGranted) {
      await _initializeRenderers();
      await _createPeerConnection();

      // Voice command initialization is handled in _onSettingsChanged()
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
      _showErrorAlert(
          'Failed to initialize video renderers. Please restart the app.');
    }
  }

  Future<void> _createPeerConnection() async {
    if (prefs == null) {
      if (kDebugMode) {
        print("SharedPreferences is not initialized");
      }
      return;
    }

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
      _remoteStream = event.streams[0]; // Store the remote stream
      _toggleSpeaker(_settingsModel.speakerEnabled); // Apply speaker setting
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
        if (device.kind == 'videoinput' &&
            device.label.toLowerCase().contains('back')) {
          backCameraId = device.deviceId;
          break;
        }
      }

      // Always request audio and video
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true, // Always request audio
        'video': backCameraId != null
            ? {
                'deviceId': backCameraId,
                 'minWidth': 1280,
                'minHeight': 720,
                'minFrameRate': 30,
              }
            : true,
      });

      _localRenderer.srcObject = stream;
      _localStream = stream;

      // Add video track
      var videoTrack = stream.getVideoTracks()[0];
      await _peerConnection!.addTrack(videoTrack, stream);

      // Store the audio track for later use
      _audioTrack = stream.getAudioTracks()[0];
      _audioTrack!.enabled = _settingsModel.micEnabled;

      // Always add the audio track
      _audioSender = await _peerConnection!.addTrack(_audioTrack!, stream);



      if (backCameraId == null) {
        if (kDebugMode) {
          print('Back camera not found');
        }
        _showErrorSnackBar('Back camera not found. Using default camera.');
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
      RTCSessionDescription? localDescription =
          await _peerConnection!.getLocalDescription();
      if (localDescription == null) {
        if (kDebugMode) {
          print("Local description is not set");
        }
        return;
      }

      // Prepare ICE candidates as a list of maps
List<Map<String, dynamic>> iceCandidates = [];
for (var i = 0; i < _gatheredIceCandidates.length && i < 3; i++) {
  var candidate = _gatheredIceCandidates[i];
  iceCandidates.add({
    'candidate': candidate.candidate,
    'sdpMid': candidate.sdpMid,
    'sdpMLineIndex': candidate.sdpMLineIndex,
  });
}

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
      Future.delayed(const Duration(seconds: 2), _sendQRCode);
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
      Future.delayed(const Duration(seconds: 2), _sendQRCode);

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
  Future<void> _onOfferReceived(
      String sdp, List<Map<String, dynamic>> iceCandidates) async {
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
  Future<void> _onAnswerReceived(
      String sdp, List<Map<String, dynamic>> iceCandidates) async {
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
  void _processScannedData(String type, String sdp,
      List<Map<String, dynamic>> iceCandidates) async {
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

  void handleVoiceCommand(String command) {
    command = command.toLowerCase();

    if (command == 'view_next') {
      // Handle 'next' command
      int currentIndex = _viewModes.indexOf(_selectedViewMode);
      int nextIndex = (currentIndex + 1) % _viewModes.length;
      String nextMode = _viewModes[nextIndex];
      setState(() {
        _selectedViewMode = nextMode;
      });
      switchViewMode(nextMode);
    } else if (command == 'view_back') {
      // Handle 'back' command
      int currentIndex = _viewModes.indexOf(_selectedViewMode);
      int prevIndex = (currentIndex - 1 + _viewModes.length) % _viewModes.length;
      String prevMode = _viewModes[prevIndex];
      setState(() {
        _selectedViewMode = prevMode;
      });
      switchViewMode(prevMode);
    } else if (command == 'mute_mic') {
    _settingsModel.updatemicEnabled(false);
    _toggleMic(false);
    _showInfoSnackBar('Mic has been muted.');
  } else if (command == 'unmute_mic') {
    _settingsModel.updatemicEnabled(true);
    _toggleMic(true);
    _showInfoSnackBar('Mic has been unmuted.');
  } else if (command == 'mute_speaker') {
    _settingsModel.updateSpeakerEnabled(false);
    _toggleSpeaker(false);
    _showInfoSnackBar('Speaker has been muted.');
  } else if (command == 'unmute_speaker') {
    _settingsModel.updateSpeakerEnabled(true);
    _toggleSpeaker(true);
    _showInfoSnackBar('Speaker has been unmuted.');
  
    } else if (command == 'full_vr_mode') {
      setState(() {
        _selectedViewMode = 'Full VR Mode';
      });
      switchViewMode('Full VR Mode');
    } else if (command == 'vr50_50_mode') {
      setState(() {
        _selectedViewMode = '50/50 VR Mode';
      });
      switchViewMode('50/50 VR Mode');
    } else if (command == 'pip_vr_mode') {
      setState(() {
        _selectedViewMode = 'PIP VR Mode';
      });
      switchViewMode('PIP VR Mode');
    } else if (command == 'pip_vr_mode2') {
      setState(() {
        _selectedViewMode = 'PIP VR Mode2';
      });
      switchViewMode('PIP VR Mode2');
    } else {
      if (kDebugMode) {
        print('Unknown command received: $command');
      }
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
        content:
            const Text('Camera and microphone permissions are required to proceed.'),
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
          child: Text(termsOfService),
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

  /// Handles changes in the settings model.
void _onSettingsChanged() {
  // Handle enableVoiceCommands changes
  if (_settingsModel.enableVoiceCommands) {
    if (_voiceCommandUtils == null) {
      _voiceCommandUtils = VoiceCommandUtils(
        onCommandRecognized: handleVoiceCommand,
        settingsModel: _settingsModel,
      );
      _voiceCommandUtils!.initSpeech(); // Ignoring Future
    }
  } else {
    if (_voiceCommandUtils != null) {
      _voiceCommandUtils!.stopListening();
      _voiceCommandUtils = null;
    }
  }

  // Handle speakerEnabled changes
  _toggleSpeaker(_settingsModel.speakerEnabled);

 // Handle micEnabled changes
  if (_audioTrack != null) {
    _audioTrack!.enabled = _settingsModel.micEnabled;
  }

  setState(() {
    // Update UI if necessary
  });
}

// main.dart
Future<void> _toggleMic(bool enable) async {
  try {
    if (_audioTrack != null) {
      _audioTrack!.enabled = enable;
      if (kDebugMode) {
        print('Microphone has been ${enable ? 'enabled' : 'disabled'}.');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error toggling mic: $e');
    }
  }
}

// Modify _toggleSpeaker function
Future<void> _toggleSpeaker(bool enable) async {
  try {
    if (_remoteStream != null) {
      var audioTracks = _remoteStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = enable;
      }
      if (kDebugMode) {
        print('Speaker has been ${enable ? 'enabled' : 'disabled'}.');
      }
    } else {
      if (kDebugMode) {
        print('Cannot toggle speaker: Remote stream is null.');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error toggling speaker: $e');
    }
  }
}




  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();

    _voiceCommandUtils?.dispose(); // Dispose voice command utils if initialized

    _settingsModel.removeListener(_onSettingsChanged); // Remove settings listener
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
    /// The build method remains mostly unchanged...
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/visuyou_logo_512x512.png',
                  height: 36.0, // Increased logo size
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8.0),
                const Expanded(
                  child: Text(
                    'VisuYou',
                    style: TextStyle(
                      fontSize: 22.0, // Larger font size for better readability
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow:
                        TextOverflow.ellipsis, // Prevent overflow, but ellipsis should not be needed
                    maxLines: 1, // Prevent the title from taking too much space
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            const FittedBox(
              fit: BoxFit.scaleDown, // Scale down the subtitle to fit properly
              child: Text(
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
            icon: const Icon(Icons.settings, size: 28, color: Colors.grey), // Increased icon size and set color to grey
            onPressed: () => _navigateToSettingsPage(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 28, color: Colors.grey), // Increased icon size and set color to grey
            onPressed: () => _navigateToAboutPage(context),
          ),
          DropdownButton<String>(
            value: _selectedViewMode,
            dropdownColor: Colors.black87,
            style: const TextStyle(color: Colors.white),
            underline: Container(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 28),
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
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Opacity(
              opacity: 0.05, // Adjust the opacity to make it subtle
              child: Image.asset(
                'assets/visuyou_background.png', // Path to the background image
                fit: BoxFit.cover, // Cover the entire background
              ),
            ),
          ),

          // All other UI components come here
          _renderersInitialized
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
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0), // Added padding for buttons
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0, vertical: 12.0), // Larger button size
                                textStyle: const TextStyle(fontSize: 18), // Larger text size
                              ),
                              onPressed: _isOfferer || _connecting ? null : _createOffer,
                              child: const Text('Create Offer'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0, vertical: 12.0), // Larger button size
                                textStyle: const TextStyle(fontSize: 18), // Larger text size
                              ),
                              onPressed: _connecting ? null : _scanQRCode,
                              child: const Text('Scan QR Code'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(child: CircularProgressIndicator()),
        ],
      ),
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

  const FullVRVideoView({Key? key, required this.remoteRenderer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hide the system UI when entering VR mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      body: GestureDetector(
        onDoubleTap: () {
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
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure video fills the box
                  ),
                ),
                // Right Eye View
                SizedBox(
                  width: halfWidth,
                  height: constraints.maxHeight,
                  child: RTCVideoView(
                    remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, // Ensure video fills the box
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
        onDoubleTap: () {
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
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                      SizedBox(
                        width: quarterWidth,
                        height: constraints.maxHeight,
                        child: RTCVideoView(
                          remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                      SizedBox(
                        width: quarterWidth,
                        height: constraints.maxHeight,
                        child: RTCVideoView(
                          remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
        onDoubleTap: () {
          // Restore the system UI when exiting VR mode
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          Navigator.pop(context);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final halfWidth = constraints.maxWidth / 2;
            final pipSize =
                constraints.maxWidth / 5; // Adjust the size of the PiP view here

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
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                      Positioned(
                        right: 20.0,
                        bottom: 20.0,
                        width: pipSize,
                        height: pipSize,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: RTCVideoView(
                            pipRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                      Positioned(
                        right: 20.0,
                        bottom: 20.0,
                        width: pipSize,
                        height: pipSize,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: RTCVideoView(
                            pipRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
