/// Data models + JSON contract shared with the backend.
/// Field names here ARE the API contract (see SPEC.md section 7).
library;

import '../core/phi.dart';
import '../core/soil_reading.dart';

T? _enum<T extends Enum>(List<T> values, Object? name) =>
    name == null ? null : values.byName(name as String);

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

// ---------------------------------------------------------------------------
// User
// ---------------------------------------------------------------------------

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? organisation;
  final String? photoUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.organisation,
    this.photoUrl,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'organisation': organisation,
        'photoUrl': photoUrl,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        organisation: j['organisation'],
        photoUrl: j['photoUrl'],
      );
}

// ---------------------------------------------------------------------------
// Location
// ---------------------------------------------------------------------------

const locationTypes = [
  'Home garden',
  'Balcony / terrace',
  'Community garden',
  'School campus',
  'Residential society',
  'Park',
  'Farm',
  'Office campus',
  'Other',
];

enum ManagedBy { me, organisation }

class Location {
  final String id;
  final String name;
  final String type;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? description;
  final List<String> photoPaths; // local file paths now, URLs from backend later
  final ManagedBy managedBy;
  final String? organisationName;
  final DateTime createdAt;
  final String? sensorNodeId;
  final int? latestPhi;
  final String? latestTier;
  final DateTime? lastAssessedAt;

  const Location({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.latitude,
    this.longitude,
    this.description,
    this.photoPaths = const [],
    this.managedBy = ManagedBy.me,
    this.organisationName,
    required this.createdAt,
    this.sensorNodeId,
    this.latestPhi,
    this.latestTier,
    this.lastAssessedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'photoPaths': photoPaths,
        'managedBy': managedBy.name,
        'organisationName': organisationName,
        'createdAt': createdAt.toIso8601String(),
        if (sensorNodeId != null) 'sensorNodeId': sensorNodeId,
        if (latestPhi != null) 'latestPhi': latestPhi,
        if (latestTier != null) 'latestTier': latestTier,
        if (lastAssessedAt != null) 'lastAssessedAt': lastAssessedAt!.toIso8601String(),
      };

  factory Location.fromJson(Map<String, dynamic> j) => Location(
        id: j['id'],
        name: j['name'],
        type: j['type'],
        address: j['address'],
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        description: j['description'],
        photoPaths: List<String>.from(j['photoPaths'] ?? const []),
        managedBy: _enum(ManagedBy.values, j['managedBy']) ?? ManagedBy.me,
        organisationName: j['organisationName'],
        createdAt: DateTime.parse(j['createdAt']),
        sensorNodeId: j['sensorNodeId'] as String?,
        latestPhi: (j['latestPhi'] as num?)?.toInt(),
        latestTier: j['latestTier'] as String?,
        lastAssessedAt: j['lastAssessedAt'] != null ? DateTime.tryParse(j['lastAssessedAt']) : null,
      );
}

// ---------------------------------------------------------------------------
// Assessment  (draft fields are nullable: empty is NOT zero)
// ---------------------------------------------------------------------------

const weatherOptions = ['Sunny', 'Partly cloudy', 'Cloudy', 'Windy', 'Light rain', 'Rain'];

enum AssessmentStatus { draft, submitted }

class ActionTaken {
  final DateTime date;
  final String note;
  const ActionTaken(this.date, this.note);
  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'note': note};
  factory ActionTaken.fromJson(Map<String, dynamic> j) =>
      ActionTaken(DateTime.parse(j['date']), j['note']);
}

// ---------------------------------------------------------------------------
// AI Insights & Habitat Suggestions
// ---------------------------------------------------------------------------

class HabitatSuggestion {
  final String field; // 'flowers', 'nesting', 'shelter', 'water'
  final String value; // 'High', 'Medium', 'Low' or 'Present', 'Absent'
  final double confidence; // e.g. 0.8 (80%)

  const HabitatSuggestion({
    required this.field,
    required this.value,
    this.confidence = 0.8,
  });

  String get chipLabel {
    final pct = (confidence <= 1.0) ? (confidence * 100).round() : confidence.round();
    final fieldCap = field.isEmpty ? '' : '${field[0].toUpperCase()}${field.substring(1)}';
    return 'AI suggests $fieldCap: $value ($pct%) · Apply';
  }

