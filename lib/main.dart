import 'dart:io';
import 'dart:async';
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
      title: 'ChoyNotes AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8), // Notta Blue Accent
          background: const Color(0xFFF8F9FA),
        ),
        useMaterial3: true,
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
  bool _shouldBeListening = false;
  
  // Controller para sa real-time text input
  final TextEditingController _textController = TextEditingController();
  
  // Real-time storage para hindi mawala ang data (Notta Auto-Save style)
  String _finalizedText = ""; 
  String _interimText = "";   
  
  List<Map<String, String>> _savedNotes = []; // May kasamang Date/Time at Duration

  // Timer para sa duration tracker ng Notta
  Timer? _recordingTimer;
  int _secondsRecorded = 0;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadNotes();
  }

  // Timer logic gaya ng Notta
  void _startTimer() {
    _secondsRecorded = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsRecorded++;
      });
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _initAndStartSpeech() async {
    bool available = await _speech.initialize(
      onError: (val) {
        print('onError: $val');
        // Kung nag-timeout ang engine loop pero aktibo pa ang record, buhayin ulit gaya ng Notta
        if (_shouldBeListening) _startListeningLoop();
      },
      onStatus: (status) {
        print('onStatus: $status');
        if (status == 'notListening' && _shouldBeListening) {
          // I-commit ang huling narinig bago mag-restart ang bagong loop
          if (_interimText.isNotEmpty) {
            _finalizedText = "$_finalizedText $_interimText".trim();
            _interimText = "";
          }
          _startListeningLoop();
        }
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _shouldBeListening = true;
      });
      _startTimer();
      _startListeningLoop();
    }
  }

  void _startListeningLoop() async {
    if (!_shouldBeListening) return;

    await _speech.listen(
      onResult: (val) {
        setState(() {
          _interimText = val.recognizedWords;
          
          // Ipakita ang pinagsamang luma at bagong naririnig sa screen ng real-time
          if (_finalizedText.isEmpty) {
            _textController.text = _interimText;
          } else {
            _textController.text = "$_finalizedText $_interimText";
          }

          // I-scroll ang cursor sa pinakadulo gaya ng auto-scroll ng Notta
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length)
          );
        });
      },
      listenFor: const Duration(hours: 1), // Ituloy ang session hanggang isang oras
      pauseFor: const Duration(seconds: 4),  // Mabilis mag-segment ng sentences para malinis ang pagkakadugtong
      partialResults: true,
      listenMode: stt.ListenMode.dictation, // Naka-optimize para sa tuloy-tuloy na pagdidikta
    );
  }

  void _listen() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        _textController.clear();
        _finalizedText = "";
        _interimText = "";
        _initAndStartSpeech();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kailangan ng permiso sa Mic para mag-record.')),
        );
      }
    } else {
      _stopListeningAndLock();
    }
  }

  void _stopListeningAndLock() async {
    _stopTimer();
    setState(() {
      _isListening = false;
      _shouldBeListening = false;
      // Pagsamahin ang natitirang text sa memory
      if (_interimText.isNotEmpty) {
        _finalizedText = "$_finalizedText $_interimText".trim();
      }
      _textController.text = _finalizedText;
    });
    await _speech.stop();
    
    // Auto-save agad pagka-stop para siguradong ligtas ang transcription (Notta Style)
    if (_textController.text.trim().isNotEmpty) {
      _saveNote();
    }
  }

  void _saveNote() async {
    String txt = _textController.text.trim();
    if (txt.isEmpty) return;

    String timestamp = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    String durationStr = _formatDuration(_secondsRecorded == 0 ? 5 : _secondsRecorded);

    setState(() {
      _savedNotes.insert(0, {
        'text': txt,
        'date': timestamp,
        'duration': durationStr,
      });
      _textController.clear();
      _finalizedText = "";
      _interimText = "";
    });

    // Isulat sa File JSON para mas madaling i-parse ang Metadata ng Notta app
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/notta_notes.txt');
    
    List<String> rawLines = _savedNotes.map((n) => "${n['date']}|${n['duration']}|${n['text']}").toList();
    await file.writeAsString(rawLines.join('\n===\n'));
  }

  void _loadNotes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notta_notes.txt');
      if (await file.exists()) {
        String contents = await file.readAsString();
        if (contents.trim().isEmpty) return;
        
        List<String> blocks = contents.split('\n===\n');
        List<Map<String, String>> loaded = [];
        
        for (var block in blocks) {
          var parts = block.split('|');
          if (parts.length >= 3) {
            loaded.add({
              'date': parts[0],
              'duration': parts[1],
              'text': parts.sublist(2).join('|'), 
            });
          }
        }
        setState(() {
          _savedNotes = loaded;
        });
      }
    } catch (e) {
      print("Error loading notes: $e");
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('ChoyNotes AI', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // UI Kapag nagre-record (Notta Live Board UI)
          if (_isListening)
            Container(
              color: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Transcribing Live: ${_formatDuration(_secondsRecorded)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ],
              ),
            ),

          // Main Transcription Editor Box
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _isListening ? Colors.blueAccent.withOpacity(0.5) : Colors.transparent, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: TextField(
                controller: _textController,
                maxLines: null,
                readOnly: _isListening, // Pwedeng i-manual edit ng user kapag naka-pause ang mic gaya ng Notta
                style: const TextStyle(fontSize: 17, height: 1.6, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: _isListening ? "Nagsisimula nang makinig..." : "Pindutin ang Mic sa ibaba para mag-transcribe...",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Recent Recordings / Transcripts (Notta Style List)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Mga Transkripsyon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
          ),
          
          Expanded(
            flex: 3,
            child: _savedNotes.isEmpty
                ? const Center(child: Text('Walang nakaimbak na transkripsyon.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _savedNotes.length,
                    itemBuilder: (context, index) {
                      final item = _savedNotes[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(item['text'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 12, color: Colors.black38),
                                const SizedBox(width: 4),
                                Text(item['date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                const SizedBox(width: 16),
                                const Icon(Icons.timer_outlined, size: 14, color: Colors.black38),
                                const SizedBox(width: 4),
                                Text(item['duration'] ?? '00:00', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Central control button bar (Notta Signature UI)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _listen,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.red : const Color(0xFF1A73E8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : const Color(0xFF1A73E8)).withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
