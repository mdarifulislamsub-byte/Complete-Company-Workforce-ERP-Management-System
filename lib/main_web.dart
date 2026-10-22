import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:ui_web' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:country_picker/country_picker.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const WebAdminApp());
}

class WebAdminApp extends StatelessWidget {
  const WebAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SBM Attendance Admin',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.indigo,
      ),
      home: const WebAdminLoginPage(),
    );
  }
}

class NetworkImageWebFix extends StatelessWidget {
  final String imageUrl;
  final double radius;

  const NetworkImageWebFix({
    super.key,
    required this.imageUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final String viewId = 'firebase-logo-${imageUrl.hashCode}';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewId,
          (int viewId) {
        final html.ImageElement imgElement = html.ImageElement()
          ..src = imageUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.display = 'block';

        return imgElement;
      },
    );

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: HtmlElementView(
          viewType: viewId,
        ),
      ),
    );
  }
}

class WebAdminLoginPage extends StatefulWidget {
  const WebAdminLoginPage({super.key});

  @override
  State<WebAdminLoginPage> createState() => _WebAdminLoginPageState();
}

class _WebAdminLoginPageState extends State<WebAdminLoginPage> {
  final TextEditingController _idController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  void _login() async {
    final String id = _idController.text.trim().toUpperCase();

    final String password = _passwordController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter ID and Password!",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ১. আগের হার্ডকোড করা মাস্টার অ্যাডমিন চেক
    if (id == "M-355" && password == "123456") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WebAdminHome(adminId: id),
        ),
      );
      return;
    }

    try {
      // ২. ফায়ারবেস থেকে এমপ্লয়ি বা ম্যানেজার চেক করা
      final doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(id)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User ID not found!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final String role = data['role']?.toString().toLowerCase() ?? '';
      final String storedPassword = data['password']?.toString() ?? '';

      // ৩. রোল চেক: শুধু 'admin' অথবা 'manager' হলে লগইন করতে পারবে
      if (role != 'admin' && role != 'manager') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Access denied! Only Admins and Managers can log in."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ৪. পাসওয়ার্ড চেক (যদি ইউজারের পাসওয়ার্ড ফায়ারবেসে সেভ করা থাকে)
      if (storedPassword.isNotEmpty && storedPassword != password) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Incorrect password!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // সব ঠিক থাকলে হোম পেজে প্রবেশ করবে
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WebAdminHome(adminId: id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 70,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 15),
                const Text(
                  "SBM COMPUTER ADMIN",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: "Admin ID",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                    ),
                    child: const Text(
                      "LOGIN",
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
        ),
      ),
    );
  }
}
//==============================
// STOCK REQUEST PAGE
//==============================
class WebToolsReportPage extends StatefulWidget {
  final String adminId;

  const WebToolsReportPage({super.key, required this.adminId});

  @override
  State<WebToolsReportPage> createState() => _WebToolsReportPageState();
}

class _WebToolsReportPageState extends State<WebToolsReportPage> {
  String selectedMenu = "View Details";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 260,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text(
                    "Tools Menu",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000080),
                    ),
                  ),
                ),
                const Divider(height: 1),
                _buildSidebarItem("View Details", Icons.visibility_outlined),
                _buildSidebarItem("Onhand Stock", Icons.inventory_2_outlined),
                _buildSidebarItem("Stock Request", Icons.request_quote_outlined),
                _buildSidebarItem("Approved Request", Icons.check_circle_outline),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 👈 Uporer "Stock Request" title text-ti ekhane baad dewa hoyeche jate table-er area boro thake
                    Expanded(
                      child: selectedMenu == "View Details"
                          ? _buildToolsListCardView()
                          : (selectedMenu == "Stock Request" || selectedMenu == "Approved Request")
                          ? _buildToolsTableView()
                          : Center(
                        child: Text(
                          "Here is the content for $selectedMenu",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsListCardView() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tools')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text("No tools found!", style: TextStyle(color: Colors.grey, fontSize: 15)));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final String? toolImg = data['imageUrl']?.toString();
            final String itemCode = data['itemCode']?.toString() ?? '';
            final String itemName = data['name']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: toolImg != null && toolImg.isNotEmpty
                    ? NetworkImageWebFix(imageUrl: toolImg, radius: 24)
                    : const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFE8EAF6),
                  child: Icon(Icons.build, color: Color(0xFF000080), size: 22),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000080).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF000080).withOpacity(0.2)),
                      ),
                      child: Text(
                        "Code: $itemCode",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF000080),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        itemName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildToolsTableView() {
    bool isApprovedRequest = selectedMenu == "Approved Request";

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: isApprovedRequest
          ? FirebaseFirestore.instance.collection('stock_requests').orderBy('createdAt', descending: true).snapshots()
          : FirebaseFirestore.instance.collection('tools').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Text(isApprovedRequest ? "No approved requests found!" : "No tools found!", style: const TextStyle(color: Colors.grey, fontSize: 15)));
        }

        if (isApprovedRequest) {
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final requestData = docs[index].data();
              final String prfNo = requestData['prfNo']?.toString() ?? 'PRF NO - N/A';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WebApprovedRequestPreviewPage(
                          adminId: widget.adminId,
                          requestData: requestData,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Request ID: ${docs[index].id.substring(0, 8).toUpperCase()}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF000080).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            prfNo,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080), fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        return Column(
          children: [
            // 👇 Fixed Header Row with SkyBlue Background Color
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7FA), // SkyBlue Background Color
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: const [
                  Expanded(flex: 1, child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF006064)))),
                  Expanded(flex: 4, child: Text('Item Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF006064)))),
                  Expanded(flex: 1, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF006064)))),
                  Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF006064)))),
                  Expanded(flex: 1, child: Text('Remark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF006064)))),
                ],
              ),
            ),
            const Divider(height: 1),

            // 👇 Expanded ListView for Scrolling Body Items
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final String docId = doc.id;
                  final String itemCode = data['itemCode']?.toString() ?? '';
                  final String itemName = data['name']?.toString() ?? '';
                  final String? toolImg = data['imageUrl']?.toString();

                  final String qty = data['quantity']?.toString() ?? '-';
                  final String unit = data['unit']?.toString() ?? '-';
                  final String remark = data['remark']?.toString() ?? '-';

                  return InkWell(
                    onTap: () {
                      _showToolDetailDialog(context, docId, itemCode, itemName, toolImg, qty, unit, remark);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: Text(itemCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                          Expanded(flex: 4, child: Text(itemName, style: const TextStyle(fontSize: 14))),
                          Expanded(flex: 1, child: Text(qty, style: const TextStyle(fontSize: 14))),
                          Expanded(flex: 1, child: Text(unit, style: const TextStyle(fontSize: 14))),
                          Expanded(flex: 1, child: Text(remark, style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),

            // 👇 Footer and Confirm Submit Button Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFF000080), size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Review all items carefully before final submission.",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      FirebaseFirestore.instance.collection('tools').get().then((snapshot) {
                        final docs = snapshot.docs;
                        if (docs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("No tools found to submit!"), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WebStockRequestPreviewPage(
                              adminId: widget.adminId,
                              toolDocs: docs,
                            ),
                          ),
                        ).then((_) {
                          setState(() {});
                        });
                      });
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text(
                      "Confirm Submit",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showToolDetailDialog(BuildContext context, String docId, String code, String name, String? imageUrl, String existingQty, String existingUnit, String existingRemark) {
    final TextEditingController qtyController = TextEditingController(text: existingQty == '-' ? '' : existingQty);
    final TextEditingController remarkController = TextEditingController(text: existingRemark == '-' ? '' : existingRemark);
    String? selectedUnit = existingUnit == '-' ? null : existingUnit;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 750,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EAF6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: NetworkImageWebFix(imageUrl: imageUrl, radius: 70),
                          )
                              : const Icon(Icons.build, size: 50, color: Color(0xFF000080)),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF000080).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text("Code: $code", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080))),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Qty select",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FE),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: InputDecoration(
                              labelText: "unit select",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FE),
                            ),
                            items: const [
                              DropdownMenuItem(value: "Pcs", child: Text("Pcs")),
                              DropdownMenuItem(value: "Box", child: Text("Box")),
                              DropdownMenuItem(value: "Set", child: Text("Set")),
                              DropdownMenuItem(value: "Nos", child: Text("Nos")),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                selectedUnit = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: remarkController,
                      decoration: InputDecoration(
                        labelText: "Remark",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FE),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text("Cancel", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        const SizedBox(width: 15),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final String qty = qtyController.text.trim();
                            final String remark = remarkController.text.trim();
                            final String unit = selectedUnit ?? '';

                            if (qty.isEmpty || unit.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please fill Quantity and Unit!"), backgroundColor: Colors.orange),
                              );
                              return;
                            }

                            try {
                              await FirebaseFirestore.instance
                                  .collection('tools')
                                  .doc(docId)
                                  .update({
                                'quantity': qty,
                                'unit': unit,
                                'remark': remark,
                              });

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Stock request updated successfully!"), backgroundColor: Colors.green),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Failed to update: $e"), backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: const Text("Submit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebarItem(String title, IconData icon) {
    bool isSelected = selectedMenu == title;
    return InkWell(
      onTap: () {
        setState(() {
          selectedMenu = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF000080).withOpacity(0.08) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF000080) : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF000080) : Colors.grey.shade700,
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF000080) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//===============================================
//PRF APPROVED PAGE
//===============================================

class WebApprovedRequestPreviewPage extends StatefulWidget {
  final String adminId;
  final Map<String, dynamic> requestData;

  const WebApprovedRequestPreviewPage({super.key, required this.adminId, required this.requestData});

  @override
  State<WebApprovedRequestPreviewPage> createState() => _WebApprovedRequestPreviewPageState();
}

class _WebApprovedRequestPreviewPageState extends State<WebApprovedRequestPreviewPage> {
  late Map<String, dynamic> currentRequestData;

  @override
  void initState() {
    super.initState();
    currentRequestData = Map<String, dynamic>.from(widget.requestData);
  }

  // ২৪টি করে আইটেম বা ইমেজ পিস করার হেল্পার ফাংশন
  List<List<dynamic>> _chunkList(List<dynamic> list, int chunkSize) {
    List<List<dynamic>> chunks = [];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  // ফায়ারস্টোরে সিগনেচার আপডেট করার ফাংশন
  Future<void> _updateApprovalStatus(String fieldName, String successMessage) async {
    if (fieldName == 'approvedBy') {
      final verifiedBy = currentRequestData['verifiedBy']?.toString() ?? '';
      if (verifiedBy.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please 'Confirm Verify' first before approving!"), backgroundColor: Colors.orange),
        );
        return;
      }
    } else if (fieldName == 'receivedBy') {
      final approvedBy = currentRequestData['approvedBy']?.toString() ?? '';
      if (approvedBy.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please 'Confirm Approved' first before receiving!"), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    // 👈 প্রতিবার ক্লিক করলেই প্রসেসিং বা লোডিং উইন্ডো দেখাবে
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF000080)),
                SizedBox(width: 20),
                Text("Processing Request & Uploading PDF...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        );
      },
    );

    try {
      final String docId = currentRequestData['id']?.toString() ?? currentRequestData['docId']?.toString() ?? '';

      setState(() {
        currentRequestData[fieldName] = widget.adminId;
      });

      if (docId.isEmpty) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('stock_requests')
            .where('prfNo', isEqualTo: currentRequestData['prfNo'])
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final targetDoc = querySnapshot.docs.first;
          await targetDoc.reference.update({fieldName: widget.adminId});
        }
      } else {
        await FirebaseFirestore.instance.collection('stock_requests').doc(docId).update({
          fieldName: widget.adminId,
        });
      }

      await _generateUploadAndSavePdf();

      if (!mounted) return;
      Navigator.pop(context); // কাজ শেষ হলে লোডিং উইন্ডো বন্ধ হবে

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      setState(() {
        currentRequestData[fieldName] = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ফায়ারবেস স্টোরেজে পিডিএফ আপলোড এবং ফায়ারস্টোরে লিংক সেভ করার ফাংশন (Multi-page Chunked Support)
  Future<void> _generateUploadAndSavePdf() async {
    try {
      final pdfDoc = pw.Document();
      final rawItemsList = (currentRequestData['items'] as List?) ?? [];

      // 👇 Numeric ascending sorting (10001, 10002, 10003...)
      final List<dynamic> itemsList = List.from(rawItemsList);
      itemsList.sort((a, b) {
        final codeA = int.tryParse((a is Map<String, dynamic> ? a['itemCode']?.toString() : '0') ?? '0') ?? 0;
        final codeB = int.tryParse((b is Map<String, dynamic> ? b['itemCode']?.toString() : '0') ?? '0') ?? 0;
        return codeA.compareTo(codeB);
      });

      final itemChunks = _chunkList(itemsList, 20);
      final imageChunks = _chunkList(itemsList, 24); // Protiti page-e 24-ti kore image gallery

      final adminSnapshot = await FirebaseFirestore.instance.collection('employees').doc(widget.adminId).get();
      final adminData = adminSnapshot.data() ?? {};
      final String companyId = adminData['companyId']?.toString() ?? adminData['company']?.toString() ?? '';

      Query<Map<String, dynamic>> prfQuery = FirebaseFirestore.instance.collection('prf_letter_heads').limit(1);
      if (companyId.isNotEmpty) {
        prfQuery = FirebaseFirestore.instance.collection('prf_letter_heads').where('companyId', isEqualTo: companyId).limit(1);
      }
      final prfSnapshot = await prfQuery.get();
      final prfDocs = prfSnapshot.docs;
      Map<String, dynamic> prfData = prfDocs.isNotEmpty ? prfDocs.first.data() : {};

      final String companyName = prfData['companyName']?.toString() ?? 'MACDOWELL OFFSHORE ENGINEERING PET. LTD.';
      final String address = prfData['address']?.toString() ?? '3 SOONLE STREET #01-05, SINGAPORE 627606';
      final String regNo = prfData['regNo']?.toString() ?? '200804295k';
      final String phone = prfData['phone']?.toString() ?? 'phone +65 67104933';
      final String fax = prfData['fax']?.toString() ?? 'Fax : +65 6659 6929';
      final String email = prfData['email']?.toString() ?? 'Mail : arifulislam0@gmail.com';
      final String website = prfData['website']?.toString() ?? '';
      final String department = prfData['department']?.toString() ?? 'PIPING';
      final String purpose = prfData['purpose']?.toString() ?? 'TO BE USE FOR PRODUCTION & OFFICIAL';
      final String controlNo = prfData['controlNo']?.toString() ?? 'PRF-SBMME';
      final String dateNeeded = prfData['dateNeeded']?.toString() ?? 'ASAP';
      final String prfNo = currentRequestData['prfNo']?.toString() ?? 'N/A';

      final Timestamp? requestTimestamp = currentRequestData['createdAt'] as Timestamp?;
      String savedDate = requestTimestamp != null ? DateFormat('dd/MM/yyyy').format(requestTimestamp.toDate()) : '';

      Uint8List? logoBytes;
      final String? logoUrl = prfData['logoUrl']?.toString().trim();
      if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          final logoRes = await http.get(Uri.parse(logoUrl));
          if (logoRes.statusCode == 200) logoBytes = logoRes.bodyBytes;
        } catch (_) {}
      }

      Map<String, Uint8List> imageBytesCache = {};
      List<Future<void>> downloadTasks = [];
      for (var item in itemsList) {
        final data = item is Map<String, dynamic> ? item : {};
        final String? imageUrl = data['imageUrl']?.toString();
        if (imageUrl != null && imageUrl.isNotEmpty && !imageBytesCache.containsKey(imageUrl)) {
          downloadTasks.add(
            http.get(Uri.parse(imageUrl)).then((response) {
              if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
                imageBytesCache[imageUrl] = response.bodyBytes;
              }
            }).catchError((_) {
              // 👈 Link expired ba fail korle o code hang korbe na, skip kore jabe
            }),
          );
        }
      }

      // 👈 Timeout ebong try-catch add kora holo jate kono image link expire thakle o process atke na thake
      try {
        await Future.wait(downloadTasks).timeout(const Duration(seconds: 12));
      } catch (_) {}

      // ১. Proti page-e 20-ti kore item ebong signature add kora hocche
      for (int pageIndex = 0; pageIndex < itemChunks.length; pageIndex++) {
        final chunk = itemChunks[pageIndex];

        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (pageIndex == 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 120,
                              height: 90,
                              alignment: pw.Alignment.center,
                              child: logoBytes != null ? pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain) : pw.PdfLogo(),
                            ),
                            pw.Expanded(
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8.0),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(companyName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                                    pw.SizedBox(height: 3),
                                    pw.Text(address, style: const pw.TextStyle(fontSize: 8.5)),
                                    pw.SizedBox(height: 2),
                                    pw.Text("Company Reg.no. : $regNo", style: const pw.TextStyle(fontSize: 8.5)),
                                    pw.SizedBox(height: 2),
                                    pw.Row(
                                      children: [
                                        pw.Text(phone, style: const pw.TextStyle(fontSize: 8.5)),
                                        pw.SizedBox(width: 15),
                                        pw.Text(fax, style: const pw.TextStyle(fontSize: 8.5)),
                                      ],
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Row(
                                      children: [
                                        pw.Text(email, style: const pw.TextStyle(fontSize: 8.5)),
                                        pw.SizedBox(width: 15),
                                        pw.Text(website, style: const pw.TextStyle(fontSize: 8.5)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            pw.Container(
                              width: 70,
                              height: 70,
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: currentRequestData['pdfUrl']?.toString().isNotEmpty == true
                                    ? currentRequestData['pdfUrl']!
                                    : "PRF No: $prfNo, Control No: $controlNo, Date: $savedDate",
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 10),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.SizedBox(width: 100),
                            pw.Text("PURCHASE REQUISITION FORM", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(4)),
                              child: pw.Text(prfNo, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.black, width: 1),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text("Department : $department", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                    pw.SizedBox(height: 6),
                                    pw.Text("PURPOSE : $purpose", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  ],
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text("CONTROL NO : $controlNo", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                        if (savedDate.isNotEmpty)
                                          pw.Text("Date: $savedDate", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                      ],
                                    ),
                                    pw.SizedBox(height: 6),
                                    pw.Text("Date Needed : $dateNeeded", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 15),
                      ],
                      pw.Text(
                        "Requested Items List (Page ${pageIndex + 1} of ${itemChunks.length}):",
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Table.fromTextArray(
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                        cellStyle: const pw.TextStyle(fontSize: 8.5),
                        cellAlignment: pw.Alignment.centerLeft,
                        headers: ['Code', 'Item Description', 'Quantity', 'Unit', 'Remark'],
                        data: chunk.map((item) {
                          final data = item is Map<String, dynamic> ? item : {};
                          return [
                            data['itemCode']?.toString() ?? '',
                            data['name']?.toString() ?? '',
                            data['quantity']?.toString() ?? '-',
                            data['unit']?.toString() ?? '-',
                            data['remark']?.toString() ?? '-',
                          ];
                        }).toList(),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Requested by", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 20),
                          pw.Text("ID: ${currentRequestData['adminId'] ?? 'N/A'}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Verified by", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 20),
                          pw.Text((currentRequestData['verifiedBy']?.toString() ?? '').isNotEmpty ? "Signed" : "Pending", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Approved by", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 20),
                          pw.Text((currentRequestData['approvedBy']?.toString() ?? '').isNotEmpty ? "Signed" : "Pending", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Received by", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 20),
                          pw.Text((currentRequestData['receivedBy']?.toString() ?? '').isNotEmpty ? "Signed" : "Pending", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      // ২. Image gallery pages add kora hocche (protiti page-e 24-ti kore image grid)
      for (int imgPageIndex = 0; imgPageIndex < imageChunks.length; imgPageIndex++) {
        final imgChunk = imageChunks[imgPageIndex];
        final List<pw.Widget> pageImageWidgets = [];

        for (var item in imgChunk) {
          final data = item is Map<String, dynamic> ? item : {};
          final String itemCode = data['itemCode']?.toString() ?? '';
          final String? imageUrl = data['imageUrl']?.toString();
          Uint8List? imgBytes = (imageUrl != null && imageUrl.isNotEmpty) ? imageBytesCache[imageUrl] : null;

          pageImageWidgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: imgBytes != null
                        ? pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.contain)
                        : pw.Center(
                      child: pw.Text("No Image", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    itemCode,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blue900),
                  ),
                ],
              ),
            ),
          );
        }

        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Requested Items Images Gallery (Page ${imgPageIndex + 1} of ${imageChunks.length}):",
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Expanded(
                    child: pw.GridView(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.95,
                      children: pageImageWidgets,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      final Uint8List pdfBytes = await pdfDoc.save();
      final String prfNoStr = prfNo.replaceAll(RegExp(r'[^\w\s]+'), '_');
      final Reference storageRef = FirebaseStorage.instance.ref().child('prf_pdfs/$prfNoStr.pdf');

      final UploadTask uploadTask = storageRef.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      final String actualDocId = currentRequestData['id']?.toString() ?? currentRequestData['docId']?.toString() ?? '';
      if (actualDocId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('stock_requests').doc(actualDocId).update({'pdfUrl': downloadUrl});
      } else {
        final querySnapshot = await FirebaseFirestore.instance.collection('stock_requests').where('prfNo', isEqualTo: prfNo).get();
        if (querySnapshot.docs.isNotEmpty) {
          await querySnapshot.docs.first.reference.update({'pdfUrl': downloadUrl});
        }
      }

      setState(() {
        currentRequestData['pdfUrl'] = downloadUrl;
      });
    } catch (e) {
      print("PDF Upload Exception: $e");
    }
  }

  Widget _buildSignatureColumn(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildRequesterSignatureColumn(String requesterId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('employees').doc(requesterId).get(),
        builder: (context, snapshot) {
          String empName = "";
          String empId = requesterId;
          String designation = "";

          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() ?? {};
            empName = data['name']?.toString() ?? "";
            empId = data['id']?.toString() ?? requesterId;
            designation = data['designation']?.toString() ?? "";
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Requested by",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (empName.isNotEmpty)
                Text(empName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
              if (empId.isNotEmpty)
                Text("ID: $empId", style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              if (designation.isNotEmpty)
                Text(designation, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              const SizedBox(height: 35),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVerifierSignatureColumn(String? userId, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: userId == null || userId.isEmpty
          ? _buildSignatureColumn(title)
          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('employees').doc(userId).get(),
        builder: (context, snapshot) {
          String empName = "";
          String empId = userId;
          String designation = "";

          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() ?? {};
            empName = data['name']?.toString() ?? "";
            empId = data['id']?.toString() ?? userId;
            designation = data['designation']?.toString() ?? "";
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 10),
              if (empName.isNotEmpty)
                Text(empName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
              if (empId.isNotEmpty)
                Text("ID: $empId", style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              if (designation.isNotEmpty)
                Text(designation, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              const SizedBox(height: 35),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String prfNo = currentRequestData['prfNo']?.toString() ?? 'PRF NO - N/A';
    final List items = currentRequestData['items'] is List ? currentRequestData['items'] as List : [];

    // UI-এর জন্য ২৪টি করে আইটেম এবং ছবি chunk করে নেওয়া হলো
    final itemChunks = _chunkList(items, 24);
    final imageChunks = _chunkList(items, 24);

    final Timestamp? requestTimestamp = currentRequestData['createdAt'] as Timestamp?;
    String savedDate = '';
    if (requestTimestamp != null) {
      savedDate = DateFormat('dd/MM/yyyy').format(requestTimestamp.toDate());
    }

    final bool isVerified = (currentRequestData['verifiedBy']?.toString() ?? '').isNotEmpty;
    final bool isApproved = (currentRequestData['approvedBy']?.toString() ?? '').isNotEmpty;
    final bool isReceived = (currentRequestData['receivedBy']?.toString() ?? '').isNotEmpty;
    final String pdfUrl = currentRequestData['pdfUrl']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000080),
        title: const Text("Approved Request Preview", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Column(
            children: [
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('employees').doc(widget.adminId).get(),
                builder: (context, adminSnapshot) {
                  if (adminSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final Map<String, dynamic> adminData = adminSnapshot.data?.data() ?? {};
                  final String companyId = adminData['companyId']?.toString() ?? adminData['company']?.toString() ?? '';

                  Query<Map<String, dynamic>> prfQuery = FirebaseFirestore.instance.collection('prf_letter_heads').limit(1);

                  if (companyId.isNotEmpty) {
                    prfQuery = FirebaseFirestore.instance.collection('prf_letter_heads').where('companyId', isEqualTo: companyId).limit(1);
                  }

                  return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: prfQuery.get(),
                    builder: (context, prfSnapshot) {
                      if (prfSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final List<QueryDocumentSnapshot<Map<String, dynamic>>> prfDocs = prfSnapshot.data?.docs ?? [];
                      Map<String, dynamic> prfData = {};

                      if (prfDocs.isNotEmpty) {
                        prfData = prfDocs.first.data();
                      }

                      final String companyName = prfData['companyName']?.toString() ?? 'MACDOWELL OFFSHORE ENGINEERING PET. LTD.';
                      final String address = prfData['address']?.toString() ?? '3 SOONLE STREET #01-05, SINGAPORE 627606';

                      String rawRegNo = prfData['regNo']?.toString() ?? '200804295k';
                      rawRegNo = rawRegNo.replaceAll('Company Reg.no.', '').replaceAll(':', '').trim();
                      final String regNo = rawRegNo;

                      String rawPhone = prfData['phone']?.toString() ?? '+65 67104933 , 6710 4934';
                      rawPhone = rawPhone.replaceAll('phone', '').replaceAll('Phone', '').replaceAll(':', '').trim();
                      final String phone = "phone $rawPhone";

                      String rawFax = prfData['fax']?.toString() ?? '+65 6659 6929';
                      rawFax = rawFax.replaceAll('Fax', '').replaceAll('fax', '').replaceAll(':', '').trim();
                      final String fax = "Fax : $rawFax";

                      String rawEmail = prfData['email']?.toString() ?? 'arifulislam0@gmail.com';
                      rawEmail = rawEmail.replaceAll('Mail', '').replaceAll('mail', '').replaceAll('Email', '').replaceAll(':', '').trim();
                      final String email = "Mail : $rawEmail";

                      String rawWebsite = prfData['website']?.toString() ?? '';
                      rawWebsite = rawWebsite.replaceAll('Website', '').replaceAll('website', '').replaceAll(':', '').trim();
                      final String website = "Website : $rawWebsite";

                      final String department = prfData['department']?.toString() ?? 'PIPING';
                      final String purpose = prfData['purpose']?.toString() ?? 'TO BE USE FOR PRODUCTION & OFFICIAL';
                      final String controlNo = prfData['controlNo']?.toString() ?? 'PRF-SBMME';
                      final String dateNeeded = prfData['dateNeeded']?.toString() ?? 'ASAP';
                      final String? logoUrl = prfData['logoUrl']?.toString().trim();

                      return Column(
                        children: [
                          // ১. আইটেম পেজগুলোর ইউআই প্রিভিউ (প্রতি পেজে ২৪টি করে)
                          for (int pageIndex = 0; pageIndex < itemChunks.length; pageIndex++) ...[
                            Container(
                              constraints: const BoxConstraints(maxWidth: 1000, minHeight: 1414),
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (pageIndex == 0) ...[
                                        Table(
                                          border: const TableBorder.symmetric(
                                            inside: BorderSide.none,
                                            outside: BorderSide.none,
                                          ),
                                          columnWidths: const {
                                            0: FixedColumnWidth(160),
                                            1: FlexColumnWidth(),
                                            2: FixedColumnWidth(120),
                                          },
                                          children: [
                                            TableRow(
                                              children: [
                                                Container(
                                                  height: 130,
                                                  alignment: Alignment.center,
                                                  color: Colors.white,
                                                  child: logoUrl != null && logoUrl.isNotEmpty
                                                      ? Padding(
                                                    padding: const EdgeInsets.all(4.0),
                                                    child: Image.network(
                                                      logoUrl,
                                                      fit: BoxFit.contain,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.apartment, size: 50, color: Color(0xFF000080)),
                                                    ),
                                                  )
                                                      : const Icon(Icons.apartment, size: 50, color: Color(0xFF000080)),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(companyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                      const SizedBox(height: 4),
                                                      Text(address, style: const TextStyle(fontSize: 12)),
                                                      const SizedBox(height: 2),
                                                      Text("Company Reg.no. : $regNo", style: const TextStyle(fontSize: 12)),
                                                      const SizedBox(height: 2),
                                                      Wrap(
                                                        spacing: 20,
                                                        children: [
                                                          Text(phone, style: const TextStyle(fontSize: 12)),
                                                          Text(fax, style: const TextStyle(fontSize: 12)),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Wrap(
                                                        spacing: 20,
                                                        children: [
                                                          Text(email, style: const TextStyle(fontSize: 12)),
                                                          Text(website, style: const TextStyle(fontSize: 12)),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  alignment: Alignment.topRight,
                                                  child: QrImageView(
                                                    data: pdfUrl.isNotEmpty ? pdfUrl : "PRF No: $prfNo, Control No: $controlNo, Date: $savedDate",
                                                    version: QrVersions.auto,
                                                    size: 115.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 15),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const SizedBox(width: 140),
                                            const Text("PURCHASE REQUISITION FORM", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(color: const Color.fromRGBO(0, 0, 128, 0.1), borderRadius: BorderRadius.circular(6)),
                                              child: Text(prfNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF000080))),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 15),
                                        Table(
                                          border: const TableBorder(
                                            horizontalInside: BorderSide(color: Colors.black, width: 1),
                                            verticalInside: BorderSide(color: Colors.black, width: 1),
                                            top: BorderSide(color: Colors.black, width: 1),
                                            bottom: BorderSide(color: Colors.black, width: 1),
                                            left: BorderSide(color: Colors.black, width: 1),
                                            right: BorderSide(color: Colors.black, width: 1),
                                          ),
                                          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.2)},
                                          children: [
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text("Department : $department", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                      const SizedBox(height: 8),
                                                      Text("PURPOSE : $purpose", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text("CONTROL NO : $controlNo", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                          if (savedDate.isNotEmpty)
                                                            Text("Date: $savedDate", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF000080))),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 10),
                                                      Text("Date Needed : $dateNeeded", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 25),
                                      ],
                                      Text(
                                        "Requested Items List (Page ${pageIndex + 1} of ${itemChunks.length}):",
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                                      ),
                                      const SizedBox(height: 10),
                                      Table(
                                        border: TableBorder.all(color: Colors.grey.shade400),
                                        columnWidths: const {
                                          0: FlexColumnWidth(0.8),
                                          1: FlexColumnWidth(4.5),
                                          2: FlexColumnWidth(0.9),
                                          3: FlexColumnWidth(0.8),
                                          4: FlexColumnWidth(1.0),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(color: const Color(0xFF000080).withOpacity(0.08)),
                                            children: const [
                                              Padding(padding: EdgeInsets.all(10), child: Text("Code", style: TextStyle(fontWeight: FontWeight.bold))),
                                              Padding(padding: EdgeInsets.all(10), child: Text("Item Description", style: TextStyle(fontWeight: FontWeight.bold))),
                                              Padding(padding: EdgeInsets.all(10), child: Text("Quantity", style: TextStyle(fontWeight: FontWeight.bold))),
                                              Padding(padding: EdgeInsets.all(10), child: Text("Unit", style: TextStyle(fontWeight: FontWeight.bold))),
                                              Padding(padding: EdgeInsets.all(10), child: Text("Remark", style: TextStyle(fontWeight: FontWeight.bold))),
                                            ],
                                          ),
                                          ...itemChunks[pageIndex].map<TableRow>((item) {
                                            final Map<String, dynamic> data = item is Map<String, dynamic> ? item : {};
                                            final String itemCode = data['itemCode']?.toString() ?? '';
                                            final String itemName = data['name']?.toString() ?? '';
                                            final String qty = data['quantity']?.toString() ?? '-';
                                            final String unit = data['unit']?.toString() ?? '-';
                                            final String remark = data['remark']?.toString() ?? '-';

                                            return TableRow(
                                              children: [
                                                Padding(padding: const EdgeInsets.all(10), child: Text(itemCode)),
                                                Padding(padding: const EdgeInsets.all(10), child: Text(itemName)),
                                                Padding(padding: const EdgeInsets.all(10), child: Text(qty)),
                                                Padding(padding: const EdgeInsets.all(10), child: Text(unit)),
                                                Padding(padding: const EdgeInsets.all(10), child: Text(remark)),
                                              ],
                                            );
                                          }),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Signatures Section
                                  Table(
                                    border: const TableBorder.symmetric(inside: BorderSide.none, outside: BorderSide.none),
                                    columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
                                    children: [
                                      TableRow(
                                        children: [
                                          _buildRequesterSignatureColumn(currentRequestData['adminId'] ?? widget.adminId),
                                          _buildVerifierSignatureColumn(currentRequestData['verifiedBy']?.toString(), "Verified by"),
                                          _buildVerifierSignatureColumn(currentRequestData['approvedBy']?.toString(), "Approved by"),
                                          _buildVerifierSignatureColumn(currentRequestData['receivedBy']?.toString(), "Received by"),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],

                          // ২. ইমেজ গ্যালারি পেজগুলোর ইউআই প্রিভিউ (প্রতি পেজে সর্বোচ্চ ২৪টি ছবি)
                          for (int imgPageIndex = 0; imgPageIndex < imageChunks.length; imgPageIndex++) ...[
                            Container(
                              constraints: const BoxConstraints(maxWidth: 1000, minHeight: 1414),
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Requested Items Images Gallery (Page ${imgPageIndex + 1} of ${imageChunks.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF000080))),
                                  const SizedBox(height: 20),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85),
                                    itemCount: imageChunks[imgPageIndex].length,
                                    itemBuilder: (context, index) {
                                      final data = imageChunks[imgPageIndex][index] is Map<String, dynamic> ? imageChunks[imgPageIndex][index] as Map<String, dynamic> : {};
                                      final String itemCode = data['itemCode']?.toString() ?? '';
                                      final String? imageUrl = data['imageUrl']?.toString();

                                      return Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: imageUrl != null && imageUrl.isNotEmpty
                                                  ? Image.network(imageUrl, fit: BoxFit.contain, width: double.infinity, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey))
                                                  : const Icon(Icons.image, size: 50, color: Colors.grey),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(itemCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF000080))),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),

              // Footer Buttons Section
              SizedBox(
                width: 1000,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVerified ? Colors.grey : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isVerified ? null : () => _updateApprovalStatus('verifiedBy', "Request verified successfully!"),
                      icon: const Icon(Icons.verified_user),
                      label: Text(isVerified ? "Verified" : "Confirm Verify", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isApproved ? Colors.grey : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isApproved ? null : () => _updateApprovalStatus('approvedBy', "Request approved successfully!"),
                      icon: const Icon(Icons.thumb_up),
                      label: Text(isApproved ? "Approved" : "Confirm Approved", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isReceived ? Colors.grey : Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isReceived ? null : () => _updateApprovalStatus('receivedBy', "Request received successfully!"),
                      icon: const Icon(Icons.assignment_turned_in),
                      label: Text(isReceived ? "Received" : "Confirm Received", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return Dialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Color(0xFF000080)),
                                    SizedBox(width: 20),
                                    Text("Opening PDF...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        try {
                          String pdfUrl = currentRequestData['pdfUrl']?.toString() ?? '';

                          if (pdfUrl.isEmpty) {
                            await _generateUploadAndSavePdf();
                            pdfUrl = currentRequestData['pdfUrl']?.toString() ?? '';
                          }

                          if (pdfUrl.isNotEmpty) {
                            await Printing.layoutPdf(
                              onLayout: (PdfPageFormat format) async {
                                final pdfDoc = pw.Document();
                                final itemsList = (currentRequestData['items'] as List?) ?? [];

                                final printItemChunks = _chunkList(itemsList, 24);
                                final printImageChunks = _chunkList(itemsList, 24);

                                final Map<String, Uint8List> imageBytesCache = {};

                                // লেটারহেড ডেটা এবং লোগো ফেচ করার জন্য
                                final adminSnapshot = await FirebaseFirestore.instance.collection('employees').doc(widget.adminId).get();
                                final adminData = adminSnapshot.data() ?? {};
                                final String companyId = adminData['companyId']?.toString() ?? adminData['company']?.toString() ?? '';

                                Query<Map<String, dynamic>> prfQuery = FirebaseFirestore.instance.collection('prf_letter_heads').limit(1);
                                if (companyId.isNotEmpty) {
                                  prfQuery = FirebaseFirestore.instance.collection('prf_letter_heads').where('companyId', isEqualTo: companyId).limit(1);
                                }
                                final prfSnapshot = await prfQuery.get();
                                final prfDocs = prfSnapshot.docs;
                                Map<String, dynamic> prfData = prfDocs.isNotEmpty ? prfDocs.first.data() : {};

                                final String companyName = prfData['companyName']?.toString() ?? 'MACDOWELL OFFSHORE ENGINEERING PET. LTD.';
                                final String address = prfData['address']?.toString() ?? '3 SOONLE STREET #01-05, SINGAPORE 627606';
                                final String regNo = prfData['regNo']?.toString() ?? '200804295k';
                                final String phone = prfData['phone']?.toString() ?? 'phone +65 67104933';
                                final String fax = prfData['fax']?.toString() ?? 'Fax : +65 6659 6929';
                                final String email = prfData['email']?.toString() ?? 'Mail : arifulislam0@gmail.com';
                                final String website = prfData['website']?.toString() ?? '';
                                final String department = prfData['department']?.toString() ?? 'PIPING';
                                final String purpose = prfData['purpose']?.toString() ?? 'TO BE USE FOR PRODUCTION & OFFICIAL';
                                final String controlNo = prfData['controlNo']?.toString() ?? 'PRF-SBMME';
                                final String dateNeeded = prfData['dateNeeded']?.toString() ?? 'ASAP';
                                final String prfNo = currentRequestData['prfNo']?.toString() ?? 'N/A';

                                final Timestamp? requestTimestamp = currentRequestData['createdAt'] as Timestamp?;
                                String savedDate = requestTimestamp != null ? DateFormat('dd/MM/yyyy').format(requestTimestamp.toDate()) : '';

                                Uint8List? logoBytes;
                                final String? logoUrl = prfData['logoUrl']?.toString().trim();
                                if (logoUrl != null && logoUrl.isNotEmpty) {
                                  try {
                                    final logoRes = await http.get(Uri.parse(logoUrl));
                                    if (logoRes.statusCode == 200) logoBytes = logoRes.bodyBytes;
                                  } catch (_) {}
                                }

                                for (var item in itemsList) {
                                  final data = item is Map<String, dynamic> ? item : {};
                                  final String? imageUrl = data['imageUrl']?.toString();
                                  if (imageUrl != null && imageUrl.isNotEmpty && !imageBytesCache.containsKey(imageUrl)) {
                                    try {
                                      final response = await http.get(Uri.parse(imageUrl));
                                      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
                                        imageBytesCache[imageUrl] = response.bodyBytes;
                                      }
                                    } catch (_) {}
                                  }
                                }

                                // ==========================================================
                                // ১. আইটেম লিস্ট পেজগুলো রেন্ডার করার অংশ (Fixed layout for clean page break)
                                // ==========================================================
                                for (int pageIndex = 0; pageIndex < printItemChunks.length; pageIndex++) {
                                  final chunk = printItemChunks[pageIndex];
                                  pdfDoc.addPage(
                                    pw.Page(
                                      pageFormat: format,
                                      margin: const pw.EdgeInsets.all(32),
                                      build: (pw.Context context) {
                                        return pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            if (pageIndex == 0) ...[
                                              pw.Row(
                                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                                children: [
                                                  pw.Container(
                                                    width: 120,
                                                    height: 90,
                                                    alignment: pw.Alignment.center,
                                                    child: logoBytes != null ? pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain) : pw.PdfLogo(),
                                                  ),
                                                  pw.Expanded(
                                                    child: pw.Padding(
                                                      padding: const pw.EdgeInsets.symmetric(horizontal: 8.0),
                                                      child: pw.Column(
                                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                                        children: [
                                                          pw.Text(companyName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                                                          pw.SizedBox(height: 3),
                                                          pw.Text(address, style: const pw.TextStyle(fontSize: 8.5)),
                                                          pw.SizedBox(height: 2),
                                                          pw.Text("Company Reg.no. : $regNo", style: const pw.TextStyle(fontSize: 8.5)),
                                                          pw.SizedBox(height: 2),
                                                          pw.Row(
                                                            children: [
                                                              pw.Text(phone, style: const pw.TextStyle(fontSize: 8.5)),
                                                              pw.SizedBox(width: 15),
                                                              pw.Text(fax, style: const pw.TextStyle(fontSize: 8.5)),
                                                            ],
                                                          ),
                                                          pw.SizedBox(height: 2),
                                                          pw.Row(
                                                            children: [
                                                              pw.Text(email, style: const pw.TextStyle(fontSize: 8.5)),
                                                              pw.SizedBox(width: 15),
                                                              pw.Text(website, style: const pw.TextStyle(fontSize: 8.5)),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  pw.Container(
                                                    width: 70,
                                                    height: 70,
                                                    child: pw.BarcodeWidget(
                                                      barcode: pw.Barcode.qrCode(),
                                                      data: currentRequestData['pdfUrl']?.toString().isNotEmpty == true
                                                          ? currentRequestData['pdfUrl']!
                                                          : "PRF No: $prfNo, Control No: $controlNo, Date: $savedDate",
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              pw.SizedBox(height: 10),
                                              pw.Row(
                                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                                children: [
                                                  pw.SizedBox(width: 100),
                                                  pw.Text("PURCHASE REQUISITION FORM", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                                                  pw.Container(
                                                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(4)),
                                                    child: pw.Text(prfNo, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                                  ),
                                                ],
                                              ),
                                              pw.SizedBox(height: 12),
                                              pw.Container(
                                                padding: const pw.EdgeInsets.all(8),
                                                decoration: pw.BoxDecoration(
                                                  border: pw.Border.all(color: PdfColors.black, width: 1),
                                                ),
                                                child: pw.Row(
                                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                                  children: [
                                                    pw.Expanded(
                                                      child: pw.Column(
                                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                                        children: [
                                                          pw.Text("Department : $department", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                                          pw.SizedBox(height: 6),
                                                          pw.Text("PURPOSE : $purpose", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                    pw.Expanded(
                                                      child: pw.Column(
                                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                                        children: [
                                                          pw.Row(
                                                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              pw.Text("CONTROL NO : $controlNo", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                                              if (savedDate.isNotEmpty)
                                                                pw.Text("Date: $savedDate", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                                            ],
                                                          ),
                                                          pw.SizedBox(height: 6),
                                                          pw.Text("Date Needed : $dateNeeded", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              pw.SizedBox(height: 15),
                                            ],
                                            pw.Text("Requested Items List (Page ${pageIndex + 1} of ${printItemChunks.length}):", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                            pw.SizedBox(height: 6),
                                            pw.Table.fromTextArray(
                                              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                                              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                                              cellStyle: const pw.TextStyle(fontSize: 8.5),
                                              cellAlignment: pw.Alignment.centerLeft,
                                              headers: ['Code', 'Item Description', 'Quantity', 'Unit', 'Remark'],
                                              data: chunk.map((item) {
                                                final data = item is Map<String, dynamic> ? item : {};
                                                return [
                                                  data['itemCode']?.toString() ?? '',
                                                  data['name']?.toString() ?? '',
                                                  data['quantity']?.toString() ?? '-',
                                                  data['unit']?.toString() ?? '-',
                                                  data['remark']?.toString() ?? '-',
                                                ];
                                              }).toList(),
                                            ),
                                            pw.Spacer(), // 👈 এটি সিগনেচার সেকশনকে সবসময় পেজের একদম নিচে সুন্দরভাবে ফিক্সড রাখবে
                                            pw.Divider(color: PdfColors.grey300),
                                            pw.SizedBox(height: 5),
                                            pw.Row(
                                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                              children: [
                                                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                                  pw.Text("Requested by", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                                  pw.SizedBox(height: 15),
                                                  pw.Text("ID: ${currentRequestData['adminId'] ?? 'N/A'}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                                ]),
                                                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                                  pw.Text("Verified by", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                                  pw.SizedBox(height: 15),
                                                  pw.Text((currentRequestData['verifiedBy']?.toString() ?? '').isNotEmpty ? "Signed" : "Pending", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                                ]),
                                                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                                  pw.Text("Approved by", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                                  pw.SizedBox(height: 15),
                                                  pw.Text((currentRequestData['approvedBy']?.toString() ?? '').isNotEmpty ? "Signed" : "Pending", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                                ]),
                                                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                                  pw.Text("Received by", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                                  pw.SizedBox(height: 15),
                                                  pw.Text((currentRequestData['receivedBy']?.toString() ?? '').isNotEmpty ? "Signed" : "Pending", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                                ]),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                }

                                // ==========================================================
                                // ২. ইমেজ গ্যালারি পেজগুলো রেন্ডার করার অংশ (প্রতি পেজে ২৪টি করে ইমেজ)
                                // ==========================================================
                                for (int imgPageIndex = 0; imgPageIndex < printImageChunks.length; imgPageIndex++) {
                                  final imgChunk = printImageChunks[imgPageIndex];
                                  final List<pw.Widget> printImageWidgets = [];

                                  for (var item in imgChunk) {
                                    final data = item is Map<String, dynamic> ? item : {};
                                    final String itemCode = data['itemCode']?.toString() ?? '';
                                    final String? imageUrl = data['imageUrl']?.toString();
                                    final Uint8List? imgBytes = (imageUrl != null && imageUrl.isNotEmpty) ? imageBytesCache[imageUrl] : null;

                                    printImageWidgets.add(
                                      pw.Container(
                                        padding: const pw.EdgeInsets.all(3),
                                        decoration: pw.BoxDecoration(
                                          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                                          borderRadius: pw.BorderRadius.circular(3),
                                        ),
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                                          mainAxisAlignment: pw.MainAxisAlignment.center,
                                          children: [
                                            pw.Expanded(
                                              child: imgBytes != null
                                                  ? pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.contain)
                                                  : pw.Center(
                                                child: pw.Text("No Image", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                                              ),
                                            ),
                                            pw.SizedBox(height: 2),
                                            pw.Text(
                                              itemCode,
                                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blue900),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  pdfDoc.addPage(
                                    pw.Page(
                                      pageFormat: format,
                                      margin: const pw.EdgeInsets.all(24), // মার্জিন একটু কমিয়ে দেওয়া হয়েছে যাতে ২৪টি ইমেজ A4 পেজে পারফেক্টলি বসে
                                      build: (pw.Context context) {
                                        return pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text(
                                              "Requested Items Images Gallery (Page ${imgPageIndex + 1} of ${printImageChunks.length}):",
                                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                                            ),
                                            pw.SizedBox(height: 8),
                                            pw.Expanded(
                                              child: pw.GridView(
                                                crossAxisCount: 4, // প্রতি লাইনে ৪টি করে ইমেজ (মোট ২৪টি ইমেজ প্রতি পেজে সুন্দরভাবে সাজানো থাকবে)
                                                crossAxisSpacing: 8,
                                                mainAxisSpacing: 8,
                                                childAspectRatio: 0.95,
                                                children: printImageWidgets,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                }

                                return pdfDoc.save();
                              },
                            );

                          }
                        } catch (e) {
                          print("Error during PDF download/print: $e");
                        } finally {
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Download PDF / Print", style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
// =========================================================
// STOCK REQUEST PREVIEW & PRINT PAGE (PRF Letter Head Shathe Mill Rekhe Updated)
// =========================================================

class WebStockRequestPreviewPage extends StatefulWidget {
  final String adminId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> toolDocs;

  const WebStockRequestPreviewPage({
    super.key,
    required this.adminId,
    required this.toolDocs,
  });

  @override
  State<WebStockRequestPreviewPage> createState() => _WebStockRequestPreviewPageState();
}

class _WebStockRequestPreviewPageState extends State<WebStockRequestPreviewPage> {
  String generatedPrfNo = "PRF NO - LOADING...";

  @override
  void initState() {
    super.initState();
    _fetchCurrentPrfNumber();
  }

  Future<void> _fetchCurrentPrfNumber() async {
    try {
      final counterRef = FirebaseFirestore.instance.collection('settings').doc('prf_counter');
      final snapshot = await counterRef.get();
      int currentNo = 1000000;

      if (snapshot.exists) {
        currentNo = snapshot.data()?['lastPrfNo'] ?? 1000000;
        currentNo = currentNo + 1;
      } else {
        currentNo = 1000001;
      }

      setState(() {
        generatedPrfNo = "PRF NO - $currentNo";
      });
    } catch (e) {
      setState(() {
        generatedPrfNo = "PRF NO - 1000001";
      });
    }
  }

  // ২৪টি করে আইটেম বা ইমেজ পিস করার হেল্পার ফাংশন
  List<List<dynamic>> _chunkList(List<dynamic> list, int chunkSize) {
    List<List<dynamic>> chunks = [];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    final String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final filteredTools = widget.toolDocs.where((doc) {
      final data = doc.data();
      final qty = data['quantity']?.toString().trim() ?? '';
      return qty.isNotEmpty && qty != '-' && qty != '0';
    }).toList();

    // 👈 Ekhane rawItemsData toiri hobar por itemCode onujayi ascending order- e sort kore newa holo
    final List<Map<String, dynamic>> rawItemsData = filteredTools.map((doc) => doc.data()).toList();
    rawItemsData.sort((a, b) {
      final codeA = int.tryParse(a['itemCode']?.toString() ?? '0') ?? 0;
      final codeB = int.tryParse(b['itemCode']?.toString() ?? '0') ?? 0;
      return codeA.compareTo(codeB);
    });

    final itemChunks = _chunkList(rawItemsData, 24);
    final imageChunks = _chunkList(rawItemsData, 24);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000080),
        title: const Text(
          "Stock Request Preview",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        child: Center(
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('employees').doc(widget.adminId).get(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final adminData = adminSnapshot.data?.data() ?? {};
              final String companyId = adminData['companyId'] ?? adminData['company'] ?? '';

              var prfQuery = FirebaseFirestore.instance.collection('prf_letter_heads').limit(1);
              if (companyId.isNotEmpty) {
                prfQuery = FirebaseFirestore.instance.collection('prf_letter_heads').where('companyId', isEqualTo: companyId).limit(1);
              }

              return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: prfQuery.get(),
                builder: (context, prfSnapshot) {
                  if (prfSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final prfDocs = prfSnapshot.data?.docs ?? [];
                  Map<String, dynamic> prfData = {};
                  if (prfDocs.isNotEmpty) {
                    prfData = prfDocs.first.data();
                  }

                  final String companyName = prfData['companyName']?.toString() ?? 'MACDOWELL OFFSHORE ENGINEERING PET. LTD.';
                  final String address = prfData['address']?.toString() ?? '3 SOONLE STREET #01-05, SINGAPORE 627606';
                  String rawRegNo = prfData['regNo']?.toString() ?? '200804295k';
                  rawRegNo = rawRegNo.replaceAll('Company Reg.no.', '').replaceAll(':', '').trim();
                  final String regNo = rawRegNo;

                  String rawPhone = prfData['phone']?.toString() ?? '+65 67104933 , 6710 4934';
                  rawPhone = rawPhone.replaceAll('phone', '').replaceAll('Phone', '').replaceAll(':', '').trim();
                  final String phone = "phone $rawPhone";

                  String rawFax = prfData['fax']?.toString() ?? '+65 6659 6929';
                  rawFax = rawFax.replaceAll('Fax', '').replaceAll('fax', '').replaceAll(':', '').trim();
                  final String fax = "Fax : $rawFax";

                  String rawEmail = prfData['email']?.toString() ?? 'arifulislam0@gmail.com';
                  rawEmail = rawEmail.replaceAll('Mail', '').replaceAll('mail', '').replaceAll('Email', '').replaceAll(':', '').trim();
                  final String email = "Mail : $rawEmail";

                  String rawWebsite = prfData['website']?.toString() ?? '';
                  rawWebsite = rawWebsite.replaceAll('Website', '').replaceAll('website', '').replaceAll(':', '').trim();
                  final String website = "Website : $rawWebsite";

                  final String department = prfData['department']?.toString() ?? 'PIPING';
                  final String purpose = prfData['purpose']?.toString() ?? 'TO BE USE FOR PRODUCTION & OFFICIAL';
                  final String controlNo = prfData['controlNo']?.toString() ?? 'PRF-SBMME';
                  final String dateNeeded = prfData['dateNeeded']?.toString() ?? 'ASAP';
                  final String? logoUrl = prfData['logoUrl']?.toString().trim();

                  return Column(
                    children: [
                      // ১. আইটেম পেজগুলোর ইউআই প্রিভিউ (প্রতি পেজে ২৪টি করে)
                      for (int pageIndex = 0; pageIndex < itemChunks.length; pageIndex++) ...[
                        Container(
                          constraints: const BoxConstraints(
                            maxWidth: 1000,
                            minHeight: 1414,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (pageIndex == 0) ...[
                                    Table(
                                      border: const TableBorder.symmetric(inside: BorderSide.none, outside: BorderSide.none),
                                      columnWidths: const {
                                        0: FixedColumnWidth(160),
                                        1: FlexColumnWidth(),
                                        2: FixedColumnWidth(80),
                                      },
                                      children: [
                                        TableRow(
                                          children: [
                                            Container(
                                              height: 130,
                                              alignment: Alignment.center,
                                              color: Colors.white,
                                              child: (logoUrl != null && logoUrl.isNotEmpty)
                                                  ? Padding(
                                                padding: const EdgeInsets.all(4.0),
                                                child: Image.network(
                                                  logoUrl,
                                                  fit: BoxFit.contain,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.apartment, size: 50, color: Color(0xFF000080)),
                                                ),
                                              )
                                                  : const Icon(Icons.apartment, size: 50, color: Color(0xFF000080)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(companyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  Text(address, style: const TextStyle(fontSize: 12)),
                                                  const SizedBox(height: 2),
                                                  Text("Company Reg.no. : $regNo", style: const TextStyle(fontSize: 12)),
                                                  const SizedBox(height: 2),
                                                  Wrap(
                                                    spacing: 20,
                                                    children: [
                                                      Text(phone, style: const TextStyle(fontSize: 12)),
                                                      Text(fax, style: const TextStyle(fontSize: 12)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Wrap(
                                                    spacing: 20,
                                                    children: [
                                                      Text(email, style: const TextStyle(fontSize: 12)),
                                                      Text(website, style: const TextStyle(fontSize: 12)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              alignment: Alignment.topRight,
                                              child: QrImageView(
                                                data: "PRF No: $generatedPrfNo, Control No: $controlNo, Date: $currentDate",
                                                version: QrVersions.auto,
                                                size: 100,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const SizedBox(width: 140),
                                        const Text(
                                          "PURCHASE REQUISITION FORM",
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF000080).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            generatedPrfNo,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Table(
                                      border: const TableBorder(
                                        horizontalInside: BorderSide(color: Colors.black, width: 1),
                                        verticalInside: BorderSide(color: Colors.black, width: 1),
                                        top: BorderSide(color: Colors.black, width: 1),
                                        bottom: BorderSide(color: Colors.black, width: 1),
                                        left: BorderSide(color: Colors.black, width: 1),
                                        right: BorderSide(color: Colors.black, width: 1),
                                      ),
                                      columnWidths: const {
                                        0: FlexColumnWidth(2),
                                        1: FlexColumnWidth(1.2),
                                      },
                                      children: [
                                        TableRow(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Department : $department", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                  const SizedBox(height: 8),
                                                  Text("PURPOSE : $purpose", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text("CONTROL NO : $controlNo", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                      Text("Date: $currentDate", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF000080))),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text("Date Needed : $dateNeeded", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 25),
                                  ],
                                  Text(
                                    "Requested Items List (Page ${pageIndex + 1} of ${itemChunks.length}):",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                                  ),
                                  const SizedBox(height: 10),
                                  Table(
                                    border: TableBorder.all(color: Colors.grey.shade400),
                                    columnWidths: const {
                                      0: FlexColumnWidth(0.8),
                                      1: FlexColumnWidth(4.5),
                                      2: FlexColumnWidth(0.9),
                                      3: FlexColumnWidth(0.8),
                                      4: FlexColumnWidth(1.0),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(color: const Color(0xFF000080).withOpacity(0.08)),
                                        children: const [
                                          Padding(padding: EdgeInsets.all(10), child: Text("Code", style: TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: EdgeInsets.all(10), child: Text("Item Description", style: TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: EdgeInsets.all(10), child: Text("Quantity", style: TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: EdgeInsets.all(10), child: Text("Unit", style: TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: EdgeInsets.all(10), child: Text("Remark", style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      ...itemChunks[pageIndex].map((item) {
                                        final String itemCode = item['itemCode']?.toString() ?? '';
                                        final String itemName = item['name']?.toString() ?? '';
                                        final String qty = item['quantity']?.toString() ?? '-';
                                        final String unit = item['unit']?.toString() ?? '-';
                                        final String remark = item['remark']?.toString() ?? '-';

                                        return TableRow(
                                          children: [
                                            Padding(padding: const EdgeInsets.all(10), child: Text(itemCode)),
                                            Padding(padding: const EdgeInsets.all(10), child: Text(itemName)),
                                            Padding(padding: const EdgeInsets.all(10), child: Text(qty)),
                                            Padding(padding: const EdgeInsets.all(10), child: Text(unit)),
                                            Padding(padding: const EdgeInsets.all(10), child: Text(remark)),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                              Table(
                                border: const TableBorder.symmetric(
                                  inside: BorderSide.none,
                                  outside: BorderSide.none,
                                ),
                                columnWidths: const {
                                  0: FlexColumnWidth(1),
                                  1: FlexColumnWidth(1),
                                  2: FlexColumnWidth(1),
                                  3: FlexColumnWidth(1),
                                },
                                children: [
                                  TableRow(
                                    children: [
                                      _buildRequesterSignatureColumn(widget.adminId),
                                      _buildSignatureColumn("Verified by"),
                                      _buildSignatureColumn("Approved by"),
                                      _buildSignatureColumn("Received by"),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],

                      // ২. ইমেজ গ্যালারি পেজগুলোর ইউআই প্রিভিউ (প্রতি পেজে সর্বোচ্চ ২৪টি ছবি)
                      for (int imgPageIndex = 0; imgPageIndex < imageChunks.length; imgPageIndex++) ...[
                        Container(
                          constraints: const BoxConstraints(
                            maxWidth: 1000,
                            minHeight: 1414,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Requested Items Images Gallery (Page ${imgPageIndex + 1} of ${imageChunks.length}):",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF000080),
                                ),
                              ),
                              const SizedBox(height: 20),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: imageChunks[imgPageIndex].length,
                                itemBuilder: (context, index) {
                                  final item = imageChunks[imgPageIndex][index];
                                  final String itemCode = item['itemCode']?.toString() ?? '';
                                  final String? imageUrl = item['imageUrl']?.toString();

                                  return Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: imageUrl != null && imageUrl.isNotEmpty
                                              ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            width: double.infinity,
                                            errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                          )
                                              : const Icon(Icons.image, size: 50, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          itemCode,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF000080),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],

                      const SizedBox(height: 25),
                      SizedBox(
                        width: 1000,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              // Loading dialog shuru
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    child: const Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(color: Color(0xFF000080)),
                                          SizedBox(width: 20),
                                          Text("Submitting Stock Request...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );

                              int finalNo = 1000001;
                              try {
                                final counterRef = FirebaseFirestore.instance.collection('settings').doc('prf_counter');
                                await FirebaseFirestore.instance.runTransaction((transaction) async {
                                  final snapshot = await transaction.get(counterRef);
                                  if (snapshot.exists) {
                                    finalNo = (snapshot.data()?['lastPrfNo'] ?? 1000000) + 1;
                                  } else {
                                    finalNo = 1000001;
                                  }
                                  transaction.set(counterRef, {'lastPrfNo': finalNo}, SetOptions(merge: true));
                                });
                              } catch (e) {
                                finalNo = 1000001;
                              }

                              final String realPrfNo = "PRF NO - $finalNo";

                              // Firestore-e sorted rawItemsData save kora hocche jate database-eo sothik serial thake
                              await FirebaseFirestore.instance.collection('stock_requests').add({
                                'prfNo': realPrfNo,
                                'adminId': widget.adminId,
                                'createdAt': FieldValue.serverTimestamp(),
                                'items': rawItemsData, // 👈 Sothik serial kora data save hobe
                              });

                              // Tool gular quantity dash (-) kore update kora
                              for (var doc in widget.toolDocs) {
                                await doc.reference.update({
                                  'quantity': '-',
                                  'unit': '-',
                                  'remark': '-',
                                });
                              }

                              if (!mounted) return;
                              Navigator.pop(context); // Loading dialog bondho

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Stock request submitted successfully with $realPrfNo!"), backgroundColor: Colors.green),
                              );

                              // Sob kaj sheshe Approved Request page ba ager page-e fire jaowa
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text("Final Submit & Print", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRequesterSignatureColumn(String requesterId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('employees').doc(requesterId).get(),
        builder: (context, snapshot) {
          String empName = "";
          String empId = requesterId;
          String designation = "";

          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() ?? {};
            empName = data['name']?.toString() ?? "";
            empId = data['id']?.toString() ?? requesterId;
            designation = data['designation']?.toString() ?? "";
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Requested by",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (empName.isNotEmpty)
                Text(empName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
              if (empId.isNotEmpty)
                Text("ID: $empId", style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              if (designation.isNotEmpty)
                Text(designation, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              const SizedBox(height: 35),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSignatureColumn(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }
}

class WebAdminHome extends StatefulWidget {
  final String adminId;

  const WebAdminHome({super.key, required this.adminId});

  @override
  State<WebAdminHome> createState() => _WebAdminHomeState();
}

class _WebAdminHomeState extends State<WebAdminHome> {
  Widget? _currentPage;
  Map<String, bool> userPermissions = {};
  bool isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _fetchUserPermissions();
  }

  Future<void> _fetchUserPermissions() async {
    if (widget.adminId == "M-355") {
      setState(() => isLoadingPermissions = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('employees').doc(widget.adminId).get();
      if (doc.exists && doc.data()!.containsKey('permissions')) {
        final saved = Map<String, dynamic>.from(doc.data()!['permissions']);
        setState(() => userPermissions = saved.map((k, v) => MapEntry(k, v == true)));
      }
    } catch (_) {}
    setState(() => isLoadingPermissions = false);
  }

  @override
  Widget build(BuildContext context) {
    final String adminId = widget.adminId;
    bool isMaster = adminId == "M-355";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(82),
        child: Container(
          color: const Color(0xFF000080),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const SizedBox(
                    width: 250,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("SBM GROUP OF COMPANNY", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 3),
                        Text("Admin Control Panel", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _headerButton(context, "Home", Icons.home, adminId),
                            PopupMenuButton<String>(
                              tooltip: "Administration",
                              offset: const Offset(0, 45),
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                if (value == "managePermissions") {
                                  setState(() => _currentPage = const WebPermissionManagementPage());
                                  return;
                                }
                                if (value == "permissionControl") {
                                  setState(() => _currentPage = const WebPermissionControlPage());
                                  return;
                                }
                                if (value == "centerCreate") {
                                  setState(() => _currentPage = const WebCenterCreatePage());
                                  return;
                                }
                                if (value == "attendance") {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Attendance page will be connected next.")));
                                  return;
                                }
                                if (value == "settings") {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings page will be connected next.")));
                                  return;
                                }
                              },
                              itemBuilder: (context) {
                                List<PopupMenuItem<String>> items = [];
                                if (isMaster || userPermissions['manage_permissions'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "managePermissions", child: Row(children: [Icon(Icons.admin_panel_settings, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Manage Permissions", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['permission_control'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "permissionControl", child: Row(children: [Icon(Icons.security, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Permission Control", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['center_create'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "centerCreate", child: Row(children: [Icon(Icons.add_business, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Center Create", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['attendance_mgmt'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "attendance", child: Row(children: [Icon(Icons.camera_alt, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Attendance", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['settings_mgmt'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "settings", child: Row(children: [Icon(Icons.settings, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Settings", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                return items;
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text("Administration", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 3),
                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: "All Report",
                              offset: const Offset(0, 45),
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                if (value == "attendanceReport") { _openHeaderPage(context, "HISTORY", adminId); return; }
                                if (value == "dailyProgressReport") { _openHeaderPage(context, "DAILY PROGRESS", adminId); return; }
                                if (value == "toolsReport") { setState(() => _currentPage = WebToolsReportPage(adminId: adminId)); return; }
                                if (value == "materialReport") { _openHeaderPage(context, "MATERIAL", adminId); return; }
                                if (value == "history") { _openHeaderPage(context, "HISTORY", adminId); return; }
                              },
                              itemBuilder: (context) {
                                List<PopupMenuItem<String>> items = [];
                                if (isMaster || userPermissions['attendance_report'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "attendanceReport", child: Row(children: [Icon(Icons.fact_check, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Attendance Report", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['daily_progress_report'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "dailyProgressReport", child: Row(children: [Icon(Icons.trending_up, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Daily Progress Report", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['tools_report'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "toolsReport", child: Row(children: [Icon(Icons.build, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Tools Report", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['material_report'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "materialReport", child: Row(children: [Icon(Icons.inventory_2, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Material Report", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['history_report'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "history", child: Row(children: [Icon(Icons.history, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("History", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                return items;
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.assessment, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text("All Report", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 3),
                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: "Employee Portal",
                              offset: const Offset(0, 45),
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                if (value == "allEmployees") {
                                  setState(() => _currentPage = WebAllEmployeesPage(onEmployeeTap: (employeeData) { setState(() => _currentPage = WebEmployeeDetailsPage(employeeData: employeeData, onBack: () => setState(() => _currentPage = const WebAllEmployeesPage()))); }));
                                  return;
                                }
                                if (value == "addEmployee") {
                                  setState(() => _currentPage = const WebAddEmployeePage());
                                  return;
                                }
                                if (value == "manager") {
                                  setState(() => _currentPage = WebAllEmployeesPage(roleFilter: "manager", onEmployeeTap: (employeeData) { setState(() => _currentPage = WebEmployeeDetailsPage(employeeData: employeeData, onBack: () => setState(() => _currentPage = WebAllEmployeesPage(roleFilter: "manager")))); }));
                                  return;
                                }
                                if (value == "admin") {
                                  setState(() => _currentPage = const WebAllEmployeesPage(roleFilter: "admin"));
                                  return;
                                }
                              },
                              itemBuilder: (context) {
                                List<PopupMenuItem<String>> items = [];
                                if (isMaster || userPermissions['all_employees'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "allEmployees", child: Row(children: [Icon(Icons.people, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("All Employees", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['add_employee'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "addEmployee", child: Row(children: [Icon(Icons.person_add, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Add Employee", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['manager_portal'] == true) {
                                  items.add(const PopupMenuItem(value: "manager", child: Row(children: [Icon(Icons.supervisor_account, color: Color(0xFF000080)), SizedBox(width: 10), Text("Manager")])));
                                }
                                if (isMaster || userPermissions['admin_portal'] == true) {
                                  items.add(const PopupMenuItem(value: "admin", child: Row(children: [Icon(Icons.admin_panel_settings, color: Color(0xFF000080)), SizedBox(width: 10), Text("Admin")])));
                                }
                                return items;
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_alt, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text("Employee Portal", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 3),
                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            if (isMaster || userPermissions['all_project'] == true)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() => _currentPage = WebAllProjectsPage(onProjectTap: (projectData, projectId) { setState(() => _currentPage = WebAllProjectDetailsScreen(projectData: projectData, projectId: projectId, onTestPackageTap: (testPackageId, testPackageName) { setState(() => _currentPage = TestPackageDetailScreen(projectId: projectId, testPackageId: testPackageId, testPackageName: testPackageName, allowDelete: false)); })); }));
                                  },
                                  style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  icon: const Icon(Icons.business_center, size: 16),
                                  label: const Text("All Project", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('employees').doc(adminId).get(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      final String name = data?['name']?.toString() ?? "Admin";
                      final String? imageUrl = data?['profileImageUrl']?.toString();
                      return InkWell(
                        onTap: () => _showAdminMenu(context, data, adminId),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              imageUrl != null && imageUrl.isNotEmpty ? NetworkImageWebFix(imageUrl: imageUrl, radius: 19) : const CircleAvatar(radius: 19, backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xFF000080))),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(width: 5),
                              const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _currentPage ?? const SizedBox(),
    );
  }
}

//============================================================
//MANAGE CONTROL PAGE
//============================================================

class WebEmployeePermissionDetailPage extends StatefulWidget {
  final Map<String, dynamic> employeeData;
  final String employeeDocId;

  const WebEmployeePermissionDetailPage({
    super.key,
    required this.employeeData,
    required this.employeeDocId,
  });

  @override
  State<WebEmployeePermissionDetailPage> createState() => _WebEmployeePermissionDetailPageState();
}

class _WebEmployeePermissionDetailPageState extends State<WebEmployeePermissionDetailPage> {
  final Map<String, List<Map<String, dynamic>>> appModules = {
    "Employee Portal": [
      {"name": "All Employees", "key": "all_employees"},
      {"name": "Add Employee", "key": "add_employee"},
      {"name": "Manager Portal", "key": "manager_portal"},
      {"name": "Admin Portal", "key": "admin_portal"},
    ],
    "All Report": [
      {"name": "Attendance Report", "key": "attendance_report"},
      {"name": "Daily Progress Report", "key": "daily_progress_report"},
      {"name": "Tools Report", "key": "tools_report"},
      {"name": "Material Report", "key": "material_report"},
      {"name": "History", "key": "history_report"},
    ],
    "Administration": [
      {"name": "Manage Permissions", "key": "manage_permissions"},
      {"name": "Permission Control", "key": "permission_control"},
      {"name": "Center Create", "key": "center_create"},
      {"name": "Attendance", "key": "attendance_mgmt"},
      {"name": "Settings", "key": "settings_mgmt"},
    ],
    "Projects & Tools": [
      {"name": "All Project", "key": "all_project"},
      {"name": "Tools Management", "key": "tools_management"},
      {"name": "Stock Request", "key": "stock_request"},
      {"name": "Approved Request", "key": "approved_request"},
      {"name": "PRF Letter Head", "key": "prf_letter_head"},
    ],
  };

  Map<String, bool> permissions = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
  }

  Future<void> _loadUserPermissions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeDocId)
          .get();

      if (doc.exists && doc.data()!.containsKey('permissions')) {
        final savedPermissions = Map<String, dynamic>.from(doc.data()!['permissions']);
        setState(() {
          permissions = savedPermissions.map((key, value) => MapEntry(key, value == true));
        });
      }
    } catch (_) {}
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _updatePermission(String key, bool value) async {
    setState(() {
      permissions[key] = value;
    });

    try {
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeDocId)
          .set({
        'permissions': permissions,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permission updated successfully!"), duration: Duration(milliseconds: 800), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.employeeData['name']?.toString() ?? 'Unknown User';
    final String id = widget.employeeData['id']?.toString() ?? '';
    final String designation = widget.employeeData['designation']?.toString() ?? 'N/A';
    final String role = widget.employeeData['role']?.toString().toUpperCase() ?? 'WORKER';
    final String? imageUrl = widget.employeeData['profileImageUrl']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000080),
        title: Text("Permissions for $name", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF000080)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      imageUrl != null && imageUrl.isNotEmpty
                          ? NetworkImageWebFix(imageUrl: imageUrl, radius: 30)
                          : const CircleAvatar(radius: 30, backgroundColor: Color(0xFFE8EAF6), child: Icon(Icons.person, size: 35, color: Color(0xFF000080))),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("ID: $id | Designation: $designation | Role: $role", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  "App Modules & Button Access Control",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                ),
                const SizedBox(height: 15),
                ...appModules.entries.map((entry) {
                  String sectionName = entry.key;
                  List<Map<String, dynamic>> buttons = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sectionName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                        ),
                        const Divider(height: 20),
                        ...buttons.map((btn) {
                          String btnName = btn['name'];
                          String btnKey = btn['key'];
                          bool isGranted = permissions[btnKey] ?? false;

                          return SwitchListTile(
                            title: Text(btnName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                            subtitle: Text("Access to $btnName", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            value: isGranted,
                            activeColor: const Color(0xFF000080),
                            onChanged: (val) {
                              _updatePermission(btnKey, val);
                            },
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WebPermissionControlPage extends StatefulWidget {
  const WebPermissionControlPage({super.key});

  @override
  State<WebPermissionControlPage> createState() => _WebPermissionControlPageState();
}

class _WebPermissionControlPageState extends State<WebPermissionControlPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Permission Control Panel - Managers List",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000080),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                // 👇 Shudhu jader role 'manager' ba 'MANAGER', tader-kei query kora hocche
                stream: FirebaseFirestore.instance
                    .collection('employees')
                    .where('role', isEqualTo: 'manager')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF000080)));
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No managers found!",
                        style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final String id = data['id']?.toString() ?? doc.id;
                      final String name = data['name']?.toString() ?? 'No Name';
                      final String designation = data['designation']?.toString() ?? 'N/A';
                      final String role = data['role']?.toString().toUpperCase() ?? 'MANAGER';
                      final String? imageUrl = data['profileImageUrl']?.toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WebEmployeePermissionDetailPage(
                                  employeeData: data,
                                  employeeDocId: doc.id,
                                ),
                              ),
                            );
                          },
                          leading: imageUrl != null && imageUrl.isNotEmpty
                              ? NetworkImageWebFix(imageUrl: imageUrl, radius: 24)
                              : const CircleAvatar(
                            radius: 24,
                            backgroundColor: Color(0xFFE8EAF6),
                            child: Icon(Icons.person, color: Color(0xFF000080)),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text("ID: $id | Designation: $designation | Role: $role"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF000080).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080), fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//============================================================
//MANAGE CONTROL PAGE (FINISH)
//============================================================

Widget _headerButton(
  BuildContext context,
  String title,
  IconData icon,
  String adminId,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: TextButton.icon(
      onPressed: () {
        _openHeaderPage(context, title, adminId);
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: Icon(
        icon,
        size: 16,
      ),
      label: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

void _openHeaderPage(
  BuildContext context,
  String title,
  String adminId,
) {
  if (title == "ALL EMPLOYEES") {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WebAllEmployeesPage(),
      ),
    );
    return;
  }

  if (title == "ADD EMPLOYEE") {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WebAddEmployeePage()),
    );
    return;
  }
  if (title == "Home") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WebAdminHome(
          adminId: adminId,
        ),
      ),
    );
    return;
  }

  if (title == "Administration") {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WebPermissionManagementPage(),
      ),
    );
    return;
  }

  if (title == "All Report") {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebAllAttendanceReportPage(
          adminId: adminId,
        ),
      ),
    );
    return;
  }

  if (title == "Employee Portal") {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WebAllEmployeesPage(),
      ),
    );
    return;
  }
  if (title == "HISTORY") {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebHistoryPage(
          adminId: adminId,
        ),
      ),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        "$title page will be connected next.",
      ),
    ),
  );
}

void _showAdminMenu(
    BuildContext context,
    Map<String, dynamic>? data,
    String adminId,
    ) {
  final String name = data?['name']?.toString() ?? "Admin";

  final String role = data?['role']?.toString() ?? "admin";

  final String? imageUrl = data?['profileImageUrl']?.toString();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.only(
          top: 85,
          right: 25,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 👇 এখানে NetworkImageWebFix উইজেট বসানো হলো
                imageUrl != null && imageUrl.isNotEmpty
                    ? NetworkImageWebFix(
                  imageUrl: imageUrl!,
                  radius: 46,
                )
                    : const CircleAvatar(
                  radius: 46,
                  backgroundColor: Color(0xFFE8EAF6),
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: Color(0xFF000080),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$adminId • ${role.toUpperCase()}",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // প্রথমে পপআপ মেনু বন্ধ করা হচ্ছে
                          Navigator.pop(dialogContext);

                          // সরাসরি ডিটেইলড প্রফাইল এডিট পেজে নিয়ে যাওয়া হচ্ছে[cite: 10]
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WebAdminProfileEditPage(
                                adminId: adminId,
                                initialData: data,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person),
                        label: const Text("PROFILE"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WebAdminLoginPage(),
                            ),
                                (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "LOG OUT",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
// =====================================================
// ADMIN PROFILE EDIT PAGE CLASS (WITH FULL HEADER MENUS)
// =====================================================

// 1. MINE PAGE ADMIN PROFILE

class WebAdminProfileEditPage extends StatefulWidget {
  final String adminId;
  final Map<String, dynamic>? initialData;

  const WebAdminProfileEditPage({
    super.key,
    required this.adminId,
    this.initialData,
  });

  @override
  State<WebAdminProfileEditPage> createState() => _WebAdminProfileEditPageState();
}

class _WebAdminProfileEditPageState extends State<WebAdminProfileEditPage> {
  String selectedTab = "Personal";
  bool _isUpdating = false;

  late String selectedEmployeeId;
  late String currentStaffName;

  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _tinController = TextEditingController();
  final TextEditingController _nidController = TextEditingController();
  final TextEditingController _passportController = TextEditingController();
  final TextEditingController _spouseMobileController = TextEditingController();
  final TextEditingController _birthCertController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _spouseNameController = TextEditingController();

  final TextEditingController _houseNameController = TextEditingController();
  final TextEditingController _houseBlockController = TextEditingController();
  final TextEditingController _houseLevelController = TextEditingController();
  final TextEditingController _houseRoomController = TextEditingController();

  final TextEditingController _offMobileController = TextEditingController();
  final TextEditingController _offPhoneController = TextEditingController();
  final TextEditingController _offEmailController = TextEditingController();
  final TextEditingController _faxController = TextEditingController();
  final TextEditingController _skypeController = TextEditingController();
  final TextEditingController _perMobileController = TextEditingController();
  final TextEditingController _perPhoneController = TextEditingController();
  final TextEditingController _perEmailController = TextEditingController();
  final TextEditingController _presPostcodeController = TextEditingController();
  final TextEditingController _presAddressController = TextEditingController();
  final TextEditingController _permPostcodeController = TextEditingController();
  final TextEditingController _permAddressController = TextEditingController();

  final TextEditingController _emgNameController = TextEditingController();
  final TextEditingController _emgMobileController = TextEditingController();
  final TextEditingController _emgPhoneController = TextEditingController();
  final TextEditingController _emgEmailController = TextEditingController();
  final TextEditingController _emgAddressController = TextEditingController();

  String _religion = "Islam";
  String _nationality = "New Zealand";
  String _bloodGroup = "A+";
  String _gender = "Male";
  String _maritalStatus = "Unmarried";
  String _spouseProfession = "Farmer";
  String _emailNotification = "NO";
  String _foodFacility = "Supply own";

  String _presCountry = "Bangladesh";
  String _presDivision = "Sylhet";
  String _presDistrict = "Habiganj";
  String _presThana = "Sayestaganj";

  String _permCountry = "Bangladesh";
  String _permDivision = "Rangpur";
  String _permDistrict = "Rangpur";
  String _permThana = "Rangpur Sadar";
  String _emgRelation = "Father";

  Map<String, bool> userPermissions = {};
  bool isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    selectedEmployeeId = widget.adminId;
    currentStaffName = widget.initialData?['name']?.toString() ?? 'Admin User';
    _loadInitialData(widget.initialData);
    _fetchUserPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserPermissions() async {
    if (widget.adminId == "M-355") {
      setState(() => isLoadingPermissions = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('employees').doc(widget.adminId).get();
      if (doc.exists && doc.data()!.containsKey('permissions')) {
        final saved = Map<String, dynamic>.from(doc.data()!['permissions']);
        setState(() => userPermissions = saved.map((k, v) => MapEntry(k, v == true)));
      }
    } catch (_) {}
    setState(() => isLoadingPermissions = false);
  }

  void _loadInitialData(Map<String, dynamic>? data) {
    if (data != null) {
      _tinController.text = data['tin']?.toString() ?? '';
      _nidController.text = data['nid']?.toString() ?? '';
      _passportController.text = data['passport']?.toString() ?? '';
      _spouseMobileController.text = data['spouseMobile']?.toString() ?? '';
      _birthCertController.text = data['birthCertificateId']?.toString() ?? '';
      _dobController.text = data['dob']?.toString() ?? '01/10/1994';
      _spouseNameController.text = data['spouseName']?.toString() ?? '';

      _houseNameController.text = data['houseName']?.toString() ?? '';
      _houseBlockController.text = data['houseBlock']?.toString() ?? '';
      _houseLevelController.text = data['houseLevel']?.toString() ?? '';
      _houseRoomController.text = data['houseRoom']?.toString() ?? '';

      _religion = data['religion']?.toString() ?? 'Islam';
      _nationality = data['nationality']?.toString() ?? 'New Zealand';
      _bloodGroup = data['bloodGroup']?.toString() ?? 'A+';
      _gender = data['gender']?.toString() ?? 'Male';
      _maritalStatus = data['maritalStatus']?.toString() ?? 'Unmarried';
      _spouseProfession = data['spouseProfession']?.toString() ?? 'Farmer';
      _foodFacility = data['foodFacility']?.toString() ?? 'Supply own';

      _offMobileController.text = data['offMobile']?.toString() ?? '';
      _offPhoneController.text = data['offPhone']?.toString() ?? '';
      _offEmailController.text = data['offEmail']?.toString() ?? '';
      _faxController.text = data['fax']?.toString() ?? '';
      _skypeController.text = data['skype']?.toString() ?? '';
      _perMobileController.text = data['perMobile']?.toString() ?? '';
      _perPhoneController.text = data['perPhone']?.toString() ?? '';
      _perEmailController.text = data['perEmail']?.toString() ?? '';
      _presPostcodeController.text = data['presPostcode']?.toString() ?? '';
      _presAddressController.text = data['presAddress']?.toString() ?? '';
      _permPostcodeController.text = data['permPostcode']?.toString() ?? '';
      _permAddressController.text = data['permAddress']?.toString() ?? '';

      _emgNameController.text = data['emgName']?.toString() ?? '';
      _emgMobileController.text = data['emgMobile']?.toString() ?? '';
      _emgPhoneController.text = data['emgPhone']?.toString() ?? '';
      _emgEmailController.text = data['emgEmail']?.toString() ?? '';
      _emgAddressController.text = data['emgAddress']?.toString() ?? '';

      _emailNotification = data['emailNotification']?.toString() ?? 'NO';
      _presCountry = data['presCountry']?.toString() ?? 'Bangladesh';
      _presDivision = data['presDivision']?.toString() ?? 'Sylhet';
      _presDistrict = data['presDistrict']?.toString() ?? 'Habiganj';
      _permCountry = data['permCountry']?.toString() ?? 'Bangladesh';
      _permDivision = data['permDivision']?.toString() ?? 'Rangpur';
      _permDistrict = data['permDistrict']?.toString() ?? 'Rangpur';
      _emgRelation = data['emgRelation']?.toString() ?? 'Father';
    } else {
      _tinController.clear();
      _nidController.clear();
      _passportController.clear();
      _spouseMobileController.clear();
      _birthCertController.clear();
      _dobController.clear();
      _spouseNameController.clear();
      _houseNameController.clear();
      _houseBlockController.clear();
      _houseLevelController.clear();
      _houseRoomController.clear();
      _offMobileController.clear();
      _offPhoneController.clear();
      _offEmailController.clear();
      _faxController.clear();
      _skypeController.clear();
      _perMobileController.clear();
      _perPhoneController.clear();
      _perEmailController.clear();
      _presPostcodeController.clear();
      _presAddressController.clear();
      _permPostcodeController.clear();
      _permAddressController.clear();
      _emgNameController.clear();
      _emgMobileController.clear();
      _emgPhoneController.clear();
      _emgEmailController.clear();
      _emgAddressController.clear();
    }
  }

  Widget _headerButton(BuildContext context, String title, IconData icon, String adminId) {
    return TextButton.icon(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => WebAdminHome(adminId: adminId)),
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  void _showAdminMenu(BuildContext context, Map<String, dynamic>? data, String adminId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Admin Menu"),
        content: const Text("Manage your profile or logout."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMaster = widget.adminId == "M-355";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(82),
        child: Container(
          color: const Color(0xFF000080),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const SizedBox(
                    width: 250,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("SBM GROUP OF COMPANNY", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 3),
                        Text("Admin Control Panel", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _headerButton(context, "Home", Icons.home, widget.adminId),
                            PopupMenuButton<String>(
                              tooltip: "Administration",
                              offset: const Offset(0, 45),
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => WebAdminHome(adminId: widget.adminId)),
                                );
                              },
                              itemBuilder: (context) {
                                List<PopupMenuItem<String>> items = [];
                                if (isMaster || userPermissions['manage_permissions'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "managePermissions", child: Row(children: [Icon(Icons.admin_panel_settings, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Manage Permissions", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['permission_control'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "permissionControl", child: Row(children: [Icon(Icons.security, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Permission Control", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                if (isMaster || userPermissions['center_create'] == true) {
                                  items.add(const PopupMenuItem<String>(value: "centerCreate", child: Row(children: [Icon(Icons.add_business, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Center Create", style: TextStyle(fontWeight: FontWeight.w600))])));
                                }
                                return items;
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text("Administration", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 3),
                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: "All Report",
                              offset: const Offset(0, 45),
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => WebAdminHome(adminId: widget.adminId)),
                                );
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem<String>(value: "toolsReport", child: Row(children: [Icon(Icons.build, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("Tools Report", style: TextStyle(fontWeight: FontWeight.w600))])),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.assessment, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text("All Report", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 3),
                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: "Employee Portal",
                              offset: const Offset(0, 45),
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => WebAdminHome(adminId: widget.adminId)),
                                );
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem<String>(value: "allEmployees", child: Row(children: [Icon(Icons.people, color: Color(0xFF000080), size: 20), SizedBox(width: 10), Text("All Employees", style: TextStyle(fontWeight: FontWeight.w600))])),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_alt, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text("Employee Portal", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 3),
                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => WebAdminHome(adminId: widget.adminId)),
                                  );
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                icon: const Icon(Icons.business_center, size: 16),
                                label: const Text("All Project", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('employees').doc(widget.adminId).get(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      final String name = data?['name']?.toString() ?? "Admin";
                      return InkWell(
                        onTap: () => _showAdminMenu(context, data, widget.adminId),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(radius: 19, backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xFF000080))),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(width: 5),
                              const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                              const Text("Profile Management", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF000080))),
                              const Spacer(),
                              const Text("StaffID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(width: 15),

                              // 👇 ValueListenableBuilder সহ সঠিকভাবে ফিল্টারিং লজিক যুক্ত ড্রপডাউন
                              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance.collection('employees').orderBy('id').snapshots(),
                                builder: (context, snapshot) {
                                  final allEmployees = snapshot.data?.docs ?? [];

                                  return StatefulBuilder(
                                    builder: (context, setDropdownState) {
                                      return ValueListenableBuilder<TextEditingValue>(
                                        valueListenable: _searchController,
                                        builder: (context, value, child) {
                                          final searchQuery = value.text.toLowerCase();
                                          final filteredEmployees = allEmployees.where((doc) {
                                            final data = doc.data();
                                            final empId = (data['id']?.toString() ?? doc.id).toLowerCase();
                                            final empName = (data['name']?.toString() ?? '').toLowerCase();
                                            return empId.contains(searchQuery) || empName.contains(searchQuery);
                                          }).toList();

                                          return Container(
                                            width: 250,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: Colors.grey.shade400),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: PopupMenuButton<String>(
                                              offset: const Offset(0, 42),
                                              color: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        selectedEmployeeId,
                                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const Icon(Icons.arrow_drop_down, color: Colors.black54),
                                                  ],
                                                ),
                                              ),
                                              itemBuilder: (context) => [
                                                PopupMenuItem<String>(
                                                  enabled: false,
                                                  child: SizedBox(
                                                    width: 280,
                                                    child: TextField(
                                                      controller: _searchController,
                                                      autofocus: true,
                                                      decoration: const InputDecoration(
                                                        hintText: "Search ID or Name...",
                                                        prefixIcon: Icon(Icons.search, size: 18),
                                                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      onChanged: (val) {
                                                        setDropdownState(() {});
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                if (filteredEmployees.isEmpty)
                                                  const PopupMenuItem<String>(
                                                    enabled: false,
                                                    child: Text("No employee found", style: TextStyle(color: Colors.grey)),
                                                  ),
                                                ...filteredEmployees.map((doc) {
                                                  final data = doc.data();
                                                  final String empId = data['id']?.toString() ?? doc.id;
                                                  final String empName = data['name']?.toString() ?? '';
                                                  return PopupMenuItem<String>(
                                                    value: doc.id,
                                                    child: Text(
                                                      "$empId ($empName)",
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                    ),
                                                  );
                                                }),
                                              ],
                                              onSelected: (selectedDocId) async {
                                                final docSnap = await FirebaseFirestore.instance.collection('employees').doc(selectedDocId).get();
                                                if (docSnap.exists && mounted) {
                                                  setState(() {
                                                    selectedEmployeeId = selectedDocId;
                                                    final data = docSnap.data();
                                                    currentStaffName = data?['name']?.toString() ?? '';
                                                    _loadInitialData(data);
                                                    _searchController.clear();
                                                  });
                                                }
                                              },
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),

                              const SizedBox(width: 30),
                              const Text("Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(width: 15),
                              Text(currentStaffName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 220,
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: Colors.grey.shade300)),
                              ),
                              child: Column(
                                children: [
                                  _buildTabItem("Personal"),
                                  _buildTabItem("Contact"),
                                  _buildTabItem("Parents"),
                                  _buildTabItem("Photo"),
                                  _buildTabItem("Job Description"),
                                  _buildTabItem("Education"),
                                  _buildTabItem("Event"),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(30),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (selectedTab == "Personal") ...[
                                      PersonalTabWidget(
                                        tinController: _tinController,
                                        nidController: _nidController,
                                        passportController: _passportController,
                                        spouseMobileController: _spouseMobileController,
                                        birthCertController: _birthCertController,
                                        dobController: _dobController,
                                        spouseNameController: _spouseNameController,
                                        religion: _religion,
                                        nationality: _nationality,
                                        bloodGroup: _bloodGroup,
                                        gender: _gender,
                                        maritalStatus: _maritalStatus,
                                        spouseProfession: _spouseProfession,
                                        onReligionChanged: (val) => setState(() => _religion = val!),
                                        onNationalityChanged: (val) => setState(() => _nationality = val),
                                        onBloodGroupChanged: (val) => setState(() => _bloodGroup = val!),
                                        onGenderChanged: (val) => setState(() => _gender = val!),
                                        onMaritalStatusChanged: (val) => setState(() => _maritalStatus = val!),
                                        onSpouseProfessionChanged: (val) => setState(() => _spouseProfession = val!),
                                        buildFormRow: _buildFormRow,
                                        buildDropdownRow: _buildDropdownRow,
                                      ),
                                    ] else if (selectedTab == "Contact") ...[
                                      ContactTabWidget(
                                        offMobileController: _offMobileController,
                                        offPhoneController: _offPhoneController,
                                        offEmailController: _offEmailController,
                                        faxController: _faxController,
                                        skypeController: _skypeController,
                                        perMobileController: _perMobileController,
                                        perPhoneController: _perPhoneController,
                                        perEmailController: _perEmailController,
                                        presPostcodeController: _presPostcodeController,
                                        presAddressController: _presAddressController,
                                        permPostcodeController: _permPostcodeController,
                                        permAddressController: _permAddressController,
                                        emgNameController: _emgNameController,
                                        emgMobileController: _emgMobileController,
                                        emgPhoneController: _emgPhoneController,
                                        emgEmailController: _emgEmailController,
                                        emgAddressController: _emgAddressController,
                                        houseNameController: _houseNameController,
                                        houseBlockController: _houseBlockController,
                                        houseLevelController: _houseLevelController,
                                        houseRoomController: _houseRoomController,
                                        foodFacility: _foodFacility,
                                        emailNotification: _emailNotification,
                                        presCountry: _presCountry,
                                        presDivision: _presDivision,
                                        presDistrict: _presDistrict,
                                        presThana: _presThana,
                                        permCountry: _permCountry,
                                        permDivision: _permDivision,
                                        permDistrict: _permDistrict,
                                        permThana: _permThana,
                                        emgRelation: _emgRelation,
                                        onEmailNotificationChanged: (val) => setState(() => _emailNotification = val!),
                                        onFoodFacilityChanged: (val) => setState(() => _foodFacility = val!),
                                        onPresCountryChanged: (val) => setState(() => _presCountry = val),
                                        onPresDivisionChanged: (val) => setState(() => _presDivision = val!),
                                        onPresDistrictChanged: (val) => setState(() => _presDistrict = val!),
                                        onPresThanaChanged: (val) => setState(() => _presThana = val!),
                                        onPermCountryChanged: (val) => setState(() => _permCountry = val),
                                        onPermDivisionChanged: (val) => setState(() => _permDivision = val!),
                                        onPermDistrictChanged: (val) => setState(() => _permDistrict = val!),
                                        onPermThanaChanged: (val) => setState(() => _permThana = val!),
                                        onEmgRelationChanged: (val) => setState(() => _emgRelation = val!),
                                        buildFormRow: _buildFormRow,
                                        buildDropdownRow: _buildDropdownRow,
                                        buildSectionHeader: _buildSectionHeader,
                                      ),
                                    ] else if (selectedTab == "Photo") ...[
                                      const PhotoTabWidget(),
                                    ] else ...[
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(50),
                                          child: Text("Content for $selectedTab tab", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 40),
                                    const Divider(),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xff159bc0),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: _isUpdating ? null : () async {
                                          setState(() => _isUpdating = true);
                                          try {
                                            if (selectedTab == "Personal") {
                                              await FirebaseFirestore.instance.collection('employees').doc(selectedEmployeeId).update({
                                                'tin': _tinController.text.trim(),
                                                'religion': _religion,
                                                'nationality': _nationality,
                                                'nid': _nidController.text.trim(),
                                                'bloodGroup': _bloodGroup,
                                                'passport': _passportController.text.trim(),
                                                'spouseMobile': _spouseMobileController.text.trim(),
                                                'gender': _gender,
                                                'maritalStatus': _maritalStatus,
                                                'birthCertificateId': _birthCertController.text.trim(),
                                                'dob': _dobController.text.trim(),
                                                'spouseName': _spouseNameController.text.trim(),
                                                'spouseProfession': _spouseProfession,
                                              });
                                            } else if (selectedTab == "Contact") {
                                              await FirebaseFirestore.instance.collection('employees').doc(selectedEmployeeId).update({
                                                'offMobile': _offMobileController.text.trim(),
                                                'offPhone': _offPhoneController.text.trim(),
                                                'offEmail': _offEmailController.text.trim(),
                                                'emailNotification': _emailNotification,
                                                'foodFacility': _foodFacility,
                                                'fax': _faxController.text.trim(),
                                                'skype': _skypeController.text.trim(),
                                                'perMobile': _perMobileController.text.trim(),
                                                'perPhone': _perPhoneController.text.trim(),
                                                'perEmail': _perEmailController.text.trim(),
                                                'presCountry': _presCountry,
                                                'presDivision': _presDivision,
                                                'presDistrict': _presDistrict,
                                                'presThana': _presThana,
                                                'presPostcode': _presPostcodeController.text.trim(),
                                                'presAddress': _presAddressController.text.trim(),
                                                'houseName': _houseNameController.text.trim(),
                                                'houseBlock': _houseBlockController.text.trim(),
                                                'houseLevel': _houseLevelController.text.trim(),
                                                'houseRoom': _houseRoomController.text.trim(),
                                                'permCountry': _permCountry,
                                                'permDivision': _permDivision,
                                                'permDistrict': _permDistrict,
                                                'permThana': _permThana,
                                                'permPostcode': _permPostcodeController.text.trim(),
                                                'permAddress': _permAddressController.text.trim(),
                                                'emgName': _emgNameController.text.trim(),
                                                'emgRelation': _emgRelation,
                                                'emgMobile': _emgMobileController.text.trim(),
                                                'emgPhone': _emgPhoneController.text.trim(),
                                                'emgEmail': _emgEmailController.text.trim(),
                                                'emgAddress': _emgAddressController.text.trim(),
                                              });
                                            }
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Updated successfully!"), backgroundColor: Colors.green),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Failed to update: $e"), backgroundColor: Colors.red),
                                            );
                                          } finally {
                                            if (mounted) setState(() => _isUpdating = false);
                                          }
                                        },
                                        child: const Text("Update", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isUpdating)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xff159bc0)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title) {
    bool isSelected = selectedTab == title;
    return InkWell(
      onTap: () => setState(() => selectedTab = title),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff148da8) : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.red.shade700, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
          const Text("-", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFormRow(String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
          ),
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
          ),
          Expanded(
            child: SizedBox(
              height: 42,
              child: DropdownButtonFormField<String>(
                value: value,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                ),
                items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 2. PERSONAL TAB

class PersonalTabWidget extends StatelessWidget {
  final TextEditingController tinController;
  final TextEditingController nidController;
  final TextEditingController passportController;
  final TextEditingController spouseMobileController;
  final TextEditingController birthCertController;
  final TextEditingController dobController;
  final TextEditingController spouseNameController;

  final String religion;
  final String nationality;
  final String bloodGroup;
  final String gender;
  final String maritalStatus;
  final String spouseProfession;

  final ValueChanged<String?> onReligionChanged;
  final ValueChanged<String> onNationalityChanged;
  final ValueChanged<String?> onBloodGroupChanged;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onMaritalStatusChanged;
  final ValueChanged<String?> onSpouseProfessionChanged;

  final Function(String, TextEditingController, String) buildFormRow;
  final Function(String, List<String>, String, ValueChanged<String?>) buildDropdownRow;

  const PersonalTabWidget({
    super.key,
    required this.tinController,
    required this.nidController,
    required this.passportController,
    required this.spouseMobileController,
    required this.birthCertController,
    required this.dobController,
    required this.spouseNameController,
    required this.religion,
    required this.nationality,
    required this.bloodGroup,
    required this.gender,
    required this.maritalStatus,
    required this.spouseProfession,
    required this.onReligionChanged,
    required this.onNationalityChanged,
    required this.onBloodGroupChanged,
    required this.onGenderChanged,
    required this.onMaritalStatusChanged,
    required this.onSpouseProfessionChanged,
    required this.buildFormRow,
    required this.buildDropdownRow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              buildFormRow("TIN***", tinController, "Enter TIN"),
              buildDropdownRow("Religion", ["Islam", "Hindu", "Christian", "Buddhist"], religion, onReligionChanged),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 140,
                      child: Text("Nationality", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: InkWell(
                          onTap: () {
                            showCountryPicker(
                              context: context,
                              showPhoneCode: false,
                              onSelect: (Country country) {
                                onNationalityChanged(country.name);
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  nationality.isEmpty ? "Select Country" : nationality,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              buildFormRow("NID", nidController, "Enter NID"),
              buildDropdownRow("Blood Group", ["A+", "A-", "B+", "B-", "O+", "O-", "AB+"], bloodGroup, onBloodGroupChanged),
              buildFormRow("Passport", passportController, "Enter Passport"),
              buildFormRow("Spouse Mobile", spouseMobileController, "Enter Spouse Mobile"),
            ],
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            children: [
              buildDropdownRow("Gender", ["Male", "Female", "Other"], gender, onGenderChanged),
              buildDropdownRow("Marital Status", ["Unmarried", "Married", "Divorced"], maritalStatus, onMaritalStatusChanged),
              buildFormRow("Birth Certificate ID", birthCertController, "Enter Birth Certificate ID"),
              buildFormRow("DOB", dobController, "DD/MM/YYYY"),
              buildFormRow("Spouse Name", spouseNameController, "Enter Spouse Name"),
              buildDropdownRow("Spouse Profession", ["Farmer", "Service", "Business", "Housewife"], spouseProfession, onSpouseProfessionChanged),
            ],
          ),
        ),
      ],
    );
  }
}

// 3. CONTACT TAB

class ContactTabWidget extends StatefulWidget {
  final TextEditingController offMobileController;
  final TextEditingController offPhoneController;
  final TextEditingController offEmailController;
  final TextEditingController faxController;
  final TextEditingController skypeController;
  final TextEditingController perMobileController;
  final TextEditingController perPhoneController;
  final TextEditingController perEmailController;
  final TextEditingController presPostcodeController;
  final TextEditingController presAddressController;
  final TextEditingController permPostcodeController;
  final TextEditingController permAddressController;
  final TextEditingController emgNameController;
  final TextEditingController emgMobileController;
  final TextEditingController emgPhoneController;
  final TextEditingController emgEmailController;
  final TextEditingController emgAddressController;

  final TextEditingController houseNameController;
  final TextEditingController houseBlockController;
  final TextEditingController houseLevelController;
  final TextEditingController houseRoomController;

  final String emailNotification;
  final String foodFacility; // Food Facility Field
  final String presCountry;
  final String presDivision;
  final String presDistrict;
  final String presThana;
  final String permCountry;
  final String permDivision;
  final String permDistrict;
  final String permThana;
  final String emgRelation;

  final ValueChanged<String?> onEmailNotificationChanged;
  final ValueChanged<String?> onFoodFacilityChanged; // Food Facility Callback
  final ValueChanged<String> onPresCountryChanged;
  final ValueChanged<String?> onPresDivisionChanged;
  final ValueChanged<String?> onPresDistrictChanged;
  final ValueChanged<String?> onPresThanaChanged;
  final ValueChanged<String> onPermCountryChanged;
  final ValueChanged<String?> onPermDivisionChanged;
  final ValueChanged<String?> onPermDistrictChanged;
  final ValueChanged<String?> onPermThanaChanged;
  final ValueChanged<String?> onEmgRelationChanged;

  final Function(String, TextEditingController, String) buildFormRow;
  final Function(String, List<String>, String, ValueChanged<String?>) buildDropdownRow;
  final Function(String) buildSectionHeader;

  const ContactTabWidget({
    super.key,
    required this.offMobileController,
    required this.offPhoneController,
    required this.offEmailController,
    required this.faxController,
    required this.skypeController,
    required this.perMobileController,
    required this.perPhoneController,
    required this.perEmailController,
    required this.presPostcodeController,
    required this.presAddressController,
    required this.permPostcodeController,
    required this.permAddressController,
    required this.emgNameController,
    required this.emgMobileController,
    required this.emgPhoneController,
    required this.emgEmailController,
    required this.emgAddressController,
    required this.houseNameController,
    required this.houseBlockController,
    required this.houseLevelController,
    required this.houseRoomController,
    required this.emailNotification,
    required this.foodFacility,
    required this.presCountry,
    required this.presDivision,
    required this.presDistrict,
    required this.presThana,
    required this.permCountry,
    required this.permDivision,
    required this.permDistrict,
    required this.permThana,
    required this.emgRelation,
    required this.onEmailNotificationChanged,
    required this.onFoodFacilityChanged,
    required this.onPresCountryChanged,
    required this.onPresDivisionChanged,
    required this.onPresDistrictChanged,
    required this.onPresThanaChanged,
    required this.onPermCountryChanged,
    required this.onPermDivisionChanged,
    required this.onPermDistrictChanged,
    required this.onPermThanaChanged,
    required this.onEmgRelationChanged,
    required this.buildFormRow,
    required this.buildDropdownRow,
    required this.buildSectionHeader,
  });

  @override
  State<ContactTabWidget> createState() => _ContactTabWidgetState();
}

class _ContactTabWidgetState extends State<ContactTabWidget> {
  List<csc.State> _presStates = [];
  List<csc.City> _presCities = [];

  List<csc.State> _permStates = [];
  List<csc.City> _permCities = [];

  bool _isLoadingPresStates = false;
  bool _isLoadingPresCities = false;
  bool _isLoadingPermStates = false;
  bool _isLoadingPermCities = false;

  @override
  void initState() {
    super.initState();
    if (widget.presCountry.isNotEmpty) {
      _loadPresStatesForCountry(widget.presCountry);
    }
    if (widget.permCountry.isNotEmpty) {
      _loadPermStatesForCountry(widget.permCountry);
    }
  }

  Future<void> _loadPresStatesForCountry(String countryName) async {
    setState(() => _isLoadingPresStates = true);
    try {
      var countries = await csc.getAllCountries();
      var selectedCountry = countries.firstWhere(
            (c) => c.name.toLowerCase() == countryName.toLowerCase(),
        orElse: () => countries.first,
      );
      var states = await csc.getStatesOfCountry(selectedCountry.isoCode);
      if (!mounted) return;
      setState(() {
        _presStates = states;
        _isLoadingPresStates = false;
      });
      if (states.isNotEmpty) {
        String firstState = states.first.name;
        if (!states.any((s) => s.name == widget.presDivision)) {
          widget.onPresDivisionChanged(firstState);
        }
        _loadPresCitiesForState(selectedCountry.isoCode, widget.presDivision.isNotEmpty ? widget.presDivision : firstState);
      } else {
        setState(() {
          _presCities = [];
        });
        widget.onPresDivisionChanged(null);
        widget.onPresDistrictChanged(null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPresStates = false);
    }
  }

  Future<void> _loadPresCitiesForState(String countryIso, String stateName) async {
    setState(() => _isLoadingPresCities = true);
    try {
      var states = await csc.getStatesOfCountry(countryIso);
      var selectedState = states.firstWhere(
            (s) => s.name.toLowerCase() == stateName.toLowerCase(),
        orElse: () => states.first,
      );
      var cities = await csc.getStateCities(countryIso, selectedState.isoCode);
      if (!mounted) return;
      setState(() {
        _presCities = cities;
        _isLoadingPresCities = false;
      });
      if (cities.isNotEmpty) {
        if (!cities.any((c) => c.name == widget.presDistrict)) {
          widget.onPresDistrictChanged(cities.first.name);
        }
      } else {
        widget.onPresDistrictChanged(null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPresCities = false);
    }
  }

  Future<void> _loadPermStatesForCountry(String countryName) async {
    setState(() => _isLoadingPermStates = true);
    try {
      var countries = await csc.getAllCountries();
      var selectedCountry = countries.firstWhere(
            (c) => c.name.toLowerCase() == countryName.toLowerCase(),
        orElse: () => countries.first,
      );
      var states = await csc.getStatesOfCountry(selectedCountry.isoCode);
      if (!mounted) return;
      setState(() {
        _permStates = states;
        _isLoadingPermStates = false;
      });
      if (states.isNotEmpty) {
        String firstState = states.first.name;
        if (!states.any((s) => s.name == widget.permDivision)) {
          widget.onPermDivisionChanged(firstState);
        }
        _loadPermCitiesForState(selectedCountry.isoCode, widget.permDivision.isNotEmpty ? widget.permDivision : firstState);
      } else {
        setState(() {
          _permCities = [];
        });
        widget.onPermDivisionChanged(null);
        widget.onPermDistrictChanged(null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPermStates = false);
    }
  }

  Future<void> _loadPermCitiesForState(String countryIso, String stateName) async {
    setState(() => _isLoadingPermCities = true);
    try {
      var states = await csc.getStatesOfCountry(countryIso);
      var selectedState = states.firstWhere(
            (s) => s.name.toLowerCase() == stateName.toLowerCase(),
        orElse: () => states.first,
      );
      var cities = await csc.getStateCities(countryIso, selectedState.isoCode);
      if (!mounted) return;
      setState(() {
        _permCities = cities;
        _isLoadingPermCities = false;
      });
      if (cities.isNotEmpty) {
        if (!cities.any((c) => c.name == widget.permDistrict)) {
          widget.onPermDistrictChanged(cities.first.name);
        }
      } else {
        widget.onPermDistrictChanged(null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPermCities = false);
    }
  }

  Future<void> _fetchAddressByPostcode(String postcode) async {
    if (postcode.length == 6) {
      String token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoyNjQ0MSwiZm9yZXZlciI6ZmFsc2UsImlzcyI6Ik9uZU1hcCIsImlhdCI6MTc5MTI5NjkzOCwibmJmIjoxNzkxMjk2OTM4LCJleHAiOjE3OTE1NTYxMzgsImp0aSI6ImYzMjY5YTQ3LTRlODUtNGYwYi05YzQ2LTE5YzA4NThhYzhiNyJ9.vhE1_iDglxmMosKN2Fi_qerHmgIHo52m393z2zbKo7HzgyYjdeWy2Oj6_2glRHzXnSBw7l5i8JKMBhO1Kegdorfn1Ze-C0i-AeYwptBs-73tMvbejvB_w8qTwtvO971YqDJ0K-B8zKSs6XHvur5v2EKA6I1h5FCfXtUH7N52JO1fnQzpOSKwKXcOZ-FYg8UhnLRoeq3HzreMKy2sAuk4S6aVA_MIaHVy5a7R3SIedhCY_D1FB0tR06MNjCHoB-y97zProeACKvz3Zg2zSUEBxUotzW4pRQKTK2KqhW6-yagUxQt-h0BPiSwpiwDZAPCdhwj5RbVeksrS7Ba4Sz06hQ";

      final url = Uri.parse('https://www.onemap.gov.sg/api/common/elastic/search?searchVal=$postcode&returnGeom=N&getAddrDetails=Y');

      try {
        final response = await http.get(
          url,
          headers: {'Authorization': token},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List results = data['results'];

          if (!mounted) return;
          if (results.isNotEmpty) {
            final addressDetails = results[0];
            String block = addressDetails['BLK_NO'] ?? '';
            String road = addressDetails['ROAD_NAME'] ?? '';
            String building = addressDetails['BUILDING'] ?? '';

            String fullAddress = '';
            if (block.isNotEmpty) fullAddress += 'Blk $block ';
            if (road.isNotEmpty) fullAddress += road;
            if (building.isNotEmpty && building != "NIL") fullAddress += ', $building';

            setState(() {
              widget.presAddressController.text = fullAddress.trim();
            });
          } else {
            setState(() {
              widget.presAddressController.text = "Thikana paoya jayni";
            });
          }
        }
      } catch (e) {
        print("Error fetching address: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> presStateNames = _presStates.map((s) => s.name).toList();
    List<String> presCityNames = _presCities.map((c) => c.name).toList();

    List<String> permStateNames = _permStates.map((s) => s.name).toList();
    List<String> permCityNames = _permCities.map((c) => c.name).toList();

    String selectedPresStateValue = presStateNames.contains(widget.presDivision) ? widget.presDivision : (presStateNames.isNotEmpty ? presStateNames.first : "");
    String selectedPresCityValue = presCityNames.contains(widget.presDistrict) ? widget.presDistrict : (presCityNames.isNotEmpty ? presCityNames.first : "");

    String selectedPermStateValue = permStateNames.contains(widget.permDivision) ? widget.permDivision : (permStateNames.isNotEmpty ? permStateNames.first : "");
    String selectedPermCityValue = permCityNames.contains(widget.permDistrict) ? widget.permDistrict : (permCityNames.isNotEmpty ? permCityNames.first : "");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.buildSectionHeader("Official Contact"),
                  widget.buildFormRow("Mobile", widget.offMobileController, "Enter Mobile"),
                  widget.buildFormRow("Phone", widget.offPhoneController, "Enter Phone"),
                  widget.buildFormRow("Email", widget.offEmailController, "Enter Email"),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Email Notification", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Radio<String>(value: "YES", groupValue: widget.emailNotification, onChanged: widget.onEmailNotificationChanged),
                              const Text("YES"),
                              const SizedBox(width: 20),
                              Radio<String>(value: "NO", groupValue: widget.emailNotification, onChanged: widget.onEmailNotificationChanged),
                              const Text("NO"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  widget.buildFormRow("Fax", widget.faxController, "Enter Fax"),
                  widget.buildFormRow("Skype", widget.skypeController, "Enter Skype"),
                ],
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.buildSectionHeader("Personal Contact"),
                  widget.buildFormRow("Mobile", widget.perMobileController, "Enter Mobile"),
                  widget.buildFormRow("Phone", widget.perPhoneController, "Enter Phone"),
                  widget.buildFormRow("Email", widget.perEmailController, "Enter Email"),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.buildSectionHeader("Present Address"),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Country", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: InkWell(
                              onTap: () {
                                showCountryPicker(
                                  context: context,
                                  showPhoneCode: false,
                                  onSelect: (Country country) {
                                    widget.onPresCountryChanged(country.name);
                                    _loadPresStatesForCountry(country.name);
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(widget.presCountry.isEmpty ? "Select Country" : widget.presCountry, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _isLoadingPresStates
                      ? const LinearProgressIndicator()
                      : widget.buildDropdownRow("State", presStateNames, selectedPresStateValue, (val) async {
                    widget.onPresDivisionChanged(val);
                    var countries = await csc.getAllCountries();
                    var selectedCountry = countries.firstWhere(
                          (c) => c.name.toLowerCase() == widget.presCountry.toLowerCase(),
                      orElse: () => countries.first,
                    );
                    if (val != null) {
                      _loadPresCitiesForState(selectedCountry.isoCode, val);
                    }
                  }),
                  _isLoadingPresCities
                      ? const LinearProgressIndicator()
                      : widget.buildDropdownRow("District/City", presCityNames, selectedPresCityValue, widget.onPresDistrictChanged),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Postcode", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: TextFormField(
                              controller: widget.presPostcodeController,
                              onChanged: (value) {
                                setState(() {});
                                if (widget.presCountry.toLowerCase() == "singapore") {
                                  _fetchAddressByPostcode(value);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: "Enter PostCode",
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Address", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: widget.presAddressController,
                            onChanged: (value) {
                              setState(() {});
                            },
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: "Enter Present Address",
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // House Section
                  widget.buildSectionHeader("House"),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("House Name", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance.collection('houses').snapshots(),
                              builder: (context, snapshot) {
                                List<String> houseNames = [];
                                if (snapshot.hasData) {
                                  houseNames = snapshot.data!.docs
                                      .map((doc) => doc.data()['houseName']?.toString() ?? '')
                                      .where((name) => name.isNotEmpty)
                                      .toSet()
                                      .toList();
                                }
                                String currentVal = widget.houseNameController.text;

                                return DropdownButtonFormField<String>(
                                  value: houseNames.contains(currentVal) ? currentVal : null,
                                  decoration: InputDecoration(
                                    hintText: "Select House Name",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                                  ),
                                  items: houseNames.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        widget.houseNameController.text = val;
                                        widget.houseBlockController.clear();
                                        widget.houseLevelController.clear();
                                        widget.houseRoomController.clear();
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Block", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: widget.houseNameController.text.isEmpty
                                  ? Stream.empty()
                                  : FirebaseFirestore.instance
                                  .collection('houses')
                                  .where('houseName', isEqualTo: widget.houseNameController.text)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                List<String> blocks = [];
                                if (snapshot.hasData) {
                                  blocks = snapshot.data!.docs
                                      .map((doc) => doc.data()['blockNo']?.toString() ?? '')
                                      .where((b) => b.isNotEmpty)
                                      .toSet()
                                      .toList();
                                }
                                String currentVal = widget.houseBlockController.text;

                                return DropdownButtonFormField<String>(
                                  value: blocks.contains(currentVal) ? currentVal : null,
                                  decoration: InputDecoration(
                                    hintText: "Select Block",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                                  ),
                                  items: blocks.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        widget.houseBlockController.text = val;
                                        widget.houseLevelController.clear();
                                        widget.houseRoomController.clear();
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Level", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: (widget.houseNameController.text.isEmpty || widget.houseBlockController.text.isEmpty)
                                  ? Stream.empty()
                                  : FirebaseFirestore.instance
                                  .collection('houses')
                                  .where('houseName', isEqualTo: widget.houseNameController.text)
                                  .where('blockNo', isEqualTo: widget.houseBlockController.text)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                List<String> levels = [];
                                if (snapshot.hasData) {
                                  levels = snapshot.data!.docs
                                      .map((doc) => doc.data()['level']?.toString() ?? '')
                                      .where((l) => l.isNotEmpty)
                                      .toSet()
                                      .toList();
                                }
                                String currentVal = widget.houseLevelController.text;

                                return DropdownButtonFormField<String>(
                                  value: levels.contains(currentVal) ? currentVal : null,
                                  decoration: InputDecoration(
                                    hintText: "Select Level",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                                  ),
                                  items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        widget.houseLevelController.text = val;
                                        widget.houseRoomController.clear();
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Room No", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: (widget.houseNameController.text.isEmpty ||
                                  widget.houseBlockController.text.isEmpty ||
                                  widget.houseLevelController.text.isEmpty)
                                  ? Stream.empty()
                                  : FirebaseFirestore.instance
                                  .collection('houses')
                                  .where('houseName', isEqualTo: widget.houseNameController.text)
                                  .where('blockNo', isEqualTo: widget.houseBlockController.text)
                                  .where('level', isEqualTo: widget.houseLevelController.text)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                List<String> rooms = [];
                                if (snapshot.hasData) {
                                  rooms = snapshot.data!.docs
                                      .map((doc) => doc.data()['roomNo']?.toString() ?? '')
                                      .where((r) => r.isNotEmpty)
                                      .toSet()
                                      .toList();
                                }
                                String currentVal = widget.houseRoomController.text;

                                return DropdownButtonFormField<String>(
                                  value: rooms.contains(currentVal) ? currentVal : null,
                                  decoration: InputDecoration(
                                    hintText: "Select Room No",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                                  ),
                                  items: rooms.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        widget.houseRoomController.text = val;
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.buildSectionHeader("Permanent Address"),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Country", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: InkWell(
                              onTap: () {
                                showCountryPicker(
                                  context: context,
                                  showPhoneCode: false,
                                  onSelect: (Country country) {
                                    widget.onPermCountryChanged(country.name);
                                    _loadPermStatesForCountry(country.name);
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(widget.permCountry.isEmpty ? "Select Country" : widget.permCountry, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _isLoadingPermStates
                      ? const LinearProgressIndicator()
                      : widget.buildDropdownRow("State", permStateNames, selectedPermStateValue, (val) async {
                    widget.onPermDivisionChanged(val);
                    var countries = await csc.getAllCountries();
                    var selectedCountry = countries.firstWhere(
                          (c) => c.name.toLowerCase() == widget.permCountry.toLowerCase(),
                      orElse: () => countries.first,
                    );
                    if (val != null) {
                      _loadPermCitiesForState(selectedCountry.isoCode, val);
                    }
                  }),
                  _isLoadingPermCities
                      ? const LinearProgressIndicator()
                      : widget.buildDropdownRow("District/City", permCityNames, selectedPermCityValue, widget.onPermDistrictChanged),
                  widget.buildFormRow("Postcode", widget.permPostcodeController, "Enter PostCode"),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Address", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: widget.permAddressController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: "Enter Permanent Address",
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 👇 Food Facility Section Added Next to House Section
                  widget.buildSectionHeader("Food Facility"),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Facility", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Radio<String>(
                                value: "Supply own",
                                groupValue: widget.foodFacility,
                                onChanged: widget.onFoodFacilityChanged,
                              ),
                              const Text("Supply own", style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 15),
                              Radio<String>(
                                value: "Supply Company",
                                groupValue: widget.foodFacility,
                                onChanged: widget.onFoodFacilityChanged,
                              ),
                              const Text("Supply Company", style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        widget.buildSectionHeader("Emergency Contact"),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  widget.buildFormRow("Name", widget.emgNameController, "Enter Name"),
                  widget.buildDropdownRow("Relation", ["Father", "Mother", "Brother", "Sister", "Spouse", "Other"], widget.emgRelation.isNotEmpty ? widget.emgRelation : "Father", widget.onEmgRelationChanged),
                  widget.buildFormRow("Mobile", widget.emgMobileController, "Enter Mobile"),
                ],
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              child: Column(
                children: [
                  widget.buildFormRow("Phone", widget.emgPhoneController, "Enter Phone"),
                  widget.buildFormRow("Email", widget.emgEmailController, "Enter Email"),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text("Address", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: widget.emgAddressController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: "Enter Emergency Address",
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

//4. PHOTO ADD TAB

class PhotoTabWidget extends StatelessWidget {
  const PhotoTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPhotoBox("Employee")),
            const SizedBox(width: 20),
            Expanded(child: _buildPhotoBox("Father")),
            const SizedBox(width: 20),
            Expanded(child: _buildPhotoBox("Mother")),
          ],
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: 320,
          child: _buildPhotoBox("Signature"),
        ),
      ],
    );
  }

  Widget _buildPhotoBox(String title) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.green.shade900,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            height: 140,
            width: 140,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: const Icon(Icons.image, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff159bc0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {},
              child: const Text("Browse", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}


// =====================================================
// ADMIN PROFILE DIALOG (FINAL & FULLY WORKING)
// =====================================================
void _showAdminProfile(
    BuildContext context,
    Map<String, dynamic>? data,
    String adminId,
    ) {
  final String name = data?['name']?.toString() ?? '';
  final String fin = data?['fin']?.toString() ?? '';
  final String workPermit = data?['workPermit']?.toString() ?? '';
  final String designation = data?['designation']?.toString() ?? '';
  final String role = data?['role']?.toString() ?? 'admin';
  final String? initialImageUrl = data?['profileImageUrl']?.toString();

  bool isUploading = false;
  String? currentImageUrl = initialImageUrl;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "ADMIN PROFILE",
              style: TextStyle(
                color: Color(0xFF000080),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // প্রফাইল পিকচার এবং ক্যামেরা আইকন (StreamBuilder দিয়ে লাইভ আপডেট)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('employees')
                              .doc(adminId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final liveData = snapshot.data?.data();
                            final String? liveImgUrl =
                                liveData?['profileImageUrl']?.toString() ??
                                    currentImageUrl;

                            // 👇 ফ্লাটার ওয়েবে CORS সমস্যা চিরতরে সমাধানের জন্য NetworkImageWebFix ব্যবহার করা হলো
                            return (liveImgUrl != null && liveImgUrl.isNotEmpty)
                                ? NetworkImageWebFix(
                              imageUrl: liveImgUrl,
                              radius: 55,
                            )
                                : const CircleAvatar(
                              radius: 55,
                              backgroundColor: Color(0xFFE8EAF6),
                              child: Icon(
                                Icons.person,
                                size: 60,
                                color: Color(0xFF000080),
                              ),
                            );
                          },
                        ),
                        if (isUploading)
                          const Positioned.fill(
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.black45,
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: isUploading
                                ? null
                                : () async {
                              try {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image =
                                await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 500,
                                  maxHeight: 500,
                                );

                                if (image == null) return;

                                setDialogState(() {
                                  isUploading = true;
                                });

                                // ওয়েবের জন্য bytes রিড করা
                                final bytes = await image.readAsBytes();

                                // ফায়ারবেস স্টোরেজে আপলোড করার কোড
                                final storageRef = FirebaseStorage
                                    .instance
                                    .ref()
                                    .child('admin_profiles')
                                    .child('$adminId.jpg');

                                // মেটাডাটা সহ আপলোড করা
                                final metadata = SettableMetadata(
                                    contentType: 'image/jpeg');
                                await storageRef.putData(bytes, metadata);

                                final rawUrl =
                                await storageRef.getDownloadURL();

                                // ক্যাশিং প্রবলেম দূর করার জন্য টাইমস্ট্যাম্প যুক্ত করা
                                final downloadUrl =
                                    "$rawUrl&v=${DateTime.now().millisecondsSinceEpoch}";

                                // ফায়ারস্টোরে এমপ্লয়ী ডকুমেন্টে ইমেজ ইউআরএল আপডেট করা
                                await FirebaseFirestore.instance
                                    .collection('employees')
                                    .doc(adminId)
                                    .update({
                                  'profileImageUrl': downloadUrl,
                                });

                                setDialogState(() {
                                  currentImageUrl = downloadUrl;
                                  isUploading = false;
                                });

                                if (!dialogContext.mounted) return;
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Profile picture updated successfully!"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() {
                                  isUploading = false;
                                });
                                if (!dialogContext.mounted) return;
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Failed to upload image: $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF000080),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _profileRow("Name", name),
                    _profileRow("Employee ID", adminId),
                    _profileRow("FIN Number", fin),
                    _profileRow("Work Permit", workPermit),
                    _profileRow("Designation", designation),
                    _profileRow("Role", role.toUpperCase()),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("CLOSE",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _profileRow(
  String title,
  String value,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            "$title:",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? "Not Available" : value,
          ),
        ),
      ],
    ),
  );
}

// =====================================================
// ALL PROJECT এর জন্য একদম আলাদা ডিটেইলস পেজ (যেখানে ডিলিট বাটন থাকবে না)
// =====================================================
class WebAllProjectDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final String projectId;
  final Function(String testPackageId, String testPackageName)?
      onTestPackageTap; // 👈 এই লাইনটি এখানে বসাবেন

  const WebAllProjectDetailsScreen({
    super.key,
    required this.projectData,
    required this.projectId,
    this.onTestPackageTap, // 👈 আর কনস্ট্রাক্টরে এটি এভাবে যুক্ত করে দেবেন
  });

  @override
  State<WebAllProjectDetailsScreen> createState() =>
      _WebAllProjectDetailsScreenState();
}

class _WebAllProjectDetailsScreenState
    extends State<WebAllProjectDetailsScreen> {
  // নতুন ডাটা অ্যাড করার ডায়ালগ (এখানে ডিলিট অপশন বাদ দেওয়া হয়েছে)
  void _openManagementDialog(
    BuildContext context, {
    required String title,
    required String collectionName,
    required String labelName,
    required IconData icon,
    bool requireTestPackage = false,
    bool requireLineNumber = false,
    bool requireSpoolNumber = false,
    bool allowMultipleInput = false,
  }) {
    final TextEditingController controller = TextEditingController();
    String? selectedTestPackageId;
    String? selectedLineNumberId;
    String? selectedSpoolNumberId;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: SizedBox(
                width: 680,
                height: 750,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF000080),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(),

                      if (requireTestPackage) ...[
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(widget.projectId)
                              .collection('testPakeged')
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final testPackages = snapshot.data?.docs ?? [];
                            return DropdownButtonFormField<String>(
                              value: selectedTestPackageId,
                              decoration: const InputDecoration(
                                labelText: "Select Test Package",
                                prefixIcon: Icon(Icons.layers),
                                border: OutlineInputBorder(),
                              ),
                              items: testPackages.map((doc) {
                                final data = doc.data();
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(data['name']?.toString() ?? ''),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedTestPackageId = value;
                                  selectedLineNumberId = null;
                                  selectedSpoolNumberId = null;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (requireLineNumber) ...[
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: selectedTestPackageId == null
                              ? Stream.empty()
                              : FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(widget.projectId)
                                  .collection('lineNumbers')
                                  .where('testPackageId',
                                      isEqualTo: selectedTestPackageId)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            final lineNumbers = snapshot.data?.docs ?? [];
                            return DropdownButtonFormField<String>(
                              value: selectedLineNumberId,
                              decoration: const InputDecoration(
                                labelText: "Select Line Number",
                                prefixIcon: Icon(Icons.linear_scale),
                                border: OutlineInputBorder(),
                              ),
                              items: lineNumbers.map((doc) {
                                final data = doc.data();
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(data['name']?.toString() ?? ''),
                                );
                              }).toList(),
                              onChanged: selectedTestPackageId == null
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        selectedLineNumberId = value;
                                        selectedSpoolNumberId = null;
                                      });
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (requireSpoolNumber) ...[
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: selectedLineNumberId == null
                              ? Stream.empty()
                              : FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(widget.projectId)
                                  .collection('spoolNumbers')
                                  .where('lineNumberId',
                                      isEqualTo: selectedLineNumberId)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            final spoolNumbers = snapshot.data?.docs ?? [];
                            return DropdownButtonFormField<String>(
                              value: selectedSpoolNumberId,
                              decoration: const InputDecoration(
                                labelText: "Select Spool Number",
                                prefixIcon: Icon(Icons.alt_route),
                                border: OutlineInputBorder(),
                              ),
                              items: spoolNumbers.map((doc) {
                                final data = doc.data();
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(data['name']?.toString() ?? ''),
                                );
                              }).toList(),
                              onChanged: selectedLineNumberId == null
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        selectedSpoolNumberId = value;
                                      });
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      TextField(
                        controller: controller,
                        maxLines: allowMultipleInput ? 3 : 1,
                        decoration: InputDecoration(
                          labelText: labelName,
                          hintText: allowMultipleInput
                              ? "Enter multiple separated by comma (e.g. 1, 2, 3...)"
                              : "Enter $labelName",
                          prefixIcon: Icon(icon),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final rawText = controller.text.trim();
                            if (rawText.isEmpty) return;

                            try {
                              final List<String> items = rawText
                                  .split(RegExp(r'[,\n]'))
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                              if (items.isEmpty) return;

                              final batch = FirebaseFirestore.instance.batch();
                              for (final item in items) {
                                final newDocRef = FirebaseFirestore.instance
                                    .collection('projects')
                                    .doc(widget.projectId)
                                    .collection(collectionName)
                                    .doc();

                                final Map<String, dynamic> dataToSave = {
                                  'name': item,
                                  'createdAt': FieldValue.serverTimestamp(),
                                };

                                if (requireTestPackage &&
                                    selectedTestPackageId != null) {
                                  dataToSave['testPackageId'] =
                                      selectedTestPackageId;
                                }
                                if (requireLineNumber &&
                                    selectedLineNumberId != null) {
                                  dataToSave['lineNumberId'] =
                                      selectedLineNumberId;
                                }
                                if (requireSpoolNumber &&
                                    selectedSpoolNumberId != null) {
                                  dataToSave['spoolNumberId'] =
                                      selectedSpoolNumberId;
                                }

                                batch.set(newDocRef, dataToSave);
                              }

                              await batch.commit();
                              controller.clear();
                              Navigator.pop(dialogContext);
                            } catch (e) {
                              // error
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add),
                          label: Text("CREATE ${title.toUpperCase()}"),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      // ডায়ালগের ভেতরের লিস্ট থেকে ডিলিট বাটন বাদ দিয়ে শুধু লিস্ট দেখানো হচ্ছে
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(widget.projectId)
                              .collection(collectionName)
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final docs = snapshot.data?.docs ?? [];
                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data();
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Icon(icon,
                                        color: const Color(0xFF000080)),
                                    title: Text(data['name']?.toString() ?? ''),
                                    trailing: const SizedBox
                                        .shrink(), // ডিলিট বাটন নেই
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String projectName =
        widget.projectData['name']?.toString() ?? 'Project';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // নতুন কিছু অ্যাড করার বাটনগুলো এখানে ফুল সচল থাকবে
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Test Pakeged",
                            collectionName: "testPakeged",
                            labelName: "Test Pakeged Name",
                            icon: Icons.layers,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Test Pakeged"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Line Number",
                            collectionName: "lineNumbers",
                            labelName: "Line Number",
                            icon: Icons.linear_scale,
                            requireTestPackage: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add line number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Spool Number",
                            collectionName: "spoolNumbers",
                            labelName: "Spool Number",
                            icon: Icons.alt_route,
                            requireTestPackage: true,
                            requireLineNumber: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Spool number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Joint Number",
                            collectionName: "jointNumbers",
                            labelName: "Joint Number",
                            icon: Icons.join_full,
                            requireTestPackage: true,
                            requireLineNumber: true,
                            requireSpoolNumber: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Joint Number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Support Number",
                            collectionName: "supportNumbers",
                            labelName: "Support Number",
                            icon: Icons.support,
                            requireTestPackage: true,
                            requireLineNumber: true,
                            requireSpoolNumber: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Support number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Valve Number",
                            collectionName: "valveNumbers",
                            labelName: "Valve Number",
                            icon: Icons.settings_input_component,
                            requireTestPackage: true,
                            requireLineNumber: true,
                            requireSpoolNumber: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Valve number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 15),
                const Text(
                  "All Test Package Hierarchy List",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000080)),
                ),
                const SizedBox(height: 15),

                // টেস্ট প্যাকেজ লিস্ট (কোনো ডিলিট বাটন নেই)
                SizedBox(
                  height: 600,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('testPakeged')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final testPackages = snapshot.data?.docs ?? [];
                      if (testPackages.isEmpty) {
                        return const Center(
                            child: Text("No Test Package found."));
                      }

                      return ListView.builder(
                        itemCount: testPackages.length,
                        itemBuilder: (context, index) {
                          final doc = testPackages[index];
                          final data = doc.data();
                          final packageName = data['name']?.toString() ?? '';

                          // [WebAllProjectDetailsScreen ক্লাসের ভেতরের টেস্ট প্যাকেজ লিস্টের অংশটি এভাবে ঠিক করুন]
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(Icons.layers,
                                  color: Color(0xFF000080)),
                              title: Text(
                                "Test Package: $packageName",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              trailing: const SizedBox.shrink(),
                              onTap: () {
                                final String testPackageId = doc.id;
                                if (widget.onTestPackageTap != null) {
                                  widget.onTestPackageTap!(
                                      testPackageId, packageName);
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// ALL PROJECT পেজ (যেখান থেকে প্রজেক্টের লিস্ট দেখাবে এবং ক্লিক করলে ডিলিট ছাড়া ডিটেইলসে যাবে)
// =====================================================
class WebAllProjectsPage extends StatelessWidget {
  final void Function(Map<String, dynamic> projectData, String projectId)?
      onProjectTap;

  const WebAllProjectsPage({
    super.key,
    this.onProjectTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .orderBy('name')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final projects = snapshot.data?.docs ?? [];
            if (projects.isEmpty) {
              return const Center(
                child: Text(
                  "No Projects Found",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final doc = projects[index];
                final data = doc.data();
                final projectName =
                    data['name']?.toString() ?? 'Unnamed Project';
                final String projectId = doc.id;

                // 👈 প্রতিটি প্রজেক্টের ভেতরের সমস্ত ডেটা রিয়েল-টাইম হিসাব করার জন্য উইজেট
                return ProjectCardWithProgress(
                  projectId: projectId,
                  projectName: projectName,
                  projectData: data,
                  onTap: () {
                    if (onProjectTap != null) {
                      onProjectTap!(data, projectId);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// 👈 আলাদা একটি স্টেটলেস উইজেট যা প্রতিটি প্রজেক্টের প্রোগ্রেস পার্সেন্টেজ হিসাব করবে
class ProjectCardWithProgress extends StatelessWidget {
  final String projectId;
  final String projectName;
  final Map<String, dynamic> projectData;
  final VoidCallback onTap;

  const ProjectCardWithProgress({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.projectData,
    required this.onTap,
  });

  // 👈 আইডি দিয়ে ফায়ারস্টোর থেকে ম্যানেজার, ট্রেড এবং কোম্পানির নাম রিয়েল-টাইমে নিয়ে আসার ফাংশন
  Future<Map<String, String>> _fetchProjectDetails() async {
    String managerName = projectData['projectManager']?.toString() ??
        projectData['managerName']?.toString() ??
        'N/A';
    String tradeName = projectData['trade']?.toString() ??
        projectData['tradeName']?.toString() ??
        'N/A';
    String companyName = projectData['companyName']?.toString() ??
        projectData['company']?.toString() ??
        'N/A';

    try {
      final firestore = FirebaseFirestore.instance;

      // ১. ম্যানেজার নাম আনা (যদি managerId থাকে)
      final managerId = projectData['managerId']?.toString();
      if ((managerName == 'N/A' || managerName.isEmpty) &&
          managerId != null &&
          managerId.isNotEmpty) {
        final mDoc =
            await firestore.collection('employees').doc(managerId).get();
        if (mDoc.exists) {
          managerName = mDoc.data()?['name']?.toString() ?? 'N/A';
        }
      }

      // ২. ট্রেড নাম আনা (যদি tradeId থাকে)
      final tradeId = projectData['tradeId']?.toString();
      if ((tradeName == 'N/A' || tradeName.isEmpty) &&
          tradeId != null &&
          tradeId.isNotEmpty) {
        final tDoc = await firestore.collection('trades').doc(tradeId).get();
        if (tDoc.exists) {
          tradeName = tDoc.data()?['name']?.toString() ?? 'N/A';
        }
      }

      // ৩. কোম্পানি নাম আনা (যদি companyId থাকে)
      final companyId = projectData['companyId']?.toString();
      if ((companyName == 'N/A' || companyName.isEmpty) &&
          companyId != null &&
          companyId.isNotEmpty) {
        final cDoc =
            await firestore.collection('companies').doc(companyId).get();
        if (cDoc.exists) {
          companyName = cDoc.data()?['name']?.toString() ?? 'N/A';
        }
      }
    } catch (e) {
      // কোনো এরর হলে ডিফল্ট ভ্যালু থাকবে
    }

    return {
      'manager': managerName,
      'trade': tradeName,
      'company': companyName,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _fetchProjectDetails(),
      builder: (context, detailsSnapshot) {
        final details = detailsSnapshot.data ?? {};
        final String projectManager = details['manager'] ?? 'N/A';
        final String trade = details['trade'] ?? 'N/A';
        final String companyName = details['company'] ?? 'N/A';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('testPakeged')
              .snapshots(),
          builder: (context, tpSnap) {
            final testPackages = tpSnap.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .doc(projectId)
                  .collection('lineNumbers')
                  .snapshots(),
              builder: (context, lineSnap) {
                final lines = lineSnap.data?.docs ?? [];
                final lineIds = lines.map((l) => l.id).toList();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('projects')
                      .doc(projectId)
                      .collection('spoolNumbers')
                      .snapshots(),
                  builder: (context, spoolSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('projects')
                          .doc(projectId)
                          .collection('jointNumbers')
                          .snapshots(),
                      builder: (context, jointSnap) {
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(projectId)
                              .collection('supportNumbers')
                              .snapshots(),
                          builder: (context, supportSnap) {
                            return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(projectId)
                                  .collection('valveNumbers')
                                  .snapshots(),
                              builder: (context, valveSnap) {
                                // ১. টেস্ট প্যাকেজের পয়েন্ট হিসাব
                                int grandTotal = testPackages.length * 3;
                                int grandCompleted = 0;

                                for (var tp in testPackages) {
                                  var tpData = tp.data();
                                  if (tpData['isHydroTest'] == true)
                                    grandCompleted++;
                                  if (tpData['isLineCheck'] == true)
                                    grandCompleted++;
                                  if (tpData['isReInstrument'] == true)
                                    grandCompleted++;
                                }

                                // ২. স্পুল হিসাব
                                final spools = (spoolSnap.data?.docs ?? [])
                                    .where((s) => lineIds
                                        .contains(s.data()['lineNumberId']))
                                    .toList();
                                final spoolIds =
                                    spools.map((s) => s.id).toList();

                                for (var spool in spools) {
                                  grandTotal += 1;
                                  if (spool.data()['isInstalled'] == true)
                                    grandCompleted++;
                                }

                                // ৩. জয়েন্ট হিসাব (৫টি পয়েন্ট)
                                final joints = (jointSnap.data?.docs ?? [])
                                    .where((j) => spoolIds
                                        .contains(j.data()['spoolNumberId']))
                                    .toList();
                                for (var j in joints) {
                                  grandTotal += 5;
                                  var jData = j.data();
                                  if (jData['isFitup'] == true)
                                    grandCompleted++;
                                  if (jData['isWelding'] == true)
                                    grandCompleted++;
                                  if (jData['isUtPt'] == true) grandCompleted++;
                                  if (jData['isRadiationTest'] == true)
                                    grandCompleted++;
                                  if (jData['isVisual'] == true)
                                    grandCompleted++;
                                }

                                // ৪. সাপোর্ট হিসাব (৩টি পয়েন্ট)
                                final supports = (supportSnap.data?.docs ?? [])
                                    .where((s) => spoolIds
                                        .contains(s.data()['spoolNumberId']))
                                    .toList();
                                for (var s in supports) {
                                  grandTotal += 3;
                                  var sData = s.data();
                                  if (sData['isInstalled'] == true)
                                    grandCompleted++;
                                  if (sData['isFitup'] == true)
                                    grandCompleted++;
                                  if (sData['isWelding'] == true)
                                    grandCompleted++;
                                }

                                // ৫. ভালভ হিসাব (৩টি পয়েন্ট)
                                final valves = (valveSnap.data?.docs ?? [])
                                    .where((v) => spoolIds
                                        .contains(v.data()['spoolNumberId']))
                                    .toList();
                                for (var v in valves) {
                                  grandTotal += 3;
                                  var vData = v.data();
                                  if (vData['isInstalled'] == true)
                                    grandCompleted++;
                                  if (vData['isFitup'] == true)
                                    grandCompleted++;
                                  if (vData['isWelding'] == true)
                                    grandCompleted++;
                                }

                                // পার্সেন্টেজ ক্যালকুলেশন
                                double percentage = grandTotal > 0
                                    ? (grandCompleted / grandTotal) * 100
                                    : 0;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 8),
                                    leading: const Icon(Icons.business_center,
                                        color: Color(0xFF000080), size: 32),
                                    title: Text(
                                      projectName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF000080)),
                                    ),
                                    // ProjectCardWithProgress ক্লাসের ভেতরের subtitle অংশটি এভাবে আপডেট করুন:
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Wrap(
                                        spacing: 15,
                                        runSpacing: 4,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person,
                                                  size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text("Manager: $projectManager",
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black87)),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.engineering,
                                                  size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text("Trade: $trade",
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black87)),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.apartment,
                                                  size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text("Company: $companyName",
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black87)),
                                            ],
                                          ),

                                          // 👇 নতুন যোগ করা অংশ: প্রজেক্টে কতজন এমপ্লয়ী অ্যাসাইন করা আছে তার রিয়েল-টাইম কাউন্ট
                                          StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('projects')
                                                .doc(projectId)
                                                .collection('assignedEmployees')
                                                .snapshots(),
                                            builder: (context, empSnapshot) {
                                              int assignedCount =
                                                  empSnapshot.hasData
                                                      ? empSnapshot
                                                          .data!.docs.length
                                                      : 0;

                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.group,
                                                      size: 14,
                                                      color: Color(0xFF000080)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Employees: $assignedCount",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF000080),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: percentage == 100
                                                ? Colors.green.shade100
                                                : Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: percentage == 100
                                                    ? Colors.green
                                                    : Colors.blue.shade200),
                                          ),
                                          child: Text(
                                            "${percentage.toStringAsFixed(0)}%",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: percentage == 100
                                                  ? Colors.green.shade800
                                                  : const Color(0xFF000080),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.arrow_forward_ios,
                                            size: 16, color: Colors.grey),
                                      ],
                                    ),
                                    onTap: onTap,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class WebAllEmployeesPage extends StatelessWidget {
  final String? roleFilter;

  // Employee profile click করলে এই function চলবে
  final void Function(Map<String, dynamic> employeeData)? onEmployeeTap;

  const WebAllEmployeesPage({
    super.key,
    this.roleFilter,
    this.onEmployeeTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🔹 যদি roleFilter না থাকে → সব Employee দেখাবে
    // 🔹 Manager/Admin থাকলে → শুধু সেই role-এর Employee দেখাবে
    final employeeStream = roleFilter == null
        ? FirebaseFirestore.instance.collection('employees').snapshots()
        : FirebaseFirestore.instance
            .collection('employees')
            .where(
              'role',
              isEqualTo: roleFilter,
            )
            .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: StreamBuilder<QuerySnapshot>(
        stream: employeeStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text("No Employee Added Yet!"),
            );
          }

          return Center(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 1450,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  final String id = data['id']?.toString() ?? '';

                  final String name = data['name']?.toString() ?? '';

                  final String designation =
                      data['designation']?.toString() ?? '';

                  final String role = data['role']?.toString() ?? 'worker';

                  final bool isRegistered = data['isRegistered'] == true;

                  // ম্যানেজারের নাম আছে কিনা তা চেক করার জন্য
                  final String? managerName =
                      data['assignedManagerName']?.toString();
                  final bool hasManager =
                      managerName != null && managerName.isNotEmpty;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        if (onEmployeeTap != null) {
                          onEmployeeTap!(data);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ১. প্রোফাইল আইকন (Leading)
                            // ১. এমপ্লয়ীর রিয়েল প্রফাইল পিকচার বা ডিফল্ট আইকন
                            Builder(
                              builder: (context) {
                                final String? empImgUrl = data['profileImageUrl']?.toString();

                                return (empImgUrl != null && empImgUrl.isNotEmpty)
                                    ? NetworkImageWebFix(
                                  imageUrl: empImgUrl,
                                  radius: 20, // এমপ্লয়ী কার্ডের বৃত্তের জন্য সাইজ 20
                                )
                                    : const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Color(0xFFE8EAF6),
                                  child: Icon(
                                    Icons.person,
                                    color: Color(0xFF000080),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 16),

                            // ২. বাঁ পাশের অংশ: নাম, আইডি, রোল ও রেজিস্ট্রেশন (স্ট্যান্ডার্ড ফন্ট সাইজ ১৩)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "ID: $id | $designation",
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Role: ${role.toUpperCase()}",
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isRegistered
                                        ? "Registered ✅"
                                        : "Not Registered ❌",
                                    style: TextStyle(
                                      color: isRegistered
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            // ৩. ডান পাশের অংশ: কোম্পানি, ম্যানেজার এবং প্রজেক্ট (বাঁ পাশের সাথে ফন্ট সাইজ ১৩ করে মিলানো হলো)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // কোম্পানির নাম
                                if (data['companyName'] != null &&
                                    data['companyName'].toString().isNotEmpty)
                                  Text(
                                    " ${data['companyName']}",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize:
                                          16, // 👈 ফন্ট সাইজ বাঁ পাশের সাথে সমান করা হলো
                                    ),
                                  ),

                                // ম্যানেজারের নাম
                                if (hasManager) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Manager: $managerName",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.indigo,
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          13, // 👈 ফন্ট সাইজ বাঁ পাশের সাথে সমান করা হলো
                                    ),
                                  ),
                                ],

                                // ম্যানেজারের ঠিক নিচে রিয়েল-টাইম প্রজেক্টের নাম
                                const SizedBox(height: 4),
                                StreamBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance
                                      .collection('employees')
                                      .doc(docs[index].id)
                                      .snapshots(),
                                  builder: (context, projectSnapshot) {
                                    final empDocData =
                                        projectSnapshot.data?.data() ?? {};
                                    final String assignedProject =
                                        empDocData['assignedProjectName']
                                                ?.toString() ??
                                            '';

                                    if (assignedProject.isEmpty) {
                                      return const SizedBox
                                          .shrink(); // প্রজেক্ট না থাকলে কিছু দেখাবে না
                                    }

                                    return Text(
                                      "Assigned Project Name: $assignedProject",
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize:
                                            13, // 👈 ফন্ট সাইজ বাঁ পাশের সাথে সমান করা হলো
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF000080),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                            // ৪. যদি ম্যানেজার ফিল্টার পেজ হয়, তবে 'ADD' বাটন দেখাবে
                            if (roleFilter?.toLowerCase() == 'manager') ...[
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _showNonManagerEmployees(
                                    context,
                                    id,
                                  );
                                },
                                icon: const Icon(
                                  Icons.add,
                                  size: 18,
                                ),
                                label: const Text("ADD"),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class WebCenterCreatePage extends StatefulWidget {
  const WebCenterCreatePage({super.key});

  @override
  State<WebCenterCreatePage> createState() => _WebCenterCreatePageState();
}

class _WebCenterCreatePageState extends State<WebCenterCreatePage> {
  bool _isCreatingCompany = false;

  String _makeCode(String value) {
    String code = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    code = code.replaceAll(RegExp(r'^_+|_+$'), '');
    return code;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ================= ROLE MANAGEMENT =================
  void _openRoleManagement() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 750,
            height: 650,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "ROLE MANAGEMENT",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('roles').orderBy('name').snapshots(),
                      builder: (context, roleSnapshot) {
                        if (roleSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final roleDocs = roleSnapshot.data?.docs ?? [];
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('employees').orderBy('id').snapshots(),
                          builder: (context, employeeSnapshot) {
                            if (employeeSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final employeeDocs = employeeSnapshot.data?.docs ?? [];
                            return Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _showAddRoleDialog(roleDocs),
                                  icon: const Icon(Icons.add),
                                  label: const Text("ADD ROLE"),
                                ),
                                const SizedBox(height: 15),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: roleDocs.length,
                                    itemBuilder: (context, index) {
                                      final roleDoc = roleDocs[index];
                                      final roleData = roleDoc.data();
                                      final String roleName = roleData['name']?.toString() ?? '';
                                      final String roleCode = roleData['code']?.toString().toLowerCase() ?? _makeCode(roleName);
                                      String parentName = "Top Level";
                                      final parentId = roleData['parentRoleId']?.toString();

                                      if (parentId != null) {
                                        for (final parent in roleDocs) {
                                          if (parent.id == parentId) {
                                            parentName = parent.data()['name']?.toString() ?? '';
                                            break;
                                          }
                                        }
                                      }

                                      final assignedEmployees = employeeDocs.where((employeeDoc) {
                                        final employeeData = employeeDoc.data();
                                        final employeeRole = employeeData['role']?.toString().toLowerCase();
                                        return employeeRole == roleCode;
                                      }).toList();

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.account_tree),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(roleName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                        const SizedBox(height: 3),
                                                        Text("Reports to role: $parentName", style: const TextStyle(color: Colors.grey)),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red),
                                                    onPressed: () => _deleteRole(roleDoc.id),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              const Divider(),
                                              const SizedBox(height: 6),
                                              Text("Employees (${assignedEmployees.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080))),
                                              const SizedBox(height: 8),
                                              if (assignedEmployees.isEmpty)
                                                const Text("No employee assigned to this role.", style: TextStyle(color: Colors.grey))
                                              else
                                                ...assignedEmployees.map((employeeDoc) {
                                                  final employeeData = employeeDoc.data();
                                                  final id = employeeData['id']?.toString() ?? employeeDoc.id;
                                                  final name = employeeData['name']?.toString() ?? '';
                                                  return Container(
                                                    margin: const EdgeInsets.only(bottom: 6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    decoration: BoxDecoration(color: const Color(0xFFF8F9FE), borderRadius: BorderRadius.circular(10)),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.person_outline, size: 20, color: Color(0xFF000080)),
                                                        const SizedBox(width: 10),
                                                        Expanded(child: Text("$id - $name", style: const TextStyle(fontWeight: FontWeight.w600))),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= DESIGNATION MANAGEMENT =================
  void _openDesignationManagement() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 650,
            height: 520,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "DESIGNATION MANAGEMENT",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const Divider(),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: "Designation Name",
                      hintText: "Enter designation name",
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isEmpty) {
                          _showMessage("Please enter designation name", error: true);
                          return;
                        }
                        try {
                          await FirebaseFirestore.instance.collection('designations').add({
                            'name': name,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          controller.clear();
                          _showMessage("Designation added successfully");
                        } catch (e) {
                          _showMessage("Failed to add designation: $e", error: true);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("CREATE DESIGNATION"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('designations').orderBy('name').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(child: Text("No Designation Added Yet", style: TextStyle(color: Colors.grey)));
                        }
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const Icon(Icons.badge, color: Color(0xFF000080)),
                                title: Text(data['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () async {
                                    try {
                                      await FirebaseFirestore.instance.collection('designations').doc(doc.id).delete();
                                      _showMessage("Designation deleted successfully");
                                    } catch (e) {
                                      _showMessage("Failed to delete designation: $e", error: true);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= HOUSE MANAGEMENT =================
  // ================= HOUSE MANAGEMENT =================
  void _openHouseManagement() {
    final TextEditingController houseNameController = TextEditingController();
    final TextEditingController blockNoController = TextEditingController();
    final TextEditingController levelController = TextEditingController();
    final TextEditingController roomNoController = TextEditingController();
    final TextEditingController seatController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SizedBox(
                width: 700,
                height: 700,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "HOUSE MANAGEMENT",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              TextField(
                                controller: houseNameController,
                                decoration: const InputDecoration(
                                  labelText: "House Name",
                                  hintText: "Enter house name",
                                  prefixIcon: Icon(Icons.home, color: Color(0xFF000080)),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: blockNoController,
                                decoration: const InputDecoration(
                                  labelText: "Block NO",
                                  hintText: "Enter block number",
                                  prefixIcon: Icon(Icons.domain, color: Color(0xFF000080)),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: levelController,
                                decoration: const InputDecoration(
                                  labelText: "Level",
                                  hintText: "Enter level",
                                  prefixIcon: Icon(Icons.layers, color: Color(0xFF000080)),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: roomNoController,
                                decoration: const InputDecoration(
                                  labelText: "Room NO",
                                  hintText: "Enter room number",
                                  prefixIcon: Icon(Icons.meeting_room, color: Color(0xFF000080)),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: seatController,
                                decoration: const InputDecoration(
                                  labelText: "Seat",
                                  hintText: "Enter seat number/name",
                                  prefixIcon: Icon(Icons.chair, color: Color(0xFF000080)),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final houseName = houseNameController.text.trim();
                                    final blockNo = blockNoController.text.trim();
                                    final level = levelController.text.trim();
                                    final roomNo = roomNoController.text.trim();
                                    final seat = seatController.text.trim();

                                    if (houseName.isEmpty) {
                                      _showMessage("Please enter house name", error: true);
                                      return;
                                    }

                                    try {
                                      await FirebaseFirestore.instance.collection('houses').add({
                                        'houseName': houseName,
                                        'blockNo': blockNo,
                                        'level': level,
                                        'roomNo': roomNo,
                                        'seat': seat,
                                        'createdAt': FieldValue.serverTimestamp(),
                                      });

                                      blockNoController.clear();
                                      levelController.clear();
                                      roomNoController.clear();
                                      seatController.clear();

                                      _showMessage("House details added successfully");
                                    } catch (e) {
                                      _showMessage("Failed to add house: $e", error: true);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF000080),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text("CREATE HOUSE"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Added Houses List", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080), fontSize: 14)),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('houses').orderBy('createdAt', descending: true).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Center(child: Text("No House Added Yet", style: TextStyle(color: Colors.grey)));
                            }
                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data();
                                final hName = data['houseName'] ?? '';
                                final bNo = data['blockNo'] ?? '';
                                final lvl = data['level'] ?? '';
                                final rNo = data['roomNo'] ?? '';
                                final st = data['seat'] ?? '';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: const Icon(Icons.home, color: Color(0xFF000080)),
                                    title: Text("House: $hName", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text("Block: $bNo | Level: $lvl | Room: $rNo | Seat: $st"),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () async {
                                        try {
                                          await FirebaseFirestore.instance.collection('houses').doc(doc.id).delete();
                                          _showMessage("House deleted successfully");
                                        } catch (e) {
                                          _showMessage("Failed to delete house: $e", error: true);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================= ADD TOOLS MANAGEMENT =================
  void _openAddToolsManagement() async {
    String autoCode = "10001";
    try {
      final query = await FirebaseFirestore.instance.collection('tools').orderBy('itemCode', descending: true).limit(1).get();
      if (query.docs.isNotEmpty) {
        final lastCode = int.tryParse(query.docs.first.data()['itemCode']?.toString() ?? '') ?? 10000;
        autoCode = (lastCode + 1).toString();
      }
    } catch (_) {}

    final TextEditingController codeController = TextEditingController(text: autoCode);
    final TextEditingController nameController = TextEditingController();

    Uint8List? selectedImageBytes;
    bool isUploadingImage = false;
    String? successMessage;
    String? errorMessage;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 10,
              child: Container(
                width: 820,
                height: 780,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF000080).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.build_rounded, color: Color(0xFF000080), size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Tools Management", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF000080))),
                              SizedBox(height: 2),
                              Text("Add and manage tools inventory with high-end control", style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Divider(height: 25),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        final ImagePicker picker = ImagePicker();
                                        final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500);
                                        if (image == null) return;
                                        final bytes = await image.readAsBytes();
                                        setDialogState(() {
                                          selectedImageBytes = bytes;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(60),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 110,
                                            height: 110,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: const Color(0xFF000080), width: 2.5),
                                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                                            ),
                                            child: selectedImageBytes != null ? ClipOval(child: Image.memory(selectedImageBytes!, fit: BoxFit.cover)) : const Icon(Icons.camera_alt_outlined, size: 42, color: Color(0xFF000080)),
                                          ),
                                          Positioned(
                                            bottom: 2,
                                            right: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(color: Color(0xFF000080), shape: BoxShape.circle),
                                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text("Tool Picture", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(width: 30),
                                Expanded(
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: codeController,
                                        readOnly: true,
                                        decoration: InputDecoration(
                                          labelText: "Item Code (Auto Generated)",
                                          prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF000080)),
                                          filled: true,
                                          fillColor: Colors.grey.shade200,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: nameController,
                                        decoration: InputDecoration(
                                          labelText: "Item Name",
                                          hintText: "Enter item name",
                                          prefixIcon: const Icon(Icons.badge, color: Color(0xFF000080)),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            if (successMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                margin: const EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade300, width: 1.5)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(successMessage!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14))),
                                  ],
                                ),
                              ),
                            ],

                            if (errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                margin: const EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade300, width: 1.5)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_rounded, color: Colors.red, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14))),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: isUploadingImage ? null : () async {
                                  final code = codeController.text.trim();
                                  final name = nameController.text.trim();
                                  if (code.isEmpty || name.isEmpty) {
                                    setDialogState(() {
                                      errorMessage = "Please enter Item Name!";
                                      successMessage = null;
                                    });
                                    return;
                                  }
                                  try {
                                    setDialogState(() {
                                      isUploadingImage = true;
                                      errorMessage = null;
                                      successMessage = null;
                                    });
                                    String imageUrl = '';
                                    if (selectedImageBytes != null) {
                                      final storageRef = FirebaseStorage.instance.ref().child('tool_images').child('${DateTime.now().millisecondsSinceEpoch}.jpg');
                                      final metadata = SettableMetadata(contentType: 'image/jpeg');
                                      await storageRef.putData(selectedImageBytes!, metadata);
                                      final rawUrl = await storageRef.getDownloadURL();
                                      imageUrl = "$rawUrl&v=${DateTime.now().millisecondsSinceEpoch}";
                                    }
                                    await FirebaseFirestore.instance.collection('tools').add({
                                      'itemCode': code,
                                      'name': name,
                                      'imageUrl': imageUrl,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    int nextCodeVal = (int.tryParse(code) ?? 10000) + 1;
                                    codeController.text = nextCodeVal.toString();
                                    nameController.clear();
                                    selectedImageBytes = null;

                                    setDialogState(() {
                                      isUploadingImage = false;
                                      successMessage = "Tool added successfully!";
                                    });
                                    Future.delayed(const Duration(seconds: 3), () {
                                      if (dialogContext.mounted) {
                                        setDialogState(() {
                                          successMessage = null;
                                        });
                                      }
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      isUploadingImage = false;
                                      errorMessage = "Failed to add tool: $e";
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF000080),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: isUploadingImage ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_circle_outline),
                                label: Text(isUploadingImage ? "ADDING TOOL..." : "ADD TOOL", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Added Tools List", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080), fontSize: 15)),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('tools').orderBy('createdAt', descending: true).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(child: Text("No Tools Added Yet", style: TextStyle(color: Colors.grey)));
                          }
                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final String? toolImg = data['imageUrl']?.toString();
                              final String itemCode = data['itemCode']?.toString() ?? '';
                              final String itemName = data['name']?.toString() ?? '';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: toolImg != null && toolImg.isNotEmpty ? NetworkImageWebFix(imageUrl: toolImg, radius: 24) : const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE8EAF6), child: Icon(Icons.build, color: Color(0xFF000080), size: 22)),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF000080).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF000080).withOpacity(0.2)),
                                        ),
                                        child: Text("Code: $itemCode", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF000080))),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () async {
                                      try {
                                        await FirebaseFirestore.instance.collection('tools').doc(doc.id).delete();
                                        setDialogState(() {
                                          successMessage = "Tool deleted successfully!";
                                        });
                                        Future.delayed(const Duration(seconds: 3), () {
                                          if (dialogContext.mounted) {
                                            setDialogState(() {
                                              successMessage = null;
                                            });
                                          }
                                        });
                                      } catch (e) {
                                        setDialogState(() {
                                          errorMessage = "Failed to delete tool: $e";
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddRoleDialog(List<QueryDocumentSnapshot<Map<String, dynamic>>> roleDocs) {
    final controller = TextEditingController();
    String? parentRoleId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Role"),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: "Role Name", hintText: "Enter role name", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String?>(
                      value: parentRoleId,
                      decoration: const InputDecoration(labelText: "Reports To Role", border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text("Top Level / No Parent")),
                        ...roleDocs.map((doc) => DropdownMenuItem<String?>(value: doc.id, child: Text(doc.data()['name']?.toString() ?? ''))),
                      ],
                      onChanged: (value) => setDialogState(() => parentRoleId = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                ElevatedButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    try {
                      await FirebaseFirestore.instance.collection('roles').add({
                        'name': name,
                        'code': _makeCode(name),
                        'parentRoleId': parentRoleId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      _showMessage("Role add failed: $e", error: true);
                    }
                  },
                  child: const Text("ADD"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRole(String roleId) async {
    try {
      final employeeCheck = await FirebaseFirestore.instance.collection('employees').where('roleId', isEqualTo: roleId).limit(1).get();
      final childRoleCheck = await FirebaseFirestore.instance.collection('roles').where('parentRoleId', isEqualTo: roleId).limit(1).get();

      if (employeeCheck.docs.isNotEmpty || childRoleCheck.docs.isNotEmpty) {
        _showMessage("This role is in use. Reassign employees/child roles first.", error: true);
        return;
      }
      await FirebaseFirestore.instance.collection('roles').doc(roleId).delete();
      _showMessage("Role deleted");
    } catch (e) {
      _showMessage("Role delete failed: $e", error: true);
    }
  }

  // ================= TRADE MANAGEMENT =================
  void _openTradeManagement() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 700,
            height: 550,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "TRADE MANAGEMENT",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const Divider(),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: "New Trade Name",
                      hintText: "Enter trade name",
                      prefixIcon: Icon(Icons.engineering),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("CREATE TRADE"),
                      onPressed: () async {
                        final String name = controller.text.trim();
                        if (name.isEmpty) {
                          _showMessage("Please enter trade name", error: true);
                          return;
                        }
                        try {
                          final duplicate = await FirebaseFirestore.instance.collection('trades').where('code', isEqualTo: _makeCode(name)).limit(1).get();
                          if (duplicate.docs.isNotEmpty) {
                            _showMessage("This Trade already exists", error: true);
                            return;
                          }
                          await FirebaseFirestore.instance.collection('trades').add({
                            'name': name,
                            'code': _makeCode(name),
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          controller.clear();
                          _showMessage("Trade created successfully");
                        } catch (e) {
                          _showMessage("Trade add failed: $e", error: true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('trades').orderBy('name').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final tradeDocs = snapshot.data?.docs ?? [];
                        if (tradeDocs.isEmpty) {
                          return const Center(child: Text("No Trade Created Yet", style: TextStyle(color: Colors.grey)));
                        }
                        return ListView.builder(
                          itemCount: tradeDocs.length,
                          itemBuilder: (context, index) {
                            final tradeDoc = tradeDocs[index];
                            final tradeData = tradeDoc.data();
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const Icon(Icons.engineering, color: Color(0xFF000080)),
                                title: Text(tradeData['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteTrade(tradeDoc.id),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteTrade(String tradeId) async {
    try {
      final projectCheck = await FirebaseFirestore.instance.collection('projects').where('tradeId', isEqualTo: tradeId).limit(1).get();
      final employeeCheck = await FirebaseFirestore.instance.collection('employees').where('tradeId', isEqualTo: tradeId).limit(1).get();

      if (projectCheck.docs.isNotEmpty || employeeCheck.docs.isNotEmpty) {
        _showMessage("Trade is in use. Remove project/employee assignments first.", error: true);
        return;
      }
      await FirebaseFirestore.instance.collection('trades').doc(tradeId).delete();
      _showMessage("Trade deleted");
    } catch (e) {
      _showMessage("Trade delete failed: $e", error: true);
    }
  }

  // ================= PROJECT MANAGEMENT =================
  void _openProjectManagement() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 750,
            height: 600,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "PROJECT MANAGEMENT",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const Divider(),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('trades').orderBy('name').snapshots(),
                    builder: (context, tradeSnapshot) {
                      final trades = tradeSnapshot.data?.docs ?? [];
                      return ElevatedButton.icon(
                        onPressed: trades.isEmpty ? null : () => _showAddProjectDialog(trades),
                        icon: const Icon(Icons.add),
                        label: const Text("ADD PROJECT"),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('projects').orderBy('name').snapshots(),
                      builder: (context, projectSnapshot) {
                        final projectDocs = projectSnapshot.data?.docs ?? [];
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('trades').snapshots(),
                          builder: (context, tradeSnapshot) {
                            final tradeDocs = tradeSnapshot.data?.docs ?? [];
                            return ListView.builder(
                              itemCount: projectDocs.length,
                              itemBuilder: (context, index) {
                                final doc = projectDocs[index];
                                final data = doc.data();
                                final tradeId = data['tradeId']?.toString();
                                String tradeName = "No Trade";

                                for (final trade in tradeDocs) {
                                  if (trade.id == tradeId) {
                                    tradeName = trade.data()['name']?.toString() ?? '';
                                  }
                                }

                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.business_center),
                                    title: Text(data['name']?.toString() ?? ''),
                                    subtitle: Text("Trade: $tradeName"),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteProject(doc.id),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddProjectDialog(List<QueryDocumentSnapshot<Map<String, dynamic>>> tradeDocs) {
    final controller = TextEditingController();
    String? tradeId;
    String? managerId;
    String? companyId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Project"),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(labelText: "Project Name", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('employees').where('role', isEqualTo: 'manager').snapshots(),
                        builder: (context, managerSnapshot) {
                          final managers = managerSnapshot.data?.docs ?? [];
                          return DropdownButtonFormField<String>(
                            value: managerId,
                            decoration: const InputDecoration(labelText: "Select Manager", border: OutlineInputBorder()),
                            items: managers.map((doc) {
                              final data = doc.data();
                              final mName = data['name']?.toString() ?? '';
                              final mId = data['id']?.toString() ?? doc.id;
                              return DropdownMenuItem<String>(value: doc.id, child: Text("$mName ($mId)"));
                            }).toList(),
                            onChanged: (value) => setDialogState(() => managerId = value),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: tradeId,
                        decoration: const InputDecoration(labelText: "Select Trade", border: OutlineInputBorder()),
                        items: tradeDocs.map((doc) {
                          final data = doc.data();
                          return DropdownMenuItem<String>(value: doc.id, child: Text(data['name']?.toString() ?? ''));
                        }).toList(),
                        onChanged: (value) => setDialogState(() => tradeId = value),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('companies').orderBy('name').snapshots(),
                        builder: (context, companySnapshot) {
                          final companies = companySnapshot.data?.docs ?? [];
                          return DropdownButtonFormField<String>(
                            value: companyId,
                            decoration: const InputDecoration(labelText: "Select Company", border: OutlineInputBorder()),
                            items: companies.map((doc) {
                              final data = doc.data();
                              return DropdownMenuItem<String>(value: doc.id, child: Text(data['name']?.toString() ?? ''));
                            }).toList(),
                            onChanged: (value) => setDialogState(() => companyId = value),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                ElevatedButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty || tradeId == null || managerId == null || companyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fill all fields (Name, Manager, Trade, Company)!"), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    try {
                      final tradeDoc = tradeDocs.firstWhere((doc) => doc.id == tradeId);
                      final tradeName = tradeDoc.data()['name']?.toString() ?? '';

                      final managerDoc = await FirebaseFirestore.instance.collection('employees').doc(managerId).get();
                      final managerName = managerDoc.data()?['name']?.toString() ?? 'N/A';

                      final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
                      final companyName = companyDoc.data()?['name']?.toString() ?? 'N/A';

                      await FirebaseFirestore.instance.collection('projects').add({
                        'name': name,
                        'code': _makeCode(name),
                        'tradeId': tradeId,
                        'trade': tradeName,
                        'managerId': managerId,
                        'projectManager': managerName,
                        'companyId': companyId,
                        'companyName': companyName,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      _showMessage("Project add failed: $e", error: true);
                    }
                  },
                  child: const Text("ADD"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProject(String projectId) async {
    try {
      final employeeCheck = await FirebaseFirestore.instance.collection('employees').where('projectIds', arrayContains: projectId).limit(1).get();
      if (employeeCheck.docs.isNotEmpty) {
        _showMessage("Project is assigned to employees. Remove assignments first.", error: true);
        return;
      }
      await FirebaseFirestore.instance.collection('projects').doc(projectId).delete();
      _showMessage("Project deleted");
    } catch (e) {
      _showMessage("Project delete failed: $e", error: true);
    }
  }

  // ================= COMPANY MANAGEMENT =================
  void _openCompanyManagement() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: SizedBox(
                width: 650,
                height: 520,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "COMPANY MANAGEMENT",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                            ),
                          ),
                          IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const Divider(),
                      TextField(
                        controller: controller,
                        enabled: !_isCreatingCompany,
                        decoration: const InputDecoration(
                          labelText: "Company Name",
                          hintText: "Enter company name",
                          prefixIcon: Icon(Icons.apartment),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isCreatingCompany ? null : () async {
                            final String name = controller.text.trim();
                            if (name.isEmpty) {
                              _showMessage("Please enter company name", error: true);
                              return;
                            }
                            final String code = _makeCode(name);
                            if (code.isEmpty) {
                              _showMessage("Please enter a valid company name", error: true);
                              return;
                            }
                            setState(() => _isCreatingCompany = true);
                            setDialogState(() {});
                            try {
                              final companyRef = FirebaseFirestore.instance.collection('companies').doc(code);
                              final existingCompany = await companyRef.get();
                              if (existingCompany.exists) {
                                _showMessage("This company already exists", error: true);
                                return;
                              }
                              await companyRef.set({
                                'name': name,
                                'code': code,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              controller.clear();
                              _showMessage("Company created successfully");
                            } catch (e) {
                              _showMessage("Company create failed: $e", error: true);
                            } finally {
                              if (mounted) {
                                setState(() => _isCreatingCompany = false);
                                setDialogState(() {});
                              }
                            }
                          },
                          icon: _isCreatingCompany ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_business),
                          label: Text(_isCreatingCompany ? "CREATING COMPANY..." : "CREATE COMPANY"),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('companies').orderBy('name').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final companyDocs = snapshot.data?.docs ?? [];
                            if (companyDocs.isEmpty) {
                              return const Center(child: Text("No Company Created Yet", style: TextStyle(color: Colors.grey)));
                            }
                            return ListView.builder(
                              itemCount: companyDocs.length,
                              itemBuilder: (context, index) {
                                final companyDoc = companyDocs[index];
                                final companyData = companyDoc.data();
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: const Icon(Icons.apartment, color: Color(0xFF000080)),
                                    title: Text(companyData['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () async {
                                        try {
                                          await FirebaseFirestore.instance.collection('companies').doc(companyDoc.id).delete();
                                          _showMessage("Company deleted successfully");
                                        } catch (e) {
                                          _showMessage("Company delete failed: $e", error: true);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(35),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 35),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPremiumButton(
                    title: "MANAGE ROLES",
                    icon: Icons.account_tree_rounded,
                    onTap: _openRoleManagement,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumButton(
                    title: "MANAGE TRADES",
                    icon: Icons.engineering_rounded,
                    onTap: _openTradeManagement,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumButton(
                    title: "MANAGE PROJECTS",
                    icon: Icons.business_center_rounded,
                    onTap: _openProjectManagement,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumButton(
                    title: "CREATE COMPANY",
                    icon: Icons.apartment_rounded,
                    onTap: _openCompanyManagement,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumButton(
                    title: "DESIGNATION",
                    icon: Icons.badge_rounded,
                    onTap: _openDesignationManagement,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumButton(
                    title: "ADD TOOLS",
                    icon: Icons.build_rounded,
                    onTap: _openAddToolsManagement,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumButton(
                    title: "HOUSE",
                    icon: Icons.home_rounded,
                    onTap: _openHouseManagement,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumButton(
                    title: "PRF LETTER HEAD",
                    icon: Icons.description_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebPrfLetterHeadPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 320,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF4F5FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000080).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: const Color(0xFF000080).withOpacity(0.15), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFF000080).withOpacity(0.1),
          highlightColor: const Color(0xFF000080).withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000080).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF000080), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000080),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF000080), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, color: Colors.grey, size: 30),
        SizedBox(height: 5),
        Text("Add Logo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }
}

class WebPrfLetterHeadPage extends StatefulWidget {
  const WebPrfLetterHeadPage({super.key});

  @override
  State<WebPrfLetterHeadPage> createState() => _WebPrfLetterHeadPageState();
}

class _WebPrfLetterHeadPageState extends State<WebPrfLetterHeadPage> {
  String? selectedCompanyId;
  bool isSubmitted = false;
  bool isSaving = false;

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _tellController = TextEditingController();
  final TextEditingController _faxController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController(text: "PIPING");
  final TextEditingController _purposeController = TextEditingController(text: "TO BE USE FOR PRODUCTION & OFFICIAL");
  final TextEditingController _controlNoController = TextEditingController(text: "PRF-SBMME");
  final TextEditingController _dateNeededController = TextEditingController(text: "ASAP");

  Uint8List? _logoBytes;
  String? _existingLogoUrl;

  // =========================================================
  // LOAD COMPANY DETAILS
  // =========================================================
  Future<void> _loadCompanyDetails(String companyId) async {
    try {
      final prfDoc = await FirebaseFirestore.instance.collection('prf_letter_heads').doc(companyId).get();
      final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();

      if (!mounted) return;

      final prfData = prfDoc.data() ?? {};
      final companyData = companyDoc.data() ?? {};

      final String? prfLogoUrl = prfData['logoUrl']?.toString().trim();
      final String? companyLogoUrl = companyData['logoUrl']?.toString().trim();

      final String? finalLogoUrl = (prfLogoUrl != null && prfLogoUrl.isNotEmpty)
          ? prfLogoUrl
          : (companyLogoUrl != null && companyLogoUrl.isNotEmpty ? companyLogoUrl : null);
      debugPrint("PRF LOGO URL = ${prfData['logoUrl']}");
      debugPrint("COMPANY LOGO URL = ${companyData['logoUrl']}");
      debugPrint("FINAL LOGO URL = $finalLogoUrl");

      setState(() {
        _companyNameController.text = prfData['companyName']?.toString() ?? companyData['name']?.toString().toUpperCase() ?? 'COMPANY NAME';
        _addressController.text = prfData['address']?.toString() ?? companyData['address']?.toString() ?? '3 SOONLE STREET #01-05, SINGAPORE 627606';
        _regNoController.text = prfData['regNo']?.toString() ?? companyData['regNo']?.toString() ?? '200804295k';
        _tellController.text = prfData['phone']?.toString() ?? companyData['contact']?.toString() ?? 'phone +65 67104933 , 6710 4934';
        _faxController.text = prfData['fax']?.toString() ?? companyData['fax']?.toString() ?? 'Fax : +65 6659 6929';
        _emailController.text = prfData['email']?.toString() ?? companyData['email']?.toString() ?? 'Mail : arifulislam@gmail.com';
        _websiteController.text = prfData['website']?.toString() ?? companyData['website']?.toString() ?? 'Website : ariful.4327647264736746hdaghgfdoht';

        _departmentController.text = prfData['department']?.toString() ?? 'PIPING';
        _purposeController.text = prfData['purpose']?.toString() ?? 'TO BE USE FOR PRODUCTION & OFFICIAL';
        _controlNoController.text = prfData['controlNo']?.toString() ?? 'PRF-SBMME';
        _dateNeededController.text = prfData['dateNeeded']?.toString() ?? 'ASAP';

        _existingLogoUrl = finalLogoUrl;
        _logoBytes = null;

        isSubmitted = true;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load company details: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // PICK LOGO
  // =========================================================
  Future<void> _pickLogo() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _logoBytes = bytes;
        _existingLogoUrl = null;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to select logo: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // SAVE LETTER HEAD + LOGO
  // =========================================================
  Future<void> _saveLetterHeadToFirebase() async {
    if (selectedCompanyId == null) return;

    setState(() {
      isSaving = true;
    });

    try {
      String logoUrl = _existingLogoUrl ?? "";

      if (_logoBytes != null) {
        final storageRef = FirebaseStorage.instance.ref().child('prf_logos/$selectedCompanyId.png');
        final uploadTask = storageRef.putData(_logoBytes!, SettableMetadata(contentType: 'image/png'));
        final snapshot = await uploadTask;
        final rawUrl = await snapshot.ref.getDownloadURL();
        logoUrl = '$rawUrl&v=${DateTime.now().millisecondsSinceEpoch}';
      }

      final dataMap = {
        'companyId': selectedCompanyId,
        'companyName': _companyNameController.text.trim(),
        'address': _addressController.text.trim(),
        'regNo': _regNoController.text.trim(),
        'phone': _tellController.text.trim(),
        'fax': _faxController.text.trim(),
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
        'department': _departmentController.text.trim(),
        'purpose': _purposeController.text.trim(),
        'controlNo': _controlNoController.text.trim(),
        'dateNeeded': _dateNeededController.text.trim(),
        'logoUrl': logoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('prf_letter_heads').doc(selectedCompanyId).set(dataMap, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        isSaving = false;
        _existingLogoUrl = logoUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Letter Head & Logo Saved Successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000080),
        title: const Text("PRF Letter Head", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isSubmitted) ...[
                  const Text("Select Company for PRF Letter Head", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF000080))),
                  const SizedBox(height: 8),
                  const Text("Choose a company from the list below to proceed with the letter head.", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 30),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('companies').orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final companies = snapshot.data?.docs ?? [];
                      if (companies.isEmpty) {
                        return const Text("No company found! Please create a company first.");
                      }

                      return DropdownButtonFormField<String>(
                        value: selectedCompanyId,
                        decoration: InputDecoration(
                          labelText: "Select Company",
                          prefixIcon: const Icon(Icons.apartment, color: Color(0xFF000080)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: companies.map((doc) {
                          final data = doc.data();
                          final companyName = data['name']?.toString() ?? 'Unnamed Company';
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(companyName, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCompanyId = value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  if (selectedCompanyId != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000080),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (selectedCompanyId != null) {
                            _loadCompanyDetails(selectedCompanyId!);
                          }
                        },
                        child: const Text("SUBMIT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            isSubmitted = false;
                          });
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("Back to Select"),
                      ),
                      ElevatedButton.icon(
                        onPressed: isSaving ? null : _saveLetterHeadToFirebase,
                        icon: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(isSaving ? "SAVING..." : "SAVE"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Table(
                          border: const TableBorder(
                            horizontalInside: BorderSide(color: Colors.black, width: 1),
                            verticalInside: BorderSide(color: Colors.black, width: 1),
                            top: BorderSide(color: Colors.black, width: 1),
                            bottom: BorderSide(color: Colors.black, width: 1),
                            left: BorderSide(color: Colors.black, width: 1),
                            right: BorderSide(color: Colors.black, width: 1),
                          ),
                          columnWidths: const {
                            0: FixedColumnWidth(180),
                            1: FlexColumnWidth(),
                          },
                          children: [
                            TableRow(
                              children: [
                                InkWell(
                                  onTap: _pickLogo,
                                  child: Container(
                                    height: 140,
                                    width: 180,
                                    alignment: Alignment.center,
                                    color: Colors.white,
                                    child: _logoBytes != null
                                        ? Image.memory(_logoBytes!, width: double.infinity, height: 130, fit: BoxFit.contain)
                                        : (_existingLogoUrl != null && _existingLogoUrl!.trim().isNotEmpty
                                        ? Image.network(_existingLogoUrl!, width: double.infinity, height: 130, fit: BoxFit.contain, loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)), errorBuilder: (context, error, stackTrace) => const _LogoPlaceholder())
                                        : const _LogoPlaceholder()),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextField(
                                          controller: _companyNameController,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      TextField(
                                        controller: _addressController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                      const SizedBox(height: 3),
                                      TextField(
                                        controller: _regNoController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          IntrinsicWidth(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(minWidth: 50, maxWidth: 350),
                                              child: TextField(
                                                controller: _tellController,
                                                style: const TextStyle(fontSize: 13),
                                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 25),
                                          Expanded(
                                            child: TextField(
                                              controller: _faxController,
                                              style: const TextStyle(fontSize: 13),
                                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          IntrinsicWidth(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(minWidth: 50, maxWidth: 350),
                                              child: TextField(
                                                controller: _emailController,
                                                style: const TextStyle(fontSize: 13),
                                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 25),
                                          Expanded(
                                            child: TextField(
                                              controller: _websiteController,
                                              style: const TextStyle(fontSize: 13),
                                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        const Center(
                          child: Text("PURCHASE REQISTION FORM", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 15),
                        Table(
                          border: const TableBorder(
                            horizontalInside: BorderSide(color: Colors.black, width: 1),
                            verticalInside: BorderSide(color: Colors.black, width: 1),
                            top: BorderSide(color: Colors.black, width: 1),
                            bottom: BorderSide(color: Colors.black, width: 1),
                            left: BorderSide(color: Colors.black, width: 1),
                            right: BorderSide(color: Colors.black, width: 1),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1.2),
                          },
                          children: [
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text("Department : ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Expanded(
                                            child: TextField(
                                              controller: _departmentController,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Text("PURPOSE : ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Expanded(
                                            child: TextField(
                                              controller: _purposeController,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text("CONTROL NO  ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Expanded(
                                            child: TextField(
                                              controller: _controlNoController,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Text("Date Needed  ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Expanded(
                                            child: TextField(
                                              controller: _dateNeededController,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
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
}


class WebEmployeeDetailsPage extends StatelessWidget {
  final Map<String, dynamic> employeeData;
  final VoidCallback onBack;

  const WebEmployeeDetailsPage({
    super.key,
    required this.employeeData,
    required this.onBack,
  });

  Future<Map<String, String>> _loadOrganizationData() async {
    final String tradeId = employeeData['tradeId']?.toString() ?? '';

    final String companyId = employeeData['companyId']?.toString() ?? '';

    String tradeName = 'Not Assigned';
    String companyName = 'Not Assigned';

    try {
      if (tradeId.isNotEmpty) {
        final tradeDoc = await FirebaseFirestore.instance
            .collection('trades')
            .doc(tradeId)
            .get();

        if (tradeDoc.exists) {
          final data = tradeDoc.data();
          tradeName = data?['name']?.toString() ?? 'Not Assigned';
        }
      }

      if (companyId.isNotEmpty) {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();

        if (companyDoc.exists) {
          final data = companyDoc.data();
          companyName = data?['name']?.toString() ?? 'Not Assigned';
        }
      }
    } catch (e) {
      tradeName = 'Not Available';
      companyName = 'Not Available';
    }

    return {
      'tradeName': tradeName,
      'companyName': companyName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final String id = employeeData['id']?.toString() ?? '';

    final String name = employeeData['name']?.toString() ?? '';

    final String fin = employeeData['fin']?.toString() ?? '';

    final String workPermit = employeeData['workPermit']?.toString() ?? '';

    final String countryCode = employeeData['countryCode']?.toString() ?? '';

    final String phone = employeeData['phone']?.toString() ?? '';

    final String fullPhoneNumber =
        employeeData['fullPhoneNumber']?.toString() ?? '';

    final String designation = employeeData['designation']?.toString() ?? '';

    final String role = employeeData['role']?.toString() ?? '';

    final String tradeId = employeeData['tradeId']?.toString() ?? '';

    final String companyId = employeeData['companyId']?.toString() ?? '';

    final bool isRegistered = employeeData['isRegistered'] == true;

    final String? imageUrl = employeeData['profileImageUrl']?.toString();

    final List<dynamic> projectIds = employeeData['projectIds'] is List
        ? employeeData['projectIds'] as List
        : [];

    return FutureBuilder<Map<String, String>>(
      future: _loadOrganizationData(),
      builder: (context, snapshot) {
        final String tradeName = snapshot.data?['tradeName'] ?? 'Loading...';

        final String companyName =
            snapshot.data?['companyName'] ?? 'Loading...';

        return Container(
          color: const Color(0xFFF5F7FC),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1050,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 22),

                    // =====================================================
                    // PROFILE HERO CARD
                    // =====================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black12,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 18,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF000080),
                                width: 3,
                              ),
                            ),
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? NetworkImageWebFix(
                              imageUrl: imageUrl!,
                              radius: 45, // প্রফাইল পেজের বড় বৃত্তের জন্য সাইজ 45
                            )
                                : const CircleAvatar(
                              radius: 45,
                              backgroundColor: Color(0xFFE8EAF6),
                              child: Icon(
                                Icons.person,
                                size: 65,
                                color: Color(0xFF000080),
                              ),
                            ),
                          ),
                          const SizedBox(width: 25),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? "No Name" : name,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  id,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _badge(
                                      Icons.work_outline,
                                      designation.isEmpty
                                          ? "No Designation"
                                          : designation,
                                    ),
                                    _badge(
                                      Icons.badge_outlined,
                                      role.isEmpty
                                          ? "No Role"
                                          : role.toUpperCase(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // =====================================================
                    // PERSONAL INFORMATION
                    // =====================================================
                    _sectionTitle(
                      Icons.person_outline,
                      "PERSONAL INFORMATION",
                    ),
                    const SizedBox(height: 12),
                    _informationGrid(
                      children: [
                        _infoCard("Employee ID", id, Icons.badge_outlined),
                        _infoCard("Full Name", name, Icons.person_outline),
                        _infoCard(
                            "FIN Number", fin, Icons.credit_card_outlined),
                        _infoCard("Work Permit", workPermit,
                            Icons.card_membership_outlined),
                        _infoCard(
                            "Designation", designation, Icons.work_outline),
                        _infoCard("Role", role.toUpperCase(),
                            Icons.admin_panel_settings_outlined),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // =====================================================
                    // ORGANIZATION
                    // =====================================================
                    _sectionTitle(
                      Icons.account_tree_outlined,
                      "ORGANIZATION",
                    ),
                    const SizedBox(height: 12),
                    _informationGrid(
                      children: [
                        _infoCard(
                            "Trade ID", tradeId, Icons.engineering_outlined),
                        _infoCard(
                            "Trade Name", tradeName, Icons.handyman_outlined),
                        _infoCard(
                            "Company ID", companyId, Icons.business_outlined),
                        _infoCard("Company Name", companyName,
                            Icons.apartment_outlined),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // =====================================================
                    // CONTACT INFORMATION
                    // =====================================================
                    _sectionTitle(
                      Icons.contact_phone_outlined,
                      "CONTACT INFORMATION",
                    ),
                    const SizedBox(height: 12),
                    _informationGrid(
                      children: [
                        _infoCard("Country Code", countryCode, Icons.public),
                        _infoCard("Phone", phone, Icons.phone_outlined),
                        _infoCard("Full Phone Number", fullPhoneNumber,
                            Icons.phone_android_outlined),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // =====================================================
                    // PROJECT INFORMATION (Live Stream & Dialog Button)
                    // =====================================================
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.business_center,
                                color: Color(0xFF000080), size: 36),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "PROJECT INFORMATION",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  StreamBuilder<
                                      QuerySnapshot<Map<String, dynamic>>>(
                                    stream: FirebaseFirestore.instance
                                        .collection('projects')
                                        .where('managerId', isEqualTo: id)
                                        .snapshots(),
                                    builder: (context, projectSnap) {
                                      final projects =
                                          projectSnap.data?.docs ?? [];
                                      int projectCount = projects.length;

                                      return Row(
                                        children: [
                                          Text(
                                            projectCount > 0
                                                ? "$projectCount Projects Assigned"
                                                : "No Project Assigned",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: projectCount > 0
                                                  ? Colors.black87
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const Spacer(),
                                          ElevatedButton(
                                            onPressed: () {
                                              _showManagerProjectsDialog(
                                                  context, id, name);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF000080),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                            child:
                                                Text("$projectCount Projects"),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EAF6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.folder_outlined,
                              color: Color(0xFF000080),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${projectIds.length} Project"
                              "${projectIds.length == 1 ? '' : 's'}",
                              style: const TextStyle(
                                color: Color(0xFF000080),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // =====================================================
                    // ACCOUNT STATUS
                    // =====================================================
                    _sectionTitle(
                      Icons.security_outlined,
                      "ACCOUNT STATUS",
                    ),
                    const SizedBox(height: 12),
                    _informationGrid(
                      children: [
                        _statusCard(
                          "Registration",
                          isRegistered ? "REGISTERED" : "NOT REGISTERED",
                          isRegistered,
                        ),
                        _infoCard(
                          "Account Role",
                          role.isEmpty ? "Not Available" : role.toUpperCase(),
                          Icons.shield_outlined,
                        ),
                      ],
                    ),

                    // Role যদি MANAGER হয় তবেই Assigned Employees সেকশন দেখাবে
                    if (role.toUpperCase() == 'MANAGER') ...[
                      const SizedBox(height: 25),
                      _sectionTitle(
                        Icons.group_outlined,
                        "ASSIGNED EMPLOYEES",
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('managers')
                            .doc(id)
                            .collection('assignedEmployees')
                            .snapshots(),
                        builder: (context, snapshot) {
                          int count =
                              snapshot.hasData ? snapshot.data!.docs.length : 0;

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Assigned Employees List",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    Text(
                                      "Total $count employees assigned",
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF000080),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    _showAssignedEmployeesDialog(context, id);
                                  },
                                  icon: const Icon(Icons.visibility_outlined,
                                      size: 18),
                                  label: Text("VIEW EMPLOYEES ($count)"),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 25),

                    // =====================================================
                    // FOOTER
                    // =====================================================
                    Center(
                      child: Text(
                        "SBM GROUP OF COMPANNY • Employee Management System",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================
  // SECTION TITLE
  // ===========================================================
  Widget _sectionTitle(
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAF6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF000080),
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF000080),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ===========================================================
// MANAGER PROJECTS DIALOG (ULTRA-PREMIUM & LARGE DESIGN)
// ===========================================================
  void _showManagerProjectsDialog(
      BuildContext context, String managerId, String managerName) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 850,
            height: 620,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // 👈 প্রিমিয়াম ডার্ক নেভি ব্যাকগ্রাউন্ড
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // প্রিমিয়াম ব্লু গ্রেডিয়েন্ট হেডার
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            managerName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF1F5F9), // প্রিমিয়াম অফ-হোয়াইট নাম
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Manage and assign personnel to active projects seamlessly",
                            style: TextStyle(fontSize: 13.5, color: Colors.white.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.white12, thickness: 1.2),
                ),

                // প্রজেক্ট লিস্ট সেকশন
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .where('managerId', isEqualTo: managerId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }

                      final projects = snapshot.data?.docs ?? [];

                      if (projects.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_off_outlined, size: 55, color: Colors.white54),
                              const SizedBox(height: 12),
                              const Text(
                                "No projects assigned to this manager yet.",
                                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final doc = projects[index];
                          final data = doc.data();
                          final projectName =
                              data['name']?.toString() ?? 'Unnamed Project';
                          final projectId = doc.id;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B), // 👈 প্রিমিয়াম ডার্ক স্লেট কার্ড ব্যাকগ্রাউন্ড
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.folder_open_rounded, color: Color(0xFF38BDF8), size: 26),
                              ),
                              title: Text(
                                projectName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Color(0xFFF1F5F9), // প্রিমিয়াম অফ-হোয়াইট প্রজেক্ট নাম
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "Click to assign employees and manage project workflow",
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white70),
                              ),
                              onTap: () {
                                _showAssignEmployeesToProjectDialog(
                                    context, managerId, projectId, projectName);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // ক্লোজ বাটন ফুটার
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 130,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================
// SELECT EMPLOYEES AND ASSIGN / UNASSIGN TO PROJECT DIALOG (ULTRA-LUXURY DARK)
// ===========================================================
  void _showAssignEmployeesToProjectDialog(BuildContext context,
      String managerId, String projectId, String projectName) {
    Set<String> selectedEmployeeIds = {};
    Timer? messageTimer;

    void showCenterSuccessDialog(String msg) {
      messageTimer?.cancel();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (successContext) {
          messageTimer = Timer(const Duration(seconds: 7), () {
            if (successContext.mounted) {
              Navigator.pop(successContext);
            }
          });

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFF1E293B),
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46).withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF34D399),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Success!",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        messageTimer?.cancel();
                        Navigator.pop(successContext);
                      },
                      child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 900,
                height: 720,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A), // 👈 প্রিমিয়াম ডার্ক নেভি ব্যাকগ্রাউন্ড
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                ),
                child: Column(
                  children: [
                    // প্রিমিয়াম ব্লু গ্রেডিয়েন্ট হেডার
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 24, 24, 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.assignment_ind_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Assign / Unassign Employees",
                                  style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Project: $projectName",
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.85),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                messageTimer?.cancel();
                                Navigator.pop(dialogContext);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // এমপ্লয়ী লিস্ট ও প্রোফাইল কার্ড সেকশন
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('managers')
                              .doc(managerId)
                              .collection('assignedEmployees')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator(color: Colors.white));
                            }

                            final employeeDocs = snapshot.data?.docs ?? [];

                            if (employeeDocs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.group_off,
                                        size: 55, color: Colors.white54),
                                    const SizedBox(height: 12),
                                    const Text("No employees found under this manager.",
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              );
                            }

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(projectId)
                                  .collection('assignedEmployees')
                                  .snapshots(),
                              builder: (context, projSnap) {
                                final assignedInProjDocs = projSnap.data?.docs ?? [];
                                final Set<String> currentAssignedIds =
                                assignedInProjDocs.map((doc) => doc.id).toSet();

                                return ListView.separated(
                                  itemCount: employeeDocs.length,
                                  separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    final empDoc = employeeDocs[index];
                                    final empData = empDoc.data() as Map<String, dynamic>;
                                    final empId = empDoc.id;
                                    final empName = empData['name'] ?? 'No Name';
                                    final designation = empData['designation'] ?? 'N/A';
                                    final role = empData['role'] ?? 'N/A';
                                    final company = empData['companyName'] ??
                                        empData['company'] ??
                                        'N/A';
                                    final trade =
                                        empData['tradeName'] ?? empData['trade'] ?? 'N/A';

                                    final assignedProjectName =
                                    empData['assignedProjectName']?.toString();

                                    final bool isAlreadyAssignedInDb = currentAssignedIds.contains(empId);

                                    final bool isAssignedToOtherProject =
                                        assignedProjectName != null &&
                                            assignedProjectName.isNotEmpty &&
                                            assignedProjectName != projectName &&
                                            !isAlreadyAssignedInDb;

                                    final bool isSelected =
                                    selectedEmployeeIds.contains(empId);

                                    return Container(
                                      key: ValueKey(empId),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        // 👇 ফুটারের হুবহু কালারটি এখানে ব্যবহার করা হলো
                                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isSelected ? Colors.white : const Color(0xFF334155),
                                          width: isSelected ? 2 : 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                            future: FirebaseFirestore.instance
                                                .collection('employees')
                                                .doc(empId)
                                                .get(),
                                            builder: (context, empSnap) {
                                              final mainEmpData = empSnap.data?.data();
                                              final String? empImgUrl = mainEmpData?['profileImageUrl']?.toString()
                                                  ?? empData['profileImageUrl']?.toString();

                                              return Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.2),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: (empImgUrl != null && empImgUrl.isNotEmpty)
                                                    ? NetworkImageWebFix(
                                                  imageUrl: empImgUrl,
                                                  radius: 26,
                                                )
                                                    : const CircleAvatar(
                                                  radius: 26,
                                                  backgroundColor: Color(0xFF334155),
                                                  child: Icon(
                                                    Icons.person_rounded,
                                                    color: Colors.white,
                                                    size: 26,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      empName,
                                                      style: TextStyle( // 👈 এখান থেকে 'const' সরিয়ে দেওয়া হয়েছে
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: const Color(0xFFCBD5E1),
                                                      ),
                                                    ),
                                                    if (isAlreadyAssignedInDb) ...[
                                                      const SizedBox(width: 12),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withOpacity(0.12),
                                                          borderRadius:
                                                          BorderRadius.circular(8),
                                                          border: Border.all(
                                                              color: Colors.white.withOpacity(0.3), width: 1.2),
                                                        ),
                                                        child: Text(
                                                          "Assigned: $projectName",
                                                          style: const TextStyle(
                                                              fontSize: 11.5,
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 12,
                                                  runSpacing: 6,
                                                  children: [
                                                    _buildWhiteInfoChip("ID: $empId", Icons.badge_outlined),
                                                    _buildWhiteInfoChip("Company: $company", Icons.business_outlined),
                                                    _buildWhiteInfoChip("Trade: $trade", Icons.engineering_outlined),
                                                    _buildWhiteInfoChip("Designation: $designation", Icons.work_outline),
                                                    _buildWhiteInfoChip("Role: ${role.toString().toUpperCase()}", Icons.shield_outlined),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Transform.scale(
                                            scale: 1.15,
                                            child: Checkbox(
                                              value: isSelected,
                                              activeColor: Colors.white,
                                              checkColor: const Color(0xFF1E293B),
                                              side: const BorderSide(color: Colors.white, width: 2),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(5)),
                                              onChanged: isAssignedToOtherProject
                                                  ? null
                                                  : (bool? value) {
                                                setDialogState(() {
                                                  if (value == true) {
                                                    selectedEmployeeIds.add(empId);
                                                  } else {
                                                    selectedEmployeeIds.remove(empId);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    // 👇 প্রিমিয়াম ডার্ক নেভি কালারফুল ফুটার এবং উজ্জ্বল বাটন সেকশন
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B), // ডার্ক স্লেট ফুটার ব্যাকগ্রাউন্ড
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(25),
                          bottomRight: Radius.circular(25),
                        ),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                      ),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF334155),
                              foregroundColor: Colors.redAccent.shade200,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.redAccent.shade200.withOpacity(0.5), width: 1.5),
                              ),
                            ),
                            onPressed: () async {
                              if (selectedEmployeeIds.isEmpty) {
                                showCenterSuccessDialog("Please select at least one employee to out-assign!");
                                return;
                              }

                              try {
                                final firestore = FirebaseFirestore.instance;
                                final batch = firestore.batch();

                                for (String empId in selectedEmployeeIds) {
                                  final assignedEmpRef = firestore
                                      .collection('projects')
                                      .doc(projectId)
                                      .collection('assignedEmployees')
                                      .doc(empId);
                                  batch.delete(assignedEmpRef);

                                  final employeeRef =
                                  firestore.collection('employees').doc(empId);
                                  batch.update(employeeRef, {
                                    'projectIds': FieldValue.arrayRemove([projectId]),
                                    'assignedProjectName': FieldValue.delete(),
                                  });

                                  final managerEmployeeRef = firestore
                                      .collection('managers')
                                      .doc(managerId)
                                      .collection('assignedEmployees')
                                      .doc(empId);
                                  batch.update(managerEmployeeRef, {
                                    'assignedProjectName': FieldValue.delete(),
                                    'projectId': FieldValue.delete(),
                                  });
                                }

                                await batch.commit();

                                if (!context.mounted) return;
                                setDialogState(() {
                                  selectedEmployeeIds.clear();
                                });
                                showCenterSuccessDialog("Selected employees successfully out-assigned from project!");
                              } catch (e) {
                                if (!context.mounted) return;
                                showCenterSuccessDialog("Failed to out-assign: $e");
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            label: const Text("OUT ASSIGNED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 4,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              if (selectedEmployeeIds.isEmpty) {
                                showCenterSuccessDialog("Please select at least one employee to assign!");
                                return;
                              }

                              try {
                                final firestore = FirebaseFirestore.instance;
                                final batch = firestore.batch();

                                for (String empId in selectedEmployeeIds) {
                                  final assignedEmpRef = firestore
                                      .collection('projects')
                                      .doc(projectId)
                                      .collection('assignedEmployees')
                                      .doc(empId);

                                  batch.set(assignedEmpRef, {
                                    'employeeId': empId,
                                    'assignedAt': FieldValue.serverTimestamp(),
                                  });

                                  final employeeRef =
                                  firestore.collection('employees').doc(empId);
                                  batch.set(
                                      employeeRef,
                                      {
                                        'projectIds': FieldValue.arrayUnion([projectId]),
                                        'assignedProjectName': projectName,
                                      },
                                      SetOptions(merge: true));

                                  final managerEmployeeRef = firestore
                                      .collection('managers')
                                      .doc(managerId)
                                      .collection('assignedEmployees')
                                      .doc(empId);

                                  batch.set(
                                      managerEmployeeRef,
                                      {
                                        'assignedProjectName': projectName,
                                        'projectId': projectId,
                                      },
                                      SetOptions(merge: true));
                                }

                                await batch.commit();

                                if (!context.mounted) return;
                                setDialogState(() {
                                  selectedEmployeeIds.clear();
                                });
                                showCenterSuccessDialog("Employees assigned to project successfully!");
                              } catch (e) {
                                if (!context.mounted) return;
                                showCenterSuccessDialog("Failed to assign: $e");
                              }
                            },
                            icon: const Icon(Icons.task_alt_rounded, size: 20),
                            label: const Text("SAVE ASSIGNMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildWhiteInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w500), // কালার একটু সফট করা হলো
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ===========================================================
  // ASSIGNED EMPLOYEES POPUP DIALOG
  // ===========================================================
  void _showAssignedEmployeesDialog(BuildContext context, String managerId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.people, color: Color(0xFF000080)),
                  SizedBox(width: 8),
                  Text(
                    "Assigned Employees",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('managers')
                  .doc(managerId)
                  .collection('assignedEmployees')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        "No employees assigned to this manager yet.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final empData =
                              docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8EAF6),
                              child:
                                  Icon(Icons.person, color: Color(0xFF000080)),
                            ),
                            title: Text(
                              empData['name'] ?? 'No Name',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "ID: ${empData['employeeId'] ?? 'N/A'} | ${empData['designation'] ?? empData['role'] ?? ''}",
                            ),
                            trailing: Text(
                              empData['companyName'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE"),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================
  // INFORMATION GRID
  // ===========================================================
  Widget _informationGrid({
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool small = constraints.maxWidth < 650;

        return GridView.count(
          crossAxisCount: small ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: small ? 6.5 : 5.2,
          children: children,
        );
      },
    );
  }

  // ===========================================================
  // INFO CARD
  // ===========================================================
  Widget _infoCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 19,
              color: const Color(0xFF000080),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? "Not Available" : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // STATUS CARD
  // ===========================================================
  Widget _statusCard(
    String title,
    String value,
    bool active,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withOpacity(0.06)
            : Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.cancel,
            color: active ? Colors.green : Colors.red,
            size: 25,
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // BADGE
  // ===========================================================
  Widget _badge(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF000080),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF000080),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

void _showNonManagerEmployees(BuildContext context, String managerId) async {
  // ম্যানেজারের নাম ফেচ করে নেওয়া যাতে পেজে পাস করা যায়
  final managerDoc = await FirebaseFirestore.instance
      .collection('employees')
      .doc(managerId)
      .get();
  final managerName = managerDoc.data()?['name'] ?? 'Manager';

  if (!context.mounted) return;

  // পপ-আপের বদলে এখন ফুল পেজ ওপেন হবে
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WebAddEmployeeToManagerPage(
        managerId: managerId,
        managerName: managerName,
      ),
    ),
  );
}

class WebAddEmployeeToManagerPage extends StatefulWidget {
  final String managerId;
  final String managerName;

  const WebAddEmployeeToManagerPage({
    super.key,
    required this.managerId,
    required this.managerName,
  });

  @override
  State<WebAddEmployeeToManagerPage> createState() =>
      _WebAddEmployeeToManagerPageState();
}

class _WebAddEmployeeToManagerPageState
    extends State<WebAddEmployeeToManagerPage> {
  String? selectedCompanyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000080),
        title: Text(
          "Add Employee to Manager: ${widget.managerName} (${widget.managerId})",
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1450),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // কোম্পানি সিলেক্ট করার ড্রপডাউন
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('companies')
                    .snapshots(),
                builder: (context, companySnapshot) {
                  if (companySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (companySnapshot.hasError) {
                    return Text("Error: ${companySnapshot.error}");
                  }
                  final companies = companySnapshot.data?.docs ?? [];
                  return DropdownButtonFormField<String>(
                    value: selectedCompanyId,
                    decoration: InputDecoration(
                      labelText: "SELECT COMPANY",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: companies.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final companyName = data['name']?.toString() ??
                          data['companyName']?.toString() ??
                          doc.id;
                      return DropdownMenuItem<String>(
                          value: doc.id, child: Text(companyName));
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedCompanyId = value),
                  );
                },
              ),

              const SizedBox(height: 20),

              // এমপ্লয়ি লিস্ট
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('employees')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }

                    final allEmployees = snapshot.data?.docs ?? [];

                    final employees = allEmployees.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final role =
                          data['role']?.toString().trim().toLowerCase() ?? '';
                      final companyId = data['companyId']?.toString() ?? '';
                      return role != 'manager' &&
                          selectedCompanyId != null &&
                          companyId == selectedCompanyId;
                    }).toList();

                    if (selectedCompanyId == null) {
                      return const Center(
                        child: Text(
                          "Please select a company first.",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey),
                        ),
                      );
                    }

                    if (employees.isEmpty) {
                      return const Center(
                        child: Text(
                          "No employee found for this company.",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        final doc = employees[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final name = data['name']?.toString() ?? '';
                        final id = data['id']?.toString() ?? '';
                        final designation =
                            data['designation']?.toString() ?? '';
                        final role = data['role']?.toString() ?? '';
                        final bool isRegistered = data['isRegistered'] == true;

                        final String? existingManagerId =
                            data['assignedManagerId']?.toString();
                        final String? existingManagerName =
                            data['assignedManagerName']?.toString();
                        final bool isAlreadyAssigned =
                            existingManagerId != null &&
                                existingManagerId.isNotEmpty;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8EAF6),
                              child:
                                  Icon(Icons.person, color: Color(0xFF000080)),
                            ),
                            title: Text(
                              name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text("ID: $id | $designation"),
                                Text("Role: ${role.toUpperCase()}"),
                                if (isAlreadyAssigned)
                                  Text(
                                    "Already Assigned to: ${existingManagerName ?? existingManagerId} (ID: $existingManagerId)",
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold),
                                  )
                                else
                                  Text(
                                    isRegistered
                                        ? "Registered ✅"
                                        : "Not Registered ❌",
                                    style: TextStyle(
                                      color: isRegistered
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAlreadyAssigned
                                    ? Colors.grey
                                    : const Color(0xFF000080),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: isAlreadyAssigned
                                  ? null
                                  : () async {
                                      try {
                                        // ১. ম্যানেজারের সাব-কালেকশনে ডাটা সেভ করা
                                        await FirebaseFirestore.instance
                                            .collection('managers')
                                            .doc(widget.managerId)
                                            .collection('assignedEmployees')
                                            .doc(doc.id)
                                            .set({
                                          'employeeId': id,
                                          'employeeDocId': doc.id,
                                          'name': name,
                                          'designation': designation,
                                          'role': role,
                                          'companyId': data['companyId'],
                                          'companyName': data['companyName'],
                                          'assignedAt':
                                              FieldValue.serverTimestamp(),
                                        });

                                        // ২. এমপ্লয়ির নিজের প্রোফাইলেও ম্যানেজারের ইনফরমেশন আপডেট করা
                                        await FirebaseFirestore.instance
                                            .collection('employees')
                                            .doc(doc.id)
                                            .update({
                                          'assignedManagerId': widget.managerId,
                                          'assignedManagerName':
                                              widget.managerName,
                                        });

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  "$name assigned successfully"),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text("Assignment failed: $e"),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                  isAlreadyAssigned ? "ASSIGNED" : "SELECT"),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebPermissionManagementPage extends StatefulWidget {
  const WebPermissionManagementPage({super.key});

  @override
  State<WebPermissionManagementPage> createState() =>
      _WebPermissionManagementPageState();
}

class _WebPermissionManagementPageState
    extends State<WebPermissionManagementPage> {
  String? selectedEmployeeId;
  String? selectedRoleId;
  String? selectedTradeId;
  String? selectedReportsToEmployeeId;

  Set<String> selectedProjectIds = {};

  bool _isSavingAssignment = false;
  final TextEditingController _newProjectNameController =
      TextEditingController();

  bool _isCreatingProject = false;
  String? _newProjectManagerId;
  String? _newProjectTradeId;
  String? _newProjectCompanyId;
  bool _isCreatingCompany = false;

  // Trade/Project/Role here don't hard-code
  final Map<String, String> permissionTitles = {
    'allEmployee': 'All Employee',
    'myAttendance': 'My Attendance',
    'history': 'History',
    'tools': 'Tools',
    'material': 'Material',
    'dailyProgress': 'Daily Progress',
    'settings': 'Settings',
    'help': 'Help',
    'addEmployee': 'Add Employee',
    'managePermissions': 'Manage Permissions',
  };

  // =========================================================
  // HELPERS
  // =========================================================

  String _makeCode(String value) {
    String code =
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

    code = code.replaceAll(
      RegExp(r'^_+|_+$'),
      '',
    );

    return code;
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================
  // PERMISSION UPDATE
  // =========================================================

  Future<void> _updatePermission(
    String employeeId,
    String permissionKey,
    bool value,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .update({
        'permissions.$permissionKey': value,
      });

      _showMessage(
        "Permission updated successfully",
      );
    } catch (e) {
      _showMessage(
        "Permission update failed: $e",
        error: true,
      );
    }
  }

  // =========================================================
  // LOAD EMPLOYEE
  // =========================================================

  void _loadEmployee(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final dynamic projectsRaw = data['projectIds'];

    setState(() {
      selectedEmployeeId = doc.id;

      selectedRoleId = data['roleId']?.toString();

      selectedTradeId = data['tradeId']?.toString();

      selectedReportsToEmployeeId = data['reportsToEmployeeId']?.toString();

      if (projectsRaw is List) {
        selectedProjectIds = projectsRaw.map((e) => e.toString()).toSet();
      } else {
        selectedProjectIds = {};
      }
    });
  }

  Future<void> _createNewProject() async {
    final String projectName = _newProjectNameController.text.trim();

    if (_newProjectManagerId == null) {
      _showMessage(
        "Please select a manager",
        error: true,
      );
      return;
    }

    if (_newProjectTradeId == null) {
      _showMessage(
        "Please select a trade",
        error: true,
      );
      return;
    }
    if (_newProjectCompanyId == null) {
      _showMessage(
        "Please select a company",
        error: true,
      );
      return;
    }

    if (projectName.isEmpty) {
      _showMessage(
        "Please enter project name",
        error: true,
      );
      return;
    }

    try {
      setState(() {
        _isCreatingProject = true;
      });

      final String projectCode = _makeCode(projectName);

      final duplicate = await FirebaseFirestore.instance
          .collection('projects')
          .where(
            'tradeId',
            isEqualTo: _newProjectTradeId,
          )
          .where(
            'code',
            isEqualTo: projectCode,
          )
          .limit(1)
          .get();

      if (duplicate.docs.isNotEmpty) {
        _showMessage(
          "This project already exists under this trade",
          error: true,
        );
        return;
      }

      final projectRef =
          await FirebaseFirestore.instance.collection('projects').add({
        'name': projectName,
        'code': projectCode,
        'tradeId': _newProjectTradeId,
        'managerId': _newProjectManagerId,
        'companyId': _newProjectCompanyId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('employees')
          .doc(_newProjectManagerId)
          .update({
        'projectIds': FieldValue.arrayUnion(
          [projectRef.id],
        ),
        'organizationUpdatedAt': FieldValue.serverTimestamp(),
      });

      _newProjectNameController.clear();

      setState(() {
        _newProjectManagerId = null;
        _newProjectTradeId = null;
        _newProjectCompanyId = null;
      });

      _showMessage(
        "Project created successfully",
      );
    } catch (e) {
      _showMessage(
        "Project create failed: $e",
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingProject = false;
        });
      }
    }
  }

  Future<void> _saveAssignment(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> roleDocs,
  ) async {
    if (selectedEmployeeId == null) {
      _showMessage(
        "Please select an employee",
        error: true,
      );
      return;
    }

    if (selectedRoleId == null) {
      _showMessage(
        "Please select a role",
        error: true,
      );
      return;
    }

    if (selectedTradeId == null) {
      _showMessage(
        "Please select a trade",
        error: true,
      );
      return;
    }

    try {
      setState(() {
        _isSavingAssignment = true;
      });

      QueryDocumentSnapshot<Map<String, dynamic>>? roleDoc;

      for (final doc in roleDocs) {
        if (doc.id == selectedRoleId) {
          roleDoc = doc;
          break;
        }
      }

      if (roleDoc == null) {
        throw Exception(
          "Selected role not found",
        );
      }

      final roleData = roleDoc.data();

      final String roleCode = roleData['code']?.toString() ??
          _makeCode(
            roleData['name']?.toString() ?? '',
          );

      final employeeRef = FirebaseFirestore.instance
          .collection('employees')
          .doc(selectedEmployeeId);

      // =====================================================
      // EMPLOYEE ORGANIZATION DATA SAVE
      // =====================================================

      await employeeRef.update({
        'roleId': selectedRoleId,

        // Phone compatibility
        'role': roleCode,

        'tradeId': selectedTradeId,

        'projectIds': selectedProjectIds.toList(),

        'reportsToEmployeeId': selectedReportsToEmployeeId,

        'organizationUpdatedAt': FieldValue.serverTimestamp(),
      });

      // =====================================================
      // PROJECT MANAGER RELATION UPDATE
      // =====================================================
      for (final projectId in selectedProjectIds) {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .update({
          'tradeId': selectedTradeId,
          'managerId': selectedEmployeeId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _showMessage(
        "Organization assignment saved successfully",
      );
    } catch (e) {
      _showMessage(
        "Assignment save failed: $e",
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAssignment = false;
        });
      }
    }
  }

  // =========================================================
  // ROLE MANAGEMENT
  // =========================================================

  void _openRoleManagement() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 750,
            height: 650,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "ROLE MANAGEMENT",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000080),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('roles')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, roleSnapshot) {
                        if (roleSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (roleSnapshot.hasError) {
                          return Center(
                            child:
                                Text("Role load failed: ${roleSnapshot.error}"),
                          );
                        }

                        final roleDocs = roleSnapshot.data?.docs ?? [];

                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
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
                              return Center(
                                child: Text(
                                  "Employee load failed: ${employeeSnapshot.error}",
                                ),
                              );
                            }

                            final employeeDocs =
                                employeeSnapshot.data?.docs ?? [];

                            return Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _showAddRoleDialog(roleDocs),
                                  icon: const Icon(Icons.add),
                                  label: const Text("ADD ROLE"),
                                ),
                                const SizedBox(height: 15),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: roleDocs.length,
                                    itemBuilder: (context, index) {
                                      final roleDoc = roleDocs[index];
                                      final roleData = roleDoc.data();

                                      final String roleName =
                                          roleData['name']?.toString() ?? '';

                                      final String roleCode = roleData['code']
                                              ?.toString()
                                              .toLowerCase() ??
                                          _makeCode(roleName);

                                      String parentName = "Top Level";

                                      final parentId =
                                          roleData['parentRoleId']?.toString();

                                      if (parentId != null) {
                                        for (final parent in roleDocs) {
                                          if (parent.id == parentId) {
                                            parentName = parent
                                                    .data()['name']
                                                    ?.toString() ??
                                                '';
                                            break;
                                          }
                                        }
                                      }

                                      final assignedEmployees =
                                          employeeDocs.where((employeeDoc) {
                                        final employeeData = employeeDoc.data();

                                        final employeeRole =
                                            employeeData['role']
                                                ?.toString()
                                                .toLowerCase();

                                        return employeeRole == roleCode;
                                      }).toList();

                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.account_tree),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          roleName,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 3),
                                                        Text(
                                                          "Reports to role: $parentName",
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed: () =>
                                                        _deleteRole(roleDoc.id),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              const Divider(),
                                              const SizedBox(height: 6),
                                              Text(
                                                "Employees (${assignedEmployees.length})",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF000080),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (assignedEmployees.isEmpty)
                                                const Text(
                                                  "No employee assigned to this role.",
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                )
                                              else
                                                ...assignedEmployees.map(
                                                  (employeeDoc) {
                                                    final employeeData =
                                                        employeeDoc.data();

                                                    final id =
                                                        employeeData['id']
                                                                ?.toString() ??
                                                            employeeDoc.id;

                                                    final name =
                                                        employeeData['name']
                                                                ?.toString() ??
                                                            '';

                                                    return Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                        bottom: 6,
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFF8F9FE),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .person_outline,
                                                            size: 20,
                                                            color: Color(
                                                                0xFF000080),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          Expanded(
                                                            child: Text(
                                                              "$id - $name",
                                                              style:
                                                                  const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddRoleDialog(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> roleDocs,
  ) {
    final controller = TextEditingController();

    String? parentRoleId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Role"),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: "Role Name",
                        hintText: "Enter role name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    DropdownButtonFormField<String?>(
                      value: parentRoleId,
                      decoration: const InputDecoration(
                        labelText: "Reports To Role",
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            "Top Level / No Parent",
                          ),
                        ),
                        ...roleDocs.map(
                          (doc) {
                            return DropdownMenuItem<String?>(
                              value: doc.id,
                              child: Text(
                                doc.data()['name']?.toString() ?? '',
                              ),
                            );
                          },
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          parentRoleId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                  ),
                  child: const Text("CANCEL"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = controller.text.trim();

                    if (name.isEmpty) {
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance.collection('roles').add({
                        'name': name,
                        'code': _makeCode(name),
                        'parentRoleId': parentRoleId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(
                          context,
                        );
                      }
                    } catch (e) {
                      _showMessage(
                        "Role add failed: $e",
                        error: true,
                      );
                    }
                  },
                  child: const Text("ADD"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRole(
    String roleId,
  ) async {
    try {
      final employeeCheck = await FirebaseFirestore.instance
          .collection('employees')
          .where(
            'roleId',
            isEqualTo: roleId,
          )
          .limit(1)
          .get();

      final childRoleCheck = await FirebaseFirestore.instance
          .collection('roles')
          .where(
            'parentRoleId',
            isEqualTo: roleId,
          )
          .limit(1)
          .get();

      if (employeeCheck.docs.isNotEmpty || childRoleCheck.docs.isNotEmpty) {
        _showMessage(
          "This role is in use. Reassign employees/child roles first.",
          error: true,
        );
        return;
      }

      await FirebaseFirestore.instance.collection('roles').doc(roleId).delete();

      _showMessage(
        "Role deleted",
      );
    } catch (e) {
      _showMessage(
        "Role delete failed: $e",
        error: true,
      );
    }
  }

  // =========================================================
  // TRADE MANAGEMENT
  // =========================================================

  void _openTradeManagement() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 700,
            height: 550,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "TRADE MANAGEMENT",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000080),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: "New Trade Name",
                      hintText: "Enter trade name",
                      prefixIcon: Icon(Icons.engineering),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("CREATE TRADE"),
                      onPressed: () async {
                        final String name = controller.text.trim();

                        if (name.isEmpty) {
                          _showMessage(
                            "Please enter trade name",
                            error: true,
                          );
                          return;
                        }

                        try {
                          final duplicate = await FirebaseFirestore.instance
                              .collection('trades')
                              .where(
                                'code',
                                isEqualTo: _makeCode(name),
                              )
                              .limit(1)
                              .get();

                          if (duplicate.docs.isNotEmpty) {
                            _showMessage(
                              "This Trade already exists",
                              error: true,
                            );
                            return;
                          }

                          await FirebaseFirestore.instance
                              .collection('trades')
                              .add({
                            'name': name,
                            'code': _makeCode(name),
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          controller.clear();

                          _showMessage(
                            "Trade created successfully",
                          );
                        } catch (e) {
                          _showMessage(
                            "Trade add failed: $e",
                            error: true,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('trades')
                          .orderBy('name')
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
                              "Trade load failed: ${snapshot.error}",
                            ),
                          );
                        }

                        final tradeDocs = snapshot.data?.docs ?? [];

                        if (tradeDocs.isEmpty) {
                          return const Center(
                            child: Text(
                              "No Trade Created Yet",
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: tradeDocs.length,
                          itemBuilder: (context, index) {
                            final tradeDoc = tradeDocs[index];
                            final tradeData = tradeDoc.data();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.engineering,
                                  color: Color(0xFF000080),
                                ),
                                title: Text(
                                  tradeData['name']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    _deleteTrade(tradeDoc.id);
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteTrade(
    String tradeId,
  ) async {
    try {
      final projectCheck = await FirebaseFirestore.instance
          .collection('projects')
          .where(
            'tradeId',
            isEqualTo: tradeId,
          )
          .limit(1)
          .get();

      final employeeCheck = await FirebaseFirestore.instance
          .collection('employees')
          .where(
            'tradeId',
            isEqualTo: tradeId,
          )
          .limit(1)
          .get();

      if (projectCheck.docs.isNotEmpty || employeeCheck.docs.isNotEmpty) {
        _showMessage(
          "Trade is in use. Remove project/employee assignments first.",
          error: true,
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('trades')
          .doc(tradeId)
          .delete();

      _showMessage(
        "Trade deleted",
      );
    } catch (e) {
      _showMessage(
        "Trade delete failed: $e",
        error: true,
      );
    }
  }

  void _openCompanyManagement() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: SizedBox(
                width: 650,
                height: 520,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "COMPANY MANAGEMENT",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF000080)),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(),
                      TextField(
                        controller: controller,
                        enabled: !_isCreatingCompany,
                        decoration: const InputDecoration(
                          labelText: "Company Name",
                          hintText: "Enter company name",
                          prefixIcon: Icon(Icons.apartment),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isCreatingCompany
                              ? null
                              : () async {
                                  final String name = controller.text.trim();

                                  if (name.isEmpty) {
                                    _showMessage("Please enter company name",
                                        error: true);
                                    return;
                                  }

                                  final String code = _makeCode(name);

                                  if (code.isEmpty) {
                                    _showMessage(
                                        "Please enter a valid company name",
                                        error: true);
                                    return;
                                  }

                                  setState(() {
                                    _isCreatingCompany = true;
                                  });

                                  setDialogState(() {});

                                  try {
                                    final companyRef = FirebaseFirestore
                                        .instance
                                        .collection('companies')
                                        .doc(code);

                                    final existingCompany =
                                        await companyRef.get();

                                    if (existingCompany.exists) {
                                      _showMessage(
                                          "This company already exists",
                                          error: true);
                                      return;
                                    }

                                    await companyRef.set({
                                      'name': name,
                                      'code': code,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    controller.clear();

                                    _showMessage(
                                        "Company created successfully");
                                  } catch (e) {
                                    _showMessage("Company create failed: $e",
                                        error: true);
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isCreatingCompany = false;
                                      });

                                      setDialogState(() {});
                                    }
                                  }
                                },
                          icon: _isCreatingCompany
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add_business),
                          label: Text(_isCreatingCompany
                              ? "CREATING COMPANY..."
                              : "CREATE COMPANY"),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('companies')
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(
                                  child: Text(
                                      "Company load failed: ${snapshot.error}"));
                            }

                            final companyDocs = snapshot.data?.docs ?? [];

                            if (companyDocs.isEmpty) {
                              return const Center(
                                child: Text(
                                  "No Company Created Yet",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: companyDocs.length,
                              itemBuilder: (context, index) {
                                final companyDoc = companyDocs[index];
                                final companyData = companyDoc.data();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: const Icon(Icons.apartment,
                                        color: Color(0xFF000080)),
                                    title: Text(
                                      companyData['name']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () async {
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('companies')
                                              .doc(companyDoc.id)
                                              .delete();
                                          _showMessage(
                                              "Company deleted successfully");
                                        } catch (e) {
                                          _showMessage(
                                              "Company delete failed: $e",
                                              error: true);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openProjectManagement() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 750,
            height: 600,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "PROJECT MANAGEMENT",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000080),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(
                          dialogContext,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('trades')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, tradeSnapshot) {
                      final trades = tradeSnapshot.data?.docs ?? [];

                      return ElevatedButton.icon(
                        onPressed: trades.isEmpty
                            ? null
                            : () {
                                _showAddProjectDialog(
                                  trades,
                                );
                              },
                        icon: const Icon(Icons.add),
                        label: const Text(
                          "ADD PROJECT",
                        ),
                      );
                    },
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('projects')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, projectSnapshot) {
                        final projectDocs = projectSnapshot.data?.docs ?? [];

                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection(
                                'trades',
                              )
                              .snapshots(),
                          builder: (context, tradeSnapshot) {
                            final tradeDocs = tradeSnapshot.data?.docs ?? [];

                            return ListView.builder(
                              itemCount: projectDocs.length,
                              itemBuilder: (context, index) {
                                final doc = projectDocs[index];

                                final data = doc.data();

                                final tradeId = data['tradeId']?.toString();

                                String tradeName = "No Trade";

                                for (final trade in tradeDocs) {
                                  if (trade.id == tradeId) {
                                    tradeName =
                                        trade.data()['name']?.toString() ?? '';
                                  }
                                }

                                return Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.business_center,
                                    ),
                                    title: Text(
                                      data['name']?.toString() ?? '',
                                    ),
                                    subtitle: Text(
                                      "Trade: $tradeName",
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        _deleteProject(
                                          doc.id,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddProjectDialog(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tradeDocs,
  ) {
    final controller = TextEditingController();

    String? tradeId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Project"),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: "Project Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    DropdownButtonFormField<String>(
                      value: tradeId,
                      decoration: const InputDecoration(
                        labelText: "Select Trade",
                        border: OutlineInputBorder(),
                      ),
                      items: tradeDocs.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            doc.data()['name']?.toString() ?? '',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          tradeId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                  ),
                  child: const Text("CANCEL"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = controller.text.trim();

                    if (name.isEmpty || tradeId == null) {
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance
                          .collection(
                        'projects',
                      )
                          .add({
                        'name': name,
                        'code': _makeCode(name),
                        'tradeId': tradeId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(
                          context,
                        );
                      }
                    } catch (e) {
                      _showMessage(
                        "Project add failed: $e",
                        error: true,
                      );
                    }
                  },
                  child: const Text("ADD"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProject(
    String projectId,
  ) async {
    try {
      final employeeCheck = await FirebaseFirestore.instance
          .collection('employees')
          .where(
            'projectIds',
            arrayContains: projectId,
          )
          .limit(1)
          .get();

      if (employeeCheck.docs.isNotEmpty) {
        _showMessage(
          "Project is assigned to employees. Remove assignments first.",
          error: true,
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .delete();

      _showMessage(
        "Project deleted",
      );
    } catch (e) {
      _showMessage(
        "Project delete failed: $e",
        error: true,
      );
    }
  }

  // =========================================================
  // MAIN UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('employees')
            .orderBy('id')
            .snapshots(),
        builder: (context, employeeSnapshot) {
          if (employeeSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (employeeSnapshot.hasError) {
            return Center(
              child: Text(
                "Employee Error: "
                "${employeeSnapshot.error}",
              ),
            );
          }

          final employeeDocs = employeeSnapshot.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('roles')
                .orderBy('name')
                .snapshots(),
            builder: (context, roleSnapshot) {
              final roleDocs = roleSnapshot.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('trades')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, tradeSnapshot) {
                  final tradeDocs = tradeSnapshot.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(
                          'projects',
                        )
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, projectSnapshot) {
                      final projectDocs = projectSnapshot.data?.docs ?? [];

                      // selected employee data
                      QueryDocumentSnapshot<Map<String, dynamic>>?
                          selectedEmployeeDoc;

                      for (final doc in employeeDocs) {
                        if (doc.id == selectedEmployeeId) {
                          selectedEmployeeDoc = doc;
                          break;
                        }
                      }

                      Map<String, dynamic>? employeeData =
                          selectedEmployeeDoc?.data();

                      final permissionsRaw = employeeData?['permissions'];

                      final Map<String, dynamic> permissions =
                          permissionsRaw is Map
                              ? Map<String, dynamic>.from(
                                  permissionsRaw,
                                )
                              : {};

                      // Selected role parent
                      String? requiredParentRoleId;

                      for (final role in roleDocs) {
                        if (role.id == selectedRoleId) {
                          requiredParentRoleId =
                              role.data()['parentRoleId']?.toString();
                          break;
                        }
                      }

                      // Projects only from selected trade
                      final visibleProjects = projectDocs.where((project) {
                        final data = project.data();

                        return selectedTradeId != null &&
                            selectedEmployeeId != null &&
                            data['tradeId']?.toString() == selectedTradeId &&
                            data['managerId']?.toString() == selectedEmployeeId;
                      }).toList();

                      // Reporting manager must have parent role
                      final reportingEmployees = employeeDocs.where(
                        (employee) {
                          if (employee.id == selectedEmployeeId) {
                            return false;
                          }

                          final data = employee.data();

                          if (requiredParentRoleId == null) {
                            return false;
                          }

                          if (data['roleId']?.toString() !=
                              requiredParentRoleId) {
                            return false;
                          }

                          // Same trade
                          if (selectedTradeId != null &&
                              data['tradeId']?.toString() != selectedTradeId) {
                            return false;
                          }

                          return true;
                        },
                      ).toList();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(
                          30,
                        ),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(
                              maxWidth: 1200,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  height: 8,
                                ),
                                const SizedBox(
                                  height: 25,
                                ),

                                // ===============================
                                // PROJECT PANEL ONLY
                                // ===============================

                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final managerEmployees =
                                        employeeDocs.where((doc) {
                                      final data = doc.data();
                                      final String role = data['role']
                                              ?.toString()
                                              .toLowerCase() ??
                                          '';
                                      final String roleId =
                                          data['roleId']?.toString() ?? '';

                                      if (role == 'manager') {
                                        return true;
                                      }

                                      for (final roleDoc in roleDocs) {
                                        if (roleDoc.id == roleId) {
                                          final roleData = roleDoc.data();
                                          final String roleCode =
                                              roleData['code']
                                                      ?.toString()
                                                      .toLowerCase() ??
                                                  '';
                                          final String roleName =
                                              roleData['name']
                                                      ?.toString()
                                                      .toLowerCase() ??
                                                  '';

                                          if (roleCode == 'manager' ||
                                              roleName == 'manager') {
                                            return true;
                                          }
                                        }
                                      }

                                      return false;
                                    }).toList();

                                    Widget projectPanel = Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                            color: const Color(0xFFE6E8F0)),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 12,
                                              offset: Offset(0, 4)),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 46,
                                                height: 46,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF000080)
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                    Icons.business_center,
                                                    color: Color(0xFF000080)),
                                              ),
                                              const SizedBox(width: 12),
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "PROJECT CONTROL",
                                                      style: TextStyle(
                                                          fontSize: 19,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                              0xFF000080)),
                                                    ),
                                                    SizedBox(height: 3),
                                                    Text(
                                                      "Create and assign new projects",
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 35),
                                          DropdownButtonFormField<String>(
                                            value: managerEmployees.any((doc) =>
                                                    doc.id ==
                                                    _newProjectManagerId)
                                                ? _newProjectManagerId
                                                : null,
                                            decoration: const InputDecoration(
                                              labelText: "Manager",
                                              prefixIcon:
                                                  Icon(Icons.manage_accounts),
                                              border: OutlineInputBorder(),
                                            ),
                                            items: managerEmployees.map((doc) {
                                              final data = doc.data();
                                              final String id =
                                                  data['id']?.toString() ??
                                                      doc.id;
                                              final String name =
                                                  data['name']?.toString() ??
                                                      '';

                                              return DropdownMenuItem<String>(
                                                value: doc.id,
                                                child: Text("$name - $id"),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _newProjectManagerId = value;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 24),
                                          DropdownButtonFormField<String>(
                                            value: tradeDocs.any((doc) =>
                                                    doc.id ==
                                                    _newProjectTradeId)
                                                ? _newProjectTradeId
                                                : null,
                                            decoration: const InputDecoration(
                                              labelText: "Trade",
                                              prefixIcon:
                                                  Icon(Icons.engineering),
                                              border: OutlineInputBorder(),
                                            ),
                                            items: tradeDocs.map((doc) {
                                              final data = doc.data();

                                              return DropdownMenuItem<String>(
                                                value: doc.id,
                                                child: Text(
                                                    data['name']?.toString() ??
                                                        ''),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _newProjectTradeId = value;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 24),
                                          StreamBuilder<
                                              QuerySnapshot<
                                                  Map<String, dynamic>>>(
                                            stream: FirebaseFirestore.instance
                                                .collection('companies')
                                                .orderBy('name')
                                                .snapshots(),
                                            builder:
                                                (context, companySnapshot) {
                                              if (companySnapshot
                                                      .connectionState ==
                                                  ConnectionState.waiting) {
                                                return const SizedBox(
                                                    height: 56,
                                                    child: Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2)));
                                              }

                                              final companyDocs =
                                                  companySnapshot.data?.docs ??
                                                      [];

                                              return DropdownButtonFormField<
                                                  String>(
                                                value: companyDocs.any((doc) =>
                                                        doc.id ==
                                                        _newProjectCompanyId)
                                                    ? _newProjectCompanyId
                                                    : null,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: "Company",
                                                  prefixIcon:
                                                      Icon(Icons.apartment),
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: companyDocs.map((doc) {
                                                  final data = doc.data();

                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: doc.id,
                                                    child: Text(data['name']
                                                            ?.toString() ??
                                                        ''),
                                                  );
                                                }).toList(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _newProjectCompanyId =
                                                        value;
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          TextField(
                                            controller:
                                                _newProjectNameController,
                                            decoration: const InputDecoration(
                                              labelText: "Project Name",
                                              hintText:
                                                  "Enter new project name",
                                              prefixIcon:
                                                  Icon(Icons.add_business),
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: ElevatedButton.icon(
                                              onPressed: _isCreatingProject
                                                  ? null
                                                  : _createNewProject,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF000080),
                                                foregroundColor: Colors.white,
                                              ),
                                              icon: _isCreatingProject
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white))
                                                  : const Icon(
                                                      Icons.add_circle_outline),
                                              label: Text(_isCreatingProject
                                                  ? "CREATING PROJECT..."
                                                  : "CREATE PROJECT"),
                                            ),
                                          ),
                                          const Divider(height: 40),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "PROJECTS",
                                                style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF000080)),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF000080)
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  "${projectDocs.length}",
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF000080)),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 15),
                                          if (projectDocs.isEmpty)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(20),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8F9FE),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                "No project created yet.",
                                                style: TextStyle(
                                                    color: Colors.grey),
                                              ),
                                            )
                                          else
                                            ...projectDocs.map((projectDoc) {
                                              final projectData =
                                                  projectDoc.data();
                                              final String projectName =
                                                  projectData['name']
                                                          ?.toString() ??
                                                      '';
                                              final String managerId =
                                                  projectData['managerId']
                                                          ?.toString() ??
                                                      '';
                                              final String tradeId =
                                                  projectData['tradeId']
                                                          ?.toString() ??
                                                      '';

                                              String managerName =
                                                  "Not Assigned";
                                              String managerEmployeeId =
                                                  managerId;
                                              String tradeName = "Not Assigned";

                                              for (final employeeDoc
                                                  in employeeDocs) {
                                                if (employeeDoc.id ==
                                                    managerId) {
                                                  final data =
                                                      employeeDoc.data();
                                                  managerName = data['name']
                                                          ?.toString() ??
                                                      '';
                                                  managerEmployeeId =
                                                      data['id']?.toString() ??
                                                          employeeDoc.id;
                                                  break;
                                                }
                                              }

                                              for (final tradeDoc
                                                  in tradeDocs) {
                                                if (tradeDoc.id == tradeId) {
                                                  tradeName = tradeDoc
                                                          .data()['name']
                                                          ?.toString() ??
                                                      '';
                                                  break;
                                                }
                                              }

                                              return InkWell(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          WebProjectDetailsPage(
                                                        projectData:
                                                            projectData,
                                                        projectId:
                                                            projectDoc.id,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  width: double.infinity,
                                                  margin: const EdgeInsets.only(
                                                      bottom: 12),
                                                  padding:
                                                      const EdgeInsets.all(15),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF8F9FE),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFFE5E7EB)),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                              Icons
                                                                  .business_center_outlined,
                                                              size: 20,
                                                              color: Color(
                                                                  0xFF000080)),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              projectName,
                                                              style: const TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                          height: 10),
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                              Icons
                                                                  .person_outline,
                                                              size: 17,
                                                              color:
                                                                  Colors.grey),
                                                          const SizedBox(
                                                              width: 7),
                                                          Expanded(
                                                            child: Text(
                                                              "Manager: $managerName - $managerEmployeeId",
                                                              style: const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .black87),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                              Icons
                                                                  .engineering_outlined,
                                                              size: 17,
                                                              color:
                                                                  Colors.grey),
                                                          const SizedBox(
                                                              width: 7),
                                                          Expanded(
                                                            child: Text(
                                                              "Trade: $tradeName",
                                                              style: const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .black87),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    );

                                    return Center(
                                      child: ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 900),
                                        child: projectPanel,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class WebProjectDetailsPage extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final String projectId;
  final bool isFromAllProject;

  const WebProjectDetailsPage({
    super.key,
    required this.projectData,
    required this.projectId,
    this.isFromAllProject = false,
  });

  @override
  State<WebProjectDetailsPage> createState() => _WebProjectDetailsPageState();
}

class _WebProjectDetailsPageState extends State<WebProjectDetailsPage> {
  void _openManagementDialog(
    BuildContext context, {
    required String title,
    required String collectionName,
    required String labelName,
    required IconData icon,
    bool requireTestPackage = false,
    bool requireLineNumber = false,
    bool requireSpoolNumber = false,
    bool requireJointNumber = false,
    bool allowMultipleInput = false,
  }) {
    final TextEditingController controller = TextEditingController();
    String? selectedTestPackageId;
    String? selectedLineNumberId;
    String? selectedSpoolNumberId;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: SizedBox(
                width: 680,
                height: 780,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF000080),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (requireTestPackage) ...[
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(widget.projectId)
                              .collection('testPakeged')
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final testPackages = snapshot.data?.docs ?? [];
                            return DropdownButtonFormField<String>(
                              value: selectedTestPackageId,
                              decoration: const InputDecoration(
                                labelText: "Select Test Package",
                                prefixIcon: Icon(Icons.layers),
                                border: OutlineInputBorder(),
                              ),
                              items: testPackages.map((doc) {
                                final data = doc.data();
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(data['name']?.toString() ?? ''),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedTestPackageId = value;
                                  selectedLineNumberId = null;
                                  selectedSpoolNumberId = null;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (requireLineNumber) ...[
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: selectedTestPackageId == null
                              ? Stream.empty()
                              : FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(widget.projectId)
                                  .collection('lineNumbers')
                                  .where('testPackageId',
                                      isEqualTo: selectedTestPackageId)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            final lineNumbers = snapshot.data?.docs ?? [];
                            return DropdownButtonFormField<String>(
                              value: selectedLineNumberId,
                              decoration: const InputDecoration(
                                labelText: "Select Line Number",
                                prefixIcon: Icon(Icons.linear_scale),
                                border: OutlineInputBorder(),
                              ),
                              items: lineNumbers.map((doc) {
                                final data = doc.data();
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(data['name']?.toString() ?? ''),
                                );
                              }).toList(),
                              onChanged: selectedTestPackageId == null
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        selectedLineNumberId = value;
                                        selectedSpoolNumberId = null;
                                      });
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (requireSpoolNumber) ...[
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: selectedLineNumberId == null
                              ? Stream.empty()
                              : FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(widget.projectId)
                                  .collection('spoolNumbers')
                                  .where('lineNumberId',
                                      isEqualTo: selectedLineNumberId)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            final spoolNumbers = snapshot.data?.docs ?? [];
                            return DropdownButtonFormField<String>(
                              value: selectedSpoolNumberId,
                              decoration: const InputDecoration(
                                labelText: "Select Spool Number",
                                prefixIcon: Icon(Icons.alt_route),
                                border: OutlineInputBorder(),
                              ),
                              items: spoolNumbers.map((doc) {
                                final data = doc.data();
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(data['name']?.toString() ?? ''),
                                );
                              }).toList(),
                              onChanged: selectedLineNumberId == null
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        selectedSpoolNumberId = value;
                                      });
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: controller,
                        maxLines: allowMultipleInput ? 3 : 1,
                        decoration: InputDecoration(
                          labelText: labelName,
                          hintText: allowMultipleInput
                              ? "Enter multiple separated by comma (e.g. 1, 2, 3...)"
                              : "Enter $labelName",
                          prefixIcon: Icon(icon),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final rawText = controller.text.trim();
                            if (rawText.isEmpty) return;

                            try {
                              final List<String> items = rawText
                                  .split(RegExp(r'[,\n]'))
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                              if (items.isEmpty) return;

                              final batch = FirebaseFirestore.instance.batch();
                              for (final item in items) {
                                final newDocRef = FirebaseFirestore.instance
                                    .collection('projects')
                                    .doc(widget.projectId)
                                    .collection(collectionName)
                                    .doc();

                                final Map<String, dynamic> dataToSave = {
                                  'name': item,
                                  'createdAt': FieldValue.serverTimestamp(),
                                };

                                if (requireTestPackage &&
                                    selectedTestPackageId != null) {
                                  dataToSave['testPackageId'] =
                                      selectedTestPackageId;
                                }
                                if (requireLineNumber &&
                                    selectedLineNumberId != null) {
                                  dataToSave['lineNumberId'] =
                                      selectedLineNumberId;
                                }
                                if (requireSpoolNumber &&
                                    selectedSpoolNumberId != null) {
                                  dataToSave['spoolNumberId'] =
                                      selectedSpoolNumberId;
                                }

                                batch.set(newDocRef, dataToSave);
                              }

                              await batch.commit();
                              controller.clear();
                              Navigator.pop(dialogContext);
                            } catch (e) {
                              // error
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add),
                          label: Text("CREATE ${title.toUpperCase()}"),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(widget.projectId)
                              .collection(collectionName)
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final docs = snapshot.data?.docs ?? [];
                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data();
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Icon(icon,
                                        color: const Color(0xFF000080)),
                                    title: Text(data['name']?.toString() ?? ''),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .collection('projects')
                                            .doc(widget.projectId)
                                            .collection(collectionName)
                                            .doc(doc.id)
                                            .delete();
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String projectName =
        widget.projectData['name']?.toString() ?? 'Project';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(projectName),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrap-এর বদলে SingleChildScrollView দিয়ে Row ব্যবহার করুন:
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Test Pakeged",
                            collectionName: "testPakeged",
                            labelName: "Test Pakeged Name",
                            icon: Icons.layers,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Test Pakeged"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Line Number",
                            collectionName: "lineNumbers",
                            labelName: "Line Number",
                            icon: Icons.linear_scale,
                            requireTestPackage: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add line number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Spool Number",
                            collectionName: "spoolNumbers",
                            labelName: "Spool Number",
                            icon: Icons.alt_route,
                            requireTestPackage: true,
                            requireLineNumber: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Spool number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Joint Number",
                            collectionName: "jointNumbers",
                            labelName: "Joint Number",
                            icon: Icons.join_full,
                            requireTestPackage: true,
                            requireLineNumber: true,
                            requireSpoolNumber: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Joint Number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Support Number",
                            collectionName: "supportNumbers",
                            labelName: "Support Number",
                            icon: Icons.support,
                            requireTestPackage: true,
                            requireLineNumber: true,
                            requireSpoolNumber: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Support number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton.icon(
                        onPressed: () => _openManagementDialog(context,
                            title: "Valve Number",
                            collectionName: "valveNumbers",
                            labelName: "Valve Number",
                            icon: Icons.settings_input_component,
                            requireTestPackage: true,
                            requireLineNumber: true,
                            requireSpoolNumber: true,
                            allowMultipleInput: true),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Valve number"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      // 👇 একদম শেষে "View Details" বাটনটি দেওয়া হলো
                      ElevatedButton.icon(
                        onPressed: () => _openViewDetailsDialog(context),
                        icon: const Icon(Icons.visibility, color: Colors.white),
                        label: const Text(
                          "View Details",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000080),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 15),
                const Text(
                  "All Test Package Hierarchy List",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000080)),
                ),
                const SizedBox(height: 15),

                // টেস্ট প্যাকেজ লিস্ট সেকশন
                SizedBox(
                  height: 600,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('testPakeged')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final testPackages = snapshot.data?.docs ?? [];
                      if (testPackages.isEmpty) {
                        return const Center(
                            child: Text("No Test Package found."));
                      }

                      return ListView.builder(
                        itemCount: testPackages.length,
                        itemBuilder: (context, index) {
                          final doc = testPackages[index];
                          final data = doc.data();
                          final packageName = data['name']?.toString() ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(Icons.layers,
                                  color: Color(0xFF000080)),
                              title: Text(
                                "Test Package: $packageName",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('projects')
                                      .doc(widget.projectId)
                                      .collection('testPakeged')
                                      .doc(doc.id)
                                      .delete();
                                },
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TestPackageDetailScreen(
                                      projectId: widget.projectId,
                                      testPackageId: doc.id,
                                      testPackageName: packageName,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openViewDetailsDialog(BuildContext context) {
    String? selectedTestPackageId;
    String? selectedLineNumberId;
    final TextEditingController driveLinkController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: SizedBox(
                width: 680,
                height: 560,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "VIEW DETAILS & DRIVE LINK",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF000080),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),

                      // ১. টেস্ট প্যাকেজ ড্রপডাউন
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('projects')
                            .doc(widget.projectId)
                            .collection('testPakeged')
                            .orderBy('name')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final testPackages = snapshot.data?.docs ?? [];
                          return DropdownButtonFormField<String>(
                            value: selectedTestPackageId,
                            decoration: const InputDecoration(
                              labelText: "Select Test Package",
                              prefixIcon: Icon(Icons.layers),
                              border: OutlineInputBorder(),
                            ),
                            items: testPackages.map((doc) {
                              final data = doc.data();
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(data['name']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedTestPackageId = value;
                                selectedLineNumberId =
                                    null; // লাইন নম্বর রিসেট হবে
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // ২. লাইন নম্বর ড্রপডাউন
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: selectedTestPackageId == null
                            ? Stream.empty()
                            : FirebaseFirestore.instance
                                .collection('projects')
                                .doc(widget.projectId)
                                .collection('lineNumbers')
                                .where('testPackageId',
                                    isEqualTo: selectedTestPackageId)
                                .snapshots(),
                        builder: (context, snapshot) {
                          final lineNumbers = snapshot.data?.docs ?? [];
                          return DropdownButtonFormField<String>(
                            value: selectedLineNumberId,
                            decoration: const InputDecoration(
                              labelText: "Select Line Number",
                              prefixIcon: Icon(Icons.linear_scale),
                              border: OutlineInputBorder(),
                            ),
                            items: lineNumbers.map((doc) {
                              final data = doc.data();
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(data['name']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: selectedTestPackageId == null
                                ? null
                                : (value) {
                                    setDialogState(() {
                                      selectedLineNumberId = value;
                                    });
                                  },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // ৩. গুগল ড্রাইভ লিংক টেক্সট ফিল্ড
                      TextField(
                        controller: driveLinkController,
                        decoration: const InputDecoration(
                          labelText: "Google Drive Link",
                          hintText: "Paste Google Drive link here...",
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // সেভ বাটন
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final linkText = driveLinkController.text.trim();
                            if (selectedTestPackageId == null ||
                                selectedLineNumberId == null ||
                                linkText.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Please select Test Package, Line Number and enter Drive Link!"),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            try {
                              await FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(widget.projectId)
                                  .collection('lineNumbers')
                                  .doc(selectedLineNumberId)
                                  .update({
                                'driveLink': linkText,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              if (!context.mounted) return;
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Google Drive Link saved successfully!"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Failed to save: $e"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.save),
                          label: const Text("SAVE DRIVE LINK"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// আলাদা টেস্ট প্যাকেজ ডিটেইলস পেজ (যেখানে ক্লিক করার পর ওপেন হবে)
// টেস্ট প্যাকেজ ডিটেইলস পেজ (allowDelete ফ্ল্যাগ সহ)
class TestPackageDetailScreen extends StatelessWidget {
  final String projectId;
  final String testPackageId;
  final String testPackageName;
  final bool allowDelete;

  const TestPackageDetailScreen({
    super.key,
    required this.projectId,
    required this.testPackageId,
    required this.testPackageName,
    this.allowDelete = true,
  });

  // 👇 স্পুল ইনসটলেশন ডায়ালগ পপআপ দেখানোর ফাংশন
  void _showInstallationDialog(
      BuildContext context, String spoolDocId, Map<String, dynamic> spoolData) {
    bool isInstalled = spoolData['isInstalled'] ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Spool Installation",
                  style: TextStyle(
                      color: Color(0xFF000080), fontWeight: FontWeight.bold)),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: isInstalled,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isInstalled = value ?? false;
                      });
                    },
                  ),
                  const Text("Installation", style: TextStyle(fontSize: 16)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext), // উইন্ডো ক্লোজ করবে
                  child:
                      const Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('projects')
                          .doc(projectId)
                          .collection('spoolNumbers')
                          .doc(spoolDocId)
                          .update({
                        'isInstalled': isInstalled,
                      });

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Installation updated successfully!"),
                            backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Failed: $e"),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showJointDialog(
      BuildContext context, String jointDocId, Map<String, dynamic> jointData) {
    bool isFitup = jointData['isFitup'] ?? false;
    bool isWelding = jointData['isWelding'] ?? false;
    bool isUtPt = jointData['isUtPt'] ?? false;
    bool isRadiationTest = jointData['isRadiationTest'] ?? false;
    bool isVisual = jointData['isVisual'] ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Joint Status",
                  style: TextStyle(
                      color: Color(0xFF000080), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text("Fitup / Install"),
                      value: isFitup,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          isFitup = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text("Welding"),
                      value: isWelding,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          isWelding = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text("UT/PT"),
                      value: isUtPt,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          isUtPt = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text("Radiation Test"),
                      value: isRadiationTest,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          isRadiationTest = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text("Visual"),
                      value: isVisual,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          isVisual = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child:
                      const Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('projects')
                          .doc(projectId)
                          .collection('jointNumbers')
                          .doc(jointDocId)
                          .update({
                        'isFitup': isFitup,
                        'isWelding': isWelding,
                        'isUtPt': isUtPt,
                        'isRadiationTest': isRadiationTest,
                        'isVisual': isVisual,
                      });

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Joint status updated successfully!"),
                            backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Failed: $e"),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Support ডায়ালগ ফাংশন
  void _showSupportDialog(BuildContext context, String supportDocId,
      Map<String, dynamic> supportData) {
    bool isInstalled = supportData['isInstalled'] ?? false;
    bool isFitup = supportData['isFitup'] ?? false;
    bool isWelding = supportData['isWelding'] ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Support Status",
                  style: TextStyle(
                      color: Color(0xFF000080), fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text("Install"),
                    value: isInstalled,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isInstalled = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Fitup"),
                    value: isFitup,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isFitup = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Welding"),
                    value: isWelding,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isWelding = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child:
                      const Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('projects')
                          .doc(projectId)
                          .collection('supportNumbers')
                          .doc(supportDocId)
                          .update({
                        'isInstalled': isInstalled,
                        'isFitup': isFitup,
                        'isWelding': isWelding,
                      });

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Support status updated successfully!"),
                            backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Failed: $e"),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

// Valve ডায়ালগ ফাংশন
  void _showValveDialog(
      BuildContext context, String valveDocId, Map<String, dynamic> valveData) {
    bool isInstalled = valveData['isInstalled'] ?? false;
    bool isFitup = valveData['isFitup'] ?? false;
    bool isWelding = valveData['isWelding'] ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Valve Status",
                  style: TextStyle(
                      color: Color(0xFF000080), fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text("Install"),
                    value: isInstalled,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isInstalled = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Fitup"),
                    value: isFitup,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isFitup = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Welding"),
                    value: isWelding,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isWelding = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child:
                      const Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('projects')
                          .doc(projectId)
                          .collection('valveNumbers')
                          .doc(valveDocId)
                          .update({
                        'isInstalled': isInstalled,
                        'isFitup': isFitup,
                        'isWelding': isWelding,
                      });

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Valve status updated successfully!"),
                            backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Failed: $e"),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLineInspectionDialog(
      BuildContext context, String lineDocId, Map<String, dynamic> lineData) {
    bool isInspection = lineData['isInspection'] ?? false;
    bool isLineCheck = lineData['isLineCheck'] ?? false;
    bool isHydroTest = lineData['isHydroTest'] ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Line Inspection Status",
                  style: TextStyle(
                      color: Color(0xFF000080), fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text("Inspaction"),
                    value: isInspection,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isInspection = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Line Check"),
                    value: isLineCheck,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isLineCheck = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Hydro Test"),
                    value: isHydroTest,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isHydroTest = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child:
                      const Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('projects')
                          .doc(projectId)
                          .collection('lineNumbers')
                          .doc(lineDocId)
                          .update({
                        'isInspection': isInspection,
                        'isLineCheck': isLineCheck,
                        'isHydroTest': isHydroTest,
                      });

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Line status updated successfully!"),
                            backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Failed: $e"),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTestPackageDialog(
      BuildContext context, String tpId, Map<String, dynamic> tpData) {
    bool isHydroTest = tpData['isHydroTest'] ?? false;
    bool isLineCheck = tpData['isLineCheck'] ?? false;
    bool isReInstrument = tpData['isReInstrument'] ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Test Package Status",
                  style: TextStyle(
                      color: Color(0xFF000080), fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text("Hydro Test"),
                    value: isHydroTest,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isHydroTest = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Line Check"),
                    value: isLineCheck,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isLineCheck = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Re-Inustrument"),
                    value: isReInstrument,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        isReInstrument = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child:
                      const Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('projects')
                          .doc(projectId)
                          .collection('testPakeged')
                          .doc(tpId)
                          .update({
                        'isHydroTest': isHydroTest,
                        'isLineCheck': isLineCheck,
                        'isReInstrument': isReInstrument,
                      });

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Test Package status updated!"),
                            backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Failed: $e"),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👇 ঠিক এই জায়গাটিতে আগের সাধারণ Text উইজেটটির বদলে এটি বসাবেন:
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .doc(projectId)
                  .collection('testPakeged')
                  .doc(testPackageId)
                  .snapshots(),
              builder: (context, tpSnapshot) {
                final tpData = tpSnapshot.data?.data() ?? {};
                bool tpHydro = tpData['isHydroTest'] ?? false;
                bool tpLineCheck = tpData['isLineCheck'] ?? false;
                bool tpReInst = tpData['isReInstrument'] ?? false;

                // টেস্ট প্যাকেজের ৩টি পয়েন্টের হিসাব
                int tpTotal = 3;
                int tpCompleted = 0;
                if (tpHydro) tpCompleted++;
                if (tpLineCheck) tpCompleted++;
                if (tpReInst) tpCompleted++;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('projects')
                      .doc(projectId)
                      .collection('lineNumbers')
                      .where('testPackageId', isEqualTo: testPackageId)
                      .snapshots(),
                  builder: (context, lineSnap) {
                    final lineDocs = lineSnap.data?.docs ?? [];
                    final lineIds = lineDocs.map((l) => l.id).toList();

                    if (lineIds.isEmpty) {
                      double tpPercentage =
                          tpTotal > 0 ? (tpCompleted / tpTotal) * 100 : 0;
                      return InkWell(
                        onTap: () => _showTestPackageDialog(
                            context, testPackageId, tpData),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                "Test Package: $testPackageName",
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF000080)),
                              ),
                              const SizedBox(width: 15),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tpPercentage == 100
                                      ? Colors.green.shade100
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: tpPercentage == 100
                                          ? Colors.green
                                          : Colors.blue.shade200),
                                ),
                                child: Text(
                                  "${tpPercentage.toStringAsFixed(0)}%",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: tpPercentage == 100
                                        ? Colors.green.shade800
                                        : const Color(0xFF000080),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.edit_note,
                                  size: 20, color: Color(0xFF000080)),
                            ],
                          ),
                        ),
                      );
                    }

                    // সব সাব-কম্পোনেন্ট ট্র্যাক করে টেস্ট প্যাকেজের টোটাল পার্সেন্টেজ বের করা
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('projects')
                          .doc(projectId)
                          .collection('spoolNumbers')
                          .snapshots(),
                      builder: (context, spoolSnap) {
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(projectId)
                              .collection('jointNumbers')
                              .snapshots(),
                          builder: (context, jointSnap) {
                            return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(projectId)
                                  .collection('supportNumbers')
                                  .snapshots(),
                              builder: (context, supportSnap) {
                                return StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance
                                      .collection('projects')
                                      .doc(projectId)
                                      .collection('valveNumbers')
                                      .snapshots(),
                                  builder: (context, valveSnap) {
                                    int grandTotal = tpTotal;
                                    int grandCompleted = tpCompleted;

                                    final spools = (spoolSnap.data?.docs ?? [])
                                        .where((s) => lineIds
                                            .contains(s.data()['lineNumberId']))
                                        .toList();
                                    final spoolIds =
                                        spools.map((s) => s.id).toList();

                                    for (var spool in spools) {
                                      grandTotal += 1;
                                      if (spool.data()['isInstalled'] == true)
                                        grandCompleted++;
                                    }

                                    final joints = (jointSnap.data?.docs ?? [])
                                        .where((j) => spoolIds.contains(
                                            j.data()['spoolNumberId']))
                                        .toList();
                                    for (var j in joints) {
                                      grandTotal += 5;
                                      var data = j.data();
                                      if (data['isFitup'] == true)
                                        grandCompleted++;
                                      if (data['isWelding'] == true)
                                        grandCompleted++;
                                      if (data['isUtPt'] == true)
                                        grandCompleted++;
                                      if (data['isRadiationTest'] == true)
                                        grandCompleted++;
                                      if (data['isVisual'] == true)
                                        grandCompleted++;
                                    }

                                    final supports =
                                        (supportSnap.data?.docs ?? [])
                                            .where((s) => spoolIds.contains(
                                                s.data()['spoolNumberId']))
                                            .toList();
                                    for (var s in supports) {
                                      grandTotal += 3;
                                      var data = s.data();
                                      if (data['isInstalled'] == true)
                                        grandCompleted++;
                                      if (data['isFitup'] == true)
                                        grandCompleted++;
                                      if (data['isWelding'] == true)
                                        grandCompleted++;
                                    }

                                    final valves = (valveSnap.data?.docs ?? [])
                                        .where((v) => spoolIds.contains(
                                            v.data()['spoolNumberId']))
                                        .toList();
                                    for (var v in valves) {
                                      grandTotal += 3;
                                      var data = v.data();
                                      if (data['isInstalled'] == true)
                                        grandCompleted++;
                                      if (data['isFitup'] == true)
                                        grandCompleted++;
                                      if (data['isWelding'] == true)
                                        grandCompleted++;
                                    }

                                    double finalTpPercentage = grandTotal > 0
                                        ? (grandCompleted / grandTotal) * 100
                                        : 0;

                                    return InkWell(
                                      onTap: () => _showTestPackageDialog(
                                          context, testPackageId, tpData),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        child: Row(
                                          children: [
                                            Text(
                                              "Test Package: $testPackageName",
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF000080)),
                                            ),
                                            const SizedBox(width: 15),
                                            // 👈 টেস্ট প্যাকেজের পার্সেন্টেজ ব্যাজ
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: finalTpPercentage == 100
                                                    ? Colors.green.shade100
                                                    : Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: finalTpPercentage ==
                                                            100
                                                        ? Colors.green
                                                        : Colors.blue.shade200),
                                              ),
                                              child: Text(
                                                "${finalTpPercentage.toStringAsFixed(0)}%",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: finalTpPercentage ==
                                                          100
                                                      ? Colors.green.shade800
                                                      : const Color(0xFF000080),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.edit_note,
                                                size: 20,
                                                color: Color(0xFF000080)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 15),

            // এর নিচে বাকি লাইন নম্বরের ListView বা StreamBuilder শুরু হবে...
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('projects')
                    .doc(projectId)
                    .collection('lineNumbers')
                    .where('testPackageId', isEqualTo: testPackageId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final lines = snapshot.data?.docs ?? [];
                  if (lines.isEmpty) {
                    return const Center(
                        child: Text(
                            "No Line Number found for this Test Package."));
                  }

                  return ListView.builder(
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final lineDoc = lines[index];
                      final lineData = lineDoc.data();
                      final lineName = lineData['name']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(projectId)
                              .collection('spoolNumbers')
                              .where('lineNumberId', isEqualTo: lineDoc.id)
                              .snapshots(),
                          builder: (context, spoolSnap) {
                            final spools = spoolSnap.data?.docs ?? [];
                            final spoolIds = spools.map((s) => s.id).toList();

                            if (spoolIds.isEmpty) {
                              return ExpansionTile(
                                leading: const Icon(Icons.linear_scale,
                                    color: Colors.indigo),
                                title: Row(
                                  children: [
                                    Text(
                                      "Line: $lineName",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(width: 15),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: const Text("0%",
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey)),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.fact_check_outlined,
                                          color: Color(0xFF000080)),
                                      tooltip: "Line Inspection",
                                      onPressed: () =>
                                          _showLineInspectionDialog(
                                              context, lineDoc.id, lineData),
                                    ),
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          color: Colors.grey),
                                      offset: const Offset(0, 40),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      onSelected: (value) async {
                                        if (value == 'view') {
                                          final driveLink =
                                              lineData['driveLink']
                                                      ?.toString() ??
                                                  '';
                                          if (driveLink.isEmpty) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      "No Google Drive Link found for this line!"),
                                                  backgroundColor:
                                                      Colors.orange),
                                            );
                                            return;
                                          }
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    "Drive Link: $driveLink"),
                                                backgroundColor: Colors.blue),
                                          );
                                        } else if (value == 'edit') {
                                          TextEditingController editController =
                                              TextEditingController(
                                                  text: lineName);
                                          showDialog(
                                            context: context,
                                            builder: (dialogContext) {
                                              return AlertDialog(
                                                title: const Text(
                                                    "Edit Line Number"),
                                                content: TextField(
                                                  controller: editController,
                                                  decoration: const InputDecoration(
                                                      labelText: "Line Name",
                                                      border:
                                                          OutlineInputBorder()),
                                                ),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              dialogContext),
                                                      child:
                                                          const Text("CANCEL")),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      final newName =
                                                          editController.text
                                                              .trim();
                                                      if (newName.isEmpty)
                                                        return;
                                                      try {
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'projects')
                                                            .doc(projectId)
                                                            .collection(
                                                                'lineNumbers')
                                                            .doc(lineDoc.id)
                                                            .update({
                                                          'name': newName,
                                                          'updatedAt': FieldValue
                                                              .serverTimestamp()
                                                        });
                                                        if (!dialogContext
                                                            .mounted) return;
                                                        Navigator.pop(
                                                            dialogContext);
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                              content: Text(
                                                                  "Line updated successfully!"),
                                                              backgroundColor:
                                                                  Colors.green),
                                                        );
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                              content: Text(
                                                                  "Update failed: $e"),
                                                              backgroundColor:
                                                                  Colors.red),
                                                        );
                                                      }
                                                    },
                                                    child: const Text("UPDATE"),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        } else if (value == 'delete' &&
                                            allowDelete) {
                                          await FirebaseFirestore.instance
                                              .collection('projects')
                                              .doc(projectId)
                                              .collection('lineNumbers')
                                              .doc(lineDoc.id)
                                              .delete();
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    "Line deleted successfully!"),
                                                backgroundColor: Colors.red),
                                          );
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem<String>(
                                          value: 'view',
                                          child: Row(children: [
                                            Icon(Icons.visibility,
                                                color: Color(0xFF000080),
                                                size: 18),
                                            SizedBox(width: 10),
                                            Text("VIEW DETAILS",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13))
                                          ]),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Row(children: [
                                            Icon(Icons.edit,
                                                color: Colors.blue, size: 18),
                                            SizedBox(width: 10),
                                            Text("EDIT",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13))
                                          ]),
                                        ),
                                        if (allowDelete)
                                          const PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Row(children: [
                                              Icon(Icons.delete_outline,
                                                  color: Colors.red, size: 18),
                                              SizedBox(width: 10),
                                              Text("DELETE",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13))
                                            ]),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Text(
                                        "No Spool Number under this Line",
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 13)),
                                  ),
                                ],
                              );
                            }

                            return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(projectId)
                                  .collection('jointNumbers')
                                  .snapshots(),
                              builder: (context, jointSnap) {
                                return StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance
                                      .collection('projects')
                                      .doc(projectId)
                                      .collection('supportNumbers')
                                      .snapshots(),
                                  builder: (context, supportSnap) {
                                    return StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>>(
                                      stream: FirebaseFirestore.instance
                                          .collection('projects')
                                          .doc(projectId)
                                          .collection('valveNumbers')
                                          .snapshots(),
                                      builder: (context, valveSnap) {
                                        int totalItems = 0;
                                        int completedItems = 0;

                                        // ১. স্পুল হিসাব (১টি পয়েন্ট)
                                        for (var spool in spools) {
                                          totalItems += 1;
                                          if (spool.data()['isInstalled'] ==
                                              true) {
                                            completedItems += 1;
                                          }
                                        }

                                        // ২. জয়েন্ট হিসাব (৫টি পয়েন্ট: isFitup, isWelding, isUtPt, isRadiationTest, isVisual)
                                        final joints =
                                            (jointSnap.data?.docs ?? [])
                                                .where((j) => spoolIds.contains(
                                                    j.data()['spoolNumberId']))
                                                .toList();
                                        for (var j in joints) {
                                          totalItems += 5;
                                          var data = j.data();
                                          if (data['isFitup'] == true)
                                            completedItems++;
                                          if (data['isWelding'] == true)
                                            completedItems++;
                                          if (data['isUtPt'] == true)
                                            completedItems++;
                                          if (data['isRadiationTest'] == true)
                                            completedItems++;
                                          if (data['isVisual'] == true)
                                            completedItems++;
                                        }

                                        // ৩. সাপোর্ট হিসাব (৩টি পয়েন্ট: isInstalled, isFitup, isWelding)
                                        final supports =
                                            (supportSnap.data?.docs ?? [])
                                                .where((s) => spoolIds.contains(
                                                    s.data()['spoolNumberId']))
                                                .toList();
                                        for (var s in supports) {
                                          totalItems += 3;
                                          var data = s.data();
                                          if (data['isInstalled'] == true)
                                            completedItems++;
                                          if (data['isFitup'] == true)
                                            completedItems++;
                                          if (data['isWelding'] == true)
                                            completedItems++;
                                        }

                                        // ৪. ভালভ হিসাব (৩টি পয়েন্ট: isInstalled, isFitup, isWelding)
                                        final valves =
                                            (valveSnap.data?.docs ?? [])
                                                .where((v) => spoolIds.contains(
                                                    v.data()['spoolNumberId']))
                                                .toList();
                                        for (var v in valves) {
                                          totalItems += 3;
                                          var data = v.data();
                                          if (data['isInstalled'] == true)
                                            completedItems++;
                                          if (data['isFitup'] == true)
                                            completedItems++;
                                          if (data['isWelding'] == true)
                                            completedItems++;
                                        }

                                        double percentage = totalItems > 0
                                            ? (completedItems / totalItems) *
                                                100
                                            : 0;
                                        String percentStr =
                                            "${percentage.toStringAsFixed(0)}%";

                                        return ExpansionTile(
                                          leading: const Icon(
                                              Icons.linear_scale,
                                              color: Colors.indigo),
                                          title: Row(
                                            children: [
                                              Text(
                                                "Line: $lineName",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15),
                                              ),
                                              const SizedBox(width: 15),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: percentage == 100
                                                      ? Colors.green.shade100
                                                      : Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: percentage == 100
                                                          ? Colors.green
                                                          : Colors
                                                              .blue.shade200),
                                                ),
                                                child: Text(
                                                  percentStr,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: percentage == 100
                                                        ? Colors.green.shade800
                                                        : const Color(
                                                            0xFF000080),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.fact_check_outlined,
                                                    color: Color(0xFF000080)),
                                                tooltip: "Line Inspection",
                                                onPressed: () =>
                                                    _showLineInspectionDialog(
                                                        context,
                                                        lineDoc.id,
                                                        lineData),
                                              ),
                                              const SizedBox(width: 4),
                                              PopupMenuButton<String>(
                                                icon: const Icon(
                                                    Icons.more_vert,
                                                    color: Colors.grey),
                                                offset: const Offset(0, 40),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                onSelected: (value) async {
                                                  if (value == 'view') {
                                                    final driveLink =
                                                        lineData['driveLink']
                                                                ?.toString() ??
                                                            '';
                                                    if (driveLink.isEmpty) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                "No Google Drive Link found for this line!"),
                                                            backgroundColor:
                                                                Colors.orange),
                                                      );
                                                      return;
                                                    }
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              "Drive Link: $driveLink"),
                                                          backgroundColor:
                                                              Colors.blue),
                                                    );
                                                  } else if (value == 'edit') {
                                                    TextEditingController
                                                        editController =
                                                        TextEditingController(
                                                            text: lineName);
                                                    showDialog(
                                                      context: context,
                                                      builder: (dialogContext) {
                                                        return AlertDialog(
                                                          title: const Text(
                                                              "Edit Line Number"),
                                                          content: TextField(
                                                            controller:
                                                                editController,
                                                            decoration: const InputDecoration(
                                                                labelText:
                                                                    "Line Name",
                                                                border:
                                                                    OutlineInputBorder()),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        dialogContext),
                                                                child: const Text(
                                                                    "CANCEL")),
                                                            ElevatedButton(
                                                              onPressed:
                                                                  () async {
                                                                final newName =
                                                                    editController
                                                                        .text
                                                                        .trim();
                                                                if (newName
                                                                    .isEmpty)
                                                                  return;
                                                                try {
                                                                  await FirebaseFirestore
                                                                      .instance
                                                                      .collection(
                                                                          'projects')
                                                                      .doc(
                                                                          projectId)
                                                                      .collection(
                                                                          'lineNumbers')
                                                                      .doc(lineDoc
                                                                          .id)
                                                                      .update({
                                                                    'name':
                                                                        newName,
                                                                    'updatedAt':
                                                                        FieldValue
                                                                            .serverTimestamp()
                                                                  });
                                                                  if (!dialogContext
                                                                      .mounted)
                                                                    return;
                                                                  Navigator.pop(
                                                                      dialogContext);
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    const SnackBar(
                                                                        content:
                                                                            Text(
                                                                                "Line updated successfully!"),
                                                                        backgroundColor:
                                                                            Colors.green),
                                                                  );
                                                                } catch (e) {
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                        content:
                                                                            Text(
                                                                                "Update failed: $e"),
                                                                        backgroundColor:
                                                                            Colors.red),
                                                                  );
                                                                }
                                                              },
                                                              child: const Text(
                                                                  "UPDATE"),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  } else if (value ==
                                                          'delete' &&
                                                      allowDelete) {
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('projects')
                                                        .doc(projectId)
                                                        .collection(
                                                            'lineNumbers')
                                                        .doc(lineDoc.id)
                                                        .delete();
                                                    if (!context.mounted)
                                                      return;
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              "Line deleted successfully!"),
                                                          backgroundColor:
                                                              Colors.red),
                                                    );
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem<String>(
                                                    value: 'view',
                                                    child: Row(children: [
                                                      Icon(Icons.visibility,
                                                          color:
                                                              Color(0xFF000080),
                                                          size: 18),
                                                      SizedBox(width: 10),
                                                      Text("VIEW DETAILS",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 13))
                                                    ]),
                                                  ),
                                                  const PopupMenuItem<String>(
                                                    value: 'edit',
                                                    child: Row(children: [
                                                      Icon(Icons.edit,
                                                          color: Colors.blue,
                                                          size: 18),
                                                      SizedBox(width: 10),
                                                      Text("EDIT",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 13))
                                                    ]),
                                                  ),
                                                  if (allowDelete)
                                                    const PopupMenuItem<String>(
                                                      value: 'delete',
                                                      child: Row(children: [
                                                        Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: Colors.red,
                                                            size: 18),
                                                        SizedBox(width: 10),
                                                        Text("DELETE",
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 13))
                                                      ]),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          children: [
                                            ListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: spools.length,
                                              itemBuilder:
                                                  (context, spoolIndex) {
                                                final spoolDoc =
                                                    spools[spoolIndex];
                                                final spoolData =
                                                    spoolDoc.data();
                                                final spoolName =
                                                    spoolData['name']
                                                            ?.toString() ??
                                                        '';
                                                final bool isInstalled =
                                                    spoolData['isInstalled'] ??
                                                        false;

                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 20,
                                                      right: 15,
                                                      bottom: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      ListTile(
                                                        onTap: () =>
                                                            _showInstallationDialog(
                                                                context,
                                                                spoolDoc.id,
                                                                spoolData),
                                                        leading: const Icon(
                                                            Icons.alt_route,
                                                            color: Colors.blue,
                                                            size: 18),
                                                        title: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              "Spool: $spoolName",
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14),
                                                            ),
                                                            if (isInstalled)
                                                              const Text(
                                                                "Complete Installation",
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .green,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                          ],
                                                        ),
                                                        trailing: allowDelete
                                                            ? IconButton(
                                                                icon: const Icon(
                                                                    Icons
                                                                        .delete_outline,
                                                                    color: Colors
                                                                        .red,
                                                                    size: 18),
                                                                onPressed:
                                                                    () async {
                                                                  await FirebaseFirestore
                                                                      .instance
                                                                      .collection(
                                                                          'projects')
                                                                      .doc(
                                                                          projectId)
                                                                      .collection(
                                                                          'spoolNumbers')
                                                                      .doc(spoolDoc
                                                                          .id)
                                                                      .delete();
                                                                },
                                                              )
                                                            : null,
                                                      ),
                                                      const Divider(height: 1),
                                                      StreamBuilder<
                                                          QuerySnapshot<
                                                              Map<String,
                                                                  dynamic>>>(
                                                        stream: FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'projects')
                                                            .doc(projectId)
                                                            .collection(
                                                                'supportNumbers')
                                                            .where(
                                                                'spoolNumberId',
                                                                isEqualTo:
                                                                    spoolDoc.id)
                                                            .snapshots(),
                                                        builder: (context,
                                                            supportSnapshot) {
                                                          final supports =
                                                              supportSnapshot
                                                                      .data
                                                                      ?.docs ??
                                                                  [];
                                                          return StreamBuilder<
                                                              QuerySnapshot<
                                                                  Map<String,
                                                                      dynamic>>>(
                                                            stream: FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                    'projects')
                                                                .doc(projectId)
                                                                .collection(
                                                                    'valveNumbers')
                                                                .where(
                                                                    'spoolNumberId',
                                                                    isEqualTo:
                                                                        spoolDoc
                                                                            .id)
                                                                .snapshots(),
                                                            builder: (context,
                                                                valveSnapshot) {
                                                              final valves =
                                                                  valveSnapshot
                                                                          .data
                                                                          ?.docs ??
                                                                      [];
                                                              return StreamBuilder<
                                                                  QuerySnapshot<
                                                                      Map<String,
                                                                          dynamic>>>(
                                                                stream: FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                        'projects')
                                                                    .doc(
                                                                        projectId)
                                                                    .collection(
                                                                        'jointNumbers')
                                                                    .where(
                                                                        'spoolNumberId',
                                                                        isEqualTo:
                                                                            spoolDoc.id)
                                                                    .snapshots(),
                                                                builder: (context,
                                                                    jointSnapshot) {
                                                                  final joints =
                                                                      jointSnapshot
                                                                              .data
                                                                              ?.docs ??
                                                                          [];

                                                                  if (supports
                                                                          .isEmpty &&
                                                                      valves
                                                                          .isEmpty &&
                                                                      joints
                                                                          .isEmpty) {
                                                                    return const Padding(
                                                                      padding:
                                                                          EdgeInsets.all(
                                                                              12.0),
                                                                      child: Text(
                                                                          "No Support, Valve or Joint under this Spool",
                                                                          style: TextStyle(
                                                                              color: Colors.grey,
                                                                              fontSize: 12)),
                                                                    );
                                                                  }

                                                                  return Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            12.0),
                                                                    child:
                                                                        Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        if (joints
                                                                            .isNotEmpty) ...[
                                                                          const Text(
                                                                              "Joint Numbers:",
                                                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                                                                          const SizedBox(
                                                                              height: 6),
                                                                          Wrap(
                                                                            spacing:
                                                                                8,
                                                                            runSpacing:
                                                                                8,
                                                                            children:
                                                                                joints.map((joint) {
                                                                              final jointData = joint.data();
                                                                              final jointName = jointData['name']?.toString() ?? '';
                                                                              final bool isFitup = jointData['isFitup'] ?? false;
                                                                              final bool isWelding = jointData['isWelding'] ?? false;
                                                                              final bool isUtPt = jointData['isUtPt'] ?? false;
                                                                              final bool isRadiationTest = jointData['isRadiationTest'] ?? false;
                                                                              final bool isVisual = jointData['isVisual'] ?? false;

                                                                              return InkWell(
                                                                                onTap: () => _showJointDialog(context, joint.id, jointData),
                                                                                child: Container(
                                                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                                                  decoration: BoxDecoration(
                                                                                    color: Colors.purple.shade50,
                                                                                    borderRadius: BorderRadius.circular(6),
                                                                                    border: Border.all(color: Colors.purple.shade200),
                                                                                  ),
                                                                                  child: Row(
                                                                                    mainAxisSize: MainAxisSize.min,
                                                                                    children: [
                                                                                      const Icon(Icons.join_full, size: 14, color: Colors.purple),
                                                                                      const SizedBox(width: 6),
                                                                                      Text(jointName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                                                                                      const SizedBox(width: 10),
                                                                                      if (isFitup || isWelding || isUtPt || isRadiationTest || isVisual)
                                                                                        Text(
                                                                                          "(${isFitup ? 'Fitup ' : ''}${isWelding ? 'Welding ' : ''}${isUtPt ? 'UT/PT ' : ''}${isRadiationTest ? 'Radiation ' : ''}${isVisual ? 'Visual' : ''})",
                                                                                          style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                                                                        ),
                                                                                      if (allowDelete) ...[
                                                                                        const SizedBox(width: 6),
                                                                                        InkWell(
                                                                                          onTap: () async {
                                                                                            await FirebaseFirestore.instance.collection('projects').doc(projectId).collection('jointNumbers').doc(joint.id).delete();
                                                                                          },
                                                                                          child: const Icon(Icons.close, size: 12, color: Colors.red),
                                                                                        ),
                                                                                      ],
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            }).toList(),
                                                                          ),
                                                                          const SizedBox(
                                                                              height: 10),
                                                                        ],
                                                                        if (supports
                                                                            .isNotEmpty) ...[
                                                                          const Text(
                                                                              "Support Numbers:",
                                                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                                                          const SizedBox(
                                                                              height: 6),
                                                                          Wrap(
                                                                            spacing:
                                                                                8,
                                                                            runSpacing:
                                                                                8,
                                                                            children:
                                                                                supports.map((sup) {
                                                                              final supData = sup.data();
                                                                              final supName = supData['name']?.toString() ?? '';
                                                                              final bool isInstalled = supData['isInstalled'] ?? false;
                                                                              final bool isFitup = supData['isFitup'] ?? false;
                                                                              final bool isWelding = supData['isWelding'] ?? false;

                                                                              return InkWell(
                                                                                onTap: () => _showSupportDialog(context, sup.id, supData),
                                                                                child: Container(
                                                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                                  decoration: BoxDecoration(
                                                                                    color: Colors.orange.shade50,
                                                                                    borderRadius: BorderRadius.circular(6),
                                                                                    border: Border.all(color: Colors.orange.shade200),
                                                                                  ),
                                                                                  child: Row(
                                                                                    mainAxisSize: MainAxisSize.min,
                                                                                    children: [
                                                                                      const Icon(Icons.support, size: 12, color: Colors.orange),
                                                                                      const SizedBox(width: 4),
                                                                                      Text(supName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                                                                      if (isInstalled || isFitup || isWelding) ...[
                                                                                        const SizedBox(width: 6),
                                                                                        Text(
                                                                                          "(${isInstalled ? 'Install ' : ''}${isFitup ? 'Fitup ' : ''}${isWelding ? 'Welding' : ''})",
                                                                                          style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                                                                        ),
                                                                                      ],
                                                                                      if (allowDelete) ...[
                                                                                        const SizedBox(width: 6),
                                                                                        InkWell(
                                                                                          onTap: () async {
                                                                                            await FirebaseFirestore.instance.collection('projects').doc(projectId).collection('supportNumbers').doc(sup.id).delete();
                                                                                          },
                                                                                          child: const Icon(Icons.close, size: 12, color: Colors.red),
                                                                                        ),
                                                                                      ],
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            }).toList(),
                                                                          ),
                                                                          const SizedBox(
                                                                              height: 10),
                                                                        ],
                                                                        if (valves
                                                                            .isNotEmpty) ...[
                                                                          const Text(
                                                                              "Valve Numbers:",
                                                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                                                          const SizedBox(
                                                                              height: 6),
                                                                          Wrap(
                                                                            spacing:
                                                                                8,
                                                                            runSpacing:
                                                                                8,
                                                                            children:
                                                                                valves.map((val) {
                                                                              final valData = val.data();
                                                                              final valName = valData['name']?.toString() ?? '';
                                                                              final bool isInstalled = valData['isInstalled'] ?? false;
                                                                              final bool isFitup = valData['isFitup'] ?? false;
                                                                              final bool isWelding = valData['isWelding'] ?? false;

                                                                              return InkWell(
                                                                                onTap: () => _showValveDialog(context, val.id, valData),
                                                                                child: Container(
                                                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                                  decoration: BoxDecoration(
                                                                                    color: Colors.green.shade50,
                                                                                    borderRadius: BorderRadius.circular(6),
                                                                                    border: Border.all(color: Colors.green.shade200),
                                                                                  ),
                                                                                  child: Row(
                                                                                    mainAxisSize: MainAxisSize.min,
                                                                                    children: [
                                                                                      const Icon(Icons.settings_input_component, size: 12, color: Colors.green),
                                                                                      const SizedBox(width: 4),
                                                                                      Text(valName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                                                                      if (isInstalled || isFitup || isWelding) ...[
                                                                                        const SizedBox(width: 6),
                                                                                        Text(
                                                                                          "(${isInstalled ? 'Install ' : ''}${isFitup ? 'Fitup ' : ''}${isWelding ? 'Welding' : ''})",
                                                                                          style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                                                                        ),
                                                                                      ],
                                                                                      if (allowDelete) ...[
                                                                                        const SizedBox(width: 6),
                                                                                        InkWell(
                                                                                          onTap: () async {
                                                                                            await FirebaseFirestore.instance.collection('projects').doc(projectId).collection('valveNumbers').doc(val.id).delete();
                                                                                          },
                                                                                          child: const Icon(Icons.close, size: 12, color: Colors.red),
                                                                                        ),
                                                                                      ],
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            }).toList(),
                                                                          ),
                                                                        ],
                                                                      ],
                                                                    ),
                                                                  );
                                                                },
                                                              );
                                                            },
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//===============================================
//APPLICATION PAGE
//===============================================

class WebApplicationPage extends StatefulWidget {
  const WebApplicationPage({super.key});

  @override
  State<WebApplicationPage> createState() => _WebApplicationPageState();
}

class _WebApplicationPageState extends State<WebApplicationPage> {
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String _leaveType = "Casual";
  bool _isHalfDay = false;
  int _totalDays = 1;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String? _selectedEmployeeId;
  String _selectedEmployeeName = "";

  @override
  void initState() {
    super.initState();
    _fromDateController.text = DateFormat("dd/MM/yyyy").format(_fromDate);
    _toDateController.text = DateFormat("dd/MM/yyyy").format(_toDate);
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _reasonController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _selectFromDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
        _fromDateController.text = DateFormat("dd/MM/yyyy").format(_fromDate);
        _toDateController.text = DateFormat("dd/MM/yyyy").format(_toDate);
        _calculateDays();
      });
    }
  }

  Future<void> _selectToDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate.isBefore(_fromDate) ? _fromDate : _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _toDateController.text = DateFormat("dd/MM/yyyy").format(_toDate);
        _calculateDays();
      });
    }
  }

  void _calculateDays() {
    final int days = _toDate.difference(_fromDate).inDays + 1;
    _totalDays = _isHalfDay ? 0 : (days < 1 ? 1 : days);
  }

  void _refresh() {
    setState(() {
      _fromDate = DateTime.now();
      _toDate = DateTime.now();
      _fromDateController.text = DateFormat("dd/MM/yyyy").format(_fromDate);
      _toDateController.text = DateFormat("dd/MM/yyyy").format(_toDate);
      _leaveType = "Casual";
      _isHalfDay = false;
      _totalDays = 1;
      _selectedEmployeeId = null;
      _selectedEmployeeName = "";
      _reasonController.clear();
      _addressController.clear();
    });
  }

  void _saveLeave() {
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an Employee ID.")),
      );
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter reason for leave.")),
      );
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter address when on leave.")),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Leave application saved successfully.")),
    );
  }

  Widget _topCard({
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffdddddd)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xff159fc1)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff555555),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(IconData icon, String text, Color color) {
    return SizedBox(
      width: 120,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xff333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Expanded(
      child: SizedBox(
        height: 45,
        child: TextField(
          controller: controller,
          readOnly: onTap != null,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            suffixIcon: suffixIcon,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xff159bc0)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xff159bc0), width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formRow({required Widget label, required Widget field}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [label, field],
      ),
    );
  }

  Widget _uploadBox() {
    return Container(
      width: double.infinity,
      height: 325,
      decoration: BoxDecoration(
        color: const Color(0xfff0f8fd),
        border: Border.all(color: const Color(0xff3898ca), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload, size: 65, color: Color(0xff3b98c8)),
          const SizedBox(height: 12),
          const Text(
            "Upload Documents",
            style: TextStyle(fontSize: 18, color: Color(0xff444444)),
          ),
          const SizedBox(height: 10),
          const Text(
            "Drag & drop files here or click to browse",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.folder_open),
            label: const Text("Browse Files"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff159fc1),
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No files selected",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leftSection() {
    return Column(
      children: [
        _formRow(
          label: _label(Icons.event, "From Date", const Color(0xff20aa53)),
          field: _textField(
            controller: _fromDateController,
            hint: "",
            onTap: _selectFromDate,
            suffixIcon:
            const Icon(Icons.calendar_month, color: Color(0xff20aa53)),
          ),
        ),
        _formRow(
          label: _label(Icons.list, "Leave Type", const Color(0xff159fc1)),
          field: Expanded(
            child: SizedBox(
              height: 45,
              child: DropdownButtonFormField<String>(
                value: _leaveType,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff159bc0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                    BorderSide(color: Color(0xff159bc0), width: 2),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: "Casual", child: Text("Casual")),
                  DropdownMenuItem(value: "Sick", child: Text("Sick")),
                  DropdownMenuItem(value: "Annual", child: Text("Annual")),
                  DropdownMenuItem(
                      value: "Emergency", child: Text("Emergency")),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _leaveType = value);
                },
              ),
            ),
          ),
        ),
        _formRow(
          label: _label(Icons.chat, "Reason", const Color(0xff159fc1)),
          field: _textField(
              controller: _reasonController, hint: "Enter Reason"),
        ),
        _uploadBox(),
      ],
    );
  }

  Widget _rightSection() {
    return Column(
      children: [
        _formRow(
          label: _label(Icons.event, "To Date", Colors.redAccent),
          field: _textField(
            controller: _toDateController,
            hint: "",
            onTap: _selectToDate,
            suffixIcon: const Icon(Icons.calendar_month, color: Colors.redAccent),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _label(Icons.format_list_numbered, "Total Days", const Color(0xff159fc1)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xff159bc0)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "$_totalDays",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xff159fc1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Checkbox(
                        value: _isHalfDay,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (value) {
                          setState(() {
                            _isHalfDay = value ?? false;
                            _calculateDays();
                          });
                        },
                      ),
                      const Text(
                        "Is Half Day",
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _formRow(
          label: _label(Icons.location_on, "Address", const Color(0xff159fc1)),
          field: _textField(
            controller: _addressController,
            hint: "Enter Address",
          ),
        ),
      ],
    );
  }

  Widget _bottomButtons(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2c94bd),
              foregroundColor: Colors.white,
            ),
            child: const Text("View History"),
          ),
          const SizedBox(height: 5),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff148da8),
              foregroundColor: Colors.white,
            ),
            child: const Text("View Balance & Approver"),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _saveLeave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff21953a),
              foregroundColor: Colors.white,
            ),
            child: const Text("Save"),
          ),
          const SizedBox(height: 5),
          OutlinedButton(onPressed: _refresh, child: const Text("Refresh")),
        ],
      );
    }
    return Row(
      children: [
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff2c94bd),
            foregroundColor: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          child: const Text("View History", style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 5),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff148da8),
            foregroundColor: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          child: const Text("View Balance & Approver",
              style: TextStyle(fontSize: 16)),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _saveLeave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff21953a),
            foregroundColor: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          child: const Text("Save", style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 5),
        OutlinedButton(
          onPressed: _refresh,
          style: OutlinedButton.styleFrom(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          child: const Text("Refresh"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          Container(
            height: 64,
            color: const Color(0xFF000080),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  "SBM GROUP OF COMPANY",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.home, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    "Home",
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("/"),
                ),
                const Text(
                  "Application",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Ekhane Autocomplete dropdown ebong dan pashe nam show korar box fixed kora holo
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 180, // ড্রপডাউনে নামসহ দেখানোর জন্য উইডথ একটু বাড়িয়ে দেওয়া হলো
                      height: 40,
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('employees')
                            .orderBy('id')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: LinearProgressIndicator());
                          }
                          final docs = snapshot.data!.docs;

                          // আইডি এবং নাম একসাথে ম্যাপ বা অবজেক্ট আকারে রাখা
                          final List<Map<String, String>> employees = docs.map((doc) {
                            final data = doc.data();
                            return {
                              'id': data['id']?.toString() ?? doc.id,
                              'name': data['name']?.toString() ?? '',
                            };
                          }).where((emp) => emp['id']!.isNotEmpty).toList();

                          return Autocomplete<Map<String, String>>(
                            displayStringForOption: (Map<String, String> option) => option['id']!,
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return employees;
                              }
                              return employees.where((emp) {
                                final query = textEditingValue.text.toLowerCase();
                                return emp['id']!.toLowerCase().contains(query) ||
                                    emp['name']!.toLowerCase().contains(query);
                              });
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  child: Container(
                                    width: 260,
                                    color: Colors.white,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            "${option['id']} - ${option['name']}",
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                          onTap: () => onSelected(option),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            onSelected: (Map<String, String> selection) {
                              setState(() {
                                _selectedEmployeeId = selection['id'];
                                _selectedEmployeeName = selection['name'] ?? "";
                              });
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  hintText: "Select Employee ID",
                                  hintStyle: const TextStyle(fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xff159bc0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xff159bc0), width: 2),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: _selectedEmployeeName.isNotEmpty ? const Color(0xffe8f4f8) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedEmployeeName.isNotEmpty ? const Color(0xff159bc0) : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        _selectedEmployeeName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff000080),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(22, 20, 22, 15),
                    child: isMobile
                        ? Column(
                      children: [
                        _topCard(
                          icon: Icons.calendar_month,
                          title: "Balance",
                          value: "0",
                          valueColor: const Color(0xff159fc1),
                        ),
                        const SizedBox(height: 10),
                        _topCard(
                          icon: Icons.person,
                          title: "First Approver",
                          value: "N/A",
                          valueColor: Colors.green,
                        ),
                        const SizedBox(height: 10),
                        _topCard(
                          icon: Icons.person,
                          title: "Final Approver",
                          value: "N/A",
                          valueColor: Colors.deepPurple,
                        ),
                        const SizedBox(height: 10),
                        _topCard(
                          icon: Icons.local_offer,
                          title: "Leave Entitled",
                          value: "0",
                          valueColor: Colors.orange,
                        ),
                      ],
                    )
                        : Row(
                      children: [
                        _topCard(
                          icon: Icons.calendar_month,
                          title: "Balance",
                          value: "0",
                          valueColor: const Color(0xff159fc1),
                        ),
                        _topCard(
                          icon: Icons.person,
                          title: "First Approver",
                          value: "N/A",
                          valueColor: Colors.green,
                        ),
                        _topCard(
                          icon: Icons.person,
                          title: "Final Approver",
                          value: "N/A",
                          valueColor: Colors.deepPurple,
                        ),
                        _topCard(
                          icon: Icons.local_offer,
                          title: "Leave Entitled",
                          value: "0",
                          valueColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                        left: BorderSide(
                          color: Color(0xff20a347),
                          width: 4,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
                          decoration: const BoxDecoration(
                            color: Color(0xff218c36),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(11),
                              topLeft: Radius.circular(8),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.edit_note,
                                  color: Colors.white, size: 23),
                              SizedBox(width: 7),
                              Text(
                                "Apply for Leave",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: isMobile
                              ? Column(
                            children: [
                              _leftSection(),
                              const SizedBox(height: 20),
                              _rightSection(),
                            ],
                          )
                              : Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _leftSection()),
                              const SizedBox(width: 20),
                              Expanded(child: _rightSection()),
                            ],
                          ),
                        ),
                        Container(height: 1, color: const Color(0xffdddddd)),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _bottomButtons(isMobile),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WebAddEmployeePage extends StatefulWidget {
  const WebAddEmployeePage({super.key});

  @override
  State<WebAddEmployeePage> createState() => _WebAddEmployeePageState();
}

class _WebAddEmployeePageState extends State<WebAddEmployeePage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _finController = TextEditingController();
  final TextEditingController _workPermitController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedRole = 'worker';
  String? _selectedTradeId;
  String? _selectedCompanyId;
  String? _selectedDesignation;
  String _selectedCountryCode = '+65';
  bool _isSaving = false;

  Future<void> _saveEmployee() async {
    if (_isSaving) return;

    final String id = _idController.text.trim().toUpperCase();
    final String name = _nameController.text.trim();
    final String fin = _finController.text.trim();
    final String workPermit = _workPermitController.text.trim();
    final String designation = _selectedDesignation ?? '';
    final String phone = _phoneController.text.trim();

    if (id.isEmpty ||
        name.isEmpty ||
        fin.isEmpty ||
        workPermit.isEmpty ||
        phone.isEmpty ||
        _selectedDesignation == null ||
        _selectedTradeId == null ||
        _selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Please fill all fields and select a Designation, Trade and Company!"),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference<Map<String, dynamic>> employeeRef =
          firestore.collection('employees').doc(id);
      final DocumentSnapshot<Map<String, dynamic>> existingDoc =
          await employeeRef.get();

      if (existingDoc.exists) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Employee ID $id already exists!"),
            backgroundColor: Colors.red));
        return;
      }

      Map<String, bool> permissions;

      switch (_selectedRole) {
        case 'admin':
          permissions = {
            'allEmployee': true,
            'myAttendance': true,
            'history': true,
            'tools': true,
            'material': true,
            'dailyProgress': true,
            'settings': true,
            'help': true,
            'addEmployee': true,
            'managePermissions': true
          };
          break;
        case 'manager':
          permissions = {
            'allEmployee': true,
            'myAttendance': true,
            'history': true,
            'tools': true,
            'material': true,
            'dailyProgress': true,
            'settings': false,
            'help': true,
            'addEmployee': true,
            'managePermissions': true
          };
          break;
        case 'supervisor':
          permissions = {
            'allEmployee': true,
            'myAttendance': true,
            'history': true,
            'tools': true,
            'material': true,
            'dailyProgress': true,
            'settings': false,
            'help': true,
            'addEmployee': false,
            'managePermissions': false
          };
          break;
        default:
          permissions = {
            'allEmployee': false,
            'myAttendance': true,
            'history': false,
            'tools': false,
            'material': false,
            'dailyProgress': false,
            'settings': false,
            'help': true,
            'addEmployee': false,
            'managePermissions': false
          };
      }

      final companyDoc =
          await firestore.collection('companies').doc(_selectedCompanyId).get();
      final companyName = companyDoc.data()?['name']?.toString() ?? '';

      await employeeRef.set({
        'id': id,
        'name': name,
        'fin': fin,
        'workPermit': workPermit,
        'countryCode': _selectedCountryCode,
        'phone': phone,
        'fullPhoneNumber': '$_selectedCountryCode$phone',
        'designation': designation,
        'role': _selectedRole,
        'permissions': permissions,
        'tradeId': _selectedTradeId,
        'companyId': _selectedCompanyId,
        'companyName': companyName,
        'projectIds': <String>[],
        'password': null,
        'profileImageUrl': null,
        'faceEmbedding': null,
        'isRegistered': false,
      });

      if (!mounted) return;

      setState(() {
        _isSaving = false;

        // Clear text fields
        _idController.clear();
        _nameController.clear();
        _finController.clear();
        _workPermitController.clear();
        _phoneController.clear();

        // Reset dropdowns
        _selectedRole = 'worker';
        _selectedTradeId = null;
        _selectedCompanyId = null;
        _selectedDesignation = null;

        // Reset country code
        _selectedCountryCode = '+65';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$id Employee Added Successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Employee save failed: $e"),
          backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _finController.dispose();
    _workPermitController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 600,
            padding:
                const EdgeInsets.only(left: 12, top: 20, right: 20, bottom: 20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 15)
                ]),
            child: Column(
              children: [
                _buildField(
                    controller: _idController,
                    label: "Employee ID",
                    icon: Icons.badge),
                _buildField(
                    controller: _nameController,
                    label: "Full Name",
                    icon: Icons.person),
                _buildField(
                    controller: _finController,
                    label: "FIN Number",
                    icon: Icons.credit_card),
                _buildField(
                    controller: _workPermitController,
                    label: "Work Permit No",
                    icon: Icons.assignment),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: IntlPhoneField(
                    controller: _phoneController,
                    initialCountryCode: 'SG',
                    showCountryFlag: false,
                    pickerDialogStyle: PickerDialogStyle(width: 500),
                    decoration: const InputDecoration(
                        labelText: "Phone Number",
                        border: OutlineInputBorder()),
                    onCountryChanged: (country) => setState(
                        () => _selectedCountryCode = '+${country.dialCode}'),
                    onChanged: (phone) =>
                        _selectedCountryCode = phone.countryCode,
                  ),
                ),

                // 👇 Designation Dropdown from Firebase
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('designations')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return Text("Designation load failed: ${snapshot.error}");
                    }
                    final designationDocs = snapshot.data?.docs ?? [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: DropdownButtonFormField<String>(
                        value: designationDocs.any((doc) =>
                                doc.data()['name']?.toString() ==
                                _selectedDesignation)
                            ? _selectedDesignation
                            : null,
                        decoration: const InputDecoration(
                          labelText: "Select Designation",
                          prefixIcon: Icon(Icons.work),
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text("Select Designation"),
                        items: designationDocs.map((doc) {
                          final name = doc.data()['name']?.toString() ?? '';
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedDesignation = value),
                      ),
                    );
                  },
                ),

                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                      labelText: "Employee Role",
                      prefixIcon: Icon(Icons.manage_accounts),
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text("Admin")),
                    DropdownMenuItem(value: 'manager', child: Text("Manager")),
                    DropdownMenuItem(
                        value: 'supervisor', child: Text("Supervisor")),
                    DropdownMenuItem(value: 'worker', child: Text("Worker")),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedRole = value);
                  },
                ),
                const SizedBox(height: 18),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('trades')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text("Trade load failed: ${snapshot.error}");
                    final tradeDocs = snapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      value: tradeDocs.any((doc) => doc.id == _selectedTradeId)
                          ? _selectedTradeId
                          : null,
                      decoration: const InputDecoration(
                          labelText: "Select Trade",
                          prefixIcon: Icon(Icons.engineering),
                          border: OutlineInputBorder()),
                      hint: const Text("Select Trade"),
                      items: tradeDocs
                          .map((doc) => DropdownMenuItem<String>(
                              value: doc.id,
                              child:
                                  Text(doc.data()['name']?.toString() ?? '')))
                          .toList(),
                      onChanged: (value) => setState(() {
                        _selectedTradeId = value;
                        _selectedCompanyId = null;
                      }),
                    );
                  },
                ),
                const SizedBox(height: 18),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('companies')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const LinearProgressIndicator();
                    if (snapshot.hasError)
                      return Text("Company load failed: ${snapshot.error}");
                    final companyDocs = snapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      value:
                          companyDocs.any((doc) => doc.id == _selectedCompanyId)
                              ? _selectedCompanyId
                              : null,
                      decoration: const InputDecoration(
                          labelText: "Select Company",
                          prefixIcon: Icon(Icons.apartment),
                          border: OutlineInputBorder()),
                      hint: const Text("Select Company"),
                      items: companyDocs
                          .map((doc) => DropdownMenuItem<String>(
                              value: doc.id,
                              child:
                                  Text(doc.data()['name']?.toString() ?? '')))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCompanyId = value),
                    );
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveEmployee,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text("ADD EMPLOYEE",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      {required TextEditingController controller,
      required String label,
      required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder()),
      ),
    );
  }
}

class WebHistoryPage extends StatelessWidget {
  final String adminId;

  const WebHistoryPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          Container(
            height: 64,
            color: const Color(0xFF000080),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text("SBM", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(width: 30),
                _historyHeaderButton(context, "Administration", Icons.admin_panel_settings),
                _historyHeaderButton(context, "Report", Icons.assessment),
                PopupMenuButton<String>(
                  tooltip: "Attendance",
                  color: Colors.white,
                  offset: const Offset(0, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (value) {
                    if (value == 'individual') { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Individual Attendance page will be connected next."))); }
                    if (value == 'allReport') { Navigator.push(context, MaterialPageRoute(builder: (context) => WebAllAttendanceReportPage(adminId: adminId))); }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(value: 'individual', child: Row(children: [Icon(Icons.person_search), SizedBox(width: 10), Text("Individual Attendance")])),
                    PopupMenuItem<String>(value: 'allReport', child: Row(children: [Icon(Icons.summarize), SizedBox(width: 10), Text("All Attendance Report")])),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.fact_check, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text("Attendance", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
                _historyHeaderButton(
                  context,
                  "Application",
                  Icons.description,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WebApplicationPage(),
                      ),
                    );
                  },
                ),
                _historyHeaderButton(context, "Approval", Icons.approval),
                const Spacer(),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('employees').doc(adminId).get(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    final String name = data?['name']?.toString() ?? "Admin";
                    final String? imageUrl = data?['profileImageUrl']?.toString();
                    return InkWell(
                      onTap: () => _showHistoryAdminMenu(context, data),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 18, backgroundColor: Colors.white, backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null, child: imageUrl == null || imageUrl.isEmpty ? const Icon(Icons.person, color: Color(0xFF000080)) : null),
                            const SizedBox(width: 8),
                            Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.home, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => WebAdminHome(adminId: adminId)), (route) => false),
                  child: const Text("Home", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("/")),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("/")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyHeaderButton(
      BuildContext context,
      String title,
      IconData icon, {
        VoidCallback? onPressed,
      }) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: onPressed ?? () {
          if (title == "HOME") {
            Navigator.pop(context);
          }
        },
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        icon: Icon(icon, size: 16),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showHistoryAdminMenu(BuildContext context, Map<String, dynamic>? data) {
    final String name = data?['name']?.toString() ?? "Admin";
    final String role = data?['role']?.toString() ?? "admin";
    final String? imageUrl = data?['profileImageUrl']?.toString();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: const EdgeInsets.only(top: 75, right: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFFE8EAF6),
                    backgroundImage: (data != null && data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty) ? NetworkImage(data['profileImageUrl'].toString()) : (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                    child: (data == null || data['profileImageUrl'] == null || data['profileImageUrl'].toString().isEmpty) && (imageUrl == null || imageUrl.isEmpty) ? const Icon(Icons.person, size: 50, color: Color(0xFF000080)) : null,
                  ),
                  const SizedBox(height: 12),
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("$adminId • ${role.toUpperCase()}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showHistoryAdminProfile(context, data);
                          },
                          icon: const Icon(Icons.person),
                          label: const Text("PROFILE"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WebAdminLoginPage()), (route) => false);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          icon: const Icon(Icons.logout, color: Colors.white),
                          label: const Text("LOG OUT", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHistoryAdminProfile(BuildContext context, Map<String, dynamic>? data) {
    final String name = data?['name']?.toString() ?? '';
    final String fin = data?['fin']?.toString() ?? '';
    final String workPermit = data?['workPermit']?.toString() ?? '';
    final String designation = data?['designation']?.toString() ?? '';
    final String role = data?['role']?.toString() ?? 'admin';
    final String? imageUrl = data?['profileImageUrl']?.toString();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("ADMIN PROFILE", style: TextStyle(color: Color(0xFF000080), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: const Color(0xFFE8EAF6),
                  backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null || imageUrl.isEmpty ? const Icon(Icons.person, size: 60, color: Color(0xFF000080)) : null,
                ),
                const SizedBox(height: 20),
                _historyProfileRow("Name", name),
                _historyProfileRow("Employee ID", adminId),
                _historyProfileRow("FIN Number", fin),
                _historyProfileRow("Work Permit", workPermit),
                _historyProfileRow("Designation", designation),
                _historyProfileRow("Role", role.toUpperCase()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _historyProfileRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text("$title:", style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value.isEmpty ? "Not Available" : value)),
        ],
      ),
    );
  }
}

class WebAllAttendanceReportPage extends StatefulWidget {
  final String adminId;

  const WebAllAttendanceReportPage({
    super.key,
    required this.adminId,
  });

  @override
  State<WebAllAttendanceReportPage> createState() =>
      _WebAllAttendanceReportPageState();
}

class _WebAllAttendanceReportPageState
    extends State<WebAllAttendanceReportPage> {
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

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          // ================= NAVY FIXED HEADER =================
          Container(
            height: 70,
            color: const Color(0xFF000080),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                const Text(
                  "SBM",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 35),
                _menuButton(
                  "Administration",
                  Icons.admin_panel_settings,
                ),
                _menuButton(
                  "Report",
                  Icons.assessment,
                ),
                _menuButton(
                  "Attendance",
                  Icons.fact_check,
                ),
                _menuButton(
                  "Application",
                  Icons.description,
                ),
                _menuButton(
                  "Approval",
                  Icons.approval,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF000080),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.adminId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ================= BREADCRUMB =================
          Container(
            height: 55,
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 30,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.home,
                  color: Colors.indigo,
                  size: 18,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WebAdminHome(
                          adminId: widget.adminId,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    "Home",
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("/"),
                ),
                const Text(
                  "Attendance",
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("/"),
                ),
                const Text(
                  "All Attendance Report",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ================= PAGE BODY =================
          // ================= PAGE BODY =================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(08),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 1450,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "All Attendance Report",
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000080),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ================= FILTER CARD =================
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // YEAR
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: selectedYear,
                                decoration: const InputDecoration(
                                  labelText: "Year",
                                  border: OutlineInputBorder(),
                                ),
                                items: List.generate(
                                  8,
                                  (index) {
                                    final year =
                                        DateTime.now().year - 4 + index;

                                    return DropdownMenuItem<int>(
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
                            ),

                            const SizedBox(width: 20),

                            // MONTH
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: selectedMonth,
                                decoration: const InputDecoration(
                                  labelText: "Month",
                                  border: OutlineInputBorder(),
                                ),
                                items: List.generate(
                                  12,
                                  (index) {
                                    return DropdownMenuItem<int>(
                                      value: index + 1,
                                      child: Text(
                                        monthNames[index],
                                      ),
                                    );
                                  },
                                ),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      selectedMonth = value;
                                    });
                                  }
                                },
                              ),
                            ),

                            const SizedBox(width: 20),

                            // EMPLOYEE
                            Expanded(
                              child: StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>>(
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
                                          (doc) =>
                                              doc.data()['id']?.toString() ??
                                              '',
                                        )
                                        .where(
                                          (id) => id.isNotEmpty,
                                        ),
                                  ];

                                  return DropdownButtonFormField<String>(
                                    value: employeeIds.contains(
                                      selectedEmployeeId,
                                    )
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
                            ),

                            const SizedBox(width: 20),

                            // SHOW
                            ElevatedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isLoading = true;
                                      });

                                      await Future.delayed(
                                          const Duration(milliseconds: 300));

                                      setState(() {
                                        appliedYear = selectedYear;
                                        appliedMonth = selectedMonth;
                                        appliedEmployeeId = selectedEmployeeId;
                                        _isLoading = false;
                                      });
                                    },
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(
                                      Icons.search,
                                      color: Colors.white,
                                    ),
                              label: Text(
                                _isLoading ? "LOADING..." : "SHOW",
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 20,
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            // PRINT
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.print),
                              label: const Text("PRINT"),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        "${monthNames[appliedMonth - 1]}-$appliedYear",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ================= DATA AREA =================
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('employees')
                              .orderBy('id')
                              .snapshots(),
                          builder: (context, employeeSnapshot) {
                            if (employeeSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      "Loading employee data...",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF000080),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (employeeSnapshot.hasError) {
                              return Center(
                                child: Text(
                                  "Employee Error: "
                                  "${employeeSnapshot.error}",
                                ),
                              );
                            }

                            final allEmployees =
                                employeeSnapshot.data?.docs ?? [];

                            final visibleEmployees = appliedEmployeeId == 'ALL'
                                ? allEmployees
                                : allEmployees.where((doc) {
                                    final data = doc.data();

                                    return data['id']?.toString() ==
                                        appliedEmployeeId;
                                  }).toList();

                            return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('attendance')
                                  .snapshots(),
                              builder: (context, attendanceSnapshot) {
                                if (attendanceSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text(
                                          "Loading attendance report...",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF000080),
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          "Please wait while attendance data is being prepared.",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                if (attendanceSnapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      "Attendance Error: "
                                      "${attendanceSnapshot.error}",
                                    ),
                                  );
                                }

                                if (visibleEmployees.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      "No Employee Found",
                                    ),
                                  );
                                }

                                final attendanceDocs =
                                    attendanceSnapshot.data?.docs ?? [];

                                final List<Map<String, dynamic>>
                                    employeeReports = [];

                                int allPresent = 0;
                                int allAbsent = 0;
                                int allHoliday = 0;

                                int allActualMinutes = 0;
                                int allAccountedMinutes = 0;

                                // ============ BUILD DATA ============
                                for (final employeeDoc in visibleEmployees) {
                                  final employeeData = employeeDoc.data();

                                  final String employeeId =
                                      employeeData['id']?.toString() ??
                                          employeeDoc.id;

                                  final String employeeName =
                                      employeeData['name']?.toString() ?? '';

                                  final int totalDays = DateTime(
                                    appliedYear,
                                    appliedMonth + 1,
                                    0,
                                  ).day;

                                  final List<Map<String, dynamic>> monthRows =
                                      [];

                                  int presentCount = 0;
                                  int absentCount = 0;
                                  int holidayCount = 0;

                                  int employeeActualMinutes = 0;
                                  int employeeAccountedMinutes = 0;

                                  for (int day = 1; day <= totalDays; day++) {
                                    final DateTime currentDate = DateTime(
                                      appliedYear,
                                      appliedMonth,
                                      day,
                                    );

                                    Map<String, dynamic>? attendanceData;

                                    for (final attendanceDoc
                                        in attendanceDocs) {
                                      final data = attendanceDoc.data();

                                      if (data['employeeId']?.toString() !=
                                          employeeId) {
                                        continue;
                                      }

                                      final Timestamp? inTimestamp =
                                          data['inTime'] as Timestamp?;

                                      final Timestamp? outTimestamp =
                                          data['outTime'] as Timestamp?;

                                      DateTime? attendanceDate;

                                      if (inTimestamp != null) {
                                        attendanceDate = inTimestamp.toDate();
                                      } else if (outTimestamp != null) {
                                        attendanceDate = outTimestamp.toDate();
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
                                        currentDate.weekday == DateTime.sunday;

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
                                          attendanceData['inTime']
                                              as Timestamp?;

                                      final Timestamp? outTimestamp =
                                          attendanceData['outTime']
                                              as Timestamp?;

                                      if (inTimestamp != null) {
                                        inTime = DateFormat(
                                          'hh:mm a',
                                        ).format(
                                          inTimestamp.toDate(),
                                        );
                                      }

                                      if (outTimestamp != null) {
                                        outTime = DateFormat(
                                          'hh:mm a',
                                        ).format(
                                          outTimestamp.toDate(),
                                        );
                                      }

                                      // COMPANY RULE CALCULATION
                                      final calculatedHours =
                                          _calculateAttendanceHours(
                                        currentDate,
                                        inTimestamp,
                                        outTimestamp,
                                      );

                                      actualHours =
                                          calculatedHours['actual'] ?? "0";

                                      accountedHours =
                                          calculatedHours['accounted'] ?? "0";

                                      type =
                                          attendanceData['type']?.toString() ??
                                              "Auto";

                                      remarks = attendanceData['remarks']
                                              ?.toString() ??
                                          "";

                                      if (inTimestamp != null &&
                                          outTimestamp != null) {
                                        status = "Present";
                                      }
                                    }

                                    if (status == "Present") {
                                      presentCount++;
                                    } else if (status == "Holiday") {
                                      holidayCount++;
                                    } else {
                                      absentCount++;
                                    }

                                    employeeActualMinutes += _hoursToMinutes(
                                      actualHours,
                                    );

                                    employeeAccountedMinutes += _hoursToMinutes(
                                      accountedHours,
                                    );

                                    monthRows.add({
                                      'date': currentDate,
                                      'inTime': inTime,
                                      'outTime': outTime,
                                      'actualHours': actualHours,
                                      'accountedHours': accountedHours,
                                      'status': status,
                                      'type': type,
                                      'remarks': remarks,
                                    });
                                  }

                                  allPresent += presentCount;
                                  allAbsent += absentCount;
                                  allHoliday += holidayCount;

                                  allActualMinutes += employeeActualMinutes;

                                  allAccountedMinutes +=
                                      employeeAccountedMinutes;

                                  employeeReports.add({
                                    'employeeId': employeeId,
                                    'employeeName': employeeName,
                                    'presentCount': presentCount,
                                    'absentCount': absentCount,
                                    'holidayCount': holidayCount,
                                    'actualMinutes': employeeActualMinutes,
                                    'accountedMinutes':
                                        employeeAccountedMinutes,
                                    'monthRows': monthRows,
                                  });
                                }

                                // ============ TABLE BUILDER ============
                                Widget buildAttendanceTable(
                                  List<Map<String, dynamic>> monthRows,
                                ) {
                                  return Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minWidth: constraints.maxWidth,
                                            ),
                                            child: DataTable(
                                              headingRowHeight: 42,
                                              dataRowMinHeight: 38,
                                              dataRowMaxHeight: 38,
                                              horizontalMargin: 10,
                                              columnSpacing: 22,
                                              dividerThickness: 0.7,
                                              headingRowColor:
                                                  const WidgetStatePropertyAll(
                                                Color(0xFFF3F4F6),
                                              ),
                                              border: TableBorder.all(
                                                color: const Color(
                                                  0xFFE0E0E0,
                                                ),
                                                width: 0.7,
                                              ),
                                              columns: const [
                                                DataColumn(
                                                  label: Text("Date"),
                                                ),
                                                DataColumn(
                                                  label: Text("Day"),
                                                ),
                                                DataColumn(
                                                  label: Text(
                                                    "In Time",
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: Text(
                                                    "Out Time",
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: Text(
                                                    "Actual Hours",
                                                  ),
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
                                              rows: monthRows.map((row) {
                                                final DateTime date =
                                                    row['date'];

                                                final String status =
                                                    row['status'];

                                                Color rowColor = const Color(
                                                  0xFFF8DEDE,
                                                );

                                                if (status == "Holiday") {
                                                  rowColor = const Color(
                                                    0xFFE0F2D8,
                                                  );
                                                } else if (status ==
                                                    "Present") {
                                                  rowColor = Colors.white;
                                                }

                                                return DataRow(
                                                  color: WidgetStatePropertyAll(
                                                    rowColor,
                                                  ),
                                                  cells: [
                                                    DataCell(
                                                      Text(
                                                        DateFormat(
                                                          'dd/MM/yyyy',
                                                        ).format(
                                                          date,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        DateFormat(
                                                          'EEEE',
                                                        )
                                                            .format(
                                                              date,
                                                            )
                                                            .toUpperCase(),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        row['inTime'],
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        row['outTime'],
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        row['actualHours'],
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        row['accountedHours'],
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(status),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        row['type'],
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        row['remarks'],
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }

                                // ============ EMPLOYEE HEADER ============
                                Widget buildEmployeeHeader(
                                  Map<String, dynamic> report,
                                ) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.black12,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "Employee ID: "
                                                "${report['employeeId']}",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                "Name: "
                                                "${report['employeeName']}",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 15),
                                        Wrap(
                                          spacing: 30,
                                          runSpacing: 10,
                                          children: [
                                            Text(
                                              "Present: "
                                              "${report['presentCount']}",
                                            ),
                                            Text(
                                              "Absent: "
                                              "${report['absentCount']}",
                                            ),
                                            Text(
                                              "Holiday: "
                                              "${report['holidayCount']}",
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                // ==========================================
                                // ALL EMPLOYEES SELECTED
                                // SUMMARY FREEZE - CONTENT SCROLL
                                // ==========================================
                                if (appliedEmployeeId == 'ALL') {
                                  return Column(
                                    children: [
                                      // FIXED SUMMARY
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.black12,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: Wrap(
                                          spacing: 40,
                                          runSpacing: 15,
                                          children: [
                                            Text(
                                              "Total Employees: "
                                              "${visibleEmployees.length}",
                                            ),
                                            Text(
                                              "Present: $allPresent",
                                            ),
                                            Text(
                                              "Absent: $allAbsent",
                                            ),
                                            const Text(
                                              "Late: 0",
                                            ),
                                            const Text(
                                              "Leave: 0",
                                            ),
                                            Text(
                                              "Holiday: $allHoliday",
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // ONLY THIS PART SCROLLS
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Column(
                                            children: [
                                              ...employeeReports.map(
                                                (report) {
                                                  final monthRows = report[
                                                          'monthRows']
                                                      as List<
                                                          Map<String, dynamic>>;

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      bottom: 30,
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        buildEmployeeHeader(
                                                          report,
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        buildAttendanceTable(
                                                          monthRows,
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        _buildWorkingHoursBox(
                                                          actualMinutes: report[
                                                                  'actualMinutes']
                                                              as int,
                                                          accountedMinutes:
                                                              report['accountedMinutes']
                                                                  as int,
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                // ==========================================
                                // SINGLE EMPLOYEE SELECTED
                                // EMPLOYEE INFO FREEZE - TABLE SCROLL
                                // ==========================================
                                final Map<String, dynamic> report =
                                    employeeReports.first;

                                final monthRows = report['monthRows']
                                    as List<Map<String, dynamic>>;

                                return Column(
                                  children: [
                                    // FIXED EMPLOYEE INFO
                                    buildEmployeeHeader(report),

                                    const SizedBox(height: 12),

                                    // ONLY TABLE + TOTAL SCROLL
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            buildAttendanceTable(
                                              monthRows,
                                            ),
                                            _buildWorkingHoursBox(
                                              actualMinutes:
                                                  report['actualMinutes'],
                                              accountedMinutes:
                                                  report['accountedMinutes'],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: () {},
        icon: Icon(
          icon,
          size: 16,
          color: Colors.white,
        ),
        label: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Map<String, String> _calculateAttendanceHours(
    DateTime currentDate,
    Timestamp? inTimestamp,
    Timestamp? outTimestamp,
  ) {
    String actual = "0";
    String accounted = "0";

    if (inTimestamp == null || outTimestamp == null) {
      return {
        'actual': actual,
        'accounted': accounted,
      };
    }

    final DateTime inDateTime = inTimestamp.toDate();
    final DateTime outDateTime = outTimestamp.toDate();

    final int inMinutes = (inDateTime.hour * 60) + inDateTime.minute;

    int outMinutes = (outDateTime.hour * 60) + outDateTime.minute;

    // Midnight-এর পরে scan হলে previous day's out হিসেবে ধরা
    if (outDateTime.hour == 0) {
      outMinutes += 24 * 60;
    }

    final bool validIn = inMinutes <= (7 * 60 + 59);

    if (!validIn) {
      return {
        'actual': actual,
        'accounted': accounted,
      };
    }

    // MONDAY - THURSDAY
    if (currentDate.weekday >= DateTime.monday &&
        currentDate.weekday <= DateTime.thursday) {
      if (outMinutes >= (11 * 60 + 50) && outMinutes < (17 * 60 + 15)) {
        actual = "04.00";
        accounted = "04.00";
      } else if (outMinutes >= (17 * 60 + 15) && outMinutes < (18 * 60 + 45)) {
        actual = "08.00";
        accounted = "08.00";
      } else if (outMinutes >= (18 * 60 + 45) && outMinutes < (21 * 60 + 15)) {
        actual = "09.30";
        accounted = "10.30";
      } else if (outMinutes >= (21 * 60 + 15) && outMinutes < (23 * 60 + 15)) {
        actual = "11.8";
        accounted = "13.30";
      } else if (outMinutes >= (23 * 60 + 15) && outMinutes <= (24 * 60 + 1)) {
        actual = "14.30";
        accounted = "15.30";
      }
    }

    // FRIDAY
    else if (currentDate.weekday == DateTime.friday) {
      if (outMinutes >= (11 * 60 + 50) && outMinutes < (16 * 60 + 30)) {
        actual = "04.00";
        accounted = "04.00";
      } else if (outMinutes >= (16 * 60 + 30) && outMinutes < (18 * 60 + 30)) {
        actual = "08.00";
        accounted = "08.00";
      } else if (outMinutes >= (18 * 60 + 30) && outMinutes < (21 * 60)) {
        actual = "09.30";
        accounted = "10.30";
      } else if (outMinutes >= (21 * 60) && outMinutes < (23 * 60)) {
        actual = "11.8";
        accounted = "13.30";
      } else if (outMinutes >= (23 * 60) && outMinutes <= (23 * 60 + 46)) {
        actual = "14.30";
        accounted = "15.30";
      }
    }

    // SATURDAY
    else if (currentDate.weekday == DateTime.saturday) {
      if (outMinutes >= (11 * 60 + 50) && outMinutes < (16 * 60 + 30)) {
        actual = "04.00";
        accounted = "04.00";
      } else if (outMinutes >= (17 * 60 + 15) && outMinutes < (18 * 60 + 30)) {
        actual = "08.00";
        accounted = "10.50";
      } else if (outMinutes >= (18 * 60 + 30) && outMinutes < (21 * 60)) {
        actual = "10.30";
        accounted = "13.30";
      } else if (outMinutes >= (21 * 60) && outMinutes < (23 * 60)) {
        actual = "11.8";
        accounted = "15.30";
      }
    }

    // SUNDAY
    else if (currentDate.weekday == DateTime.sunday) {
      if (outMinutes >= (11 * 60 + 50) && outMinutes < (16 * 60 + 30)) {
        actual = "04.00";
        accounted = "04.00";
      } else if (outMinutes >= (17 * 60 + 15) && outMinutes < (18 * 60 + 30)) {
        actual = "08.00";
        accounted = "16.30";
      } else if (outMinutes >= (18 * 60 + 30) && outMinutes < (21 * 60)) {
        actual = "11.8";
        accounted = "18.00";
      } else if (outMinutes >= (21 * 60) && outMinutes < (23 * 60)) {
        actual = "13.8";
        accounted = "22.00";
      }
    }

    return {
      'actual': actual,
      'accounted': accounted,
    };
  }

  int _hoursToMinutes(String value) {
    if (value == "0" || value.isEmpty) return 0;

    final parts = value.split('.');

    final int hours = int.tryParse(parts[0]) ?? 0;

    int minutes = 0;

    if (parts.length > 1) {
      minutes = int.tryParse(parts[1]) ?? 0;
    }

    return (hours * 60) + minutes;
  }

  String _minutesToHours(int totalMinutes) {
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    return '$hours.${minutes.toString().padLeft(2, '0')}';
  }

  Widget _buildWorkingHoursBox({
    required int actualMinutes,
    required int accountedMinutes,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        top: 20,
        bottom: 30,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black12,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.access_time_filled,
                color: Color(0xFF000080),
              ),
              SizedBox(width: 10),
              Text(
                "TOTAL WORKING HOURS",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000080),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Actual Hours: ${_minutesToHours(actualMinutes)}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  "Accounted Hours: ${_minutesToHours(accountedMinutes)}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNonManagerEmployees(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 700,
            height: 600,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "SELECT EMPLOYEE",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000080),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('employees')
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

                        final allEmployees = snapshot.data?.docs ?? [];

                        // 👇 Manager role বাদ দিয়ে সব Employee
                        final employees = allEmployees.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          final role =
                              data['role']?.toString().toLowerCase() ?? '';

                          return role != 'manager';
                        }).toList();

                        if (employees.isEmpty) {
                          return const Center(
                            child: Text(
                              "No employee found.",
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: employees.length,
                          itemBuilder: (context, index) {
                            final data =
                                employees[index].data() as Map<String, dynamic>;

                            final name = data['name']?.toString() ?? '';

                            final id = data['id']?.toString() ?? '';

                            final designation =
                                data['designation']?.toString() ?? '';

                            final role = data['role']?.toString() ?? '';

                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "ID: $id | $designation\n"
                                  "Role: ${role.toUpperCase()}",
                                ),
                                trailing: const Icon(
                                  Icons.add_circle_outline,
                                  color: Color(0xFF000080),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


