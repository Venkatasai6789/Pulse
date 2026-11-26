import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../core/phi.dart';
import '../core/soil_reading.dart';
import '../models/models.dart';
import 'api_service.dart';

/// Set to true if upgrading to Firebase Blaze plan for Cloud Storage uploads.
/// Full photos will be uploaded to users/{uid}/assessments/{id}/{photoId}.jpg.
/// When false (Spark plan), full photos stay local and compressed thumbnails
/// are stored in the Firestore sub-collection assessments/{id}/photos.
const bool kUseCloudStorage = false;

enum SyncStatus { syncing, saved, offline }

class FirestoreApiService implements ApiService {
  FirestoreApiService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _rawFirestore = firestore,
        _rawAuth = auth {
    _initPersistenceAndSync();
  }

  final FirebaseFirestore? _rawFirestore;
  final FirebaseAuth? _rawAuth;

  FirebaseFirestore get _firestore => _rawFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _rawAuth ?? FirebaseAuth.instance;

  /// Global notifier for sync status (offline persistence / syncing / saved)
  final ValueNotifier<SyncStatus> syncStatus = ValueNotifier<SyncStatus>(SyncStatus.saved);

  void _initPersistenceAndSync() {
    try {
      if (_rawFirestore != null) {
        _firestore.snapshotsInSync().listen((_) {
          if (syncStatus.value == SyncStatus.syncing) {
            syncStatus.value = SyncStatus.saved;
          }
        });
      }
    } catch (e) {
      debugPrint('[firestore] Error initializing snapshots sync listener: $e');
    }
  }

  void _setSyncing() {
    syncStatus.value = SyncStatus.syncing;
  }

  void _setSaved() {
    syncStatus.value = SyncStatus.saved;
  }

