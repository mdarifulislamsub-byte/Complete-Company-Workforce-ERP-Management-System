import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:camera/camera.dart';

Future<void> testFaceNetModel() async {
  try {
    final interpreter = await Interpreter.fromAsset(
      'assets/models/facenet.tflite',
    );
    debugPrint("FaceNet Model Loaded Successfully!");
    debugPrint(
      "Input Shape: ${interpreter.getInputTensor(0).shape}",
    );
    debugPrint(
      "Output Shape: ${interpreter.getOutputTensor(0).shape}",
    );
    interpreter.close();
  } catch (e) {
    debugPrint("FaceNet Model Load Error: $e");
  }
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await testFaceNetModel();
  await loadEmployeesFromFirestore();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SBM Attendance',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.indigo,
      ),
      home: const LoginPage(),
    );
  }
}

class Employee {
  String id, name, fin, designation, workPermit;
  String? password;
  File? profileImage;
  String? profileImageUrl;
  // Face recognition data
  List<double>? faceEmbedding;
  bool isRegistered = false;
  String role = 'worker';

  Map<String, bool> permissions = {
    'allEmployee': false,
    'myAttendance': true,
    'history': false,
    'tools': false,
    'material': false,
    'dailyProgress': false,
    'settings': false,
    'help': true,
    'addEmployee': false,
    'managePermissions': false,
  };
  Employee(
      this.id,
      this.name,
      this.fin,
      this.designation,
      this.workPermit,
      );
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'fin': fin,
      'designation': designation,
      'workPermit': workPermit,
      'password': password,
      'profileImageUrl': profileImageUrl,
      'faceEmbedding': faceEmbedding,
      'isRegistered': isRegistered,
      'role': role,
      'permissions': permissions,
    };
  }
}
Map<String, bool> getDefaultPermissions(String role) {
  switch (role) {
    case 'admin':
      return {
        'allEmployee': true,
        'myAttendance': true,
        'history': true,
        'tools': true,
        'material': true,
        'dailyProgress': true,
        'settings': true,
        'help': true,
        'addEmployee': true,
        'managePermissions': true,
      };

    case 'manager':
      return {
        'allEmployee': true,
        'myAttendance': true,
        'history': true,
        'tools': true,
        'material': true,
        'dailyProgress': true,
        'settings': false,
        'help': true,
        'addEmployee': true,
        'managePermissions': true,
      };

    case 'supervisor':
      return {
        'allEmployee': true,
        'myAttendance': true,
        'history': true,
        'tools': true,
        'material': true,
        'dailyProgress': true,
        'settings': false,
        'help': true,
        'addEmployee': false,
        'managePermissions': false,
      };

    case 'worker':
    default:
      return {
        'allEmployee': false,
        'myAttendance': true,
        'history': false,
        'tools': false,
        'material': false,
        'dailyProgress': false,
        'settings': false,
        'help': true,
        'addEmployee': false,
        'managePermissions': false,
      };
  }
}

List<Employee> globalEmployeeList = [
  Employee("M-355", "MD ARIFUL ISLAM SAJIB", "F1234567N", "Developer", "WP12345"),
];

List<Map<String, dynamic>> attendanceHistory = [];
Future<void> saveEmployeeToFirestore(Employee employee) async {
  try {
    await FirebaseFirestore.instance
        .collection('employees')
        .doc(employee.id)
        .set(employee.toFirestore());

    debugPrint('Employee saved successfully: ${employee.id}');
  } catch (e) {
    debugPrint('Employee save error: $e');
  }
}
Future<void> loadEmployeesFromFirestore() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('employees')
        .get();

    final List<Employee> loadedEmployees = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final employee = Employee(
        data['id'] ?? '',
        data['name'] ?? '',
        data['fin'] ?? '',
        data['designation'] ?? '',
        data['workPermit'] ?? '',
      );

      employee.password = data['password'];
      employee.profileImageUrl = data['profileImageUrl'];
      employee.role = data['role'] ?? 'worker';

      if (data['permissions'] != null) {
        employee.permissions = Map<String, bool>.from(
          (data['permissions'] as Map).map(
                (key, value) => MapEntry(
              key.toString(),
              value == true,
            ),
          ),
        );
      }

      if (data['faceEmbedding'] != null) {
        employee.faceEmbedding =
            (data['faceEmbedding'] as List)
                .map((e) => (e as num).toDouble())
                .toList();
      }

      employee.isRegistered =
          data['isRegistered'] ?? false;

      loadedEmployees.add(employee);
    }

    if (loadedEmployees.isNotEmpty) {
      globalEmployeeList = loadedEmployees;
    }

    debugPrint(
      'Employees loaded successfully: ${globalEmployeeList.length}',
    );
  } catch (e) {
    debugPrint('Employee load error: $e');
  }
}
// --- LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  void _login() {
    String inputId = _idController.text.trim();
    String inputPass = _passController.text.trim();

    if (inputId == "M-355" && inputPass == "123456") {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardPage(adminName: "MD ARIFUL ISLAM SAJIB")));
      return;
    }

    try {
      Employee user = globalEmployeeList.firstWhere((emp) => emp.id == inputId);
      if (user.isRegistered && user.password == inputPass) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardPage(adminName: user.name, userImg: user.profileImage,currentUser: user,)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Password or Not Registered!"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee ID not found!"), backgroundColor: Colors.red));
    }
  }

  void _goToRegistration() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFFF5F5F5)],
            stops: [0.35, 0.35],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.all(30.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 25)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("WELCOME TO ATTENDANCE",
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        const Text("SBM MARINE & ENGINEERING PTE.LTD.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 35),
                        const Text("User Login", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                        const SizedBox(height: 25),
                        buildTextField("Employee ID", Icons.person, "Enter user id", _idController),
                        const SizedBox(height: 20),
                        buildTextField("Password", Icons.lock, "Enter password", _passController, isPass: true),
                        const SizedBox(height: 35),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("LOGIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Forgot password ?", style: TextStyle(color: Colors.indigo, fontSize: 13)),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("|", style: TextStyle(color: Colors.grey))),
                            Text("Forms & Documents", style: TextStyle(color: Colors.indigo, fontSize: 13)),
                          ],
                        ),
                        const Divider(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: _goToRegistration,
                              child: const Text("Registration", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                            GestureDetector(
                              onTap: _goToRegistration,
                              child: const Text("Create New ID", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              width: double.infinity,
              color: Colors.white,
              child: const Text(
                "Developer : MD ARIFUL ISLAM SAJIB  Only test for Software Developed @ 2026",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(String label, IconData icon, String hint, TextEditingController controller, {bool isPass = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPass,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.indigo),
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8F9FE),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigo, width: 2)),
          ),
        ),
      ],
    );
  }
}

// --- SCANNER PAGE (CAMERA & BIO DATA) ---
class AttendanceScannerPage extends StatefulWidget {
  const AttendanceScannerPage({super.key});

  @override
  State<AttendanceScannerPage> createState() => _AttendanceScannerPageState();
}

