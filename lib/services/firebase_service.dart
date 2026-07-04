import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import '../models/ad_model.dart';
import '../models/feed_item.dart';
import '../models/user_model.dart';
import '../screens/admin_screen.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ─── Device restriction ───────────────────────────────────────────────────

  Future<String> getDeviceId() async {
    if (kIsWeb) return 'unknown';
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.id;
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.identifierForVendor ?? 'unknown';
      }
    } catch (_) {}
    return 'unknown';
  }

  Future<bool> isDeviceBlockedForUser(String userId) async {
    // الأدمن يتجاوز حد الجهاز دائماً
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email == kAdminEmail || kAdminUids.contains(currentUser?.uid)) {
      return false;
    }
    final deviceId = await getDeviceId();
    if (deviceId == 'unknown') return false;
    final doc = await _db.collection('devices').doc(deviceId).get();
    if (!doc.exists) return false;
    final registered = doc.data()?['userId'] as String?;
    if (registered == null) return false;
    // إذا الجهاز كان مسجلاً بحساب أدمن → احذفه واسمح
    if (kAdminUids.contains(registered)) {
      try { await _db.collection('devices').doc(deviceId).delete(); } catch (_) {}
      return false;
    }
    return registered != userId;
  }

  Future<void> registerDevice(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final deviceId = await getDeviceId();
    if (deviceId == 'unknown') return;

    // جهاز الأدمن لا يُسجَّل حتى لا يحجب حسابات أخرى على نفس الجهاز
    if (currentUser?.email == kAdminEmail || kAdminUids.contains(currentUser?.uid)) {
      try { await _db.collection('devices').doc(deviceId).delete(); } catch (_) {}
      return;
    }

    final doc = await _db.collection('devices').doc(deviceId).get();
    if (!doc.exists) {
      await _db.collection('devices').doc(deviceId).set({
        'userId': userId,
        'registeredAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─── User CRUD ────────────────────────────────────────────────────────────

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(uid, doc.data()!);
  }

  Future<void> saveUser(UserModel user) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(user.uid),
      {...user.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    // index username → uid for fast lookup
    if (user.username.isNotEmpty) {
      batch.set(
        _db.collection('usernames').doc(user.username.toLowerCase()),
        {'uid': user.uid, 'username': user.username},
      );
    }
    await batch.commit();
  }

  // returns null if username is taken (by someone else)
  Future<bool> isUsernameTaken(String username, String myUid) async {
    final doc = await _db
        .collection('usernames')
        .doc(username.toLowerCase())
        .get();
    if (!doc.exists) return false;
    return doc.data()?['uid'] != myUid;
  }

  Future<UserModel?> searchByUsername(String username) async {
    final doc = await _db
        .collection('usernames')
        .doc(username.toLowerCase())
        .get();
    if (!doc.exists) return null;
    final uid = doc.data()?['uid'] as String?;
    if (uid == null) return null;
    return getUser(uid);
  }

  Future<String> uploadPhoto(String uid, XFile file, int index) async {
    final ref = _storage.ref('users/$uid/photo_$index.jpg');
    final bytes = await file.readAsBytes();
    final task = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await task.ref.getDownloadURL();
  }

  Future<void> deletePhoto(String uid, int index) async {
    try {
      await _storage.ref('users/$uid/photo_$index.jpg').delete();
    } catch (_) {}
  }

  // ─── Ad CRUD ──────────────────────────────────────────────────────────────

  Future<AdModel?> getAd(String uid) async {
    final doc = await _db.collection('ads').doc(uid).get();
    if (!doc.exists) return null;
    return AdModel.fromMap(uid, doc.data()!);
  }

  Future<void> saveAd(AdModel ad) async {
    await _db.collection('ads').doc(ad.uid).set(
      {...ad.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<String> uploadAdPhoto(String uid, XFile file, int index) async {
    final ref = _storage.ref('ads/$uid/photo_$index.jpg');
    final bytes = await file.readAsBytes();
    final task = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await task.ref.getDownloadURL();
  }

  Future<void> deleteAdPhoto(String uid, int index) async {
    try {
      await _storage.ref('ads/$uid/photo_$index.jpg').delete();
    } catch (_) {}
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  Stream<List<UserModel>> publishedUsersStream() {
    return _db
        .collection('users')
        .where('published', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final users = snap.docs
          .map((d) => UserModel.fromMap(d.id, d.data()))
          .where((u) => !u.blocked)
          .toList();
      users.sort((a, b) {
        final aTime =
            snap.docs.firstWhere((d) => d.id == a.uid).data()['updatedAt'];
        final bTime =
            snap.docs.firstWhere((d) => d.id == b.uid).data()['updatedAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return (bTime as Timestamp).compareTo(aTime as Timestamp);
      });
      return users;
    });
  }

  Stream<List<AdModel>> adsStream() {
    return _db
        .collection('ads')
        .where('published', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final ads =
          snap.docs.map((d) => AdModel.fromMap(d.id, d.data())).toList();
      ads.sort((a, b) {
        final aTime =
            snap.docs.firstWhere((d) => d.id == a.uid).data()['updatedAt'];
        final bTime =
            snap.docs.firstWhere((d) => d.id == b.uid).data()['updatedAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return (bTime as Timestamp).compareTo(aTime as Timestamp);
      });
      return ads;
    });
  }

  /// Combined feed: ads take priority. Users with ads hide their profile.
  Stream<List<FeedItem>> combinedFeedStream() {
    final ctrl = StreamController<List<FeedItem>>.broadcast();

    List<UserModel> latestProfiles = [];
    List<AdModel> latestAds = [];

    void emit() {
      final adUids = latestAds.map((a) => a.uid).toSet();
      final profileItems = latestProfiles
          .where((u) => !adUids.contains(u.uid))
          .map((u) => FeedItem.fromProfile(u))
          .toList();
      final adItems = latestAds.map((a) => FeedItem.fromAd(a)).toList();
      ctrl.add([...adItems, ...profileItems]);
    }

    StreamSubscription<List<UserModel>>? profSub;
    StreamSubscription<List<AdModel>>? adSub;

    profSub = publishedUsersStream().listen(
      (profiles) {
        latestProfiles = profiles;
        emit();
      },
      onError: ctrl.addError,
    );

    adSub = adsStream().listen(
      (ads) {
        latestAds = ads;
        emit();
      },
      onError: ctrl.addError,
    );

    ctrl.onCancel = () {
      profSub?.cancel();
      adSub?.cancel();
    };

    return ctrl.stream;
  }
}
