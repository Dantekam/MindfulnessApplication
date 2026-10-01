import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final String exerciseTitle;
  final String audioUrl;

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseTitle,
    required this.audioUrl,
  });

  @override
  ExerciseDetailScreenState createState() => ExerciseDetailScreenState();
}

class ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isAudioReady = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudioPlayer();
  }

  void _initializeAudioPlayer() async {
    try {
      await _audioPlayer.setUrl(widget.audioUrl);
      if (mounted) {
        setState(() {
          _isAudioReady = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      setState(() {
        _isPlaying = false;
      });
      _audioPlayer.pause();
    } else {
      setState(() {
        _isPlaying = true;
      });
      _audioPlayer.play();
    }
  }

  void _rewind10() {
    final newPosition = _audioPlayer.position - const Duration(seconds: 10);
    _audioPlayer.seek(
      newPosition > Duration.zero ? newPosition : Duration.zero,
    );
  }

  void _forward10() {
    final newPosition = _audioPlayer.position + const Duration(seconds: 10);
    final maxDuration = _audioPlayer.duration ?? Duration.zero;
    _audioPlayer.seek(newPosition < maxDuration ? newPosition : maxDuration);
  }

  void _seekTo(double value) {
    final position = Duration(seconds: value.toInt());
    _audioPlayer.seek(position);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.exerciseTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF607D8B),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF607D8B), Color(0xFF455A64)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10 seconds button
                  IconButton(
                    icon: const Icon(
                      Icons.replay_10,
                      color: Colors.white,
                      size: 36,
                    ),
                    onPressed: _isAudioReady ? _rewind10 : null,
                  ),

                  // Play/Pause button
                  ElevatedButton(
                    onPressed: _isAudioReady ? _togglePlayPause : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF607D8B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(80, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),

                  // Forward 10 seconds button
                  IconButton(
                    icon: const Icon(
                      Icons.forward_10,
                      color: Colors.white,
                      size: 36,
                    ),
                    onPressed: _isAudioReady ? _forward10 : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              StreamBuilder<Duration>(
                stream: _audioPlayer.positionStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  final position = snapshot.data ?? Duration.zero;
                  final duration = _audioPlayer.duration ?? Duration.zero;

                  return Column(
                    children: [
                      Slider(
                        min: 0.0,
                        max: duration.inSeconds.toDouble(),
                        value: position.inSeconds.toDouble().clamp(
                          0.0,
                          duration.inSeconds.toDouble(),
                        ),
                        onChanged: _seekTo,
                        activeColor: Colors.blue,
                        inactiveColor: Colors.white70,
                      ),
                      Text(
                        '${position.toString().split('.').first} / ${duration.toString().split('.').first}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
