/// The ONLY place screens get data from.
///
/// Today: [MockApiService] stores everything on the phone (shared_preferences).
/// Later: the backend developer writes `HttpApiService implements ApiService`
/// and changes one line in main.dart. No screen code changes.
library;

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/phi.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

abstract class ApiService {
  // Auth
  Future<AppUser?> currentUser();
  Future<AppUser> signUp({required String name, required String email, required String password, String? organisation});
  Future<AppUser> login({required String email, required String password});
  Future<void> logout();
  Future<AppUser> updateProfile(AppUser user);

  // Locations
  Future<List<Location>> getLocations();
  Future<Location?> getLocation(String id);
  Future<Location> createLocation(Location location);

  // Assessments
  Future<List<Assessment>> getAssessments({String? locationId, bool submittedOnly = true});
  Future<Assessment?> getAssessment(String id);
  Future<Assessment?> latestAssessment(String locationId);
  Future<Assessment> saveDraft(Assessment draft);
  Future<void> deleteDraft(String id);

  /// Validates, calculates the PHI and stores a NEW submitted record.
  /// Submitted assessments are never overwritten.
  Future<Assessment> submitAssessment(Assessment draft);
  Future<Assessment> addActionTaken(String assessmentId, ActionTaken action);
  Future<Assessment> updateAssessmentAi(String assessmentId, AiInsight ai);

  // Community
  Future<List<Post>> getPosts({PostCategory? category});
  Future<Post> createPost(Post post);
  Future<Post> toggleLike(String postId);
  Future<void> reportPost(String postId, String reason);
  Future<void> reportConcern(ConcernReport report);
}

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

class MockApiService implements ApiService {
  MockApiService({this.seedDemoHistory = true, this.latency = const Duration(milliseconds: 250)});

  /// Adds 3 past assessments for Community Garden so the trend chart has
  /// data in the demo. Their PHIs are CALCULATED from inputs, not hard-coded.
  final bool seedDemoHistory;

  /// Small fake delay so loading states get exercised like a real backend.
  final Duration latency;

  static const _kUsers = 'pulse.users';
  static const _kSession = 'pulse.session';
  static const _kLocations = 'pulse.locations';
  static const _kAssessments = 'pulse.assessments';
  static const _kPosts = 'pulse.posts';
  static const _kConcerns = 'pulse.concerns';
  static const _kSeeded = 'pulse.seeded.v1';

  SharedPreferences? _p;

  Future<SharedPreferences> get _prefs async {
    if (_p != null) return _p!;
    _p = await SharedPreferences.getInstance();
    if (_p!.getBool(_kSeeded) != true) await _seed(_p!);
    return _p!;
  }

  Future<void> _wait() => Future.delayed(latency);

  List<Map<String, dynamic>> _read(SharedPreferences p, String key) =>
      (jsonDecode(p.getString(key) ?? '[]') as List).map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _write(SharedPreferences p, String key, List<Map<String, dynamic>> rows) =>
      p.setString(key, jsonEncode(rows));

  // ---------------------------------------------------------------- auth
  // Mock only: passwords are stored locally in plain form. The real backend
  // must handle auth properly. Never ship this as real authentication.

  @override
  Future<AppUser?> currentUser() async {
    final p = await _prefs;
    final s = p.getString(_kSession);
    return s == null ? null : AppUser.fromJson(jsonDecode(s));
  }

  @override
  Future<AppUser> signUp({required String name, required String email, required String password, String? organisation}) async {
    await _wait();
    final p = await _prefs;
    final users = _read(p, _kUsers);
    final e = email.trim().toLowerCase();
    if (users.any((u) => u['email'] == e)) throw ApiException('An account with this email already exists');
    final user = AppUser(id: newId(), name: name.trim(), email: e, organisation: organisation);
    users.add({...user.toJson(), 'password': password});
    await _write(p, _kUsers, users);
    await p.setString(_kSession, jsonEncode(user.toJson()));
    return user;
  }

