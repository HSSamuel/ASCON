import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ascon_mobile/services/api_client.dart';
import 'package:audio_session/audio_session.dart';

// ✅ Added volumeChanged to trigger instant UI rebuilds for neon borders
enum CallEvent { ringing, connected, callEnded, error, userJoined, userOffline, volumeChanged }

class CallService with WidgetsBindingObserver {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  late RtcEngine _engine;
  bool _isInitialized = false;
  bool isJoined = false;
  bool _isVideo = false; 
  
  Set<int> remoteUids = {}; 
  Set<int> activeSpeakers = {}; 

  final _callEventController = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get callEvents => _callEventController.stream;

  RtcEngine get engine => _engine; 

  Future<void> init() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      await [
        Permission.microphone, 
        Permission.camera,
        Permission.systemAlertWindow, 
        Permission.ignoreBatteryOptimizations
      ].request();
    }

    String appId = dotenv.env['AGORA_APP_ID'] ?? '';
    if (appId.isEmpty) {
      debugPrint("❌ Agora App ID is missing from env.txt");
      return;
    }

    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: appId,
        logConfig: const LogConfig(level: LogLevel.logLevelError),
      ),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("✅ Agora Joined Channel: ${connection.channelId}");
          isJoined = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("📞 Remote user answered! UID: $remoteUid");
          remoteUids.add(remoteUid); 
          _callEventController.add(CallEvent.connected);
          _callEventController.add(CallEvent.userJoined);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("📞 Remote user left! UID: $remoteUid");
          remoteUids.remove(remoteUid); 
          _callEventController.add(CallEvent.callEnded);
          _callEventController.add(CallEvent.userOffline);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("❌ Agora Error: $err - $msg");
          _callEventController.add(CallEvent.error);
        },
        // ✅ Tracks who is speaking to light up their neon border
        onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
          Set<int> currentSpeakers = {};
          for (var speaker in speakers) {
            // Lowered threshold to 3 to catch subtle speaking accurately
            if (speaker.volume != null && speaker.volume! > 3) {
              currentSpeakers.add(speaker.uid ?? 0);
            }
          }
          activeSpeakers = currentSpeakers;
          _callEventController.add(CallEvent.volumeChanged); 
        },
      ),
    );

    await _engine.enableAudio();
    
    // ✅ Tells Agora to report volume levels every 200ms
    await _engine.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);
    
    _isInitialized = true;

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized || !isJoined) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isVideo) {
        _engine.muteLocalVideoStream(true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isVideo) {
        _engine.muteLocalVideoStream(false);
      }
    }
  }

  Future<bool> joinCall({required String channelName, bool isVideo = false, int uid = 0}) async {
    if (!_isInitialized) await init();
    _isVideo = isVideo; 

    try {
      final response = await ApiClient().post('/api/agora/token', {'channelName': channelName, 'uid': uid});
      final responseData = response['data'] ?? response;

      if (responseData['token'] != null) {
        String token = responseData['token'];

        if (isVideo) {
           await _engine.enableVideo();
           await _engine.startPreview();
        } else {
           await _engine.disableVideo();
        }

        await _engine.joinChannel(
          token: token,
          channelId: channelName,
          uid: uid, 
          options: ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            channelProfile: ChannelProfileType.channelProfileCommunication,
            publishCameraTrack: isVideo, 
            publishMicrophoneTrack: true, 
          ),
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> leaveCall() async {
    if (isJoined) {
      try {
        await _engine.stopPreview(); 
      } catch (_) {}
      await _engine.leaveChannel();
      remoteUids.clear(); 
      activeSpeakers.clear(); 
      isJoined = false;
      _isVideo = false;
    }
  }

  Future<void> toggleMute(bool isMuted) async {
    if (_isInitialized) await _engine.muteLocalAudioStream(isMuted);
  }

  Future<void> toggleSpeaker(bool isSpeakerOn) async {
    if (_isInitialized) await _engine.setEnableSpeakerphone(isSpeakerOn);
  }

  Future<List<AudioDeviceInfo>> getPlaybackDevices() async {
    if (!_isInitialized) return [];
    try {
      return await _engine.getAudioDeviceManager().enumeratePlaybackDevices();
    } catch (e) {
      debugPrint("Error fetching audio devices: $e");
      return [];
    }
  }

  Future<void> setPlaybackDevice(String deviceId) async {
    if (!_isInitialized) return;
    try {
      await _engine.getAudioDeviceManager().setPlaybackDevice(deviceId);
      debugPrint("✅ Audio routed to device: $deviceId");
    } catch (e) {
      debugPrint("Error setting playback device: $e");
    }
  }

  Future<void> setAudioRoute(String route) async {
    if (!_isInitialized) return;

    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS)) {
        if (route == 'Speaker') {
          await _engine.setEnableSpeakerphone(true);
        } else {
          await _engine.setEnableSpeakerphone(false);
        }
        return; 
      }

      final session = await AudioSession.instance;

      if (route == 'Speaker') {
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.videoChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
        await _engine.setEnableSpeakerphone(true);
      } 
      else if (route == 'Earpiece') {
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
        await _engine.setEnableSpeakerphone(false);
      } 
      else if (route == 'Bluetooth') {
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth, 
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
        await _engine.setEnableSpeakerphone(false);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error setting native audio route: $e");
      }
    }
  }

  Future<void> toggleVideo(bool isVideoOff) async {
    if (_isInitialized) {
      await _engine.muteLocalVideoStream(isVideoOff);
    }
  }

  Future<void> switchCamera() async {
    if (_isInitialized) {
      await _engine.switchCamera();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}