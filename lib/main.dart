
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final context = navigatorKey.currentState?.context;
    if (context != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(message.notification?.title ?? "تنبيه"),
          content: Text(message.notification?.body ?? "وصل إشعار جديد"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("حسناً"),
            ),
          ],
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final url = message.data['url'];
    if (url != null && navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(MaterialPageRoute(
        builder: (_) => WebViewScreen(initialUrl: url),
      ));
    }
  });

  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  runApp(MyApp(initialUrl: initialMessage?.data['url']));
}

void saveTokenToFirestore(String? token) async {
  if (token == null) return;
  final firestore = FirebaseFirestore.instance;
  await firestore.collection("fcm_tokens").doc(token).set({
    "token": token,
    "timestamp": FieldValue.serverTimestamp(),
    "platform": "android",
  });
}

class MyApp extends StatelessWidget {
  final String? initialUrl;
  const MyApp({super.key, this.initialUrl});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(initialUrl: initialUrl),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final String? initialUrl;
  const SplashScreen({super.key, this.initialUrl});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showWebView = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      setState(() {
        _showWebView = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showWebView
        ? WebViewScreen(initialUrl: widget.initialUrl)
        : const Scaffold(
      backgroundColor: Color(0xFFA36D68),
      body: Center(
        child: Image(
          image: AssetImage('assets/images/splash_logo.webp'),
          width: 200,
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String? initialUrl;
  const WebViewScreen({super.key, this.initialUrl});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          bool canGoBackNow = await _controller.canGoBack();
          setState(() {
            _canGoBack = canGoBackNow;
          });
        },
      ))
      ..loadRequest(Uri.parse(widget.initialUrl ?? 'https://sienna-snake-887391.hostingersite.com/'));

    FirebaseMessaging.instance.getToken().then((token) {
      saveTokenToFirestore(token);
      FirebaseMessaging.instance.subscribeToTopic("all");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA36D68),
        title: Text(
          "حياكم الله نورتونا في دار البنات",
          style: GoogleFonts.cairo(
            textStyle: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            if (await _controller.canGoBack()) {
              _controller.goBack();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