  Map<String, dynamic> toJson() => {
        'field': field,
        'value': value,
        'confidence': confidence,
      };

  factory HabitatSuggestion.fromJson(Map<String, dynamic> j) => HabitatSuggestion(
        field: j['field'] as String? ?? '',
        value: j['value'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.8,
      );
}

class AiInsight {
  final String model;
  final DateTime generatedAt;
  final String summary;
  final List<String> photoFindings;
  final List<String> suggestions;
  final List<HabitatSuggestion> habitatSuggestions;
  final bool isHabitatPhoto;
  final String soilAdvice;

  const AiInsight({
    required this.model,
    required this.generatedAt,
    required this.summary,
    this.photoFindings = const [],
    this.suggestions = const [],
    this.habitatSuggestions = const [],
    this.isHabitatPhoto = true,
    this.soilAdvice = '',
  });

  /// Up to 2 AI tip bullets
  List<String> get tips => suggestions.take(2).toList();

  Map<String, dynamic> toJson() => {
        'model': model,
        'generatedAt': generatedAt.toIso8601String(),
        'summary': summary,
        'photoFindings': photoFindings,
        'suggestions': suggestions,
        'habitatSuggestions': habitatSuggestions.map((s) => s.toJson()).toList(),
        'isHabitatPhoto': isHabitatPhoto,
        'soilAdvice': soilAdvice,
      };

  factory AiInsight.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return AiInsight(
      model: j['model'] as String? ?? 'gemini-2.5-flash',
      generatedAt: parseDate(j['generatedAt']),
      summary: j['summary'] as String? ?? '',
      photoFindings: (j['photoFindings'] as List? ?? const []).map((e) => e.toString()).toList(),
      suggestions: (j['suggestions'] as List? ?? const []).map((e) => e.toString()).toList(),
      habitatSuggestions: (j['habitatSuggestions'] as List? ?? const [])
          .map((e) => HabitatSuggestion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      isHabitatPhoto: j['isHabitatPhoto'] as bool? ?? true,
      soilAdvice: j['soilAdvice'] as String? ?? '',
    );
  }
}

class Assessment {
  final String id;
  final String? locationId;
  final AssessmentStatus status;

  // A. Activity
  final int? visits;
  final DateTime? observedAt;
  final int? durationMinutes;
  final String? weather;
  final List<String> activityPhotoPaths;

  String? get activityPhotoPath =>
      activityPhotoPaths.isNotEmpty ? activityPhotoPaths.first : null;

  // B. Habitat
  final Level? flowers;
  final Level? nesting;
  final Level? shelter;
  final Water? water;

  // C. Environment
  final double? temperatureC;
  final double? humidityPct;
  final double? co2Ppm;
  final SoilReading? soil;
  final String? climateSource; // 'esp32_dht11' | 'manual'
  final String? climateDeviceId;
  final DateTime? climateCapturedAt;

  // D. Risk
  final RiskIndicators riskIndicators;
  final RiskLevel? riskLevel; // user-selected (dropdown)
  final String? riskDescription;
  final DateTime? riskObservedAt;
  final String? riskNotes;
  final List<String> riskPhotoPaths;

  // Output (only for submitted assessments)
  final PhiResult? result;

  // Optional AI advisory insights
  final AiInsight? ai;

  final List<ActionTaken> actionsTaken;
  final DateTime createdAt;
  final DateTime? submittedAt;

  const Assessment({
    required this.id,
    this.locationId,
    this.status = AssessmentStatus.draft,
    this.visits,
    this.observedAt,
    this.durationMinutes = 5,
    this.weather,
    this.activityPhotoPaths = const [],
    this.flowers,
    this.nesting,
    this.shelter,
    this.water,
    this.temperatureC,
    this.humidityPct,
    this.co2Ppm,
    this.soil,
    this.climateSource,
    this.climateDeviceId,
    this.climateCapturedAt,
    this.riskIndicators = const RiskIndicators(),
    this.riskLevel,
    this.riskDescription,
    this.riskObservedAt,
    this.riskNotes,
    this.riskPhotoPaths = const [],
    this.result,
    this.ai,
    this.actionsTaken = const [],
    required this.createdAt,
    this.submittedAt,
  });