  String get _currentUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw ApiException('You must be signed in to perform this operation');
    }
    return uid;
  }

  // ---------------------------------------------------------------------------
  // Date & Timestamp Helpers
  // ---------------------------------------------------------------------------

  DateTime? _toDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }

  dynamic _fromDateTime(DateTime? dt) {
    if (dt == null) return null;
    return Timestamp.fromDate(dt);
  }

  // ---------------------------------------------------------------------------
  // Photo Compression Helper (Spark plan: 480 px JPEG at quality 60)
  // ---------------------------------------------------------------------------

  Future<Uint8List?> _compressImageToThumbnail(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      final result = await FlutterImageCompress.compressWithFile(
        filePath,
        minWidth: 480,
        minHeight: 480,
        quality: 60,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      debugPrint('[firestore] Error compressing thumbnail for $filePath: $e');
      return null;
    }
  }

  Future<String?> _restorePhotoThumb(String assessmentId, String photoId, String base64Thumb) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final folder = Directory('${appDir.path}/photos/$assessmentId');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final file = File('${folder.path}/$photoId.jpg');
      if (!await file.exists()) {
        final bytes = base64Decode(base64Thumb);
        await file.writeAsBytes(bytes);
      }
      return file.path;
    } catch (e) {
      debugPrint('[firestore] Error restoring thumbnail: $e');
      return null;
    }
  }

  Future<void> _writeAssessmentPhotos(String assessmentId, String uid, Assessment assessment) async {
    final photosCol = _firestore.collection('assessments').doc(assessmentId).collection('photos');

    // 1. Activity photos
    for (int i = 0; i < assessment.activityPhotoPaths.length; i++) {
      final p = assessment.activityPhotoPaths[i];
      final photoId = 'act_$i';
      final thumbBytes = await _compressImageToThumbnail(p);
      if (thumbBytes != null) {
        final b64 = base64Encode(thumbBytes);
        await photosCol.doc(photoId).set({
          'kind': 'activity',
          'thumbB64': b64,
          'width': 480,
          'height': 480,
          'takenAt': FieldValue.serverTimestamp(),
          'storagePath': kUseCloudStorage ? 'users/$uid/assessments/$assessmentId/$photoId.jpg' : null,
        }, SetOptions(merge: true));
      }
    }

    // 2. Risk photos
    for (int i = 0; i < assessment.riskPhotoPaths.length; i++) {
      final p = assessment.riskPhotoPaths[i];
      final photoId = 'risk_$i';
      final thumbBytes = await _compressImageToThumbnail(p);
      if (thumbBytes != null) {
        final b64 = base64Encode(thumbBytes);
        await photosCol.doc(photoId).set({
          'kind': 'risk',
          'thumbB64': b64,
          'width': 480,
          'height': 480,
          'takenAt': FieldValue.serverTimestamp(),
          'storagePath': kUseCloudStorage ? 'users/$uid/assessments/$assessmentId/$photoId.jpg' : null,
        }, SetOptions(merge: true));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  @override
  Future<AppUser?> currentUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return AppUser(
          id: fbUser.uid,
          name: (data['name'] as String?)?.isNotEmpty == true
              ? data['name'] as String
              : (fbUser.displayName ?? fbUser.email?.split('@').first ?? 'User'),
          email: data['email'] as String? ?? fbUser.email ?? '',
          organisation: data['organisation'] as String?,
          photoUrl: data['photoUrl'] as String? ?? fbUser.photoURL,
        );
      }
    } catch (e) {
      debugPrint('[firestore] Error loading user profile doc: $e');
    }

    return AppUser(
      id: fbUser.uid,
      name: fbUser.displayName ?? fbUser.email?.split('@').first ?? 'User',
      email: fbUser.email ?? '',
      photoUrl: fbUser.photoURL,
    );
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    String? organisation,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(name.trim());

      final appUser = AppUser(
        id: user.uid,
        name: name.trim(),
        email: user.email ?? email,
        organisation: organisation?.trim(),
        photoUrl: user.photoURL,
      );

      _setSyncing();
      await _firestore.collection('users').doc(user.uid).set({
        'name': appUser.name,
        'email': appUser.email,
        'photoUrl': appUser.photoUrl,
        'organisation': appUser.organisation,
        'orgType': appUser.organisation != null ? 'Partner' : 'Individual',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _setSaved();

      return appUser;
    } on FirebaseAuthException catch (e) {
      _setSaved();
      if (e.code == 'email-already-in-use') {
        throw ApiException('An account with this email already exists');
      }
      throw ApiException(e.message ?? 'Registration failed');
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to sign up: $e');
    }
  }

  @override
  Future<AppUser> login({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = cred.user!;
      final profile = await currentUser();
      return profile ??
          AppUser(
            id: user.uid,
            name: user.displayName ?? 'User',
            email: user.email ?? email,
          );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw ApiException('Incorrect email or password');
      }
      throw ApiException(e.message ?? 'Login failed');
    } catch (e) {
      throw ApiException('Failed to login: $e');
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<AppUser> updateProfile(AppUser user) async {
    _setSyncing();
    try {
      await _firestore.collection('users').doc(user.id).set({
        'name': user.name,
        'email': user.email,
        'photoUrl': user.photoUrl,
        'organisation': user.organisation,
        'orgType': user.organisation != null ? 'Partner' : 'Individual',
      }, SetOptions(merge: true));

      if (_auth.currentUser != null && _auth.currentUser!.uid == user.id) {
        await _auth.currentUser!.updateDisplayName(user.name);
      }
      _setSaved();
      return user;
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to update profile: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Locations
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _locationToFirestore(Location loc, String uid, {String? coverThumb}) {
    return {
      'id': loc.id,
      'ownerUid': uid,
      'name': loc.name,
      'type': loc.type,
      'address': loc.address,
      'lat': loc.latitude,
      'lng': loc.longitude,
      'latitude': loc.latitude,
      'longitude': loc.longitude,
      'description': loc.description,
      'photoPaths': loc.photoPaths,
      'managedBy': loc.managedBy.name,
      'organisationName': loc.organisationName,
      'coverThumb': coverThumb,
      'createdAt': _fromDateTime(loc.createdAt) ?? FieldValue.serverTimestamp(),
      if (loc.sensorNodeId != null) 'sensorNodeId': loc.sensorNodeId,
      if (loc.latestPhi != null) 'latestPhi': loc.latestPhi,
      if (loc.latestTier != null) 'latestTier': loc.latestTier,
      if (loc.lastAssessedAt != null) 'lastAssessedAt': _fromDateTime(loc.lastAssessedAt),
    };
  }

  Location _locationFromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Location(
      id: doc.id,
      name: d['name'] as String? ?? '',
      type: d['type'] as String? ?? '',
      address: d['address'] as String? ?? '',
      latitude: (d['lat'] ?? d['latitude'] as num?)?.toDouble(),
      longitude: (d['lng'] ?? d['longitude'] as num?)?.toDouble(),
      description: d['description'] as String?,
      photoPaths: List<String>.from(d['photoPaths'] ?? const []),
      managedBy: ManagedBy.values.where((m) => m.name == d['managedBy']).firstOrNull ?? ManagedBy.me,
      organisationName: d['organisationName'] as String?,
      createdAt: _toDateTime(d['createdAt']) ?? DateTime.now(),
      sensorNodeId: d['sensorNodeId'] as String?,
      latestPhi: (d['latestPhi'] as num?)?.toInt(),
      latestTier: d['latestTier'] as String?,
      lastAssessedAt: _toDateTime(d['lastAssessedAt'] ?? d['latestAssessmentAt']),
    );
  }

  @override
  Future<List<Location>> getLocations() async {
    final uid = _currentUid;
    final snap = await _firestore
        .collection('locations')
        .where('ownerUid', isEqualTo: uid)
        .get();

    final list = snap.docs.map(_locationFromFirestore).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<Location?> getLocation(String id) async {
    final doc = await _firestore.collection('locations').doc(id).get();
    if (!doc.exists) return null;
    final d = doc.data()!;
    if (d['ownerUid'] != _currentUid) return null;
    return _locationFromFirestore(doc);
  }

  @override
  Future<Location> createLocation(Location location) async {
    final uid = _currentUid;
    if (location.name.trim().isEmpty) throw ApiException('Location name is required');
    if (location.address.trim().isEmpty) throw ApiException('Address / area is required');

    final id = location.id.isEmpty ? newId() : location.id;
    final locToSave = Location(
      id: id,
      name: location.name.trim(),
      type: location.type,
      address: location.address.trim(),
      latitude: location.latitude,
      longitude: location.longitude,
      description: location.description,
      photoPaths: location.photoPaths,
      managedBy: location.managedBy,
      organisationName: location.organisationName,
      createdAt: location.createdAt,
    );

    String? coverThumb;
    if (locToSave.photoPaths.isNotEmpty) {
      final bytes = await _compressImageToThumbnail(locToSave.photoPaths.first);
      if (bytes != null) {
        coverThumb = base64Encode(bytes);
      }
    }

    _setSyncing();
    try {
      final map = _locationToFirestore(locToSave, uid, coverThumb: coverThumb);
      await _firestore.collection('locations').doc(id).set(map);
      _setSaved();
      return locToSave;
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to create location: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Assessments
  // ---------------------------------------------------------------------------

  Assessment _withAssessmentId(Assessment a, String id) {
    if (a.id == id && id.isNotEmpty) return a;
    return Assessment(
      id: id,
      locationId: a.locationId,
      status: a.status,
      visits: a.visits,
      observedAt: a.observedAt,
      durationMinutes: a.durationMinutes,
      weather: a.weather,
      activityPhotoPaths: a.activityPhotoPaths,
      flowers: a.flowers,
      nesting: a.nesting,
      shelter: a.shelter,
      water: a.water,
      temperatureC: a.temperatureC,
      humidityPct: a.humidityPct,
      co2Ppm: a.co2Ppm,
      soil: a.soil,
      climateSource: a.climateSource,
      climateDeviceId: a.climateDeviceId,
      climateCapturedAt: a.climateCapturedAt,
      riskIndicators: a.riskIndicators,
      riskLevel: a.riskLevel,
      riskDescription: a.riskDescription,
      riskObservedAt: a.riskObservedAt,
      riskNotes: a.riskNotes,
      riskPhotoPaths: a.riskPhotoPaths,
      result: a.result,
      ai: a.ai,
      actionsTaken: a.actionsTaken,
      createdAt: a.createdAt,
      submittedAt: a.submittedAt,
    );
  }

  Map<String, dynamic> _assessmentToFirestore(Assessment a, String uid, {bool isSubmitting = false}) {
    final activity = {
      'visits': a.visits,
      'observedAt': _fromDateTime(a.observedAt),
      'durationMinutes': a.durationMinutes,
      'weather': a.weather,
    };
    final habitat = {
      'flowers': a.flowers?.name,
      'nesting': a.nesting?.name,
      'shelter': a.shelter?.name,
      'water': a.water?.name,
    };
    final environment = {
      'temperatureC': a.temperatureC,
      'humidityPct': a.humidityPct,
      'co2Ppm': a.co2Ppm,
      if (a.soil != null) 'soil': a.soil!.toJson(),
      if (a.climateSource != null) 'climateSource': a.climateSource,
      if (a.climateDeviceId != null) 'climateDeviceId': a.climateDeviceId,
      if (a.climateCapturedAt != null) 'climateCapturedAt': _fromDateTime(a.climateCapturedAt),
    };
    final risk = {
      'indicators': a.riskIndicators.toJson(),
      'level': a.riskLevel?.name,
      'description': a.riskDescription,
      'observedAt': _fromDateTime(a.riskObservedAt),
      'notes': a.riskNotes,
    };

    final map = <String, dynamic>{
      'id': a.id,
      'ownerUid': uid,
      'locationId': a.locationId,
      'status': a.status.name,
      'scoringVersion': scoringVersion,
      'activity': activity,
      'habitat': habitat,
      'environment': environment,
      'risk': risk,
      // Keep JSON field names from models.dart accessible
      'visits': a.visits,
      'observedAt': _fromDateTime(a.observedAt),
      'durationMinutes': a.durationMinutes,
      'weather': a.weather,
      'flowers': a.flowers?.name,
      'nesting': a.nesting?.name,
      'shelter': a.shelter?.name,
      'water': a.water?.name,
      'temperatureC': a.temperatureC,
      'humidityPct': a.humidityPct,
      'co2Ppm': a.co2Ppm,
      if (a.soil != null) 'soil': a.soil!.toJson(),
      'riskIndicators': a.riskIndicators.toJson(),
      'riskLevel': a.riskLevel?.name,
      'riskDescription': a.riskDescription,
      'riskObservedAt': _fromDateTime(a.riskObservedAt),
      'riskNotes': a.riskNotes,
      'activityPhotoPaths': a.activityPhotoPaths,
      'riskPhotoPaths': a.riskPhotoPaths,
      'createdAt': _fromDateTime(a.createdAt) ?? FieldValue.serverTimestamp(),
    };

    if (a.submittedAt != null) {
      map['submittedAt'] = _fromDateTime(a.submittedAt);
    }
    if (a.result != null) {
      map['result'] = a.result!.toJson();
    }
    if (a.ai != null) {
      map['ai'] = a.ai!.toJson();
    }
    return map;
  }

  Assessment _assessmentFromFirestore(
    DocumentSnapshot doc, {
    List<ActionTaken>? actions,
    List<String>? actPhotos,
    List<String>? riskPhotos,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    final activity = (d['activity'] as Map<String, dynamic>?) ?? {};
    final habitat = (d['habitat'] as Map<String, dynamic>?) ?? {};
    final environment = (d['environment'] as Map<String, dynamic>?) ?? {};
    final risk = (d['risk'] as Map<String, dynamic>?) ?? {};
    final resultData = d['result'] as Map<String, dynamic>?;
    final soilData = environment['soil'] ?? d['soil'];
    final soil = soilData is Map<String, dynamic>
        ? SoilReading.fromJson(soilData)
        : (soilData is Map ? SoilReading.fromJson(Map<String, dynamic>.from(soilData)) : null);

    return Assessment(
      id: doc.id,
      locationId: d['locationId'] as String?,
      status: AssessmentStatus.values.where((s) => s.name == d['status']).firstOrNull ??
          AssessmentStatus.draft,
      visits: (activity['visits'] ?? d['visits'] as num?)?.toInt(),
      observedAt: _toDateTime(activity['observedAt'] ?? d['observedAt']),
      durationMinutes: (activity['durationMinutes'] ?? d['durationMinutes'] as num?)?.toInt() ?? 5,
      weather: (activity['weather'] ?? d['weather']) as String?,
      activityPhotoPaths: actPhotos ?? List<String>.from(d['activityPhotoPaths'] ?? const []),
      flowers: Level.values.where((l) => l.name == (habitat['flowers'] ?? d['flowers'])).firstOrNull,
      nesting: Level.values.where((l) => l.name == (habitat['nesting'] ?? d['nesting'])).firstOrNull,
      shelter: Level.values.where((l) => l.name == (habitat['shelter'] ?? d['shelter'])).firstOrNull,
      water: Water.values.where((w) => w.name == (habitat['water'] ?? d['water'])).firstOrNull,
      temperatureC: (environment['temperatureC'] ?? d['temperatureC'] as num?)?.toDouble(),
      humidityPct: (environment['humidityPct'] ?? d['humidityPct'] as num?)?.toDouble(),
      co2Ppm: (environment['co2Ppm'] ?? d['co2Ppm'] as num?)?.toDouble(),
      soil: soil,
      climateSource: environment['climateSource'] as String?,
      climateDeviceId: environment['climateDeviceId'] as String?,
      climateCapturedAt: _toDateTime(environment['climateCapturedAt']),
      riskIndicators: RiskIndicators.fromJson(
        Map<String, dynamic>.from(risk['indicators'] ?? d['riskIndicators'] ?? {}),
      ),
      riskLevel: RiskLevel.values.where((r) => r.name == (risk['level'] ?? d['riskLevel'])).firstOrNull,
      riskDescription: (risk['description'] ?? d['riskDescription']) as String?,
      riskObservedAt: _toDateTime(risk['observedAt'] ?? d['riskObservedAt']),
      riskNotes: (risk['notes'] ?? d['riskNotes']) as String?,
      riskPhotoPaths: riskPhotos ?? List<String>.from(d['riskPhotoPaths'] ?? const []),
      result: resultData != null ? PhiResult.fromJson(resultData) : null,
      ai: d['ai'] != null ? AiInsight.fromJson(Map<String, dynamic>.from(d['ai'] as Map)) : null,
      actionsTaken: actions ??
          (d['actionsTaken'] as List? ?? const [])
              .map((a) => ActionTaken.fromJson(Map<String, dynamic>.from(a)))
              .toList(),
      createdAt: _toDateTime(d['createdAt']) ?? DateTime.now(),
      submittedAt: _toDateTime(d['submittedAt']),
    );
  }

  @override
  Future<List<Assessment>> getAssessments({String? locationId, bool submittedOnly = true}) async {
    final uid = _currentUid;
    Query query = _firestore.collection('assessments').where('ownerUid', isEqualTo: uid);

    if (locationId != null) {
      query = query.where('locationId', isEqualTo: locationId);
      if (submittedOnly) {
        query = query.where('status', isEqualTo: AssessmentStatus.submitted.name);
        query = query.orderBy('submittedAt', descending: true);
      }
    } else {
      if (submittedOnly) {
        query = query
            .where('status', isEqualTo: AssessmentStatus.submitted.name)
            .orderBy('submittedAt', descending: true);
      } else {
        query = query.orderBy('createdAt', descending: true);
      }
    }

    QuerySnapshot snapshot;
    try {
      snapshot = await query.get();
    } catch (e) {
      debugPrint('[firestore] Query error, falling back to client filter: $e');
      final fallbackQuery = _firestore.collection('assessments').where('ownerUid', isEqualTo: uid);
      snapshot = await fallbackQuery.get();
    }

    final results = <Assessment>[];
    for (final doc in snapshot.docs) {
      final a = _assessmentFromFirestore(doc);
      if (locationId != null && a.locationId != locationId) continue;
      if (submittedOnly && !a.isSubmitted) continue;
      results.add(a);
    }

    results.sort((a, b) => (b.submittedAt ?? b.createdAt).compareTo(a.submittedAt ?? a.createdAt));
    return results;
  }

  @override
  Future<Assessment?> getAssessment(String id) async {
    final doc = await _firestore.collection('assessments').doc(id).get();
    if (!doc.exists) return null;
    final d = doc.data()!;
    if (d['ownerUid'] != _currentUid) return null;

    // Fetch actions subcollection
    final actionsSnap = await _firestore
        .collection('assessments')
        .doc(id)
        .collection('actions')
        .orderBy('createdAt', descending: false)
        .get();

    final actions = actionsSnap.docs.map((aDoc) {
      final aData = aDoc.data();
      return ActionTaken(
        _toDateTime(aData['date']) ?? DateTime.now(),
        aData['note'] as String? ?? '',
      );
    }).toList();

    // Fetch photos subcollection
    final photosSnap = await _firestore
        .collection('assessments')
        .doc(id)
        .collection('photos')
        .get();

    final actPhotos = <String>[];
    final riskPhotos = <String>[];

    final existingAct = List<String>.from(d['activityPhotoPaths'] ?? const []);
    final existingRisk = List<String>.from(d['riskPhotoPaths'] ?? const []);
    for (final p in existingAct) {
      if (File(p).existsSync()) actPhotos.add(p);
    }
    for (final p in existingRisk) {
      if (File(p).existsSync()) riskPhotos.add(p);
    }

    // Restore from base64 thumbnails if not locally available (e.g. on another synced phone)
    for (final pDoc in photosSnap.docs) {
      final pData = pDoc.data();
      final kind = pData['kind'] as String? ?? 'activity';
      final thumbB64 = pData['thumbB64'] as String?;
      if (thumbB64 != null && thumbB64.isNotEmpty) {
        final restoredPath = await _restorePhotoThumb(id, pDoc.id, thumbB64);
        if (restoredPath != null) {
          if (kind == 'activity' && !actPhotos.contains(restoredPath)) {
            actPhotos.add(restoredPath);
          } else if (kind == 'risk' && !riskPhotos.contains(restoredPath)) {
            riskPhotos.add(restoredPath);
          }
        }
      }
    }

    return _assessmentFromFirestore(
      doc,
      actions: actions,
      actPhotos: actPhotos,
      riskPhotos: riskPhotos,
    );
  }

  @override
  Future<Assessment?> latestAssessment(String locationId) async {
    final list = await getAssessments(locationId: locationId, submittedOnly: true);
    if (list.isEmpty) return null;
    return getAssessment(list.first.id);
  }

  @override
  Future<Assessment> saveDraft(Assessment draft) async {
    if (draft.isSubmitted) {
      throw ApiException('Submitted assessments cannot be edited');
    }

    final uid = _currentUid;

    final assessmentId = draft.id.isEmpty ? newId() : draft.id;
    final docRef = _firestore.collection('assessments').doc(assessmentId);

    try {
      final existing = await docRef.get();
      if (existing.exists) {
        final status = existing.data()?['status'];
        if (status == AssessmentStatus.submitted.name) {
          throw ApiException('Submitted assessments cannot be edited');
        }
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && e.code != 'not-found') {
        rethrow;
      }
      debugPrint('[firestore] Notice checking existing assessment in saveDraft: $e');
    } catch (e) {
      if (e is ApiException) rethrow;
    }

    _setSyncing();
    try {
      final draftToSave = _withAssessmentId(draft, assessmentId);
      final data = _assessmentToFirestore(draftToSave, uid);
      await docRef.set(data, SetOptions(merge: true));
      await _writeAssessmentPhotos(assessmentId, uid, draftToSave);
      _setSaved();
      return draftToSave;
    } catch (e) {
      _setSaved();
      if (e is ApiException) rethrow;
      throw ApiException('Failed to save draft: $e');
    }
  }

  @override
  Future<void> deleteDraft(String id) async {
    final uid = _currentUid;
    final docRef = _firestore.collection('assessments').doc(id);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data();
    if (data?['ownerUid'] != uid) {
      throw ApiException('Permission denied');
    }
    if (data?['status'] != AssessmentStatus.draft.name) {
      throw ApiException('Cannot delete a submitted assessment');
    }

    _setSyncing();
    try {
      await docRef.delete();
      _setSaved();
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to delete draft: $e');
    }
  }

  @override
  Future<Assessment> submitAssessment(Assessment draft) async {
    // 1. Validate completeness
    if (!draft.isComplete) {
      throw ApiException('Please complete: ${draft.missingFields.join(', ')}');
    }

    final uid = _currentUid;

    final assessmentId = draft.id.isEmpty ? newId() : draft.id;
    final docRef = _firestore.collection('assessments').doc(assessmentId);

    // 2. Check if already submitted - never overwrite a submitted assessment
    try {
      final existing = await docRef.get();
      if (existing.exists) {
        final status = existing.data()?['status'];
        if (status == AssessmentStatus.submitted.name) {
          throw ApiException('Submitted assessments cannot be edited');
        }
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && e.code != 'not-found') {
        rethrow;
      }
      debugPrint('[firestore] Notice checking existing assessment in saveDraft: $e');
    } catch (e) {
      if (e is ApiException) rethrow;
    }

    _setSyncing();
    try {
      // 3. Calculate PHI
      final result = calculatePhi(draft.toInputs());
      final now = DateTime.now();

      final submitted = _withAssessmentId(draft, assessmentId).copyWith(
        status: AssessmentStatus.submitted,
        result: result,
        submittedAt: now,
      );

      // 4. One atomic WriteBatch: assessment + location latest fields
      final batch = _firestore.batch();
      final assessmentData = _assessmentToFirestore(submitted, uid, isSubmitting: true);
      assessmentData['submittedAt'] = FieldValue.serverTimestamp();
      batch.set(docRef, assessmentData);

      if (draft.locationId != null && draft.locationId!.isNotEmpty) {
        final locRef = _firestore.collection('locations').doc(draft.locationId!);
        try {
          final locSnap = await locRef.get();
          if (locSnap.exists) {
            batch.set(locRef, {
              'latestPhi': result.phi,
              'latestTier': result.tier.name,
              'latestAssessmentAt': FieldValue.serverTimestamp(),
              'lastAssessedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } else {
            // Seeded or mock location ID (e.g. loc-garden) not yet in Firestore:
            // Ensure ownerUid and name exist so create rule passes!
            batch.set(locRef, {
              'id': draft.locationId,
              'ownerUid': uid,
              'name': 'Community Garden',
              'type': 'Community garden',
              'address': 'Chennai',
              'latestPhi': result.phi,
              'latestTier': result.tier.name,
              'latestAssessmentAt': FieldValue.serverTimestamp(),
              'lastAssessedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint('[firestore] Notice checking location doc: $e');
        }
      }

      try {
        await batch.commit();
      } catch (batchErr) {
        debugPrint('[firestore] Batch commit failed ($batchErr), attempting direct assessment save...');
        await docRef.set(assessmentData);
      }

      // 5. Store compressed thumbnails in sub-collection
      try {
        await _writeAssessmentPhotos(assessmentId, uid, submitted);
      } catch (photoErr) {
        debugPrint('[firestore] Notice writing photo thumbnails: $photoErr');
      }

      _setSaved();
      return submitted;
    } catch (e) {
      _setSaved();
      if (e is ApiException) rethrow;
      throw ApiException('Failed to submit assessment: $e');
    }
  }

  @override
  Future<Assessment> addActionTaken(String assessmentId, ActionTaken action) async {
    final uid = _currentUid;
    final assessmentDocRef = _firestore.collection('assessments').doc(assessmentId);
    final doc = await assessmentDocRef.get();
    if (!doc.exists) throw ApiException('Assessment not found');
    if (doc.data()?['ownerUid'] != uid) throw ApiException('Permission denied');

    _setSyncing();
    try {
      final actionId = newId();
      await assessmentDocRef.collection('actions').doc(actionId).set({
        'date': _fromDateTime(action.date),
        'note': action.note,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _setSaved();

      final updated = await getAssessment(assessmentId);
      if (updated != null) return updated;

      final existing = _assessmentFromFirestore(doc);
      return existing.copyWith(actionsTaken: [...existing.actionsTaken, action]);
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to add action: $e');
    }
  }

  @override
  Future<Assessment> updateAssessmentAi(String assessmentId, AiInsight ai) async {
    final uid = _currentUid;
    final assessmentDocRef = _firestore.collection('assessments').doc(assessmentId);
    final doc = await assessmentDocRef.get();
    if (!doc.exists) throw ApiException('Assessment not found');
    if (doc.data()?['ownerUid'] != uid) throw ApiException('Permission denied');

    _setSyncing();
    try {
      await assessmentDocRef.update({
        'ai': ai.toJson(),
      });
      _setSaved();

      final updated = await getAssessment(assessmentId);
      if (updated != null) return updated;

      final existing = _assessmentFromFirestore(doc);
      return existing.copyWith(ai: ai);
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to update AI insights: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Community
  // ---------------------------------------------------------------------------

  Post _postFromFirestore(DocumentSnapshot doc, {bool likedByMe = false}) {
    final d = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorName: d['authorName'] as String? ?? 'Community Member',
      authorType: d['authorType'] as String? ?? 'Individual',
      category: PostCategory.values.where((c) => c.name == d['category']).firstOrNull ??
          PostCategory.general,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      imagePath: d['imagePath'] as String?,
      createdAt: _toDateTime(d['createdAt']) ?? DateTime.now(),
      likes: (d['likeCount'] ?? d['likes'] as num?)?.toInt() ?? 0,
      comments: (d['commentCount'] ?? d['comments'] as num?)?.toInt() ?? 0,
      likedByMe: likedByMe,
      eventDate: _toDateTime(d['eventDate']),
      eventTime: d['eventTime'] as String?,
      eventPlace: d['eventPlace'] as String?,
      hidden: d['hidden'] == true,
    );
  }

  @override
  Future<List<Post>> getPosts({PostCategory? category}) async {
    final uid = _currentUid;
    Query query = _firestore.collection('posts').where('hidden', isNotEqualTo: true);
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    query = query.orderBy('createdAt', descending: true);

    QuerySnapshot snap;
    try {
      snap = await query.get();
    } catch (e) {
      debugPrint('[firestore] getPosts query fallback: $e');
      snap = await _firestore.collection('posts').get();
    }

    final posts = <Post>[];
    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['hidden'] == true) continue;
      if (category != null && d['category'] != category.name) continue;

      // Check if reported by current user
      final reportDoc = await doc.reference.collection('reports').doc(uid).get();
      if (reportDoc.exists) continue;

      // Check if liked by current user
      final likeDoc = await doc.reference.collection('likes').doc(uid).get();
      final likedByMe = likeDoc.exists;

      posts.add(_postFromFirestore(doc, likedByMe: likedByMe));
    }

    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  @override
  Future<Post> createPost(Post post) async {
    final uid = _currentUid;
    if (post.title.trim().isEmpty) throw ApiException('Title is required');

    final id = post.id.isEmpty ? newId() : post.id;
    String? thumbB64;
    if (post.imagePath != null && post.imagePath!.isNotEmpty) {
      final bytes = await _compressImageToThumbnail(post.imagePath!);
      if (bytes != null) {
        thumbB64 = base64Encode(bytes);
      }
    }

    final map = {
      'id': id,
      'authorUid': uid,
      'authorName': post.authorName.isNotEmpty
          ? post.authorName
          : (_auth.currentUser?.displayName ?? 'Community Member'),
      'authorType': post.authorType.isNotEmpty ? post.authorType : 'Individual',
      'category': post.category.name,
      'title': post.title.trim(),
      'body': post.body.trim(),
      'thumbB64': ?thumbB64,
      'imagePath': post.imagePath,
      'eventDate': _fromDateTime(post.eventDate),
      'eventTime': post.eventTime,
      'eventPlace': post.eventPlace,
      'likeCount': 0,
      'commentCount': 0,
      'hidden': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    _setSyncing();
    try {
      await _firestore.collection('posts').doc(id).set(map);
      _setSaved();
      return post.copyWith();
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to create post: $e');
    }
  }

  @override
  Future<Post> toggleLike(String postId) async {
    final uid = _currentUid;
    final postRef = _firestore.collection('posts').doc(postId);
    final postDoc = await postRef.get();
    if (!postDoc.exists) throw ApiException('Post not found');

    final likeRef = postRef.collection('likes').doc(uid);
    final likeDoc = await likeRef.get();
    final alreadyLiked = likeDoc.exists;

    _setSyncing();
    try {
      if (alreadyLiked) {
        await likeRef.delete();
      } else {
        await likeRef.set({'createdAt': FieldValue.serverTimestamp()});
      }

      try {
        await postRef.update({
          'likeCount': FieldValue.increment(alreadyLiked ? -1 : 1),
        });
      } catch (_) {
        // Post author only update permission on post doc is expected under rules
      }

      _setSaved();
      return _postFromFirestore(await postRef.get(), likedByMe: !alreadyLiked);
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to toggle like: $e');
    }
  }

  @override
  Future<void> reportPost(String postId, String reason) async {
    final uid = _currentUid;
    _setSyncing();
    try {
      await _firestore.collection('posts').doc(postId).collection('reports').doc(uid).set({
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _setSaved();
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to report post: $e');
    }
  }

  @override
  Future<void> reportConcern(ConcernReport report) async {
    final uid = _currentUid;
    final id = report.id.isEmpty ? newId() : report.id;

    final map = {
      'id': id,
      'ownerUid': uid,
      'locationId': report.locationId,
      'areaDescription': report.areaDescription,
      'indicators': report.indicators.toJson(),
      'description': report.description,
      'observedAt': _fromDateTime(report.observedAt),
      'photoPaths': report.photoPaths,
      'createdAt': FieldValue.serverTimestamp(),
    };

    _setSyncing();
    try {
      await _firestore.collection('concerns').doc(id).set(map);
      _setSaved();
    } catch (e) {
      _setSaved();
      throw ApiException('Failed to report concern: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Devices (Hardware Sensor Nodes - owner only, NO tokens or secrets)
  // ---------------------------------------------------------------------------

  Future<void> syncDevice({
    required String deviceId,
    required String name,
    required String hardwareModel,
    required String firmwareVersion,
    String? locationId,
    DateTime? lastSeenAt,
  }) async {
    final uid = _currentUid;
    _setSyncing();
    try {
      await _firestore.collection('devices').doc(deviceId).set({
        'deviceId': deviceId,
        'ownerUid': uid,
        'name': name,
        'hardwareModel': hardwareModel,
        'firmwareVersion': firmwareVersion,
        'locationId': ?locationId,
        'lastSeenAt': _fromDateTime(lastSeenAt) ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _setSaved();
    } catch (e) {
      _setSaved();
      debugPrint('[firestore] Error syncing device: $e');
    }
  }
}