class _AttendanceScannerPageState extends State<AttendanceScannerPage> {
  File? _scannedImage;
  Employee? _matchedUser;
  bool _isLoading = false;
  double _matchingScore = 0.0;
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _isProcessingFrame = false;
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _cameraInitialized = true;
      });

      await Future.delayed(
        const Duration(milliseconds: 800),
      );

      if (mounted) {
        _scanFaceAutomatically();
      }
    } catch (e) {
      debugPrint("Camera Initialization Error: $e");
    }
  }
  Future<void> _saveAttendanceScan(Employee employee) async {
    final DateTime now = DateTime.now();

    final String dateKey =
    DateFormat('yyyy-MM-dd').format(now);

    final String documentId =
        '${employee.id}_$dateKey';

    final DocumentReference<Map<String, dynamic>> docRef =
    FirebaseFirestore.instance
        .collection('attendance')
        .doc(documentId);

    final doc = await docRef.get();

    final int currentMinutes =
        (now.hour * 60) + now.minute;

    // 06:00 AM
    const int inStart = 6 * 60;

    // 11:30 AM
    const int inEnd = (11 * 60) + 30;

    // 12:00 PM
    const int outStart = 12 * 60;

    // ================= IN TIME =================
    if (currentMinutes >= inStart &&
        currentMinutes <= inEnd) {

      if (!doc.exists ||
          doc.data()?['inTime'] == null) {

        await docRef.set({
          'employeeId': employee.id,
          'name': employee.name,
          'fin': employee.fin,
          'designation': employee.designation,
          'workPermit': employee.workPermit,

          'date': dateKey,

          'inTime': Timestamp.fromDate(now),

          'outTime': null,

          'actualHours': '0',
          'accountedHours': '0',

          'status': 'Present',
          'type': 'Auto',
          'remarks': '',

          'timestamp':
          FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
          "IN TIME SAVED: ${employee.id} - $now",
        );
      }

      return;
    }

    // ================= OUT TIME =================
    if (currentMinutes >= outStart) {

      await docRef.set({
        'employeeId': employee.id,
        'name': employee.name,
        'fin': employee.fin,
        'designation': employee.designation,
        'workPermit': employee.workPermit,

        'date': dateKey,

        'outTime': Timestamp.fromDate(now),

        'status': 'Present',
        'type': 'Auto',

        'timestamp':
        FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        "OUT TIME SAVED: ${employee.id} - $now",
      );

      return;
    }

    debugPrint(
      "Attendance scan ignored: "
          "11:31 AM - 11:59 AM",
    );
  }
  Future<void> _scanFaceAutomatically() async {
    if (_isProcessingFrame) return;

    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final XFile photo =
      await _cameraController!.takePicture();

      final File imageFile = File(photo.path);

      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _scannedImage = imageFile;
        _matchedUser = null;
        _matchingScore = 0.0;
      });

      final scannedEmbedding =
      await _generateFaceEmbedding(imageFile);

      if (scannedEmbedding == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _scannedImage = null;
        });

        _isProcessingFrame = false;

        await Future.delayed(
          const Duration(milliseconds: 700),
        );

        if (mounted) {
          _scanFaceAutomatically();
        }

        return;
      }

      Employee? bestEmployee;
      double bestSimilarity = -1.0;

      double cosineSimilarity(
          List<double> a,
          List<double> b,
          ) {
        if (a.length != b.length) {
          return -1.0;
        }

        double dotProduct = 0.0;
        double normA = 0.0;
        double normB = 0.0;

        for (int i = 0; i < a.length; i++) {
          dotProduct += a[i] * b[i];
          normA += a[i] * a[i];
          normB += b[i] * b[i];
        }

        if (normA == 0 || normB == 0) {
          return -1.0;
        }

        return dotProduct /
            (sqrt(normA) * sqrt(normB));
      }

      for (final emp in globalEmployeeList) {
        if (!emp.isRegistered ||
            emp.faceEmbedding == null) {
          continue;
        }

        final similarity = cosineSimilarity(
          scannedEmbedding,
          emp.faceEmbedding!,
        );

        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestEmployee = emp;
        }
      }

      const double matchThreshold = 0.75;

      if (bestEmployee != null &&
          bestSimilarity >= matchThreshold) {
        if (!mounted) return;
        await _saveAttendanceScan(bestEmployee);

        setState(() {
          _matchedUser = bestEmployee;
          _matchingScore =
              (bestSimilarity * 100)
                  .clamp(0.0, 100.0);
          _isLoading = false;
        });

        _isProcessingFrame = false;
        return;
      }

      if (!mounted) return;

      setState(() {
        _matchedUser = null;
        _matchingScore = 0.0;
        _isLoading = false;
        _scannedImage = null;
      });

      _isProcessingFrame = false;

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (mounted) {
        _scanFaceAutomatically();
      }
    } catch (e) {
      debugPrint(
        "Automatic Face Scan Error: $e",
      );

      _isProcessingFrame = false;

      if (!mounted) return;

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (mounted) {
        _scanFaceAutomatically();
      }
    }
  }
  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
  Future<List<double>?> _generateFaceEmbedding(File imageFile) async {
    FaceDetector? faceDetector;
    Interpreter? interpreter;

    try {
      final inputImage = InputImage.fromFile(imageFile);

      faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint("No face detected");
        return null;
      }

      if (faces.length != 1) {
        debugPrint("More than one face detected");
        return null;
      }

      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        debugPrint("Image decode failed");
        return null;
      }

      originalImage = img.bakeOrientation(originalImage);

      final faceBox = faces.first.boundingBox;

      int x = faceBox.left.floor();
      int y = faceBox.top.floor();
      int width = faceBox.width.ceil();
      int height = faceBox.height.ceil();

      final extraX = (width * 0.15).round();
      final extraY = (height * 0.15).round();

      x -= extraX;
      y -= extraY;
      width += extraX * 2;
      height += extraY * 2;

      x = x.clamp(0, originalImage.width - 1).toInt();
      y = y.clamp(0, originalImage.height - 1).toInt();

      width = width.clamp(1, originalImage.width - x).toInt();
      height = height.clamp(1, originalImage.height - y).toInt();

      final croppedFace = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      final resizedFace = img.copyResize(
        croppedFace,
        width: 160,
        height: 160,
      );

      final input = List.generate(
        1,
            (_) => List.generate(
          160,
              (yy) => List.generate(
            160,
                (xx) {
              final pixel = resizedFace.getPixel(xx, yy);

              return [
                (pixel.r.toDouble() - 127.5) / 128.0,
                (pixel.g.toDouble() - 127.5) / 128.0,
                (pixel.b.toDouble() - 127.5) / 128.0,
              ];
            },
          ),
        ),
      );

      interpreter = await Interpreter.fromAsset(
        'assets/models/facenet.tflite',
      );

      final output = [
        List<double>.filled(128, 0.0),
      ];

      interpreter.run(input, output);

      debugPrint(
        "Scanner Face Embedding Generated: ${output[0].length}",
      );

      return List<double>.from(output[0]);
    } catch (e) {
      debugPrint("Scanner Face Embedding Error: $e");
      return null;
    } finally {
      faceDetector?.close();
      interpreter?.close();
    }
  }

  Future<void> _openCamera() async {
    final ImagePicker picker = ImagePicker();

    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 90,
    );

    if (photo == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _scannedImage = File(photo.path);
      _matchedUser = null;
      _matchingScore = 0.0;
    });

    try {
      // Attendance-এর নতুন Face থেকে 128-value embedding তৈরি
      final scannedEmbedding =
      await _generateFaceEmbedding(_scannedImage!);

      if (scannedEmbedding == null) {
        setState(() {
          _isLoading = false;
          _scannedImage = null;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Face could not be detected!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Employee? bestEmployee;
      double bestSimilarity = -1.0;

      // Cosine similarity
      double cosineSimilarity(
          List<double> a,
          List<double> b,
          ) {
        if (a.length != b.length) {
          return -1.0;
        }

        double dotProduct = 0.0;
        double normA = 0.0;
        double normB = 0.0;

        for (int i = 0; i < a.length; i++) {
          dotProduct += a[i] * b[i];
          normA += a[i] * a[i];
          normB += b[i] * b[i];
        }

        if (normA == 0 || normB == 0) {
          return -1.0;
        }

        return dotProduct /
            (sqrt(normA) * sqrt(normB));
      }

      // সব Registered Employee-এর face-এর সাথে compare
      for (final emp in globalEmployeeList) {
        if (!emp.isRegistered ||
            emp.faceEmbedding == null) {
          continue;
        }

        final similarity = cosineSimilarity(
          scannedEmbedding,
          emp.faceEmbedding!,
        );

        debugPrint(
          "Face Compare ${emp.id}: $similarity",
        );

        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestEmployee = emp;
        }
      }

      // প্রথমে 75% threshold দিয়ে test
      const double matchThreshold = 0.75;

      if (bestEmployee != null &&
          bestSimilarity >= matchThreshold) {
        await FirebaseFirestore.instance
            .collection('attendance')
            .add({
          'employeeId': bestEmployee.id,
          'name': bestEmployee.name,
          'fin': bestEmployee.fin,
          'designation': bestEmployee.designation,
          'workPermit': bestEmployee.workPermit,
          'status': 'Present',
          'type': 'Face Scan',
          'similarity': bestSimilarity,
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          _matchedUser = bestEmployee;
          _matchingScore =
              (bestSimilarity * 100).clamp(0.0, 100.0);
          _isLoading = false;
        });

        debugPrint(
          "MATCHED EMPLOYEE: ${bestEmployee.id} "
              "Score: ${_matchingScore.toStringAsFixed(2)}%",
        );
      } else {
        setState(() {
          _matchedUser = null;
          _matchingScore = 0.0;
          _isLoading = false;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Face Not Recognized!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Attendance Face Matching Error: $e");

      setState(() {
        _isLoading = false;
        _matchedUser = null;
        _matchingScore = 0.0;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Face matching failed!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmAttendance() {
    if (_matchedUser != null) {
      setState(() {
        attendanceHistory.insert(0, {
          "date": DateFormat('dd/MM/yyyy').format(DateTime.now()),
          "id": _matchedUser!.id,
          "name": _matchedUser!.name,
          "in": DateFormat('h:mm a').format(DateTime.now()),
          "out": "Pending",
          "status": "PRESENT"
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ATTENDANCE SUCCESSFUL!"), backgroundColor: Colors.green)
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Scanner"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_matchedUser == null) ...[
                  const Text(
                    "FACE RECOGNITION",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Look directly at the camera",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (!_cameraInitialized ||
                      _cameraController == null ||
                      !_cameraController!.value.isInitialized)
                    const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Container(
                      width: 300,
                      height: 380,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.blue,
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: CameraPreview(
                          _cameraController!,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          "Scanning Face...",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text(
                      "Face scanning automatically...",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],

                if (_matchedUser != null) ...[
                  const Icon(
                    Icons.verified,
                    size: 70,
                    color: Colors.green,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "FACE RECOGNIZED",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      maxWidth: 500,
                    ),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "EMPLOYEE BIO-DATA",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.indigo,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          "Match Score: ${_matchingScore.toStringAsFixed(2)}%",
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const Divider(height: 30),

                        _bioRow(
                          "Name:",
                          _matchedUser!.name,
                        ),

                        _bioRow(
                          "Employee ID:",
                          _matchedUser!.id,
                        ),

                        _bioRow(
                          "Designation:",
                          _matchedUser!.designation,
                        ),

                        _bioRow(
                          "FIN Number:",
                          _matchedUser!.fin,
                        ),

                        _bioRow(
                          "Work Permit:",
                          _matchedUser!.workPermit,
                        ),

                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _confirmAttendance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "CONFIRM ATTENDANCE",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bioRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), Text(value)],
      ),
    );
  }
}

// --- ATTENDANCE REPORT PAGE ---
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  int appliedYear = DateTime.now().year;
  int appliedMonth = DateTime.now().month;
  String selectedEmployeeId = 'ALL';
  String appliedEmployeeId = 'ALL';

  final List<String> monthNames = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),

      appBar: AppBar(
        title: const Text(
          "Attendance Report",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Column(
        children: [

          // ================= TOP MENU =================
          Container(
            height: 55,
            color: const Color(0xFF000080),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [

                  _topMenuButton(
                    "Administration",
                    Icons.admin_panel_settings,
                  ),

                  _topMenuButton(
                    "Report",
                    Icons.assessment,
                  ),

                  PopupMenuButton<String>(
                    color: Colors.white,
                    onSelected: (value) {
                      if (value == 'all') {
                        // Already on All Attendance Report
                      }

                      if (value == 'individual') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Individual Attendance will be connected next.",
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'individual',
                        child: Text("Individual Attendance"),
                      ),
                      PopupMenuItem(
                        value: 'all',
                        child: Text("All Attendance Report"),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fact_check,
                            color: Colors.white,
                            size: 17,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Attendance",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),

                  _topMenuButton(
                    "Application",
                    Icons.description,
                  ),

                  _topMenuButton(
                    "Approval",
                    Icons.approval,
                  ),
                ],
              ),
            ),
          ),

          // ================= BREADCRUMB =================
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 14,
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.home,
                  color: Colors.indigo,
                  size: 18,
                ),
                SizedBox(width: 7),
                Text(
                  "Home",
                  style: TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7),
                  child: Text("/"),
                ),
                Text(
                  "Attendance",
                  style: TextStyle(color: Colors.grey),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7),
                  child: Text("/"),
                ),
                Text(
                  "All Attendance Report",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ================= BODY =================
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .orderBy(
                'timestamp',
                descending: true,
              )
                  .snapshots(),

              builder: (context, snapshot) {

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error: ${snapshot.error}",
                    ),
                  );
                }

                final allDocs =
                    snapshot.data?.docs ?? [];

                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data();

                  final Timestamp? timestamp =
                  data['timestamp'] as Timestamp?;

                  if (timestamp == null) {
                    return false;
                  }

                  final date = timestamp.toDate();

                  return date.year == appliedYear &&
                      date.month == appliedMonth;
                }).toList();

                final int totalDays =
                    DateTime(appliedYear, appliedMonth + 1, 0).day;

                final List<Map<String, dynamic>> monthRows = [];

                for (int dayNumber = 1;
                dayNumber <= totalDays;
                dayNumber++) {

                  final DateTime currentDate =
                  DateTime(
                    appliedYear,
                    appliedMonth,
                    dayNumber,
                  );

                  Map<String, dynamic>? attendanceData;

                  for (final doc in filteredDocs) {
                    final data = doc.data();

                    final Timestamp? timestamp =
                    data['timestamp'] as Timestamp?;

                    if (timestamp == null) {
                      continue;
                    }

                    final DateTime attendanceDate =
                    timestamp.toDate();

                    if (attendanceDate.year ==
                        currentDate.year &&
                        attendanceDate.month ==
                            currentDate.month &&
                        attendanceDate.day ==
                            currentDate.day) {

                      attendanceData = data;
                      break;
                    }
                  }

                  final bool isSunday =
                      currentDate.weekday ==
                          DateTime.sunday;

                  String inTime = "0";
                  String outTime = "0";
                  String actualHours = "0";
                  String accountedHours = "0";

                  String status =
                  isSunday ? "Holiday" : "Absent";

                  String type = "Auto";
                  String remarks = "";

                  if (attendanceData != null) {
                    final Timestamp? inTimestamp =
                    attendanceData['inTime'] as Timestamp?;

                    final Timestamp? outTimestamp =
                    attendanceData['outTime'] as Timestamp?;

                    if (inTimestamp != null) {
                      inTime = DateFormat('hh:mm a')
                          .format(inTimestamp.toDate());
                    }

                    if (outTimestamp != null) {
                      outTime = DateFormat('hh:mm a')
                          .format(outTimestamp.toDate());
                    }

                    // In + Out দুটো থাকলেই Present
                    if (inTimestamp != null &&
                        outTimestamp != null) {
                      status = "Present";
                    } else {
                      status = isSunday
                          ? "Holiday"
                          : "Absent";
                    }

                    type =
                        attendanceData['type']
                            ?.toString() ??
                            "Auto";
                  }

                  monthRows.add({
                    'date': currentDate,
                    'inTime': inTime,
                    'outTime': outTime,
                    'actualHours': actualHours,
                    'accountedHours':
                    accountedHours,
                    'status': status,
                    'type': type,
                    'remarks': remarks,
                  });
                }

                final Set<String> employeeIds = {};

                int present = 0;
                int absent = 0;
                int late = 0;
                int leave = 0;
                int holiday = 0;

                for (final doc in filteredDocs) {
                  final data = doc.data();

                  final id =
                      data['employeeId']
                          ?.toString() ??
                          '';

                  if (id.isNotEmpty) {
                    employeeIds.add(id);
                  }

                  final status =
                      data['status']
                          ?.toString()
                          .toLowerCase() ??
                          '';

                  if (status == 'present') {
                    present++;
                  } else if (status == 'absent') {
                    absent++;
                  } else if (status == 'late') {
                    late++;
                  } else if (status == 'leave') {
                    leave++;
                  } else if (status == 'holiday') {
                    holiday++;
                  }
                }

                String employeeId = "-";
                String employeeName = "-";

                if (filteredDocs.isNotEmpty) {
                  final firstData =
                  filteredDocs.first.data();

                  employeeId =
                      firstData['employeeId']
                          ?.toString() ??
                          "-";

                  employeeName =
                      firstData['name']
                          ?.toString() ??
                          "-";
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(15),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      const Text(
                        "All Attendance Report",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000080),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // YEAR
                      DropdownButtonFormField<int>(
                        value: selectedYear,
                        decoration:
                        const InputDecoration(
                          labelText: "Year",
                          border:
                          OutlineInputBorder(),
                        ),
                        items: List.generate(
                          8,
                              (index) {
                            final year =
                                DateTime.now().year -
                                    4 +
                                    index;

                            return DropdownMenuItem(
                              value: year,
                              child: Text(
                                year.toString(),
                              ),
                            );
                          },
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedYear = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 15),

                      // MONTH
                      DropdownButtonFormField<int>(
                        value: selectedMonth,
                        decoration:
                        const InputDecoration(
                          labelText: "Month",
                          border:
                          OutlineInputBorder(),
                        ),
                        items: List.generate(
                          12,
                              (index) =>
                              DropdownMenuItem(
                                value: index + 1,
                                child: Text(
                                  monthNames[index],
                                ),
                              ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedMonth = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 15),

// EMPLOYEE
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('employees')
                            .orderBy('id')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];

                          final List<String> employeeIds = [
                            'ALL',
                            ...docs
                                .map(
                                  (doc) => doc.data()['id']?.toString() ?? '',
                            )
                                .where(
                                  (id) => id.isNotEmpty,
                            ),
                          ];

                          return DropdownButtonFormField<String>(
                            value: employeeIds.contains(selectedEmployeeId)
                                ? selectedEmployeeId
                                : 'ALL',
                            decoration: const InputDecoration(
                              labelText: "Employee",
                              border: OutlineInputBorder(),
                            ),
                            items: employeeIds.map((id) {
                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text(id),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedEmployeeId = value;
                                });
                              }
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      // SHOW BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              appliedYear = selectedYear;
                              appliedMonth = selectedMonth;
                              appliedEmployeeId = selectedEmployeeId;
                            });
                          },
                          icon: const Icon(
                            Icons.search,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "SHOW",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                          style:
                          ElevatedButton.styleFrom(
                            backgroundColor:
                            Colors.blue,
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      Text(
                        "${monthNames[appliedMonth - 1]}-$appliedYear",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // SUMMARY
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('employees')
                            .orderBy('id')
                            .snapshots(),
                        builder: (context, employeeSnapshot) {
                          if (employeeSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (employeeSnapshot.hasError) {
                            return Text(
                              "Employee Error: ${employeeSnapshot.error}",
                            );
                          }

                          final allEmployees =
                              employeeSnapshot.data?.docs ?? [];

                          final visibleEmployees =
                          appliedEmployeeId == 'ALL'
                              ? allEmployees
                              : allEmployees.where((doc) {
                            final data = doc.data();

                            return data['id']?.toString() ==
                                appliedEmployeeId;
                          }).toList();

                          if (visibleEmployees.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(30),
                              child: Center(
                                child: Text("No Employee Found"),
                              ),
                            );
                          }

                          return Column(
                            children: visibleEmployees.map((employeeDoc) {
                              final employeeData =
                              employeeDoc.data();

                              final String employeeId =
                                  employeeData['id']?.toString() ??
                                      employeeDoc.id;

                              final String employeeName =
                                  employeeData['name']?.toString() ??
                                      '';

                              final int totalDays = DateTime(
                                appliedYear,
                                appliedMonth + 1,
                                0,
                              ).day;

                              final List<Map<String, dynamic>>
                              employeeMonthRows = [];

                              int presentCount = 0;
                              int absentCount = 0;
                              int holidayCount = 0;

                              for (int dayNumber = 1;
                              dayNumber <= totalDays;
                              dayNumber++) {
                                final DateTime currentDate =
                                DateTime(
                                  appliedYear,
                                  appliedMonth,
                                  dayNumber,
                                );

                                Map<String, dynamic>? attendanceData;

                                for (final doc in allDocs) {
                                  final data = doc.data();

                                  if (data['employeeId']
                                      ?.toString() !=
                                      employeeId) {
                                    continue;
                                  }

                                  final Timestamp? inTimestamp =
                                  data['inTime'] as Timestamp?;

                                  final Timestamp? outTimestamp =
                                  data['outTime'] as Timestamp?;

                                  DateTime? attendanceDate;

                                  if (inTimestamp != null) {
                                    attendanceDate =
                                        inTimestamp.toDate();
                                  } else if (outTimestamp != null) {
                                    attendanceDate =
                                        outTimestamp.toDate();
                                  }

                                  if (attendanceDate == null) {
                                    continue;
                                  }

                                  if (attendanceDate.year ==
                                      currentDate.year &&
                                      attendanceDate.month ==
                                          currentDate.month &&
                                      attendanceDate.day ==
                                          currentDate.day) {
                                    attendanceData = data;
                                    break;
                                  }
                                }

                                final bool isSunday =
                                    currentDate.weekday ==
                                        DateTime.sunday;

                                String inTime = "0";
                                String outTime = "0";
                                String actualHours = "0";
                                String accountedHours = "0";

                                String status =
                                isSunday
                                    ? "Holiday"
                                    : "Absent";

                                String type = "Auto";
                                String remarks = "";

                                if (attendanceData != null) {
                                  final Timestamp? inTimestamp =
                                  attendanceData['inTime']
                                  as Timestamp?;

                                  final Timestamp? outTimestamp =
                                  attendanceData['outTime']
                                  as Timestamp?;

                                  if (inTimestamp != null) {
                                    inTime =
                                        DateFormat('hh:mm a').format(
                                          inTimestamp.toDate(),
                                        );
                                  }

                                  if (outTimestamp != null) {
                                    outTime =
                                        DateFormat('hh:mm a').format(
                                          outTimestamp.toDate(),
                                        );
                                  }

                                  actualHours = "0";
                                  accountedHours = "0";

                                  if (inTimestamp != null && outTimestamp != null) {
                                    final DateTime inDateTime = inTimestamp.toDate();
                                    final DateTime outDateTime = outTimestamp.toDate();

                                    final int inMinutes =
                                        (inDateTime.hour * 60) + inDateTime.minute;

                                    final int outMinutes =
                                        (outDateTime.hour * 60) + outDateTime.minute;

                                    // In Time must be 07:59 AM or earlier
                                    final bool validInTime =
                                        inMinutes <= (7 * 60 + 59);

                                    if (validInTime) {

                                      // ================= MONDAY - THURSDAY =================
                                      if (currentDate.weekday >= DateTime.monday &&
                                          currentDate.weekday <= DateTime.thursday) {

                                        // Early Leave: 11:50 AM - before 05:15 PM
                                        if (outMinutes >= (11 * 60 + 50) &&
                                            outMinutes < (17 * 60 + 15)) {
                                          actualHours = "04.00";
                                          accountedHours = "04.00";
                                        }

                                        // 05:15 PM - before 06:45 PM
                                        else if (outMinutes >= (17 * 60 + 15) &&
                                            outMinutes < (18 * 60 + 45)) {
                                          actualHours = "08.00";
                                          accountedHours = "08.00";
                                        }

                                        // 06:45 PM - before 09:15 PM
                                        else if (outMinutes >= (18 * 60 + 45) &&
                                            outMinutes < (21 * 60 + 15)) {
                                          actualHours = "09.30";
                                          accountedHours = "10.30";
                                        }

                                        // 09:15 PM - before 11:15 PM
                                        else if (outMinutes >= (21 * 60 + 15) &&
                                            outMinutes < (23 * 60 + 15)) {
                                          actualHours = "11.8";
                                          accountedHours = "13.30";
                                        }

                                        // 11:15 PM - Midnight
                                        else if (outMinutes >= (23 * 60 + 15)) {
                                          actualHours = "14.30";
                                          accountedHours = "15.30";
                                        }
                                      }

                                      // ================= FRIDAY =================
                                      else if (currentDate.weekday == DateTime.friday) {

                                        // Early Leave: 11:50 AM - before 04:30 PM
                                        if (outMinutes >= (11 * 60 + 50) &&
                                            outMinutes < (16 * 60 + 30)) {
                                          actualHours = "04.00";
                                          accountedHours = "04.00";
                                        }

                                        // 04:30 PM - before 06:30 PM
                                        else if (outMinutes >= (16 * 60 + 30) &&
                                            outMinutes < (18 * 60 + 30)) {
                                          actualHours = "08.00";
                                          accountedHours = "08.00";
                                        }

                                        // 06:30 PM - before 09:00 PM
                                        else if (outMinutes >= (18 * 60 + 30) &&
                                            outMinutes < (21 * 60)) {
                                          actualHours = "09.30";
                                          accountedHours = "10.30";
                                        }

                                        // 09:00 PM - before 11:00 PM
                                        else if (outMinutes >= (21 * 60) &&
                                            outMinutes < (23 * 60)) {
                                          actualHours = "11.8";
                                          accountedHours = "13.30";
                                        }

                                        // 11:00 PM - Midnight
                                        else if (outMinutes >= (23 * 60)) {
                                          actualHours = "14.30";
                                          accountedHours = "15.30";
                                        }
                                      }

                                      // ================= SATURDAY =================
                                      else if (currentDate.weekday == DateTime.saturday) {

                                        // Early Leave
                                        if (outMinutes >= (11 * 60 + 50) &&
                                            outMinutes < (16 * 60 + 30)) {
                                          actualHours = "04.00";
                                          accountedHours = "04.00";
                                        }

                                        // 05:15 PM - before 06:30 PM
                                        else if (outMinutes >= (17 * 60 + 15) &&
                                            outMinutes < (18 * 60 + 30)) {
                                          actualHours = "08.00";
                                          accountedHours = "10.50";
                                        }

                                        // 06:30 PM - before 09:00 PM
                                        else if (outMinutes >= (18 * 60 + 30) &&
                                            outMinutes < (21 * 60)) {
                                          actualHours = "10.30";
                                          accountedHours = "13.30";
                                        }

                                        // 09:00 PM - before 11:00 PM
                                        else if (outMinutes >= (21 * 60) &&
                                            outMinutes < (23 * 60)) {
                                          actualHours = "11.8";
                                          accountedHours = "15.30";
                                        }
                                      }

                                      // ================= SUNDAY =================
                                      else if (currentDate.weekday == DateTime.sunday) {

                                        // Early Leave
                                        if (outMinutes >= (11 * 60 + 50) &&
                                            outMinutes < (16 * 60 + 30)) {
                                          actualHours = "04.00";
                                          accountedHours = "04.00";
                                        }

                                        // 05:15 PM - before 06:30 PM
                                        else if (outMinutes >= (17 * 60 + 15) &&
                                            outMinutes < (18 * 60 + 30)) {
                                          actualHours = "08.00";
                                          accountedHours = "16.30";
                                        }

                                        // 06:30 PM - before 09:00 PM
                                        else if (outMinutes >= (18 * 60 + 30) &&
                                            outMinutes < (21 * 60)) {
                                          actualHours = "11.8";
                                          accountedHours = "18.00";
                                        }

                                        // 09:00 PM - before 11:00 PM
                                        else if (outMinutes >= (21 * 60) &&
                                            outMinutes < (23 * 60)) {
                                          actualHours = "13.8";
                                          accountedHours = "22.00";
                                        }
                                      }
                                    }
                                  }

                                  type =
                                      attendanceData['type']
                                          ?.toString() ??
                                          "Auto";

                                  remarks =
                                      attendanceData['remarks']
                                          ?.toString() ??
                                          "";

                                  // IN + OUT দুটো থাকলেই Present
                                  if (inTimestamp != null &&
                                      outTimestamp != null) {
                                    status = "Present";
                                  } else {
                                    status =
                                    isSunday
                                        ? "Holiday"
                                        : "Absent";
                                  }
                                }

                                if (status == "Present") {
                                  presentCount++;
                                } else if (status == "Holiday") {
                                  holidayCount++;
                                } else {
                                  absentCount++;
                                }

                                employeeMonthRows.add({
                                  'date': currentDate,
                                  'inTime': inTime,
                                  'outTime': outTime,
                                  'actualHours': actualHours,
                                  'accountedHours':
                                  accountedHours,
                                  'status': status,
                                  'type': type,
                                  'remarks': remarks,
                                });
                              }

                              return Padding(
                                padding:
                                const EdgeInsets.only(
                                  bottom: 25,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [

                                    // EMPLOYEE ID + NAME + SUMMARY
                                    Container(
                                      width: double.infinity,
                                      padding:
                                      const EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Employee ID: $employeeId",
                                            style: const TextStyle(
                                              fontWeight:
                                              FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),

                                          const SizedBox(height: 6),

                                          Text(
                                            "Name: $employeeName",
                                            style: const TextStyle(
                                              fontWeight:
                                              FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          Wrap(
                                            spacing: 20,
                                            runSpacing: 10,
                                            children: [
                                              Text(
                                                "Present: $presentCount",
                                              ),
                                              Text(
                                                "Absent: $absentCount",
                                              ),
                                              Text(
                                                "Holiday: $holidayCount",
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    // EMPLOYEE TABLE
                                    SingleChildScrollView(
                                      scrollDirection:
                                      Axis.horizontal,
                                      child: DataTable(
                                        headingRowHeight: 42,
                                        dataRowMinHeight: 38,
                                        dataRowMaxHeight: 38,
                                        horizontalMargin: 10,
                                        columnSpacing: 22,
                                        dividerThickness: 0.7,

                                        headingRowColor:
                                        WidgetStateProperty.all(
                                          const Color(0xFFF3F4F6),
                                        ),

                                        border: TableBorder.all(
                                          color:
                                          const Color(0xFFE0E0E0),
                                          width: 0.7,
                                        ),

                                        headingTextStyle:
                                        const TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                          FontWeight.bold,
                                          color: Colors.black87,
                                        ),

                                        dataTextStyle:
                                        const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black87,
                                        ),

                                        columns: const [
                                          DataColumn(
                                            label: Text("Date"),
                                          ),
                                          DataColumn(
                                            label: Text("Day"),
                                          ),
                                          DataColumn(
                                            label: Text("In Time"),
                                          ),
                                          DataColumn(
                                            label: Text("Out Time"),
                                          ),
                                          DataColumn(
                                            label:
                                            Text("Actual Hours"),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              "Accounted Hours",
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text("Status"),
                                          ),
                                          DataColumn(
                                            label: Text("Type"),
                                          ),
                                          DataColumn(
                                            label: Text("Remarks"),
                                          ),
                                        ],

                                        rows:
                                        employeeMonthRows.map((row) {
                                          final DateTime dateTime =
                                          row['date']
                                          as DateTime;

                                          final String status =
                                              row['status']
                                                  ?.toString() ??
                                                  "Absent";

                                          Color rowColor =
                                              Colors.white;

                                          if (status == "Absent") {
                                            rowColor =
                                            const Color(
                                              0xFFF8DEDE,
                                            );
                                          } else if (status ==
                                              "Holiday") {
                                            rowColor =
                                            const Color(
                                              0xFFE0F2D8,
                                            );
                                          }

                                          return DataRow(
                                            color:
                                            WidgetStateProperty.all(
                                              rowColor,
                                            ),
                                            cells: [
                                              DataCell(
                                                Text(
                                                  DateFormat(
                                                    'dd/MM/yyyy',
                                                  ).format(
                                                    dateTime,
                                                  ),
                                                ),
                                              ),

                                              DataCell(
                                                Text(
                                                  DateFormat(
                                                    'EEEE',
                                                  )
                                                      .format(
                                                    dateTime,
                                                  )
                                                      .toUpperCase(),
                                                ),
                                              ),

                                              DataCell(
                                                Text(
                                                  row['inTime']
                                                      ?.toString() ??
                                                      "0",
                                                ),
                                              ),

                                              DataCell(
                                                Text(
                                                  row['outTime']
                                                      ?.toString() ??
                                                      "0",
                                                ),
                                              ),

                                              DataCell(
                                                Text(
                                                  row['actualHours']
                                                      ?.toString() ??
                                                      "0",
                                                ),
                                              ),

                                              DataCell(
                                                Text(
                                                  row['accountedHours']
                                                      ?.toString() ??
                                                      "0",
                                                ),
                                              ),

                                              DataCell(
                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontWeight:
                                                    FontWeight.w600,
                                                    color: status ==
                                                        "Absent"
                                                        ? Colors
                                                        .red.shade700
                                                        : status ==
                                                        "Holiday"
                                                        ? Colors.green
                                                        .shade800
                                                        : Colors.green
                                                        .shade700,
                                                  ),
                                                ),
                                              ),

                                              DataCell(
                                                Text(
                                                  row['type']
                                                      ?.toString() ??
                                                      "Auto",
                                                ),
                                              ),

                                              DataCell(
                                                Text(
                                                  row['remarks']
                                                      ?.toString() ??
                                                      "",
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      if (filteredDocs.isEmpty)
                        const Padding(
                          padding:
                          EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              "No Attendance Record Found",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _topMenuButton(
      String title,
      IconData icon,
      ) {
    return TextButton.icon(
      onPressed: () {},
      icon: Icon(
        icon,
        color: Colors.white,
        size: 16,
      ),
      label: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// --- REGISTRATION PAGE ---
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _regIdController = TextEditingController();
  final TextEditingController _regPassController = TextEditingController();
  File? _regImage;
  Future<List<double>?> _generateFaceEmbedding(File imageFile) async {
    FaceDetector? faceDetector;
    Interpreter? interpreter;

    try {
      // 1. আগে ছবিতে Face detect করি
      final inputImage = InputImage.fromFile(imageFile);

      faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint("No face detected");
        return null;
      }

      // একটার বেশি face থাকলে registration reject
      if (faces.length != 1) {
        debugPrint("Please keep only one face in camera");
        return null;
      }

      // 2. আসল image decode
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        debugPrint("Image decode failed");
        return null;
      }

      // Camera orientation ঠিক করা
      originalImage = img.bakeOrientation(originalImage);

      // 3. ML Kit যে মুখ detect করেছে তার bounding box
      final faceBox = faces.first.boundingBox;

      int x = faceBox.left.floor();
      int y = faceBox.top.floor();
      int width = faceBox.width.ceil();
      int height = faceBox.height.ceil();

      // Face-এর চারপাশে একটু extra জায়গা রাখি
      final extraX = (width * 0.15).round();
      final extraY = (height * 0.15).round();

      x -= extraX;
      y -= extraY;
      width += extraX * 2;
      height += extraY * 2;

      x = x.clamp(0, originalImage.width - 1).toInt();
      y = y.clamp(0, originalImage.height - 1).toInt();

      width = width.clamp(1, originalImage.width - x).toInt();
      height = height.clamp(1, originalImage.height - y).toInt();

      // 4. শুধু Face crop
      final croppedFace = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      // 5. FaceNet input = 160 x 160
      final resizedFace = img.copyResize(
        croppedFace,
        width: 160,
        height: 160,
      );

      // 6. [1,160,160,3] input
      final input = List.generate(
        1,
            (_) => List.generate(
          160,
              (yy) => List.generate(
            160,
                (xx) {
              final pixel = resizedFace.getPixel(xx, yy);

              return [
                (pixel.r.toDouble() - 127.5) / 128.0,
                (pixel.g.toDouble() - 127.5) / 128.0,
                (pixel.b.toDouble() - 127.5) / 128.0,
              ];
            },
          ),
        ),
      );

      // 7. FaceNet model
      interpreter = await Interpreter.fromAsset(
        'assets/models/facenet.tflite',
      );

      // Output = 128 values
      final output = [
        List<double>.filled(128, 0.0),
      ];

      interpreter.run(input, output);

      debugPrint(
        "Face Embedding Generated Successfully: ${output[0].length}",
      );

      return List<double>.from(output[0]);
    } catch (e) {
      debugPrint("Face Embedding Error: $e");
      return null;
    } finally {
      faceDetector?.close();
      interpreter?.close();
    }
  }

  Future<void> _pickFace() async {
    final ImagePicker picker = ImagePicker();

    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 90,
    );

    if (photo != null) {
      setState(() {
        _regImage = File(photo.path);
      });
    }
  }
  Future<void> _confirmAndSave() async {
    String id = _regIdController.text.trim().toUpperCase();
    String pass = _regPassController.text.trim();

    if (id.isEmpty || pass.length != 5 || _regImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID, 5-digit Pass & Face Scan Required!"), backgroundColor: Colors.orange));
      return;
    }

    try {
      Employee emp = globalEmployeeList.firstWhere((e) => e.id == id);
      final generatedFaceEmbedding =
      await _generateFaceEmbedding(_regImage!);

      if (generatedFaceEmbedding == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Face data could not be generated!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (emp.isRegistered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Employee already registered!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      double cosineSimilarity(
          List<double> a,
          List<double> b,
          ) {
        if (a.length != b.length) {
          return -1.0;
        }

        double dotProduct = 0.0;
        double normA = 0.0;
        double normB = 0.0;

        for (int i = 0; i < a.length; i++) {
          dotProduct += a[i] * b[i];
          normA += a[i] * a[i];
          normB += b[i] * b[i];
        }

        if (normA == 0.0 || normB == 0.0) {
          return -1.0;
        }

        return dotProduct / (sqrt(normA) * sqrt(normB));
      }

      Employee? duplicateFaceEmployee;
      double highestSimilarity = -1.0;

      for (final existingEmployee in globalEmployeeList) {
        if (existingEmployee.id == emp.id) {
          continue;
        }

        if (!existingEmployee.isRegistered ||
            existingEmployee.faceEmbedding == null) {
          continue;
        }

        final similarity = cosineSimilarity(
          generatedFaceEmbedding,
          existingEmployee.faceEmbedding!,
        );

        debugPrint(
          "Duplicate Face Check ${existingEmployee.id}: $similarity",
        );

        if (similarity > highestSimilarity) {
          highestSimilarity = similarity;
          duplicateFaceEmployee = existingEmployee;
        }
      }

      const double duplicateFaceThreshold = 0.85;

      if (duplicateFaceEmployee != null &&
          highestSimilarity >= duplicateFaceThreshold) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "This face is already registered with Employee ID: ${duplicateFaceEmployee.id}",
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Confirm Registration"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 40, backgroundImage: FileImage(_regImage!)),
              const SizedBox(height: 10),
              Text("Name: ${emp.name}"),
              Text("ID: ${emp.id}"),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                try {
                  final storageRef = FirebaseStorage.instance
                      .ref()
                      .child('employee_profiles')
                      .child('${emp.id}.jpg');

                  await storageRef.putFile(_regImage!);

                  final String imageUrl =
                  await storageRef.getDownloadURL();

                  setState(() {
                    emp.password = pass;
                    emp.profileImage = _regImage;
                    emp.profileImageUrl = imageUrl;
                    emp.faceEmbedding = generatedFaceEmbedding;
                    emp.isRegistered = true;
                  });

                  await saveEmployeeToFirestore(emp);

                  if (!mounted) return;

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Registration Saved Successfully!"),
                      backgroundColor: Colors.green,
                    ),
                  );

                  Navigator.pop(context);
                } catch (e) {
                  debugPrint("Registration Save Error: $e");

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Registration Save Failed!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Confirm"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ID not found in Employee List!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registration", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                const Text("SBM MARINE & ENGINEERING PTE. LTD.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 30),
                buildRegField("Employee ID:", "Enter employee id", _regIdController, Icons.badge),
                const SizedBox(height: 20),
                buildRegField("Password:", "Create 5-digit password", _regPassController, Icons.lock_outline, isPass: true, limit: 5),
                const SizedBox(height: 30),
                const Align(alignment: Alignment.centerLeft, child: Text("Face ID Scan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickFace,
                  child: Container(
                    height: 200, width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), border: Border.all(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(15)),
                    child: _regImage == null
                        ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50, color: Colors.blue), Text("Click to Scan Face", style: TextStyle(color: Colors.blue))])
                        : ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(_regImage!, fit: BoxFit.cover)),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(width: 250, height: 50, child: ElevatedButton(onPressed: _confirmAndSave, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("Confirm Registration", style: TextStyle(color: Colors.white, fontSize: 16)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRegField(String label, String hint, TextEditingController controller, IconData icon, {bool isPass = false, int? limit}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), TextField(controller: controller, obscureText: isPass, maxLength: limit, decoration: InputDecoration(prefixIcon: Icon(icon), hintText: hint, filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))]);
  }
}

// --- ADD EMPLOYEE PAGE ---
class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});
  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final _idC = TextEditingController(), _nameC = TextEditingController(), _finC = TextEditingController(), _wpC = TextEditingController(), _desigC = TextEditingController(), _adminC = TextEditingController();
  String _selectedRole = 'worker';

  Future<void> _submit() async {
    String id = _idC.text.trim().toUpperCase();

    if (id.isEmpty ||
        _nameC.text.trim().isEmpty ||
        _finC.text.trim().isEmpty ||
        _wpC.text.trim().isEmpty ||
        _desigC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_adminC.text.trim() != "1qaz2wsx") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid Admin Code!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Duplicate ID check
    bool alreadyExists = globalEmployeeList.any(
          (emp) => emp.id.trim().toUpperCase() == id,
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$id already exists!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final newEmployee = Employee(
      id,
      _nameC.text.trim(),
      _finC.text.trim(),
      _desigC.text.trim(),
      _wpC.text.trim(),
    );
    newEmployee.role = _selectedRole;
    newEmployee.permissions = getDefaultPermissions(_selectedRole);

    setState(() {
      globalEmployeeList.add(newEmployee);
    });

    await saveEmployeeToFirestore(newEmployee);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$id Employee Added Successfully!"),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Employee")),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Text("SBM MARINE & ENGINEERING PTE. LTD.", textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              buildInput("Employee ID:", "Enter employee id", _idC, Icons.badge),
              buildInput("Full Name:", "Enter name", _nameC, Icons.person),
              buildInput("Fin Number:", "Enter fin", _finC, Icons.credit_card),
              buildInput("Work Permit No:", "Enter work permit", _wpC, Icons.assignment),
              buildInput("Designation:", "Enter Designation", _desigC, Icons.work),
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Employee Role:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.manage_accounts),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                        DropdownMenuItem(
                          value: 'manager',
                          child: Text('Manager'),
                        ),
                        DropdownMenuItem(
                          value: 'supervisor',
                          child: Text('Supervisor'),
                        ),
                        DropdownMenuItem(
                          value: 'worker',
                          child: Text('Worker'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRole = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              buildInput("Admin code:", "Enter admin code", _adminC, Icons.admin_panel_settings),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100), child: const Text("SUBMIT", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget buildInput(String label, String hint, TextEditingController controller, IconData icon) {
    return Padding(padding: const EdgeInsets.only(bottom: 15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), TextField(controller: controller, decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))]));
  }
}

// --- ALL EMPLOYEE PAGE ---
class AllEmployeePage extends StatelessWidget {
  const AllEmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Employees")),
      body: globalEmployeeList.isEmpty
          ? const Center(child: Text("No Employee Added Yet!"))
          : Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.builder(
            itemCount: globalEmployeeList.length,
            itemBuilder: (context, index) {
              final emp = globalEmployeeList[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(backgroundImage: emp.profileImage != null ? FileImage(emp.profileImage!) : null, child: emp.profileImage == null ? const Icon(Icons.person) : null),
                  title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ID: ${emp.id} | ${emp.designation}"),
                      const SizedBox(height: 4),
                      Text(
                        emp.isRegistered
                            ? "Registered ✅"
                            : "Not Registered ❌",
                        style: TextStyle(
                          color: emp.isRegistered ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.blue),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- DASHBOARD PAGE ---
class DashboardPage extends StatefulWidget {
  final String adminName;
  final File? userImg;
  final Employee? currentUser;

  const DashboardPage({
    super.key,
    this.adminName = "MD ARIFUL ISLAM SAJIB",
    this.userImg,
    this.currentUser,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final Employee? user = widget.currentUser;

    final bool canViewAllEmployee =
        user == null ||
            user.role == 'admin' ||
            user.permissions['allEmployee'] == true;
    final bool canViewMyAttendance =
        user == null ||
            user.role == 'admin' ||
            user.permissions['myAttendance'] == true;

    final bool canViewHistory =
        user == null ||
            user.role == 'admin' ||
            user.permissions['history'] == true;

    final bool canViewTools =
        user == null ||
            user.role == 'admin' ||
            user.permissions['tools'] == true;

    final bool canViewMaterial =
        user == null ||
            user.role == 'admin' ||
            user.permissions['material'] == true;

    final bool canViewDailyProgress =
        user == null ||
            user.role == 'admin' ||
            user.permissions['dailyProgress'] == true;

    final bool canViewSettings =
        user == null ||
            user.role == 'admin' ||
            user.permissions['settings'] == true;

    final bool canViewHelp =
        user == null ||
            user.role == 'admin' ||
            user.permissions['help'] == true;

    final bool canAddEmployee =
        user == null ||
            user.role == 'admin' ||
            user.permissions['addEmployee'] == true;
    final bool canManagePermissions =
        user == null ||
            user.role == 'admin' ||
            user.permissions['managePermissions'] == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0, backgroundColor: Colors.white, automaticallyImplyLeading: false,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("WELCOME TO ATTENDANCE", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
          Text("SBM MARINE & ENGINEERING PTE.LTD", style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w900)),
        ]),
        actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.logout, color: Colors.red)), const SizedBox(width: 10)],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth < 600 ? 3 : 5;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)]), borderRadius: BorderRadius.circular(20)),
                              child: Row(children: [
                                CircleAvatar(radius: 35, backgroundColor: Colors.white, backgroundImage: widget.userImg != null ? FileImage(widget.userImg!) : null, child: widget.userImg == null ? const Icon(Icons.person, size: 30, color: Colors.blue) : null),
                                const SizedBox(width: 15),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Welcome,", style: TextStyle(color: Colors.blueGrey, fontSize: 14)), Text(widget.adminName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15))])),
                              ]),
                            ),
                          ),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: crossAxisCount,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            children: [
                              if (canViewAllEmployee)
                                buildMenuCard(
                                  context,
                                  "ALL EMPLOYEE",
                                  Icons.people,
                                  Colors.orange.shade100,
                                  Colors.orange,
                                  const AllEmployeePage(),
                                ),

                              if (canViewMyAttendance)
                                buildMenuCard(
                                  context,
                                  "MY ATTENDANCE",
                                  Icons.camera_alt,
                                  Colors.green.shade100,
                                  Colors.green,
                                  const AttendanceScannerPage(),
                                ),

                              if (canViewHistory)
                                buildMenuCard(
                                  context,
                                  "HISTORY",
                                  Icons.history,
                                  Colors.purple.shade100,
                                  Colors.purple,
                                  const HistoryPage(),
                                ),

                              if (canViewTools)
                                buildMenuCard(
                                  context,
                                  "TOOLS",
                                  Icons.build,
                                  Colors.blueGrey.shade100,
                                  Colors.blueGrey,
                                  null,
                                ),

                              if (canViewMaterial)
                                buildMenuCard(
                                  context,
                                  "MATERIAL",
                                  Icons.inventory,
                                  Colors.teal.shade100,
                                  Colors.teal,
                                  null,
                                ),

                              if (canViewDailyProgress)
                                buildMenuCard(
                                  context,
                                  "DAILY PROGRESS",
                                  Icons.trending_up,
                                  Colors.blue.shade100,
                                  Colors.blue,
                                  null,
                                ),

                              if (canViewSettings)
                                buildMenuCard(
                                  context,
                                  "SETTINGS",
                                  Icons.settings,
                                  Colors.indigo.shade100,
                                  Colors.indigo,
                                  null,
                                ),

                              if (canViewHelp)
                                buildMenuCard(
                                  context,
                                  "HELP",
                                  Icons.help,
                                  Colors.lightBlue.shade100,
                                  Colors.lightBlue,
                                  null,
                                ),

                              if (canAddEmployee)
                                buildMenuCard(
                                  context,
                                  "ADD EMPLOYEE",
                                  Icons.person_add,
                                  Colors.red.shade100,
                                  Colors.red,
                                  const AddEmployeePage(),
                                ),
                              if (canManagePermissions)
                                buildMenuCard(
                                  context,
                                  "MANAGE PERMISSIONS",
                                  Icons.admin_panel_settings,
                                  Colors.deepPurple.shade100,
                                  Colors.deepPurple,
                                  const PermissionManagementPage(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                width: double.infinity,
                color: Colors.transparent,
                child: const Text(
                  "Developer : MD ARIFUL ISLAM SAJIB Only test for Software Developed @ 2026",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF388E3C), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildMenuCard(BuildContext context, String title, IconData icon, Color bgColor, Color iconColor, Widget? targetPage) {
    return GestureDetector(
      onTap: () { if (targetPage != null) Navigator.push(context, MaterialPageRoute(builder: (context) => targetPage)); },
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(backgroundColor: bgColor, child: Icon(icon, color: iconColor, size: 24)), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))]),
      ),
    );
  }
}
class PermissionManagementPage extends StatefulWidget {
  const PermissionManagementPage({super.key});

  @override
  State<PermissionManagementPage> createState() =>
      _PermissionManagementPageState();
}

class _PermissionManagementPageState
    extends State<PermissionManagementPage> {
  Employee? selectedEmployee;

  @override
  Widget build(BuildContext context) {
    final List<Employee> editableEmployees =
    globalEmployeeList.where((emp) => emp.role != 'admin').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Permissions"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<Employee>(
              value: selectedEmployee,
              decoration: const InputDecoration(
                labelText: "Select Employee",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: editableEmployees.map((emp) {
                return DropdownMenuItem<Employee>(
                  value: emp,
                  child: Text(
                    "${emp.name} - ${emp.id} (${emp.role.toUpperCase()})",
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedEmployee = value;
                });
              },
            ),

            const SizedBox(height: 20),

            if (selectedEmployee != null)
              Expanded(
                child: ListView(
                  children: [
                    _permissionSwitch(
                      "All Employee",
                      "allEmployee",
                    ),
                    _permissionSwitch(
                      "My Attendance",
                      "myAttendance",
                    ),
                    _permissionSwitch(
                      "History",
                      "history",
                    ),
                    _permissionSwitch(
                      "Tools",
                      "tools",
                    ),
                    _permissionSwitch(
                      "Material",
                      "material",
                    ),
                    _permissionSwitch(
                      "Daily Progress",
                      "dailyProgress",
                    ),
                    _permissionSwitch(
                      "Settings",
                      "settings",
                    ),
                    _permissionSwitch(
                      "Help",
                      "help",
                    ),
                    _permissionSwitch(
                      "Add Employee",
                      "addEmployee",
                    ),
                    _permissionSwitch(
                      "Manage Permissions",
                      "managePermissions",
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _permissionSwitch(String title,
      String permissionKey,) {
    if (selectedEmployee == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        value:
        selectedEmployee!.permissions[permissionKey] ?? false,
        onChanged: (value) async {
          setState(() {
            selectedEmployee!.permissions[permissionKey] = value;
          });

          await FirebaseFirestore.instance
              .collection('employees')
              .doc(selectedEmployee!.id)
              .update({
            'permissions': selectedEmployee!.permissions,
          });
        },
      ),
    );
  }
}
