import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  runApp(const ChoyNotesApp());
}

class ChoyNotesApp extends StatefulWidget {
  const ChoyNotesApp({super.key});

  @override
  State<ChoyNotesApp> createState() => _ChoyNotesAppState();
}

class _ChoyNotesAppState extends State<ChoyNotesApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChoyNotes Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          brightness: Brightness.dark, // Pinanatiling Dark Mode gaya ng screenshot mo
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
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
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _aiQueryController = TextEditingController();

  String _finalizedText = "";
  String _interimText = "";
  String _aiResponse = "";
  bool _isAiLoading = false;

  String _selectedCategory = 'General';
  final List<String> _categories = ['General', 'School', 'Work', 'Personal'];
  List<Map<String, String>> _savedNotes = [];
  List<Map<String, String>> _filteredNotes = [];

  // ⚠️ ILAGAY ANG IYONG GEMINI API KEY DITO
  final String _geminiApiKey = "PALITAN_ITO_NG_IYONG_API_KEY";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadNotes();
    _searchController.addListener(_filterNotes);
  }

  void _filterNotes() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = List.from(_savedNotes);
      } else {
        _filteredNotes = _savedNotes.where((note) {
          return (note['text'] ?? '').toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // --- AI LOGIC ---
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
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final prompt = """
Ikaw ay si ChoyNotes AI, isang matalinong katulong sa transkripsyon. 
Ito ang nilalaman ng aking note:
\"\"\"
$contextText
\"\"\"

Batay sa transkripsyon sa itaas, sagutin ang tanong ng user sa Tagalog/English:
$userQuestion
""";

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      setState(() {
        _aiResponse = response.text ?? "Paumanhin, hindi ko nakuha ang sagot.";
      });
    } catch (e) {
      setState(() {
        _aiResponse = "Error sa AI: $e";
      });
    } finally {
      setState(() {
        _isAiLoading = false;
      });
    }
  }

  // --- NOTTA CONTINUOUS SPEECH LOGIC ---
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
      setState(() {
        _isListening = false;
        _shouldBeListening = false;
        if (_interimText.isNotEmpty) _finalizedText = "$_finalizedText $_interimText".trim();
        _textController.text = _finalizedText;
      });
      await _speech.stop();
    }
  }

  void _saveNote() async {
    String txt = _textController.text.trim();
    if (txt.isEmpty) return;

    setState(() {
      _savedNotes.insert(0, {
        'text': txt,
        'category': _selectedCategory,
        'date': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"
      });
      _filteredNotes = List.from(_savedNotes);
      _textController.clear();
      _finalizedText = "";
      _interimText = "";
    });

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/choynotes_pro.txt');
    List<String> rawLines = _savedNotes.map((n) => "${n['category']}|${n['date']}|${n['text']}").toList();
    await file.writeAsString(rawLines.join('\n===\n'));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Na-save na ang iyong note!')),
    );
  }

  void _loadNotes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/choynotes_pro.txt');
      if (await file.exists()) {
        String contents = await file.readAsString();
        if (contents.trim().isEmpty) return;
        List<String> blocks = contents.split('\n===\n');
        List<Map<String, String>> loaded = [];
        for (var block in blocks) {
          var parts = block.split('|');
          if (parts.length >= 3) {
            loaded.add({'category': parts[0], 'date': parts[1], 'text': parts.sublist(2).join('|')});
          }
        }
        setState(() {
          _savedNotes = loaded;
          _filteredNotes = List.from(_savedNotes);
        });
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    _aiQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // DITO INILAGAY ANG TAB CONTROLLER PARA MAGKAROON NG TAB 1 AT TAB 2
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ChoyNotes Pro', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF0F172A),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.wb_sunny, color: Colors.white),
              onPressed: () {}, // Theme switch placeholder mula sa screenshot mo
            ),
          ],
          // Heto ang navigation sa ilalim ng title para makalipat sa AI Tab
          bottom: const TabBar(
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(icon: Icon(Icons.mic), text: "Transcribe"),
              Tab(icon: Icon(Icons.psychology), text: "AI Assistant"),
            ],
          ),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text("Program by: Renante Fullo", style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
            
            // Dito naghahati ang Screen sa dalawang magkaibang Tab view
            Expanded(
              child: TabBarView(
                children: [
                  
                  // ================= TAB 1: TRANSCRIBE (ANG DESIGN MO SA SCREENSHOT) =================
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Dropdown Category
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Select Category:", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500)),
                              DropdownButton<String>(
                                value: _selectedCategory,
                                dropdownColor: const Color(0xFF1E293B),
                                items: _categories.map((String value) {
                                  return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(color: Colors.white)));
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedCategory = newValue!;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Input/Transcription Box gaya ng nasa screenshot mo
                          Container(
                            height: 180,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white60),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextField(
                              controller: _textController,
                              maxLines: null,
                              readOnly: _isListening,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "Magsimulang mag-record...",
                                hintStyle: TextStyle(color: Colors.white38),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _saveNote,
                              icon: const Icon(Icons.bookmark, color: Colors.white),
                              label: const Text("Save Transcript", style: TextStyle(fontSize: 16, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Search Box mula sa screenshot mo
                          TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search, color: Colors.white60),
                              hintText: "Search notes...",
                              hintStyle: const TextStyle(color: Colors.white38),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white60)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // List of Saved Notes
                          _filteredNotes.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.only(top: 40.0),
                                  child: Text("No notes found.", style: TextStyle(color: Colors.white38)),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredNotes.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredNotes[index];
                                    return Card(
                                      color: const Color(0xFF1E293B),
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      child: ListTile(
                                        title: Text(item['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                                        subtitle: Text("${item['category']} • ${item['date']}", style: const TextStyle(color: Colors.white60)),
                                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white60),
                                        onTap: () {
                                          setState(() {
                                            _textController.text = item['text'] ?? '';
                                            _finalizedText = item['text'] ?? '';
                                            _aiResponse = "Naka-load na ang note. Lumipat sa AI Assistant Tab para magtanong.";
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),

                  // ================= TAB 2: AI ASSISTANT (ANG BAGONG NOTTA AI FEATURE) =================
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Sagot ng AI:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 16)),
                                  const Divider(color: Colors.white24),
                                  _isAiLoading 
                                    ? const Center(child: Padding(padding: EdgeInsets.only(top: 20), child: CircularProgressIndicator()))
                                    : Text(_aiResponse.isEmpty ? "Pumili ng note o mag-transcribe muna, pagkatapos ay magtanong ka rito sa AI." : _aiResponse, style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _askAI(_textController.text, "Ibigay ang buod ng transkripsyon na ito gamit ang maikling bullet points."),
                              icon: const Icon(Icons.summarize),
                              label: const Text("I-Summary"),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _askAI(_textController.text, "Ano ang mga kailangang gawin o Action Items batay rito?"),
                              icon: const Icon(Icons.task_alt),
                              label: const Text("Action Items"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _aiQueryController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Magtanong sa AI tungkol sa iyong note...",
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  fillColor: const Color(0xFF1E293B),
                                  filled: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.blueAccent),
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
            
            // Ang Mic button sa pinakababa mula sa iyong screenshot
            Container(
              padding: const EdgeInsets.only(bottom: 24),
              color: const Color(0xFF0F172A),
              child: Center(
                child: GestureDetector(
                  onTap: _listen,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black25, blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Icon(_isListening ? Icons.stop : Icons.mic, size: 30, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
