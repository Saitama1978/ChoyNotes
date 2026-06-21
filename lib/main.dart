import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const ChoyNotesApp());
}

class ChoyNotesApp extends StatelessWidget {
  const ChoyNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChoyNotes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterialDesign: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "Pindutin ang mic sa ibaba para magsimulang mag-record...";
  List<String> _savedNotes = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadNotes();
  }

  void _listen() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kailangan ng permiso sa Mic para mag-record.')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _saveNote() async {
    if (_text.isNotEmpty && _text != "Pindutin ang mic sa ibaba para magsimulang mag-record...") {
      setState(() {
        _savedNotes.add(_text);
        _text = "Pindutin ang mic sa ibaba para magsimulang mag-record...";
      });
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notes.txt');
      await file.writeAsString(_savedNotes.join('\n---\n'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Na-save na ang iyong note!')),
      );
    }
  }

  void _loadNotes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notes.txt');
      if (await file.exists()) {
        String contents = await file.readAsString();
        setState(() {
          _savedNotes = contents.split('\n---\n').where((s) => s.trim().isNotEmpty).toList();
        });
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChoyNotes - AI Recorder', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _text,
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveNote,
                icon: const Icon(Icons.save),
                label: const Text('I-save ang Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Mga Na-save na Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            flex: 3,
            child: _savedNotes.isEmpty
                ? const Center(child: Text('Wala pang na-save na notes.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _savedNotes.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 2,
                        child: ListTile(
                          title: Text(_savedNotes[index]),
                          leading: const Icon(Icons.note, color: Colors.blueAccent),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        onPressed: _listen,
        backgroundColor: _isListening ? Colors.red : Colors.blueAccent,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 36),
      ),
    );
  }
}
