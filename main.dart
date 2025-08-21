
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SellCardApp());
}

const kPrimary = Color(0xFF0A3D62);

class SellCardApp extends StatelessWidget {
  const SellCardApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sell Card',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasData) return const Dashboard();
        return const PhoneLogin();
      },
    );
  }
}

class PhoneLogin extends StatefulWidget {
  const PhoneLogin({super.key});
  @override
  State<PhoneLogin> createState() => _PhoneLoginState();
}

class _PhoneLoginState extends State<PhoneLogin> {
  final phone = TextEditingController();
  final code = TextEditingController();
  String? verificationId;
  bool codeSent = false;
  bool loading = false;

  Future<void> sendCode() async {
    setState(() => loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone.text.trim(),
      verificationCompleted: (cred) async {
        try { await FirebaseAuth.instance.signInWithCredential(cred); } catch (_) {}
      },
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Verification failed')));
      },
      codeSent: (id, _) {
        setState(() { verificationId = id; codeSent = true; });
      },
      codeAutoRetrievalTimeout: (id) { verificationId = id; },
    );
    setState(() => loading = false);
  }

  Future<void> verify() async {
    if (verificationId == null) return;
    setState(() => loading = true);
    try {
      final cred = PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: code.text.trim());
      await FirebaseAuth.instance.signInWithCredential(cred);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid code')));
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Icon(Icons.credit_card, size: 64, color: kPrimary),
                const SizedBox(height: 12),
                Text('Sell Card', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: kPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Phone number (e.g. +2348012345678)',
                  ),
                ),
                const SizedBox(height: 12),
                if (codeSent)
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'OTP code',
                    ),
                  ),
                const SizedBox(height: 16),
                loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: codeSent ? verify : sendCode,
                      child: Text(codeSent ? 'Verify' : 'Send OTP'),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const UploadCard(), const MyCards(), const Profile()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Card'),
        actions: [
          IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_box_outlined), label: 'Upload'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'My Cards'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class UploadCard extends StatefulWidget {
  const UploadCard({super.key});
  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  final formKey = GlobalKey<FormState>();
  final brand = TextEditingController();
  final value = TextEditingController();
  XFile? photo;
  bool loading = false;

  Future<void> pickPhoto() async {
    final picker = ImagePicker();
    photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    setState(() {});
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate() || photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields and add a photo')));
      return;
    }
    setState(() => loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final file = File(photo!.path);
      final path = 'cards/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('cards').add({
        'userId': uid,
        'brand': brand.text.trim(),
        'cardValue': double.tryParse(value.text.trim()) ?? 0,
        'photo': url,
        'status': 'pending_review',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted. Status: Pending review')));
        brand.clear(); value.clear(); photo = null; setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: ListView(
          children: [
            Text('Upload Gift Card', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: kPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextFormField(
              controller: brand,
              decoration: const InputDecoration(labelText: 'Brand (e.g. Amazon)', border: OutlineInputBorder()),
              validator: (v)=> (v==null || v.trim().isEmpty) ? 'Enter brand' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: value,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Card Value (e.g. 100)', border: OutlineInputBorder()),
                      validator: (v)=> (v==null || v.trim().isEmpty) ? 'Enter value' : null,
                    ),
                    const SizedBox(height: 12),
                    photo == null
                      ? OutlinedButton.icon(onPressed: pickPhoto, icon: const Icon(Icons.camera_alt), label: const Text('Add Card Photo'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Photo added:'),
                            const SizedBox(height: 8),
                            Image.file(File(photo!.path), height: 180),
                            TextButton.icon(onPressed: pickPhoto, icon: const Icon(Icons.refresh), label: const Text('Retake')),
                          ],
                        ),
                    const SizedBox(height: 16),
                    loading ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(onPressed: submit, child: const Text('Submit for Review')),
                  ],
                ),
              ),
            );
  }
}

class MyCards extends StatelessWidget {
  const MyCards({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final q = FirebaseFirestore.instance.collection('cards')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No cards yet.'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final status = (d['status'] ?? 'pending_review') as String;
            return Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.credit_card),
                title: Text('${d['brand']} - ${d['cardValue']}'),
                subtitle: Text('Status: ${status.replaceAll("_"," ")}'),
              ),
            );
          },
        );
      },
    );
  }
}

class Profile extends StatelessWidget {
  const Profile({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: kPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('UID: ${user?.uid ?? ""}'),
          const SizedBox(height: 8),
          Text('Phone: ${user?.phoneNumber ?? ""}'),
          const Spacer(),
          ElevatedButton.icon(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
        ],
      ),
    );
  }
}