  bool get isSubmitted => status == AssessmentStatus.submitted;

  /// Labels of required fields that are still empty. Submit is disabled
  /// until this list is empty. Used to show "3 fields left" and highlights.
  List<String> get missingFields => [
        if (locationId == null) 'Location',
        if (visits == null) 'Number of pollinator visits',
        if (observedAt == null) 'Date & time',
        if (durationMinutes == null) 'Observation duration',
        if (weather == null) 'Weather conditions',
        if (flowers == null) 'Flowers',
        if (nesting == null) 'Nesting spaces',
        if (shelter == null) 'Shelter',
        if (water == null) 'Water',
        if (temperatureC == null) 'Temperature',
        if (humidityPct == null) 'Humidity',
        if (co2Ppm == null) 'CO₂ level',
        if (riskLevel == null) 'Risk level',
      ];

  bool get isComplete => missingFields.isEmpty;

  double? get soilMoisturePercent => soil?.percent;

  /// Only call when [isComplete]. Throws otherwise.
  AssessmentInputs toInputs() {
    if (!isComplete) throw StateError('Missing: ${missingFields.join(', ')}');
    return AssessmentInputs(
      visits: visits!,
      durationMinutes: durationMinutes!,
      flowers: flowers!,
      nesting: nesting!,
      shelter: shelter!,
      water: water!,
      temperatureC: temperatureC!,
      humidityPct: humidityPct!,
      co2Ppm: co2Ppm!,
      risk: riskIndicators,
      riskLevel: riskLevel!,
      soil: soil,
      soilMoisturePercent: soil?.percent,
    );
  }

  Assessment copyWith({
    String? locationId,
    AssessmentStatus? status,
    int? visits,
    DateTime? observedAt,
    int? durationMinutes,
    String? weather,
    String? activityPhotoPath,
    List<String>? activityPhotoPaths,
    Level? flowers,
    Level? nesting,
    Level? shelter,
    Water? water,
    double? temperatureC,
    double? humidityPct,
    double? co2Ppm,
    SoilReading? soil,
    String? climateSource,
    String? climateDeviceId,
    DateTime? climateCapturedAt,
    RiskIndicators? riskIndicators,
    RiskLevel? riskLevel,
    String? riskDescription,
    DateTime? riskObservedAt,
    String? riskNotes,
    List<String>? riskPhotoPaths,
    PhiResult? result,
    List<ActionTaken>? actionsTaken,
    DateTime? submittedAt,
    AiInsight? ai,
  }) =>
      Assessment(
        id: id,
        locationId: locationId ?? this.locationId,
        status: status ?? this.status,
        visits: visits ?? this.visits,
        observedAt: observedAt ?? this.observedAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        weather: weather ?? this.weather,
        activityPhotoPaths: activityPhotoPaths ??
            (activityPhotoPath != null
                ? [activityPhotoPath]
                : this.activityPhotoPaths),
        flowers: flowers ?? this.flowers,
        nesting: nesting ?? this.nesting,
        shelter: shelter ?? this.shelter,
        water: water ?? this.water,
        temperatureC: temperatureC ?? this.temperatureC,
        humidityPct: humidityPct ?? this.humidityPct,
        co2Ppm: co2Ppm ?? this.co2Ppm,
        soil: soil ?? this.soil,
        climateSource: climateSource ?? this.climateSource,
        climateDeviceId: climateDeviceId ?? this.climateDeviceId,
        climateCapturedAt: climateCapturedAt ?? this.climateCapturedAt,
        riskIndicators: riskIndicators ?? this.riskIndicators,
        riskLevel: riskLevel ?? this.riskLevel,
        riskDescription: riskDescription ?? this.riskDescription,
        riskObservedAt: riskObservedAt ?? this.riskObservedAt,
        riskNotes: riskNotes ?? this.riskNotes,
        riskPhotoPaths: riskPhotoPaths ?? this.riskPhotoPaths,
        result: result ?? this.result,
        ai: ai ?? this.ai,
        actionsTaken: actionsTaken ?? this.actionsTaken,
        createdAt: createdAt,
        submittedAt: submittedAt ?? this.submittedAt,
      );