  @override
  Future<AppUser> login({required String email, required String password}) async {
    await _wait();
    final p = await _prefs;
    final e = email.trim().toLowerCase();
    final row = _read(p, _kUsers).where((u) => u['email'] == e && u['password'] == password).firstOrNull;
    if (row == null) throw ApiException('Incorrect email or password');
    final user = AppUser.fromJson(row);
    await p.setString(_kSession, jsonEncode(user.toJson()));
    return user;
  }

  @override
  Future<void> logout() async => (await _prefs).remove(_kSession);

  @override
  Future<AppUser> updateProfile(AppUser user) async {
    await _wait();
    final p = await _prefs;
    final users = _read(p, _kUsers);
    final i = users.indexWhere((u) => u['id'] == user.id);
    if (i >= 0) users[i] = {...users[i], ...user.toJson()};
    await _write(p, _kUsers, users);
    await p.setString(_kSession, jsonEncode(user.toJson()));
    return user;
  }

  // ------------------------------------------------------------ locations

  @override
  Future<List<Location>> getLocations() async {
    await _wait();
    final p = await _prefs;
    return _read(p, _kLocations).map(Location.fromJson).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<Location?> getLocation(String id) async =>
      (await getLocations()).where((l) => l.id == id).firstOrNull;

  @override
  Future<Location> createLocation(Location location) async {
    await _wait();
    if (location.name.trim().isEmpty) throw ApiException('Location name is required');
    if (location.address.trim().isEmpty) throw ApiException('Address / area is required');
    final p = await _prefs;
    final rows = _read(p, _kLocations)..add(location.toJson());
    await _write(p, _kLocations, rows);
    return location;
  }

  // ---------------------------------------------------------- assessments

  @override
  Future<List<Assessment>> getAssessments({String? locationId, bool submittedOnly = true}) async {
    await _wait();
    final p = await _prefs;
    return _read(p, _kAssessments)
        .map(Assessment.fromJson)
        .where((a) => locationId == null || a.locationId == locationId)
        .where((a) => !submittedOnly || a.isSubmitted)
        .toList()
      ..sort((a, b) => (b.submittedAt ?? b.createdAt).compareTo(a.submittedAt ?? a.createdAt));
  }

  @override
  Future<Assessment?> getAssessment(String id) async =>
      (await getAssessments(submittedOnly: false)).where((a) => a.id == id).firstOrNull;

  @override
  Future<Assessment?> latestAssessment(String locationId) async =>
      (await getAssessments(locationId: locationId)).firstOrNull;

  @override
  Future<Assessment> saveDraft(Assessment draft) async {
    if (draft.isSubmitted) throw ApiException('Submitted assessments cannot be edited');
    final p = await _prefs;
    final rows = _read(p, _kAssessments);
    final i = rows.indexWhere((r) => r['id'] == draft.id);
    if (i >= 0 && rows[i]['status'] == AssessmentStatus.submitted.name) {
      throw ApiException('Submitted assessments cannot be edited');
    }
    if (i >= 0) {
      rows[i] = draft.toJson();
    } else {
      rows.add(draft.toJson());
    }
    await _write(p, _kAssessments, rows);
    return draft;
  }

  @override
  Future<void> deleteDraft(String id) async {
    final p = await _prefs;
    final rows = _read(p, _kAssessments)
      ..removeWhere((r) => r['id'] == id && r['status'] == AssessmentStatus.draft.name);
    await _write(p, _kAssessments, rows);
  }

  @override
  Future<Assessment> submitAssessment(Assessment draft) async {
    await _wait();
    if (!draft.isComplete) {
      throw ApiException('Please complete: ${draft.missingFields.join(', ')}');
    }
    final result = calculatePhi(draft.toInputs());
    final submitted = draft.copyWith(
      status: AssessmentStatus.submitted,
      result: result,
      submittedAt: DateTime.now(),
    );
    final p = await _prefs;
    final rows = _read(p, _kAssessments);
    final i = rows.indexWhere((r) => r['id'] == draft.id);
    if (i >= 0) {
      rows[i] = submitted.toJson(); // replaces the DRAFT only
    } else {
      rows.add(submitted.toJson());
    }
    await _write(p, _kAssessments, rows);
    return submitted;
  }

  @override
  Future<Assessment> addActionTaken(String assessmentId, ActionTaken action) async {
    final p = await _prefs;
    final rows = _read(p, _kAssessments);
    final i = rows.indexWhere((r) => r['id'] == assessmentId);
    if (i < 0) throw ApiException('Assessment not found');
    final a = Assessment.fromJson(rows[i]);
    // Only the actions list changes; the scores and inputs stay as submitted.
    final updated = a.copyWith(actionsTaken: [...a.actionsTaken, action]);
    rows[i] = updated.toJson();
    await _write(p, _kAssessments, rows);
    return updated;
  }

  @override
  Future<Assessment> updateAssessmentAi(String assessmentId, AiInsight ai) async {
    final p = await _prefs;
    final rows = _read(p, _kAssessments);
    final i = rows.indexWhere((r) => r['id'] == assessmentId);
    if (i < 0) throw ApiException('Assessment not found');
    final a = Assessment.fromJson(rows[i]);
    // Save AI insights to the assessment without changing result or scores
    final updated = a.copyWith(ai: ai);
    rows[i] = updated.toJson();
    await _write(p, _kAssessments, rows);
    return updated;
  }

  // ------------------------------------------------------------ community

  @override
  Future<List<Post>> getPosts({PostCategory? category}) async {
    await _wait();
    final p = await _prefs;
    return _read(p, _kPosts)
        .map(Post.fromJson)
        .where((x) => !x.hidden)
        .where((x) => category == null || x.category == category)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Post> createPost(Post post) async {
    await _wait();
    if (post.title.trim().isEmpty) throw ApiException('Title is required');
    final p = await _prefs;
    final rows = _read(p, _kPosts)..add(post.toJson());
    await _write(p, _kPosts, rows);
    return post;
  }

  @override
  Future<Post> toggleLike(String postId) async {
    final p = await _prefs;
    final rows = _read(p, _kPosts);
    final i = rows.indexWhere((r) => r['id'] == postId);
    final post = Post.fromJson(rows[i]);
    final updated = post.copyWith(
      likedByMe: !post.likedByMe,
      likes: post.likes + (post.likedByMe ? -1 : 1),
    );
    rows[i] = updated.toJson();
    await _write(p, _kPosts, rows);
    return updated;
  }

  @override
  Future<void> reportPost(String postId, String reason) async {
    // Mock: hide it from this user's feed. Backend: send to moderation queue.
    final p = await _prefs;
    final rows = _read(p, _kPosts);
    final i = rows.indexWhere((r) => r['id'] == postId);
    if (i >= 0) rows[i] = Post.fromJson(rows[i]).copyWith(hidden: true).toJson();
    await _write(p, _kPosts, rows);
  }

  @override
  Future<void> reportConcern(ConcernReport report) async {
    await _wait();
    final p = await _prefs;
    final rows = _read(p, _kConcerns)..add(report.toJson());
    await _write(p, _kConcerns, rows);
  }

  // ----------------------------------------------------------------- seed

  Future<void> _seed(SharedPreferences p) async {
    final now = DateTime.now();
    final locations = [
      Location(id: 'loc-garden', name: 'Community Garden', type: 'Community garden', address: 'Alwarpet, Chennai',
          photoPaths: const ['assets/images/loc_garden.jpg'], createdAt: now.subtract(const Duration(days: 90))),
      Location(id: 'loc-janvi', name: "Janvi's House", type: 'Home garden', address: 'Chennai',
          photoPaths: const ['assets/images/loc_house1.jpg'], createdAt: now.subtract(const Duration(days: 60))),
      Location(id: 'loc-medhaansh', name: "Medhaansh's House", type: 'Home garden', address: 'Chennai',
          photoPaths: const ['assets/images/loc_house2.jpg'], createdAt: now.subtract(const Duration(days: 30))),
    ];
    await _write(p, _kLocations, locations.map((l) => l.toJson()).toList());

    final assessments = <Map<String, dynamic>>[];
    if (seedDemoHistory) {
      // Inputs only; the PHI is calculated by the same engine as live entries.
      final history = [
        (75, 9, Level.medium, Level.low, Level.medium, Water.present, 31.0, 68.0, 720.0, RiskLevel.moderate),
        (45, 14, Level.high, Level.medium, Level.medium, Water.present, 29.0, 64.0, 650.0, RiskLevel.low),
        (15, 18, Level.high, Level.medium, Level.high, Water.present, 29.0, 61.0, 610.0, RiskLevel.low),
      ];
      for (final h in history) {
        final at = now.subtract(Duration(days: h.$1));
        final a = Assessment(
          id: newId(),
          locationId: 'loc-garden',
          visits: h.$2,
          observedAt: at,
          durationMinutes: 5,
          weather: 'Sunny',
          flowers: h.$3,
          nesting: h.$4,
          shelter: h.$5,
          water: h.$6,
          temperatureC: h.$7,
          humidityPct: h.$8,
          co2Ppm: h.$9,
          riskLevel: h.$10,
          createdAt: at,
        );
        final done = a.copyWith(
          status: AssessmentStatus.submitted,
          result: calculatePhi(a.toInputs()),
          submittedAt: at,
        );
        assessments.add(done.toJson());
      }
    }
    await _write(p, _kAssessments, assessments);

    final posts = [
      Post(id: 'p1', authorName: 'Green Horizons NGO', authorType: 'Community Partner', category: PostCategory.event,
          title: 'Pollinator Garden Workshop – This Saturday!',
          body: 'Join us for a hands-on workshop on creating pollinator-friendly gardens in urban spaces. All are welcome!',
          imagePath: 'assets/images/post_butterfly.jpg', createdAt: now.subtract(const Duration(hours: 2)),
          likes: 24, comments: 6, eventDate: now.add(const Duration(days: 3)),
          eventTime: '10:00 AM – 12:00 PM', eventPlace: 'Riverside Community Garden'),
      Post(id: 'p2', authorName: 'Riverside School', authorType: 'Educational Institution', category: PostCategory.initiative,
          title: 'Our Students Take Action!',
          body: 'A big thank you to everyone who participated in our campus pollinator count. Together, we can make a difference!',
          imagePath: 'assets/images/post_school.jpg', createdAt: now.subtract(const Duration(days: 1)), likes: 42, comments: 8),
      Post(id: 'p3', authorName: 'Community Garden Collective', authorType: 'Local Initiative', category: PostCategory.initiative,
          title: 'New Native Plants Added',
          body: "We've planted 50 native flowering plants to support local pollinators. Come visit and see the difference!",
          imagePath: 'assets/images/post_flowers.jpg', createdAt: now.subtract(const Duration(days: 2)), likes: 31, comments: 5),
      Post(id: 'p4', authorName: 'City Library', authorType: 'Municipal Organisation', category: PostCategory.event,
          title: 'Urban Biodiversity Talk', body: 'An evening talk on supporting bees and butterflies in the city.',
          createdAt: now.subtract(const Duration(days: 3)), likes: 12, comments: 2,
          eventDate: now.add(const Duration(days: 6)), eventTime: '6:00 PM – 7:30 PM', eventPlace: 'City Library'),
      Post(id: 'p5', authorName: 'Pollinator Experts Network', authorType: 'Environmental Expert', category: PostCategory.resource,
          title: 'Guide: 10 native plants bees love',
          body: 'A simple starter list of native flowering plants with staggered bloom times for South Indian gardens.',
          createdAt: now.subtract(const Duration(days: 4)), likes: 57, comments: 11),
    ];
    await _write(p, _kPosts, posts.map((x) => x.toJson()).toList());
    await p.setBool(_kSeeded, true);
  }
}
