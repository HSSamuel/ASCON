import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  // Streams for UI updates
  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;

  Future<String?> startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 50);
      
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _recorder.start(const RecordConfig(), path: path);
      return path;
    }
    return null;
  }

  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  Future<void> play(String url) async {
    if (url.startsWith('http')) {
      await _player.play(UrlSource(url));
    } else {
      await _player.play(DeviceFileSource(url));
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}