import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_quill/flutter_quill.dart' as quill;

Future<void> _requestPermissions() async {
  await Permission.microphone.request();
  await Permission.storage.request();
}

class GeofenceStream {
  final StreamController<GeofenceEvent> _controller =
      StreamController.broadcast();

  Stream<GeofenceEvent> get stream => _controller.stream;

  void addEvent(GeofenceEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}

class GeofenceEvent {
  final String geofenceId;
  final GeofenceStatus status;

  GeofenceEvent({required this.geofenceId, required this.status});
}

// ignore: constant_identifier_names
enum GeofenceStatus { ENTER, EXIT, DWELL }

final GeofenceStream geofenceStream = GeofenceStream();

void setupGeofence() {
  geofenceStream.stream.listen((GeofenceEvent event) {
    if (event.geofenceId == 'Walmart' && event.status == GeofenceStatus.ENTER) {
      showNotification("You're near Walmart! Don't forget your shopping list.");
    }
  });

  geofenceStream.addEvent(
      GeofenceEvent(geofenceId: 'Walmart', status: GeofenceStatus.ENTER));
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GeofenceService geofenceService = GeofenceService.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();
  setupGeofence();
  runApp(MyApp());
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInitSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

Future<void> showNotification(String message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'shopping_channel', // Unique ID
    'Shopping Reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
      0, 'Reminder', message, platformDetails);
}

Future<void> setupGeofenc() async {
  bool locationGranted = await _checkLocationPermissions();
  if (!locationGranted) {
    debugPrint("Location permission not granted. Geofencing disabled.");
    return;
  }

  geofenceService.setup(
    interval: 5000,
    accuracy: 100,
  );

  geofenceService.addGeofence(
    Geofence(
      id: 'Walmart',
      latitude: 37.7749,
      longitude: -122.4194,
      radius: [GeofenceRadius(id: 'default', length: 500)],
    ),
  );

  geofenceService.onGeofenceStatusChanged.listen((Geofence geofence) {
    final String geofenceId = geofence.id;

    if (geofenceId == 'Walmart') {
      showNotification(
          "You're near Saravana Stores! Don't forget your shopping list.");
    }
  });

  geofenceService.start();
}

extension on GeofenceService {
  get onGeofenceStatusChanged => null;
}

Future<bool> _checkLocationPermissions() async {
  bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    debugPrint("Location services are disabled.");
    return false;
  }
  geo.LocationPermission permission = await geo.Geolocator.checkPermission();
  // ignore: unrelated_type_equality_checks
  if (permission == LocationPermission.denied) {
    permission = await geo.Geolocator.requestPermission();
    // ignore: unrelated_type_equality_checks
    if (permission == LocationPermission.denied) {
      debugPrint("Location permissions denied.");
      return false;
    }
  }

  // ignore: unrelated_type_equality_checks
  if (permission == LocationPermission.deniedForever) {
    debugPrint("Location permissions are permanently denied.");
    return false;
  }

  return true;
}

Future<geo.Position?> _getUserLocation() async {
  bool serviceEnabled;
  geo.LocationPermission permission;

  serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    debugPrint("Location services are disabled.");
    return null;
  }

  permission = await geo.Geolocator.checkPermission();
  if (permission == geo.LocationPermission.denied) {
    permission = await geo.Geolocator.requestPermission();
    if (permission == geo.LocationPermission.denied) {
      debugPrint("Location permissions are denied.");
      return null;
    }
  }

  if (permission == geo.LocationPermission.deniedForever) {
    debugPrint("Location permissions are permanently denied.");
    return null;
  }

  return await geo.Geolocator.getCurrentPosition(
    desiredAccuracy: geo.LocationAccuracy.high,
  );
}

void getSupermarkets() async {
  geo.Position? position = await _getUserLocation();
  if (position != null) {
    List<Map<String, dynamic>> supermarkets =
        await fetchNearbySupermarkets(position.latitude, position.longitude);

    if (supermarkets.isNotEmpty) {
      for (var market in supermarkets) {
        debugPrint(
            "Found supermarket: ${market['name']} at ${market['latitude']}, ${market['longitude']}");
      }
    } else {
      debugPrint("No supermarkets found nearby.");
    }
  }
}

Future<List<Map<String, dynamic>>> fetchNearbySupermarkets(
    double lat, double lng) async {
  final radius = 1000; // 1km radius

  final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=$radius&type=supermarket&key=AIzaSyDYl3Z60Fl245bhWttO14V5SL0SeqX12s8");

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    List results = data['results'];
    return results.map((place) {
      return {
        'id': place['place_id'],
        'name': place['name'],
        'latitude': place['geometry']['location']['lat'],
        'longitude': place['geometry']['location']['lng'],
      };
    }).toList();
  } else {
    debugPrint("Error fetching supermarkets");
    return [];
  }
}

