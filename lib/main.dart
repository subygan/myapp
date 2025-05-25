import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Music Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MusicPlayerHomePage(),
    );
  }
}

class MusicPlayerHomePage extends StatefulWidget {
  const MusicPlayerHomePage({super.key});

  @override
  State<MusicPlayerHomePage> createState() => _MusicPlayerHomePageState();
}

class _MusicPlayerHomePageState extends State<MusicPlayerHomePage> {
  String? selectedDirectoryPath;
  List<String> audioFiles = [];
  String? currentPlayingFile;
  String? currentPlayingFileName;
  bool isPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _fileListingError;
  bool _isLoadingFiles = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
          if (state == PlayerState.stopped || state == PlayerState.completed) {
            // Check if stop was due to an error or natural completion
            // For this example, we'll just reset. A more robust solution
            // might involve checking an error stream or specific error states
            // if the audioplayers plugin provides them directly in PlayerState.
            currentPlayingFile = null;
            currentPlayingFileName = null;
            _position = Duration.zero;
            // If it was an error, _duration might also need reset or specific handling
          }
        });
      }
    });

    _audioPlayer.onPlayerError.listen((String? errorMsg) {
      if (mounted && errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Audio Player Error: $errorMsg"))
        );
        setState(() {
          isPlaying = false;
          currentPlayingFile = null;
          currentPlayingFileName = null;
          _position = Duration.zero;
          _duration = Duration.zero;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((Duration d) {
      if (mounted) {
        setState(() => _duration = d);
      }
    });

    _audioPlayer.onPositionChanged.listen((Duration d) {
      if (mounted) {
        setState(() => _position = d);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playFile(String filePath) async {
    try {
      await _audioPlayer.stop(); // Stop any current playback
      await _audioPlayer.play(DeviceFileSource(filePath));
      if (mounted) {
        setState(() {
          currentPlayingFile = filePath;
          currentPlayingFileName = filePath.split('/').last;
          isPlaying = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error playing file: ${filePath.split('/').last}. Unsupported format or file not found."))
        );
        setState(() {
          isPlaying = false;
          currentPlayingFile = null;
          currentPlayingFileName = null;
        });
      }
    }
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
    if (mounted) {
      setState(() {
        isPlaying = false;
      });
    }
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        isPlaying = false;
        currentPlayingFile = null;
        currentPlayingFileName = null;
        _position = Duration.zero;
      });
    }
  }

  void _listAudioFiles(String directoryPath) {
    setState(() {
      _isLoadingFiles = true;
      _fileListingError = null; // Clear previous error
    });
    final List<String> supportedExtensions = ['.mp3', '.m4a', '.wav', '.aac', '.ogg'];
    List<String> foundFiles = [];
    try {
      final dir = Directory(directoryPath);
      final List<FileSystemEntity> entities = dir.listSync(); // Can be slow for large dirs
      for (var entity in entities) {
        if (entity is File) {
          final String filePath = entity.path;
          final String extension = filePath.substring(filePath.lastIndexOf('.')).toLowerCase();
          if (supportedExtensions.contains(extension)) {
            foundFiles.add(filePath);
          }
        }
      }
      setState(() {
        audioFiles = foundFiles;
        _isLoadingFiles = false;
      });
    } on FileSystemException catch (e) {
      print('Error listing audio files: $e');
      setState(() {
        _fileListingError = 'Error listing files: ${e.message}';
        audioFiles.clear();
        _isLoadingFiles = false;
      });
    }
  }

  Future<void> _selectDirectory() async {
    try {
      String? directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath != null) {
        setState(() {
          selectedDirectoryPath = directoryPath;
          audioFiles.clear();
          currentPlayingFile = null;
          currentPlayingFileName = null;
          _fileListingError = null; // Clear error on new selection
        });
        _listAudioFiles(directoryPath);
      } else {
        // User cancelled the picker
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Directory selection cancelled."))
          );
        }
      }
    } catch (e) {
      // Handle potential exceptions from FilePicker itself, though less common
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking directory: $e"))
        );
      }
      print("Error picking directory: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Music Player'),
      ),
      body: Column(
        children: <Widget>[
          // Directory Selection Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selectedDirectoryPath == null
                    ? 'No directory selected. Please pick a directory.'
                    : 'Selected Directory: $selectedDirectoryPath'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _selectDirectory,
                  child: const Text('Select Directory'),
                ),
                if (_fileListingError != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_fileListingError!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),

          // Audio Files List
          Expanded(
            child: _isLoadingFiles
                ? const Center(child: CircularProgressIndicator())
                : audioFiles.isEmpty
                    ? Center(
                        child: Text(selectedDirectoryPath == null
                            ? 'Select a directory to see audio files.'
                            : 'No audio files (.mp3, .m4a, .wav, .aac, .ogg) found in the selected directory.'),
                      )
                    : ListView.builder(
                        itemCount: audioFiles.length,
                        itemBuilder: (context, index) {
                          final filePath = audioFiles[index];
                          final fileName = filePath.split('/').last;
                          return ListTile(
                            title: Text(fileName),
                            onTap: () => _playFile(filePath),
                            selected: currentPlayingFile == filePath,
                            selectedTileColor: Colors.blue.withOpacity(0.3), // Example color
                          );
                        },
                      ),
          ),

          // Playback Controls Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(currentPlayingFileName == null
                    ? 'Nothing playing'
                    : 'Now Playing: $currentPlayingFileName'),
                Slider(
                  value: _position.inSeconds.toDouble(),
                  min: 0.0,
                  max: _duration.inSeconds.toDouble().isNaN || _duration.inSeconds.toDouble().isInfinite
                      ? 0.0
                      : _duration.inSeconds.toDouble(),
                  onChanged: (value) async {
                    final position = Duration(seconds: value.toInt());
                    await _audioPlayer.seek(position);
                  },
                ),
                Text('${_position.toString().split('.').first} / ${_duration.toString().split('.').first}'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: isPlaying
                          ? null
                          : (currentPlayingFile != null
                              ? () async {
                                  await _audioPlayer.resume();
                                  if (mounted) setState(() => isPlaying = true);
                                }
                              : null),
                    ),
                    IconButton(
                      icon: const Icon(Icons.pause),
                      onPressed: isPlaying ? _pause : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: isPlaying || currentPlayingFile != null ? _stop : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
