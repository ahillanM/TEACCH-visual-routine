import 'package:flutter/material.dart';
import '../models/schedule_item.dart';

class StaffDashboard extends StatelessWidget {
  final List<ScheduleItem> schedule;
  final VoidCallback onScheduleChanged;

  const StaffDashboard({
    super.key,
    required this.schedule,
    required this.onScheduleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Action Bar: Predefined Routine Modules
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Predefined Routine Modules (1-Click Assignment for Lukas)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.home_work),
                          label: const Text('+ Add Evening Residential Routine'),
                          onPressed: () {
                            schedule.addAll(buildEveningResidentialModule());
                            onScheduleChanged();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Evening routine synced to Lukas!'),
                              ),
                            );
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset Completed Tasks'),
                          onPressed: () {
                            for (var item in schedule) {
                              item.isCompleted = false;
                            }
                            onScheduleChanged();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Lukas\'s Active Daily Schedule (Admin Management)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: schedule.length,
                itemBuilder: (context, index) {
                  final item = schedule[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(item.colorHex),
                        child: Icon(
                          item.isCompleted ? Icons.check : Icons.schedule,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        '${item.timeRange} • ${item.title}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Location: ${item.locationName} | Staff: ${item.staffName} | Status: ${item.isCompleted ? "Completed" : "Active"}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Swap Staff / Room'),
                            onPressed: () {
                              item.staffName = 'Ms. Berger (Substitute)';
                              item.locationName = 'Room 104';
                              item.isModifiedAlert = true;
                              onScheduleChanged();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              schedule.removeAt(index);
                              onScheduleChanged();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}