  /// Sets one field back to empty (e.g. user clears the Temperature box).
  /// [field] is the JSON key, e.g. 'temperatureC'. copyWith can't do this.
  Assessment clear(String field) {
    final j = toJson();
    if (field == 'activityPhotoPath' || field == 'activityPhotoPaths') {
      j['activityPhotoPath'] = null;
      j['activityPhotoPaths'] = [];
    } else if (field == 'riskPhotoPaths') {
      j['riskPhotoPaths'] = [];
    } else if (field == 'ai') {
      j['ai'] = null;
    } else {
      assert(j.containsKey(field), 'Unknown field $field');
      j[field] = null;
      if ((field == 'temperatureC' || field == 'humidityPct') &&
          j['temperatureC'] == null &&
          j['humidityPct'] == null) {
        j['climateSource'] = null;
        j['climateDeviceId'] = null;
        j['climateCapturedAt'] = null;
      }
    }
    return Assessment.fromJson(j);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'locationId': locationId,
        'status': status.name,
        'visits': visits,
        'observedAt': observedAt?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'weather': weather,
        'activityPhotoPath': activityPhotoPath,
        'activityPhotoPaths': activityPhotoPaths,
        'flowers': flowers?.name,
        'nesting': nesting?.name,
        'shelter': shelter?.name,
        'water': water?.name,
        'temperatureC': temperatureC,
        'humidityPct': humidityPct,
        'co2Ppm': co2Ppm,
        if (soil != null) 'soil': soil!.toJson(),
        'climateSource': climateSource,
        'climateDeviceId': climateDeviceId,
        'climateCapturedAt': climateCapturedAt?.toIso8601String(),
        'riskIndicators': riskIndicators.toJson(),
        'riskLevel': riskLevel?.name,
        'riskDescription': riskDescription,
        'riskObservedAt': riskObservedAt?.toIso8601String(),
        'riskNotes': riskNotes,
        'riskPhotoPaths': riskPhotoPaths,
        'result': result?.toJson(),
        'ai': ai?.toJson(),
        'actionsTaken': actionsTaken.map((a) => a.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'submittedAt': submittedAt?.toIso8601String(),
      };

  factory Assessment.fromJson(Map<String, dynamic> j) {
    List<String> actPhotos = const [];
    if (j['activityPhotoPaths'] != null) {
      actPhotos = List<String>.from(j['activityPhotoPaths']);
    } else if (j['activityPhotoPath'] != null) {
      actPhotos = [j['activityPhotoPath'] as String];
    }
    return Assessment(
        id: j['id'],
        locationId: j['locationId'],
        status: _enum(AssessmentStatus.values, j['status']) ?? AssessmentStatus.draft,
        visits: j['visits'],
        observedAt: _date(j['observedAt']),
        durationMinutes: j['durationMinutes'],
        weather: j['weather'],
        activityPhotoPaths: actPhotos,
        flowers: _enum(Level.values, j['flowers']),
        nesting: _enum(Level.values, j['nesting']),
        shelter: _enum(Level.values, j['shelter']),
        water: _enum(Water.values, j['water']),
        temperatureC: (j['temperatureC'] as num?)?.toDouble(),
        humidityPct: (j['humidityPct'] as num?)?.toDouble(),
        co2Ppm: (j['co2Ppm'] as num?)?.toDouble(),
        soil: j['soil'] != null
            ? SoilReading.fromJson(Map<String, dynamic>.from(j['soil'] as Map))
            : null,
        climateSource: j['climateSource'] as String?,
        climateDeviceId: j['climateDeviceId'] as String?,
        climateCapturedAt: _date(j['climateCapturedAt']),
        riskIndicators: RiskIndicators.fromJson(j['riskIndicators']),
        riskLevel: _enum(RiskLevel.values, j['riskLevel']),
        riskDescription: j['riskDescription'],
        riskObservedAt: _date(j['riskObservedAt']),
        riskNotes: j['riskNotes'],
        riskPhotoPaths: List<String>.from(j['riskPhotoPaths'] ?? const []),
        result: j['result'] == null ? null : PhiResult.fromJson(j['result']),
        ai: j['ai'] != null ? AiInsight.fromJson(Map<String, dynamic>.from(j['ai'] as Map)) : null,
        actionsTaken: (j['actionsTaken'] as List? ?? const [])
            .map((a) => ActionTaken.fromJson(Map<String, dynamic>.from(a)))
            .toList(),
        createdAt: DateTime.parse(j['createdAt']),
        submittedAt: _date(j['submittedAt']),
      );
  }
}

// ---------------------------------------------------------------------------
// Community
// ---------------------------------------------------------------------------

enum PostCategory { initiative, event, resource, report, general }

const authorTypes = [
  'Individual',
  'School',
  'Residential Society',
  'NGO',
  'Municipal Organisation',
  'Environmental Expert',
  'Community Partner',
  'Local Initiative',
  'Educational Institution',
];

class Post {
  final String id;
  final String authorName;
  final String authorType;
  final PostCategory category;
  final String title;
  final String body;
  final String? imagePath; // asset path for seed posts, file path for new ones
  final DateTime createdAt;
  final int likes;
  final int comments;
  final bool likedByMe;
  final DateTime? eventDate;
  final String? eventTime; // "10:00 AM – 12:00 PM"
  final String? eventPlace;
  final bool hidden; // reported by me -> hidden from my feed

