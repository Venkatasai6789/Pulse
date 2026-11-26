import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/data/api_service.dart';
import 'package:pulse/data/firestore_api_service.dart';
import 'package:pulse/models/models.dart';

void main() {
  group('FirestoreApiService Configuration & Constants', () {
    test('Spark plan default: kUseCloudStorage is false', () {
      expect(kUseCloudStorage, isFalse);
    });

    test('Initial sync status is saved', () {
      final service = FirestoreApiService();
      expect(service.syncStatus.value, SyncStatus.saved);
    });
  });

  group('FirestoreApiService Validation & Submit Logic', () {
    test('submitAssessment rejects incomplete draft with missing fields', () async {
      final service = FirestoreApiService();
      final incompleteDraft = Assessment(
        id: 'test-draft-1',
        createdAt: DateTime(2026, 1, 1),
      );

      // Attempting to submit without complete fields must throw ApiException
      expect(
        () => service.submitAssessment(incompleteDraft),
        throwsA(isA<ApiException>()),
      );
    });

    test('saveDraft rejects already submitted assessment', () async {
      final service = FirestoreApiService();
      final now = DateTime.now();
      final submitted = Assessment(
        id: 'test-submitted-1',
        status: AssessmentStatus.submitted,
        createdAt: now,
      );

      expect(
        () => service.saveDraft(submitted),
        throwsA(isA<ApiException>().having(
          (e) => e.toString(),
          'message',
          contains('Submitted assessments cannot be edited'),
        )),
      );
    });

    test('calculatePhi matches formula for submitted assessment inputs', () {
      const inputs = AssessmentInputs(
        visits: 20,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.high,
        shelter: Level.high,
        water: Water.present,
        temperatureC: 25.0,
        humidityPct: 60.0,
        co2Ppm: 600.0,
        risk: RiskIndicators(),
        riskLevel: RiskLevel.low,
      );

      final result = calculatePhi(inputs);
      expect(result.phi, greaterThanOrEqualTo(80));
      expect(result.tier, Tier.protect);
    });
  });
}