Future<void> setupDynamicGeofence() async {
  geo.Position? position = await _getUserLocation();
  if (position == null) return;

  List<Map<String, dynamic>> supermarkets =
      await fetchNearbySupermarkets(position.latitude, position.longitude);

  if (supermarkets.isEmpty) {
    debugPrint("No supermarkets found nearby.");
    return;
  }

  for (var market in supermarkets) {
    geofenceService.addGeofence(
      Geofence(
        id: market['id'],
        latitude: market['latitude'],
        longitude: market['longitude'],
        radius: [GeofenceRadius(id: 'default', length: 500)],
      ),
    );
  }

  geofenceService.onGeofenceStatusChanged.listen((Geofence geofence) {
    showNotification(
        "You're near ${geofence.id}! Don't forget your shopping list.");
  });

  geofenceService.start();
}

void mainn() async {
  runApp(MyApp());
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyBDmha6biWexeghJsivR63_GyWH8z87wM4",
            authDomain: "fire-setup-916d9.firebaseapp.com",
            projectId: "fire-setup-916d9",
            storageBucket: "fire-setup-916d9.firebasestorage.app",
            messagingSenderId: "885602301277",
            appId: "1:885602301277:web:62de7f53673ff9cfa824b4",
            measurementId: "G-PQ5SXG66E0"));
  } else {
    await Firebase.initializeApp();
  }
}

void mainnnn() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes App',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: LoginPage(),
    );
  }
}

class VoiceRecorder extends StatefulWidget {
  const VoiceRecorder({super.key});

  @override
  _VoiceRecorderState createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  late FlutterSoundRecorder _recorder;
  late FlutterSoundPlayer _player;

  bool isRecording = false;
  String? filePath;

