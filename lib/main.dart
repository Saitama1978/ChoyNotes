import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() => runApp(MeetingNotesApp());

class MeetingNotesApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MeetingRecorderScreen(),
    );
  }
}

class MeetingRecorderScreen extends StatefulWidget {
  @override
  _MeetingRecorderScreenState createState() => _MeetingRecorderScreenState();
}

class _MeetingRecorderScreenState extends State<MeetingRecorderScreen> {
  stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "Pindutin ang mic para magsimulang mag-record...";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
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
      appBar: AppBar(title: Text('Meeting Auto-Notes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(12),
                border: Border.all(color: Colors.grey),
                child: TextField(
                  maxLines: null,
                  controller: TextEditingController(text: _text),
                  onChanged: (value) => _text = value,
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _listen,
                  child: Text(_isListening ? 'I-stop ang Record' : 'Magsimula Mag-record'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Code para i-save sa database o file
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Na-save na ang notes!')),
                    );
                  },
                  child: Text('I-save ang Notes'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
