import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const ChoyNotesApp());
}

class ChoyNotesApp extends StatelessWidget {
  const ChoyNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChoyNotes',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MeetingRecorderScreen(),
    );
  }
}

class MeetingRecorderScreen extends StatefulWidget {
  const MeetingRecorderScreen({super.key});

  @override
  State<MeetingRecorderScreen> createState() => _MeetingRecorderScreenState();
}

class _MeetingRecorderScreenState extends State<MeetingRecorderScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "Pindutin ang Mic sa ibaba para magsimulang mag-record ng meeting...";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestPermission();
  }

  void _requestPermission() async {
    await Permission.microphone.request();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChoyNotes 🎙️'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _text,
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton.extended(
                  onPressed: _listen,
                  label: Text(_isListening ? 'Listening...' : 'Record Meeting'),
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  backgroundColor: _isListening ? Colors.red : Colors.blue,
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to ChoyNotes History!')),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Note'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
