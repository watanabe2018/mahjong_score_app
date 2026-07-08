import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'tile_confirm_screen.dart';

class CameraScreen extends StatefulWidget {
  final String password;
  const CameraScreen({super.key, required this.password});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _picker = ImagePicker();
  Uint8List? _previewBytes;
  bool _loading = false;
  String? _error;

  Future<void> _pickAndRecognize(ImageSource source) async {
    setState(() {
      _error = null;
    });
    final XFile? file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _previewBytes = bytes;
      _loading = true;
    });

    try {
      final mediaType = _guessMediaType(file.name);
      final result = await ApiService.recognizeTiles(
        imageBytes: bytes,
        mediaType: mediaType,
        password: widget.password,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TileConfirmScreen(
            initialTileCodes: result.tileCodes,
            recognitionNotes: result.notes,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '予期せぬエラーが発生しました: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _guessMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手牌を撮影')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_previewBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_previewBytes!, height: 220),
                ),
              const SizedBox(height: 24),
              if (_loading) const CircularProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              if (!_loading) ...[
                FilledButton.icon(
                  onPressed: () => _pickAndRecognize(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('写真を撮る'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickAndRecognize(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('アルバムから選ぶ'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TileConfirmScreen(
                        initialTileCodes: [],
                        recognitionNotes: '',
                      ),
                    ),
                  ),
                  child: const Text('写真を使わず手動で入力する'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
