import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/progress/domain/progress.dart';
import 'package:prforge/features/progress/presentation/progress_providers.dart';
import 'package:prforge/features/workout/presentation/exercise_notes.dart';
import 'package:prforge/features/workout/presentation/last_sessions_hint.dart';

int _id = 0;

Exercise exercise({String? notes}) => Exercise(
    id: 1,
    name: 'Bench',
    category: null,
    equipment: null,
    notes: notes,
    isBodyweight: false,
    isArchived: false);

LoggedSet logged(int session, double weight, int reps) => LoggedSet(
      sessionId: session,
      startedAt: DateTime(2026, 1, session),
      log: SetLog(
          id: ++_id,
          sessionId: session,
          exerciseId: 1,
          prescriptionId: null,
          setIndex: 0,
          setKind: SetKind.normal,
          weightKg: weight,
          reps: reps,
          isCompleted: true,
          supersetKey: null,
          roundIndex: null,
          mainSetId: null,
          note: null),
    );

Widget app(Widget child, {ExerciseProgress? progress, List<Override>? extra}) =>
    ProviderScope(
      overrides: [
        exerciseProgressProvider
            .overrideWith((ref, id) => Stream.value(progress ?? ExerciseProgress.empty)),
        ...?extra,
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  final history = buildExerciseProgress([
    logged(1, 60, 8),
    logged(2, 62.5, 8),
    logged(3, 62.5, 10),
  ]);

  group('LastSessionsHint', () {
    testWidgets('shows the most recent session', (tester) async {
      await tester.pumpWidget(
          app(LastSessionsHint(exercise: exercise()), progress: history));
      await tester.pumpAndSettle();
      expect(find.text('Last: 62.5 kg × 10'), findsOneWidget);
    });

    testWidgets('prefixes the name inside a superset', (tester) async {
      await tester.pumpWidget(app(
          LastSessionsHint(exercise: exercise(), showName: true),
          progress: history));
      await tester.pumpAndSettle();
      expect(find.text('Bench last: 62.5 kg × 10'), findsOneWidget);
    });

    testWidgets('is hidden without history', (tester) async {
      await tester.pumpWidget(app(LastSessionsHint(exercise: exercise())));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('tap opens the sheet: max weight, newest session first',
        (tester) async {
      await tester.pumpWidget(
          app(LastSessionsHint(exercise: exercise()), progress: history));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(LastSessionsHint));
      await tester.pumpAndSettle();

      expect(find.text('Max weight: 62.5 kg'), findsOneWidget);
      final newest = tester.getTopLeft(find.text('62.5 kg × 10'));
      final oldest = tester.getTopLeft(find.text('60 kg × 8'));
      expect(newest.dy, lessThan(oldest.dy));
      expect(find.text('Full progress'), findsOneWidget);
    });
  });

  group('ExerciseNotes', () {
    testWidgets('shows the plan note and the exercise note', (tester) async {
      await tester.pumpWidget(app(
        ExerciseNotes(exercise: exercise(notes: 'Slow negatives'), prescriptionId: 7),
        extra: [
          planNoteProvider.overrideWith((ref, id) async => 'Rest-pause 2×10'),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Rest-pause 2×10'), findsOneWidget);
      expect(find.text('Slow negatives'), findsOneWidget);
    });

    testWidgets('shows nothing when there are no notes', (tester) async {
      await tester.pumpWidget(app(
        ExerciseNotes(exercise: exercise(), prescriptionId: 7),
        extra: [planNoteProvider.overrideWith((ref, id) async => '  ')],
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notes), findsNothing);
    });

    testWidgets('prefixes the name inside a superset', (tester) async {
      await tester.pumpWidget(app(
        ExerciseNotes(
            exercise: exercise(notes: 'Slow'),
            prescriptionId: null,
            showName: true),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Bench: Slow'), findsOneWidget);
    });
  });
}
