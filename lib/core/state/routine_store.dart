import 'package:flutter/foundation.dart';

import '../models/routine_template.dart';

/// Routine templates (modules). Separate from schedule instances.
class RoutineStore extends ChangeNotifier {
  final List<RoutineTemplate> _templates;
  int _counter = 0;

  RoutineStore(Iterable<RoutineTemplate> initial) : _templates = [...initial];

  List<RoutineTemplate> get templates => List.unmodifiable(_templates);

  String newId() =>
      'routine-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  void save(RoutineTemplate template) {
    final i = _templates.indexWhere((t) => t.id == template.id);
    if (i < 0) {
      _templates.add(template);
    } else {
      _templates[i] = template;
    }
    notifyListeners();
  }

  RoutineTemplate duplicate(RoutineTemplate template) {
    final copy = template.copyWith(id: newId(), name: '${template.name} (copy)');
    _templates.add(copy);
    notifyListeners();
    return copy;
  }

  void remove(String id) {
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