  const Post({
    required this.id,
    required this.authorName,
    required this.authorType,
    required this.category,
    required this.title,
    required this.body,
    this.imagePath,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.likedByMe = false,
    this.eventDate,
    this.eventTime,
    this.eventPlace,
    this.hidden = false,
  });

  Post copyWith({int? likes, bool? likedByMe, bool? hidden}) => Post(
        id: id,
        authorName: authorName,
        authorType: authorType,
        category: category,
        title: title,
        body: body,
        imagePath: imagePath,
        createdAt: createdAt,
        likes: likes ?? this.likes,
        comments: comments,
        likedByMe: likedByMe ?? this.likedByMe,
        eventDate: eventDate,
        eventTime: eventTime,
        eventPlace: eventPlace,
        hidden: hidden ?? this.hidden,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'authorType': authorType,
        'category': category.name,
        'title': title,
        'body': body,
        'imagePath': imagePath,
        'createdAt': createdAt.toIso8601String(),
        'likes': likes,
        'comments': comments,
        'likedByMe': likedByMe,
        'eventDate': eventDate?.toIso8601String(),
        'eventTime': eventTime,
        'eventPlace': eventPlace,
        'hidden': hidden,
      };

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'],
        authorName: j['authorName'],
        authorType: j['authorType'],
        category: PostCategory.values.byName(j['category']),
        title: j['title'],
        body: j['body'],
        imagePath: j['imagePath'],
        createdAt: DateTime.parse(j['createdAt']),
        likes: j['likes'] ?? 0,
        comments: j['comments'] ?? 0,
        likedByMe: j['likedByMe'] ?? false,
        eventDate: _date(j['eventDate']),
        eventTime: j['eventTime'],
        eventPlace: j['eventPlace'],
        hidden: j['hidden'] ?? false,
      );
}

/// A concern reported through "Report a Concern". Not proof of contamination.
class ConcernReport {
  final String id;
  final String? locationId;
  final String areaDescription;
  final RiskIndicators indicators;
  final String description;
  final DateTime observedAt;
  final List<String> photoPaths;
  final DateTime createdAt;

  const ConcernReport({
    required this.id,
    this.locationId,
    required this.areaDescription,
    required this.indicators,
    required this.description,
    required this.observedAt,
    this.photoPaths = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'locationId': locationId,
        'areaDescription': areaDescription,
        'indicators': indicators.toJson(),
        'description': description,
        'observedAt': observedAt.toIso8601String(),
        'photoPaths': photoPaths,
        'createdAt': createdAt.toIso8601String(),
      };
}
