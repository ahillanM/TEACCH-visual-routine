import 'package:flutter/material.dart';
import '../models/schedule_item.dart';
import '../services/ai_routine_service.dart';

class ParticipantHome extends StatefulWidget {
  final List<ScheduleItem> schedule;
  final VoidCallback onScheduleChanged;

  const ParticipantHome({
    super.key,
    required this.schedule,
    required this.onScheduleChanged,
  });

  @override
  State<ParticipantHome> createState() => _ParticipantHomeState();
}

class _ParticipantHomeState extends State<ParticipantHome> {
  void _openAiRoutineModal() {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF805AD5)),
              SizedBox(width: 8),
              Text('Build Personal Routine (AI)'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type your activities in plain text (e.g., "Wake up, wash face, get dressed, eat breakfast"):',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Wake up, brush teeth, get dressed, eat breakfast...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Generate Routine Steps'),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) return;
                      setModalState(() => isLoading = true);
                      final newItem = await AiRoutineService.generateRoutineFromText(
                        controller.text,
                      );
                      widget.schedule.add(newItem);
                      widget.onScheduleChanged();
                      if (context.mounted) Navigator.pop(ctx);
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTasks = widget.schedule.where((i) => !i.isCompleted).toList();
    final completedTasks = widget.schedule.where((i) => i.isCompleted).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // TEACCH "Done Pouch" Summary at the top
          if (completedTasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade600, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Done Pouch: ${completedTasks.length} activity(s) completed!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

          // Active TEACCH Visual Cards
          ...activeTasks.map((item) => _buildTeacchCard(item)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF805AD5),
        foregroundColor: Colors.white,
        onPressed: _openAiRoutineModal,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Add Personal Routine (AI)'),
      ),
    );
  }

  Widget _buildTeacchCard(ScheduleItem item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color(item.colorHex), width: 4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calm Schedule Change Banner
            if (item.isModifiedAlert)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Schedule Update: Today with ${item.staffName} in ${item.locationName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Header: Pictogram + Title + Time/Location/Staff
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item.pictogramUrl,
                    width: 64,
                    height: 64,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.event_note, size: 64, color: Colors.blueGrey),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(item.colorHex).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.timeRange,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(item.colorHex),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${item.locationName}  •  👤 ${item.staffName}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Sub-steps Checklist
            if (item.subSteps.isNotEmpty) ...[
              const Divider(height: 24),
              ...item.subSteps.map(
                (step) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    '${step.title} (${step.durationMin} min)',
                    style: TextStyle(
                      fontSize: 15,
                      decoration: step.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  value: step.isDone,
                  onChanged: (val) {
                    setState(() => step.isDone = val ?? false);
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Error-Proof Completion Button (Moves task to Done Pouch)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Mark Activity Done (Move to Done Pouch)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() => item.isCompleted = true);
                  widget.onScheduleChanged();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}