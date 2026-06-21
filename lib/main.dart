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
        useMaterial3: true, // Inayos mula sa useMaterialDesign
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
  bool _shouldBeListening = false; // Flag para sa tuloy-tuloy na pakikinig
  
  // Gagamit tayo ng controller para sa Text Field para mas madaling dugtungan ang sulat
  final TextEditingController _textController = TextEditingController(
    text: "Pindutin ang mic sa ibaba para magsimulang mag-record..."
  );
  
  String _previousText = ""; // Lalagyan ng lumang text habang nagsasalita
  List<String> _savedNotes = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadNotes();
  }

  void _initAndStartSpeech() async {
    bool available = await _speech.initialize(
      onError: (val) => print('onError: $val'),
      onStatus: (status) {
        print('onStatus: $status');
        // KUNG KUSA SYANG NAG-STOP TAHIMIK ANG USER:
        // Pero gusto pa rin natin makinig (_shouldBeListening), i-restart ang mic
        if (status == 'notListening' && _shouldBeListening) {
          _startListeningLoop();
        }
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _shouldBeListening = true;
      });
      _startListeningLoop();
    }
  }

  void _startListeningLoop() async {
    if (!_shouldBeListening) return;

    // Kunin ang kasalukuyang nakasulat para hindi mabura kapag may bagong narinig
    _previousText = _textController.text;
    if (_previousText == "Pindutin ang mic sa ibaba para magsimulang mag-record...") {
      _previousText = "";
    }

    await _speech.listen(
      onResult: (val) => setState(() {
        if (_previousText.isEmpty) {
          _textController.text = val.recognizedWords;
        } else {
          // DUGTONG LOGIC: Lumang sinabi + space + bagong narinig
          _textController.text = "$_previousText ${val.recognizedWords}";
        }
        
        // I-move ang cursor sa dulo para laging kita ang sinusulat
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length)
        );
      }),
      listenFor: const Duration(minutes: 5), // Makikinig nang hanggang 5 minuto
      pauseFor: const Duration(seconds: 10), // 10 seconds na pause bago mag-refresh ang engine loop
      partialResults: true,
    );
  }

  void _listen() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        if (_textController.text == "Pindutin ang mic sa ibaba para magsimulang mag-record...") {
          _textController.clear();
        }
        _initAndStartSpeech();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kailangan ng permiso sa Mic para mag-record.')),
        );
      }
    } else {
      setState(() {
        _isListening = false;
        _shouldBeListening = false;
      });
      _speech.stop();
    }
  }

  void _saveNote() async {
    String currentText = _textController.text.trim();
    if (currentText.isNotEmpty && currentText != "Pindutin ang mic sa ibaba para magsimulang mag-record...") {
      setState(() {
        _savedNotes.add(currentText);
        _textController.text = "Pindutin ang mic sa ibaba para magsimulang mag-record...";
      });
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notes.txt');
      await file.writeAsString(_savedNotes.join('\n---\n'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Na-save na ang iyong note!')),
        );
      }
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
  void dispose() {
    _textController.dispose();
    super.dispose();
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(50),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              ),
              // Pinalitan ng TextField para pwedeng i-scroll at i-edit gamit ang keyboard kung gusto mo
              child: TextField(
                controller: _textController,
                maxLines: null,
                minLines: 10,
                readOnly: _isListening, // Bawal muna i-type kapag nagsasalita para walang conflict
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),
          ),
          
          // Listahan ng Saved Notes sa ibaba
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _savedNotes.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(_savedNotes[index], maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Note #${index + 1}'),
                  ),
                );
              },
            ),
          ),
          
          // Mga Buttons sa pinakababa
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, left: 16, right: 16),
            boxShadow: const [],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  onPressed: _listen,
                  backgroundColor: _isListening ? Colors.red : Colors.blueAccent,
                  child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                ),
                FloatingActionButton(
                  onPressed: _saveNote,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.save, color: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
