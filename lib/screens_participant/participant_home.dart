import 'dart:async';
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
  bool _isFocusMode = true; // Default to calming "Now & Next" view
  bool _showDonePouch = false;

  // Gentle Visual Timer State
  Timer? _timer;
  bool _timerRunning = false;
  int _elapsedSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timer?.cancel();
      setState(() => _timerRunning = false);
    } else {
      setState(() => _timerRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsedSeconds++);
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _elapsedSeconds = 0;
    });
  }

  void _openAiRoutineModal() {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFFBF9F5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF8875B8)),
              SizedBox(width: 10),
              Text(
                'Create My Routine',
                style: TextStyle(
                  color: Color(0xFF2D3748),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write your steps in your own words. We will turn them into calm visual cards:',
                style: TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'e.g., Wake up, wash face, put on jacket, eat breakfast...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF718096))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8875B8),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Build Visual Steps'),
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
      backgroundColor: const Color(0xFFF5F3EF), // Warm calming oat background
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              // 1. Top Calming Mode Switcher (Now & Next vs Full Day)
              _buildViewModeSelector(),
              const SizedBox(height: 20),

              // 2. Main Content Area
              if (activeTasks.isEmpty)
                _buildAllDoneCelebration()
              else if (_isFocusMode)
                _buildNowAndNextView(activeTasks)
              else
                ...activeTasks.map((item) => _buildRoutineCard(item, isHero: false)),

              const SizedBox(height: 12),

              // 3. Soft Collapsible "Done Pouch" at the bottom
              if (completedTasks.isNotEmpty) _buildDonePouch(completedTasks),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 2,
        backgroundColor: const Color(0xFF8875B8),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: _openAiRoutineModal,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text(
          'Add My Routine',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
    );
  }

  /// Segmented pill toggle inspired by MyVisualRoutine
  Widget _buildViewModeSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E4DC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isFocusMode = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isFocusMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isFocusMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.spa_rounded,
                      size: 18,
                      color: _isFocusMode
                          ? const Color(0xFF4A7C59)
                          : const Color(0xFF718096),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Now & Next (Calm Focus)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _isFocusMode
                            ? const Color(0xFF2D3748)
                            : const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isFocusMode = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isFocusMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: !_isFocusMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.view_agenda_rounded,
                      size: 18,
                      color: !_isFocusMode
                          ? const Color(0xFF5B8FB9)
                          : const Color(0xFF718096),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Full Day (${widget.schedule.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: !_isFocusMode
                            ? const Color(0xFF2D3748)
                            : const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// First / Then ("NOW" and "NEXT") layout
  Widget _buildNowAndNextView(List<ScheduleItem> activeTasks) {
    final currentTask = activeTasks.first;
    final nextTask = activeTasks.length > 1 ? activeTasks[1] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NOW Header Pill
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Color(currentTask.colorHex).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'HAPPENING NOW',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(currentTask.colorHex),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Hero "NOW" Card
        _buildRoutineCard(currentTask, isHero: true),

        // "UP NEXT" Preview Card (Reduces transition anxiety)
        if (nextTask != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'UP NEXT (THEN)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Colors.blueGrey.shade500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F5),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Color(nextTask.colorHex).withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(nextTask.colorHex).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.network(
                    nextTask.pictogramUrl,
                    width: 48,
                    height: 48,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.schedule_rounded,
                      size: 48,
                      color: Color(nextTask.colorHex),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextTask.timeRange,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(nextTask.colorHex),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextTask.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${nextTask.locationName} • ${nextTask.staffName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Calming MyVisualRoutine Activity Card
  Widget _buildRoutineCard(ScheduleItem item, {required bool isHero}) {
    final accentColor = Color(item.colorHex);
    final totalMinutes = item.subSteps.isEmpty
        ? 15
        : item.subSteps.fold<int>(0, (sum, s) => sum + s.durationMin);
    final completedSteps = item.subSteps.where((s) => s.isDone).length;
    final stepProgress =
        item.subSteps.isEmpty ? 0.0 : completedSteps / item.subSteps.length;

    // Visual timer calculation
    final totalSeconds = totalMinutes * 60;
    final timerProgress = (_elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
    final remainingMin = ((totalSeconds - _elapsedSeconds) / 60).ceil().clamp(0, 999);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.45),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Soft Top Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gentle Schedule Change Notice (No alarming bright red)
                if (item.isModifiedAlert)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE6C875)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wb_sunny_outlined, color: Color(0xFFB7791F)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Gentle Update: Today you are with ${item.staffName} in ${item.locationName}.',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF744210),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Large Pictogram Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Image.network(
                        item.pictogramUrl,
                        width: isHero ? 80 : 60,
                        height: isHero ? 80 : 60,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_outlined,
                          size: isHero ? 80 : 60,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.timeRange,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: isHero ? 22 : 19,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2D3748),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildInfoChip(Icons.place_outlined, item.locationName),
                              _buildInfoChip(Icons.person_outline, item.staffName),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Interactive Calming Visual Timer (Shown on Hero Card)
                if (isHero) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 20, color: accentColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Visual Time Remaining: ~$remainingMin min',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4A5568),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: accentColor,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: _toggleTimer,
                                  icon: Icon(
                                    _timerRunning
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                  ),
                                  label: Text(_timerRunning ? 'Pause' : 'Start Timer'),
                                ),
                                if (_elapsedSeconds > 0)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    onPressed: _resetTimer,
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _timerRunning || _elapsedSeconds > 0
                                ? timerProgress
                                : stepProgress,
                            minHeight: 12,
                            backgroundColor: const Color(0xFFEDF2F7),
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Tactile Step-by-Step Cards (MyVisualRoutine style)
                if (item.subSteps.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'STEPS TO FOLLOW',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF718096),
                        ),
                      ),
                      Text(
                        '$completedSteps of ${item.subSteps.length} done',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...item.subSteps.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final step = entry.value;
                    return GestureDetector(
                      onTap: () => setState(() => step.isDone = !step.isDone),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: step.isDone
                              ? const Color(0xFFEBF7F2) // Soft mint when done
                              : const Color(0xFFF9F8F6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: step.isDone
                                ? const Color(0xFF68A691)
                                : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: step.isDone
                                    ? const Color(0xFF5E9A82)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: step.isDone
                                      ? const Color(0xFF5E9A82)
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: step.isDone
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        '$idx',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4A5568),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                step.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: step.isDone
                                      ? const Color(0xFF4A7C59)
                                      : const Color(0xFF2D3748),
                                  decoration: step.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${step.durationMin} min',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Calm, Tactile "Move to Done Pouch" Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E9A82), // Soothing Sage
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text(
                      'All Finished • Put in Done Pouch',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    onPressed: () {
                      _resetTimer();
                      setState(() => item.isCompleted = true);
                      widget.onScheduleChanged();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF4A5568)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            ),
          ),
        ],
      ),
    );
  }

  /// Gentle Done Pouch at the bottom of the board
  Widget _buildDonePouch(List<ScheduleItem> completedTasks) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2EE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF5E9A82).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            onTap: () => setState(() => _showDonePouch = !_showDonePouch),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5E9A82),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            ),
            title: Text(
              'Done Pouch (${completedTasks.length} completed today)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF285E48),
              ),
            ),
            trailing: Icon(
              _showDonePouch ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF285E48),
            ),
          ),
          if (_showDonePouch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: completedTasks
                    .map(
                      (item) => Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF5E9A82),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${item.timeRange} • ${item.title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.lineThrough,
                                  color: Color(0xFF4A5568),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllDoneCelebration() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        children: [
          Icon(Icons.spa_rounded, size: 64, color: Color(0xFF5E9A82)),
          SizedBox(height: 16),
          Text(
            'Your Schedule Is Complete!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'All activities are safely tucked into your Done Pouch. Enjoy your rest time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF718096)),
          ),
        ],
      ),
    );
  }
}