  @override
  @override
  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await _player.openPlayer();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
  }

  Future<void> _startRecording() async {
    Directory dir = await getApplicationDocumentsDirectory();
    filePath = '${dir.path}/note_audio.aac';
    try {
      await _recorder.startRecorder(toFile: filePath);
      setState(() => isRecording = true);
    } catch (e) {
      print("Error starting recorder: $e");
    }
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() => isRecording = false);
  }

  Future<void> _playRecording() async {
    if (filePath != null) {
      await _player.startPlayer(fromURI: filePath!);
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: isRecording ? _stopRecording : _startRecording,
          icon: Icon(isRecording ? Icons.stop : Icons.mic, color: Colors.white),
          label: Text(
            isRecording ? "Stop Recording" : "Start Recording",
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isRecording ? Colors.red : Colors.blue,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _playRecording,
          icon: Icon(Icons.play_arrow, color: Colors.white),
          label: Text(
            "Play Recording",
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class LoginPage extends StatelessWidget {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginPage({super.key});

  void _login(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => NotesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/mainback2.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Smart Notes',
                style: TextStyle(
                  fontFamily: 'Verdana',
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              _buildTextField(_usernameController, 'Username', Icons.person),
              SizedBox(height: 16),
              _buildTextField(_passwordController, 'Password', Icons.lock,
                  obscureText: true),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _login(context),
                child: Text(
                  'Login',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black),
        labelText: hint,
        filled: true,
        fillColor: Colors.transparent, // Keep the background transparent
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black, width: 2), // Black border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.black, width: 2), // Black border when enabled
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.black, width: 2), // Black border when focused
        ),
        labelStyle:
            TextStyle(color: Colors.black), // Change label color to black
      ),
    );
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final List<Note> notes = [];
  final List<Note> completedNotes = [];
  final List<Note> recentlyDeletedNotes = [];

  void _addNote(String content) {
    setState(() {
      notes.add(
          Note(date: DateTime.now(), content: content, isCompleted: false));
    });
  }

  void _deleteNote(int index) {
    setState(() {
      recentlyDeletedNotes.add(notes[index]);
      notes.removeAt(index);
    });
  }

  void _recoverNote(int index) {
    setState(() {
      notes.add(recentlyDeletedNotes[index]);
      recentlyDeletedNotes.removeAt(index);
    });
  }

  void _modifyNote(int index, String newContent) {
    setState(() {
      notes[index] = Note(
          date: DateTime.now(),
          content: newContent,
          isCompleted: notes[index].isCompleted);
    });
  }

  void _toggleCompleted(int index) {
    setState(() {
      notes[index].isCompleted = !notes[index].isCompleted;
      if (notes[index].isCompleted) {
        completedNotes.add(notes[index]);
        notes.removeAt(index);
      }
    });
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Notes', style: TextStyle(color: Colors.black)),
          backgroundColor: Color(0xFF9BA7AF),
          actions: [
            IconButton(
              icon: Icon(Icons.logout, color: Colors.black),
              onPressed: _logout,
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.black,
            tabs: [
              Tab(text: "All Notes"),
              Tab(text: "Completed"),
              Tab(text: "Recently Deleted"),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _buildNotesList(notes, false),
                  _buildNotesList(completedNotes, true),
                  _buildDeletedNotesList(),
                ],
              ),
            ),
            VoiceRecorder(), // Adding the voice recorder at the bottom
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.black,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AddNotePage(onSave: _addNote)),
            );
          },
          child: Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildNotesList(List<Note> noteList, bool isCompletedTab) {
    return noteList.isEmpty
        ? Center(
            child: Text('No Notes Yet', style: TextStyle(color: Colors.black)))
        : ListView.builder(
            itemCount: noteList.length,
            itemBuilder: (context, index) {
              return NoteItem(
                note: noteList[index],
                onDelete: isCompletedTab ? null : () => _deleteNote(index),
                onModify:
                    isCompletedTab ? null : () => _showModifyDialog(index),
                onToggleComplete: () => _toggleCompleted(index),
              );
            },
          );
  }

  Widget _buildDeletedNotesList() {
    return recentlyDeletedNotes.isEmpty
        ? Center(
            child: Text('No Recently Deleted Notes',
                style: TextStyle(color: Colors.black)))
        : ListView.builder(
            itemCount: recentlyDeletedNotes.length,
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  title: Text(recentlyDeletedNotes[index].content),
                  subtitle: Text(
                      "Deleted on ${recentlyDeletedNotes[index].date.toLocal()}"),
                  trailing: IconButton(
                    icon: Icon(Icons.restore, color: Colors.green),
                    onPressed: () => _recoverNote(index),
                  ),
                ),
              );
            },
          );
  }

  void _showModifyDialog(int index) {
    TextEditingController controller =
        TextEditingController(text: notes[index].content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modify Note'),
        content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new note content')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              _modifyNote(index, controller.text);
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}

class Note {
  final DateTime date;
  final String content;
  bool isCompleted;

  Note({required this.date, required this.content, this.isCompleted = false});
}

class NoteItem extends StatelessWidget {
  final Note note;
  final VoidCallback? onDelete;
  final VoidCallback? onModify;
  final VoidCallback onToggleComplete;

  const NoteItem({
    required this.note,
    this.onDelete,
    this.onModify,
    required this.onToggleComplete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: Checkbox(
          value: note.isCompleted,
          onChanged: (_) => onToggleComplete(),
        ),
        title: Text(note.content, style: TextStyle(fontSize: 18)),
        subtitle: Text("Added on ${note.date.toLocal()}"),
        trailing: Wrap(
          spacing: 8,
          children: [
            if (onModify != null)
              IconButton(
                  icon: Icon(Icons.edit, color: Colors.green),
                  onPressed: onModify),
            if (onDelete != null)
              IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class AddNotePage extends StatefulWidget {
  final Function(String) onSave;

  const AddNotePage({super.key, required this.onSave});

  @override
  _AddNotePageState createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final quill.QuillController _controller = quill.QuillController.basic();

  void _saveNote() {
    final String noteContent = _controller.document.toPlainText().trim();
    if (noteContent.isNotEmpty) {
      widget.onSave(noteContent);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Note"),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            quill.QuillToolbar.simple(
              configurations: quill.QuillSimpleToolbarConfigurations(
                controller: _controller,
                multiRowsDisplay: false,
                showDividers: true,
                showFontSize: true,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showListCheck: true,
                showHeaderStyle: true,
                showListBullets: true,
                showListNumbers: true,
                showCodeBlock: true,
                showQuote: true,
                showUndo: true,
                showRedo: true,
              ),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: quill.QuillEditor(
                  focusNode: FocusNode(),
                  scrollController: ScrollController(),
                  configurations: quill.QuillEditorConfigurations(
                    controller: _controller,
                    padding: EdgeInsets.zero,
                    autoFocus: true,
                    scrollable: true,
                    expands: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveNote,
        child: Icon(Icons.save),
        tooltip: "Save Note",
      ),
    );
  }
}
