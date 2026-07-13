import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background handler top-level fonksiyon olmalı
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage _) async {}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static const _channelId = 'kt_main';
  static const _channelName = 'Kolay Tarifler';

  // Widget'lar bu stream'i dinleyerek bildirimlere tepki verir
  static final _routeCtrl = StreamController<String>.broadcast();
  static Stream<String> get routeStream => _routeCtrl.stream;

  // Uygulama kapalıyken tıklanmışsa rota burada bekler
  static String? pendingRoute;

  // Her saveToken çağrısında önceki listener cancel edilir — memory leak önlenir
  static StreamSubscription<String>? _tokenRefreshSub;

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // İzin iste
    // iOS ön plan bildirim gösterimi
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Yerel bildirim init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (r) =>
          _emit(_routeFromPayload(r.payload)),
    );

    // Android 8+ bildirim kanalı
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              importance: Importance.high,
            ),
          );
    }

    // Uygulama açıkken gelen FCM → yerel bildirim olarak göster
    FirebaseMessaging.onMessage.listen(_showLocal);

    // Arka planda bildirime tıklandı
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _emit(_routeFromData(m.data)),
    );

    // Uygulama kapalıyken bildirime tıklanmış → rota beklesin
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      pendingRoute = _routeFromData(initial.data);
    }
  }

  // Giriş yaptıktan sonra çağır
  /// Requests permission only after an explicit user action.
  static Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> saveToken(String userId) async {
    await _tokenRefreshSub?.cancel();
    final token = await _fcm.getToken();
    if (token == null) return;
    await _upsert(userId, token);
    _tokenRefreshSub = _fcm.onTokenRefresh.listen((t) => _upsert(userId, t));
  }

  // Çıkış yaparken çağır
  static Future<void> clearToken(String userId) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (_) {}
    await _fcm.deleteToken();
  }

  // ── Dahili ──────────────────────────────────────────────────────────────────

  static Future<void> _upsert(String userId, String token) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(userId)
      .set({'fcmToken': token}, SetOptions(merge: true));

  static void _showLocal(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _payloadFromData(message.data),
    );
  }

  static String? _payloadFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = (data['recipeId'] ?? data['id']) as String?;
    if (type == null) return null;
    return id != null ? '$type:$id' : type;
  }

  static String? _routeFromPayload(String? payload) {
    if (payload == null) return null;
    final parts = payload.split(':');
    return _toRoute(parts[0], parts.length > 1 ? parts[1] : null);
  }

  static String? _routeFromData(Map<String, dynamic> data) =>
      _routeFromPayload(_payloadFromData(data));

  static String? _toRoute(String type, String? id) => switch (type) {
    'recipe_liked' when id != null => '/recipe/$id',
    'comment' when id != null => '/recipe/$id',
    'pending_recipe' => '/my-submissions',
    _ => null,
  };

  static void _emit(String? route) {
    if (route != null) _routeCtrl.add(route);
  }
}
