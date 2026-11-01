/// A complete, valid program file (the importer accepts it as is).
const programTemplateSample = '''{
  "format": "prforge-program",
  "version": 1,
  "name": "Push Pull Legs",
  "days": [
    {
      "name": "Push",
      "entries": [
        {"exercise": "Bench Press", "sets": 4, "reps": 8, "weightKg": 60,
         "restSeconds": 120, "notes": "Pause 1 s on the chest"},
        {"exercise": "Incline Dumbbell Press", "sets": 3,
         "repScheme": [12, 10, 8], "weightKg": 22.5},
        {"exercise": "Cable Fly", "sets": 2, "reps": 12, "weightKg": 15,
         "type": "restPause"},
        {"rounds": 3, "superset": [
          {"exercise": "Lateral Raise", "reps": 15, "weightKg": 8},
          {"exercise": "Triceps Pushdown", "reps": 12, "weightKg": 25}
        ]}
      ]
    },
    {
      "name": "Pull",
      "entries": [
        {"exercise": "Pull-up", "sets": 3, "reps": 8},
        {"exercise": "Barbell Row", "sets": 3, "reps": 10, "weightKg": 50}
      ]
    }
  ]
}''';

/// Text copied from Settings > Import program: the file format and a sample,
/// written so it can also be pasted into an AI assistant to get a new program.
const programTemplateGuide = '''PRForge program file (JSON)

Write ONE valid JSON object and nothing else (no comments, no trailing commas). Save it as a .json file and import it in PRForge: Settings > Import program.

Structure
- "format": always "prforge-program"
- "version": always 1
- "name": program name (1-100 characters)
- "days": list of days (at least 1)
  - "name": day name, e.g. "Push"
  - "entries": exercises of the day in order (at least 1). Each entry is a single exercise or a superset.

Single exercise entry
- "exercise": name (required, 1-100 characters)
- "sets": number of sets, whole number >= 1 (required)
- "reps": target reps, whole number >= 1 (optional)
- "repScheme": reps per set, e.g. [12, 10, 8, 8] (optional; use instead of "reps")
- "weightKg": target weight in kg, >= 0 (optional; leave out for bodyweight)
- "type": "normal" (default), "warmup", "drop", "restPause" or "amrap" (optional)
- "restSeconds": rest after each set in seconds, >= 0 (optional)
- "notes": free text note (optional)

Superset entry
- "rounds": number of rounds, whole number >= 1 (required)
- "superset": list of 2 or more exercises. Each one has the same fields as a single exercise except "sets" (the rounds are the sets).

Notes
- Exercises are matched to existing ones by name (case and extra spaces are ignored); unknown names are created.
- Importing adds a new program and never changes or deletes existing data.

Sample
```json
$programTemplateSample
```
''';
