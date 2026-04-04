import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../models/task_model.dart';
import 'task_form_screen.dart';

class GraphScreen extends StatefulWidget {
  final List<Task> tasks;
  const GraphScreen({super.key, required this.tasks});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Map<int, Offset> _positions = {};
  Map<int, Color> _pathColors = {};
  
  static const double canvasWidth = 5000;
  static const double canvasHeight = 5000;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _calculateGraphPhysics();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _calculateGraphPhysics() {
    Map<int, int> depths = {};
    Map<int, Offset> positions = {};
    Map<int, Color> pathColors = {};

    int getDepth(Task t) {
      if (depths.containsKey(t.id)) return depths[t.id]!;
      if (t.blockedById == null) return 0;
      try {
        final parent = widget.tasks.firstWhere((p) => p.id == t.blockedById);
        int d = getDepth(parent) + 1;
        depths[t.id] = d; 
        return d;
      } catch (e) { 
        return 0; 
      }
    }

    Map<int, int> rowCounter = {};
    for (var t in widget.tasks) {
      int d = getDepth(t);
      int r = rowCounter[d] ?? 0;
      rowCounter[d] = r + 1;

      double x = 800.0 + (d * 550.0);
      double y = 2000.0 + (math.sin(d * 1.6) * 400.0) + (r * 250.0);
      positions[t.id] = Offset(x, y);

      if (t.blockedById != null) {
        try {
          final parent = widget.tasks.firstWhere((p) => p.id == t.blockedById);
          pathColors[t.id] = (parent.status == 'Done') ? Colors.cyanAccent : Colors.white12;
        } catch (_) { 
          pathColors[t.id] = Colors.white12; 
        }
      }
    }
    setState(() {
      _positions = positions;
      _pathColors = pathColors;
    });
  }

  void _showQuestDetailModal(Task task) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isPast = DateTime.parse(task.dueDate).toLocal().isBefore(DateTime.now()) && task.status != 'Done';
        return Container(
          height: MediaQuery.of(context).size.height * 0.80,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(32),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("REF ID: ${task.id}", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        _buildStatusTag(task.status),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(task.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text("DEADLINE: ${_formatDisplayDate(task.dueDate)}", 
                         style: TextStyle(color: isPast ? Colors.redAccent : Colors.white60, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    const Text("MISSION BRIEFING", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text(task.description.isEmpty ? "No detailed logs found." : task.description, 
                         style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TaskFormScreen(taskToEdit: task, allTasks: widget.tasks)));
                    },
                    child: const Text("ACCESS LOGS / EDIT", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: const Text("JOURNEY CARTOGRAPHY", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 14)),
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(2500),
        minScale: 0.1, maxScale: 2.0,
        child: SizedBox(
          width: canvasWidth, height: canvasHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: JourneyPathsPainter(
                    tasks: widget.tasks,
                    positions: _positions,
                    pathColors: _pathColors,
                    animationValue: _controller,
                  ),
                ),
              ),
              ...widget.tasks.map((task) {
                final pos = _positions[task.id];
                if (pos == null) return const SizedBox.shrink();
                return Positioned(
                  left: pos.dx - 110, top: pos.dy - 50,
                  child: _buildQuestNode(task),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestNode(Task task) {
    bool isDone = task.status == "Done";
    bool isActive = task.status == "In Progress";
    Color color = isDone ? Colors.greenAccent : (isActive ? Colors.cyanAccent : Colors.white24);

    return GestureDetector(
      onTap: () => _showQuestDetailModal(task),
      child: Container(
        width: 220, height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isActive ? 0.8 : 0.2), width: isActive ? 2 : 1),
          boxShadow: [if (isActive) BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("ID: ${task.id}", style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, 
                 style: TextStyle(color: isDone ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(isDone ? Icons.check_circle : Icons.circle_outlined, size: 12, color: color),
                const SizedBox(width: 4),
                Text(task.status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDisplayDate(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return "${d.month}/${d.day} @ ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildStatusTag(String status) {
    Color col = status == "Done" ? Colors.greenAccent : (status == "In Progress" ? Colors.cyanAccent : Colors.white38);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}

class JourneyPathsPainter extends CustomPainter {
  final List<Task> tasks;
  final Map<int, Offset> positions;
  final Map<int, Color> pathColors;
  final Animation<double> animationValue;

  JourneyPathsPainter({required this.tasks, required this.positions, required this.pathColors, required this.animationValue}) : super(repaint: animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.02)..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 150) { canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint); }
    for (double i = 0; i < size.height; i += 150) { canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint); }

    for (var t in tasks) {
      if (t.blockedById != null && positions.containsKey(t.blockedById) && positions.containsKey(t.id)) {
        final start = positions[t.blockedById]!;
        final end = positions[t.id]!;
        final color = pathColors[t.id] ?? Colors.white10;

        final path = Path()..moveTo(start.dx, start.dy);
        path.cubicTo(start.dx + 200, start.dy, end.dx - 200, end.dy, end.dx, end.dy);

        canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = color == Colors.cyanAccent ? 3 : 1);
        
        if (color == Colors.cyanAccent) {
          for (var metric in path.computeMetrics()) {
            final tangent = metric.getTangentForOffset(metric.length * animationValue.value);
            if (tangent != null) {
              canvas.drawCircle(tangent.position, 4, Paint()..color = Colors.white);
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}