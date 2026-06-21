
---

### 💻 Ang Upgraded "Notta AI" Style Code (`main.dart`)

Ito ang upgraded code kung saan may hiwalay na **AI Tab** para sa Chat/Q&A sa iyong transkripsyon. I-paste ito sa iyong `lib/main.dart`:

```dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
// I-import ang opisyal na Google Gemini SDK
import 'package:google_generative_ai/google_generative_ai.dart'; 

void main() {
  runApp(const ChoyNotesApp());
}

class ChoyNotesApp extends StatelessWidget {
  const ChoyNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChoyNotes AI Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8), // Notta Blue
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
  
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _aiQueryController = TextEditingController();
  
  String _finalizedText = ""; 
  String _interimText = "";   
  String _aiResponse = ""; // Dito lalabas ang sagot ng AI
  bool _isAiLoading = false;

  List<Map<String, String>> _savedNotes = []; 
  Timer? _recordingTimer;
  int _secondsRecorded = 0;

  // ⚠️ ILAGAY ANG IYONG GEMINI API KEY DITO
  final String _geminiApiKey = "PALITAN_ITO_NG_IYONG_API_KEY";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadNotes();
  }

  // --- AI LOGIC (ASK GEMINI) ---
  void _askAI(String contextText, String userQuestion) async {
    if (_geminiApiKey == "PALITAN_ITO_NG_IYONG_API_KEY" || _geminiApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Mangyaring ilagay muna ang iyong Gemini API Key sa code.')),
      );
      return;
    }

    if (contextText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walang text o transkripsyon na pwedeng suriin ang AI.')),
      );
      return;
    }

    setState(() {
      _isAiLoading = true;
      _aiResponse = "Nag-iisip ang AI...";
    });

    try {
      // Gagamit tayo ng pinakabagong mabilis at matalinong model ng Google
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      
      // Gagawa tayo ng "System Prompt" para utusan ang AI kung paano sasagutin ang note mo
      final prompt = """
Ikaw ay si ChoyNotes AI, isang matalinong katulong sa transkripsyon. 
Ito ang nilalaman ng aking note o transkripsyon:
\"\"\"
$contextText
\"\"\"

Batay sa transkripsyon sa itaas, sagutin ang tanong na ito ng user nang malinaw at direkta sa Tagalog/English:
$userQuestion
""";

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      setState(() {
        _aiResponse = response.text ?? "Paumanhin, hindi ko nakuha ang sagot.";
      });
    } catch (e) {
      setState(() {
        _aiResponse = "Nagkaroon ng error sa pagkonekta sa AI: $e";
      });
    } finally {
      setState(() {
        _isAiLoading = false;
      });
    }
  }

  // --- COPIED NOTTA RECORDER LOGIC ---
  void _startTimer() {
    _secondsRecorded = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsRecorded++);
    });
  }

  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _initAndStartSpeech() async {
    bool available = await _speech.initialize(
      onError: (val) {
        if (_shouldBeListening) _startListeningLoop();
      },
      onStatus: (status) {
        if (status == 'notListening' && _shouldBeListening) {
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
          _textController.text = _finalizedText.isEmpty ? _interimText : "$_finalizedText $_interimText";
          _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
        });
      },
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
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
      }
    } else {
      _recordingTimer?.cancel();
      setState(() {
        _isListening = false;
        _shouldBeListening = false;
        if (_interimText.isNotEmpty) _finalizedText = "$_finalizedText $_interimText".trim();
        _textController.text = _finalizedText;
      });
      await _speech.stop();
      if (_textController.text.trim().isNotEmpty) _saveNote();
    }
  }

  void _saveNote() async {
    String txt = _textController.text.trim();
    if (txt.isEmpty) return;
    String timestamp = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    String durationStr = _formatDuration(_secondsRecorded == 0 ? 5 : _secondsRecorded);

    setState(() {
      _savedNotes.insert(0, {'text': txt, 'date': timestamp, 'duration': durationStr});
    });
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
            loaded.add({'date': parts[0], 'duration': parts[1], 'text': parts.sublist(2).join('|')});
          }
        }
        setState(() => _savedNotes = loaded);
      }
    } catch (e) {
      print(e);
    }
  }

  // Pinindot ang isang lumang recording para buksan sa editor/AI analyzer
  void _openNoteToAnalyze(Map<String, String> note) {
    setState(() {
      _textController.text = note['text'] ?? '';
      _finalizedText = note['text'] ?? '';
      _aiResponse = "Nakahanda na ang note. Magtanong ka sa AI sa ibaba tungkol sa transkripsyon na ito.";
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _textController.dispose();
    _aiQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Gagawa tayo ng 2 tabs: Transcribe & AI Assistant
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text('ChoyNotes AI Pro', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.mic), text: "Transcribe"),
              Tab(icon: Icon(Icons.psychology), text: "AI Assistant"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: TRANSCRIBER & LIST ---
            Column(
              children: [
                if (_isListening)
                  Container(
                    color: Colors.amber.shade50,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.circle, color: Colors.red, size: 12),
                        const SizedBox(width: 8),
                        Text('Live Transcribing: ${_formatDuration(_secondsRecorded)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      readOnly: _isListening,
                      decoration: const InputDecoration(hintText: "Magsalita o pumili ng transkripsyon sa ibaba...", border: InputBorder.none),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(alignment: Alignment.centerLeft, child: Text('History (Tap to open/analyze)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                ),
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: _savedNotes.length,
                    itemBuilder: (context, index) {
                      final item = _savedNotes[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          onTap: () => _openNoteToAnalyze(item),
                          title: Text(item['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text("${item['date']} • ${item['duration']}"),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: _listen,
                      backgroundColor: _isListening ? Colors.red : const Color(0xFF1A73E8),
                      child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white),
                    ),
                  ),
                )
              ],
            ),

            // --- TAB 2: AI Q&A ASSISTANT (KAYANG SAGUTIN ANG NOTES) ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Dito ipapakita ang sagot ng AI
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Sagot ng AI:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 16)),
                            const Divider(),
                            _isAiLoading 
                              ? const Center(child: CircularProgressIndicator())
                              : Text(_aiResponse.isEmpty ? "Wala pang tanong. Mag-type sa ibaba para magtanong tungkol sa iyong note." : _aiResponse, style: const TextStyle(fontSize: 15, height: 1.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mabilisang Utos/Prompts gaya ng Notta
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _askAI(_textController.text, "Ibahagi sa akin ang maikling buod (summary) ng transkripsyon na ito at lagyan ng bullet points."),
                        icon: const Icon(Icons.summarize),
                        label: const Text("I-Summary"),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _askAI(_textController.text, "Ano ang mga mahahalagang 'Action Items' o mga kailangang gawin batay sa note na ito?"),
                        icon: const Icon(Icons.task_alt),
                        label: const Text("Action Items"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Custom Question input field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _aiQueryController,
                          decoration: InputDecoration(
                            hintText: "May tanong ka ba sa note na ito?",
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF1A73E8)),
                        onPressed: () {
                          if (_aiQueryController.text.trim().isNotEmpty) {
                            _askAI(_textController.text, _aiQueryController.text.trim());
                            _aiQueryController.clear();
                          }
                        },
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
