import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/task_model.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? taskToEdit;
  final int? parentTaskId; 
  final List<Task> allTasks;

  const TaskFormScreen({super.key, this.taskToEdit, this.parentTaskId, required this.allTasks});

  @override
  _TaskFormScreenState createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  bool _isAutocompleteInitialized = false; 
  
  DateTime _dueDate = DateTime.now().add(const Duration(hours: 1));
  String _status = 'To-Do';
  int? _blockedById;
  String _recurring = 'None';
  String _taskType = 'Work';
  int _importance = 1;
  bool _isLoading = false;

  final List<String> _taskTypes = [
    'Work', 'Personal', 'Health', 'Finance', 'Education', 'Shopping', 'Home', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _blockedById = widget.taskToEdit?.blockedById ?? widget.parentTaskId;

    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _descController.text = t.description;
      _dueDate = DateTime.parse(t.dueDate).toLocal();
      _status = t.status;
      _recurring = t.recurring;
      _taskType = t.taskType;
      _importance = t.importance;
    } else if (widget.parentTaskId != null) {
      try {
        final parent = widget.allTasks.firstWhere((t) => t.id == widget.parentTaskId);
        final parentDate = DateTime.parse(parent.dueDate).toLocal();
        final proposedDate = parentDate.add(const Duration(hours: 2));
        
        // Ensure child isn't defaulted to the past
        _dueDate = proposedDate.isBefore(DateTime.now()) 
            ? DateTime.now().add(const Duration(hours: 1)) 
            : proposedDate;
      } catch (_) {
        _dueDate = DateTime.now().add(const Duration(hours: 1));
      }
    }
    _loadDraft();
  }

  void _showTelemetry(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.3))),
          ],
        ),
        backgroundColor: isError ? const Color(0xFF7F1D1D) : const Color(0xFF064E3B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 6,
      )
    );
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_titleController.text.isEmpty) _titleController.text = prefs.getString('draft_t') ?? '';
      if (_descController.text.isEmpty) _descController.text = prefs.getString('draft_d') ?? '';
    });
  }

  Future<void> _updateDraft() async {
    if (widget.taskToEdit == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_t', _titleController.text);
      await prefs.setString('draft_d', _descController.text);
    }
  }

  Future<void> _pickDateTime() async {
    // Determine the "Grey Out" boundary
    DateTime minBoundary = DateTime.now().subtract(const Duration(minutes: 1));
    if (_blockedById != null) {
      final parentIdx = widget.allTasks.indexWhere((t) => t.id == _blockedById);
      if (parentIdx != -1) {
        minBoundary = DateTime.parse(widget.allTasks[parentIdx].dueDate).toLocal().add(const Duration(minutes: 1));
      }
    }

    DateTime tempDate = _dueDate.isBefore(minBoundary) ? minBoundary : _dueDate;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: 320, padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                const Text("Set Local Deadline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: () { setState(() => _dueDate = tempDate); Navigator.pop(context); },
                  child: const Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: tempDate,
                minimumDate: minBoundary, // Physical grey-out of past/invalid times
                onDateTimeChanged: (v) => tempDate = v,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameMinute(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day && d1.hour == d2.hour && d1.minute == d2.minute;
  }

  List<Task> _getAllDependents(int parentId, List<Task> allTasks) {
    List<Task> dependents = [];
    final directChildren = allTasks.where((t) => t.blockedById == parentId).toList();
    dependents.addAll(directChildren);
    for (var child in directChildren) {
      dependents.addAll(_getAllDependents(child.id, allTasks));
    }
    return dependents;
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      _showTelemetry("Validation Exception: Intent designation requires a valid string.");
      return;
    }

    // Absolute chronology checks
    if (widget.taskToEdit == null && _dueDate.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      _showTelemetry("Chronology Exception: Timelines cannot be initialized in a past state.");
      return;
    }

    if (_blockedById != null) {
      final parentIdx = widget.allTasks.indexWhere((t) => t.id == _blockedById);
      if (parentIdx != -1) {
        final parentDate = DateTime.parse(widget.allTasks[parentIdx].dueDate).toLocal();
        if (_isSameMinute(_dueDate, parentDate) || _dueDate.isBefore(parentDate)) {
          _showTelemetry("Dependency Constraint: Child timelines must strictly succeed their parent blocker.");
          return;
        }
      }
    }

    bool isExtension = false;
    Duration timeDelta = Duration.zero;
    if (widget.taskToEdit != null) {
      final oldDate = DateTime.parse(widget.taskToEdit!.dueDate).toLocal();
      if (_dueDate.isAfter(oldDate)) {
        isExtension = true;
        timeDelta = _dueDate.difference(oldDate);
      }
    }

    setState(() => _isLoading = true);
    final payload = {
      "title": _titleController.text.trim(),
      "description": _descController.text,
      "due_date": _dueDate.toUtc().toIso8601String(),
      "status": _status,
      "blocked_by_id": _blockedById,
      "recurring": _recurring,
      "sort_order": widget.taskToEdit?.sortOrder ?? 0,
      "task_type": _taskType,
      "importance": _importance
    };

    try {
      final url = widget.taskToEdit == null ? 'http://127.0.0.1:8000/tasks' : 'http://127.0.0.1:8000/tasks/${widget.taskToEdit!.id}';
      final response = widget.taskToEdit == null 
          ? await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
          : await http.put(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));

      if (response.statusCode == 200) {
        if (isExtension) {
          _showTelemetry("Chronology Sync: Parent delayed. Cascading updates to dependents...", isError: false);
          List<Task> dependents = _getAllDependents(widget.taskToEdit!.id, widget.allTasks);
          for (var child in dependents) {
            final childNewDate = DateTime.parse(child.dueDate).toLocal().add(timeDelta);
            final childPayload = {
              "title": child.title, "description": child.description,
              "due_date": childNewDate.toUtc().toIso8601String(),
              "status": child.status, "blocked_by_id": child.blockedById,
              "recurring": child.recurring, "sort_order": child.sortOrder,
              "task_type": child.taskType, "importance": child.importance
            };
            await http.put(Uri.parse('http://127.0.0.1:8000/tasks/${child.id}'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(childPayload));
          }
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('draft_t'); await prefs.remove('draft_d');
        if (mounted) Navigator.pop(context);
      } else {
        final err = jsonDecode(response.body)['detail'];
        _showTelemetry("Server Exception: $err");
      }
    } catch (e) {
      _showTelemetry("Network Exception: Workspace engine unreachable.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label, prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.taskToEdit == null ? (widget.parentTaskId != null ? "Spawn Child Task" : "Create New Intent") : "Edit ID: ${widget.taskToEdit!.id}", style: const TextStyle(fontWeight: FontWeight.w900)),
        elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(controller: _titleController, decoration: _deco("Task Title", Icons.title), onChanged: (_) => _updateDraft()),
            const SizedBox(height: 16),
            TextField(controller: _descController, maxLines: 3, decoration: _deco("Description", Icons.notes), onChanged: (_) => _updateDraft()),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: DropdownButtonFormField<String>(value: _taskType, decoration: _deco("Category", Icons.folder_outlined), items: _taskTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _taskType = v!))),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<int>(value: _importance, decoration: _deco("Importance", Icons.priority_high), items: [1,2,3,4].map((e) => DropdownMenuItem(value: e, child: Text("Level $e"))).toList(), onChanged: (v) => setState(() => _importance = v!))),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDateTime, borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue[200]!)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.blueAccent), const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("DEADLINE (LOCAL TIMEZONE)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)), Text("${_dueDate.toLocal()}".split('.')[0], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.blueAccent))]),
                    const Spacer(), const Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _status, decoration: _deco("Initial Status", Icons.flag_outlined), items: ['To-Do', 'In Progress', 'Done'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _status = v!)),
            const SizedBox(height: 16),
            Autocomplete<Task>(
              displayStringForOption: (Task option) => "ID: ${option.id} - ${option.title}",
              optionsBuilder: (TextEditingValue textEditingValue) {
                final eligibleTasks = widget.allTasks.where((t) => t.id != widget.taskToEdit?.id);
                if (textEditingValue.text.isEmpty) return eligibleTasks;
                return eligibleTasks.where((t) => t.title.toLowerCase().contains(textEditingValue.text.toLowerCase()) || t.id.toString().contains(textEditingValue.text));
              },
              onSelected: (Task selection) { 
                setState(() {
                  _blockedById = selection.id; 
                  final parentDate = DateTime.parse(selection.dueDate).toLocal();
                  if (_dueDate.isBefore(parentDate.add(const Duration(minutes: 1)))) {
                    _dueDate = parentDate.add(const Duration(hours: 2));
                    _showTelemetry("Chronology Auto-Sync: Deadline shifted to resolve parent conflict.", isError: false);
                  }
                });
                FocusManager.instance.primaryFocus?.unfocus(); 
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (!_isAutocompleteInitialized && _blockedById != null) {
                  try {
                    final parent = widget.allTasks.firstWhere((t) => t.id == _blockedById);
                    controller.text = "ID: ${parent.id} - ${parent.title}";
                  } catch (_) { controller.text = "ID: $_blockedById"; }
                  _isAutocompleteInitialized = true; 
                }
                return TextField(
                  controller: controller, focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: "Search Parent Blocker", prefixIcon: const Icon(Icons.lock_outline, color: Colors.redAccent),
                    suffixIcon: controller.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { controller.clear(); setState(() => _blockedById = null); }) : null,
                    filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                  ),
                  onChanged: (v) { if (v.trim().isEmpty) setState(() => _blockedById = null); },
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _recurring, decoration: _deco("Auto-Repeat Engine", Icons.sync_rounded), items: ['None', 'Daily', 'Weekly', 'Monthly', 'Yearly'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _recurring = v!)),
            const SizedBox(height: 40),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                onPressed: _isLoading ? null : _saveTask,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("AUTHENTICATE & SAVE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}