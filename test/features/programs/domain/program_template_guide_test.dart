import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/programs/domain/program_template.dart';
import 'package:prforge/features/programs/domain/program_template_guide.dart';

void main() {
  test('the sample in the guide is a valid program file', () {
    final template = parseProgramTemplate(programTemplateSample);
    expect(template.name, 'Push Pull Legs');
    expect(template.days, hasLength(2));
    expect(
      template.days.first.entries.whereType<TemplateSuperset>(),
      hasLength(1),
    );
  });

  test('the guide contains the sample and names every set type', () {
    expect(programTemplateGuide, contains(programTemplateSample));
    for (final type in ['normal', 'warmup', 'drop', 'restPause', 'amrap']) {
      expect(programTemplateGuide, contains('"$type"'));
    }
  });
}
