import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/task_model.dart';

import 'screens/dashboard_screen.dart'; 

void main() {
  runApp(const FlodoEnterpriseApp());
}

class FlodoEnterpriseApp extends StatelessWidget {
  const FlodoEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flodo Enterprise Task Manager',
      debugShowCheckedModeBanner: false,
      
      // ENTERPRISE SLATE THEME INJECTION
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF0F172A), // Deep Slate
        scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Light Gray Background
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF0F172A),
          secondary: Colors.blueAccent,
        ),
      ),
      
      // ROUTING FIX: Directs the app to launch the Dashboard first
      home: const DashboardScreen(),
    );
  }
}


class TaskFormScreen extends StatefulWidget {
  final Task? taskToEdit;
  final int? parentTaskId; // Captured from Dashboard "Spawn Child"
  final List<Task> allTasks;

  const TaskFormScreen({super.key, this.taskToEdit, this.parentTaskId, required this.allTasks});

  @override
  _TaskFormScreenState createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  // Notice: NO TEXT CONTROLLER FOR THE BLOCKER. We use pure state.
  
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
    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _descController.text = t.description;
      _dueDate = DateTime.parse(t.dueDate).toLocal();
      _status = t.status;
      _blockedById = t.blockedById;
      _recurring = t.recurring;
      _taskType = t.taskType;
      _importance = t.importance;
    } else if (widget.parentTaskId != null) {
      _blockedById = widget.parentTaskId; // Directly capture the ID
      _loadDraft();
    } else {
      _loadDraft();
    }
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
    DateTime tempDate = _dueDate;
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
                initialDateTime: _dueDate.isBefore(DateTime.now()) ? DateTime.now().add(const Duration(minutes: 5)) : _dueDate,
                minimumDate: DateTime.now().subtract(const Duration(minutes: 1)),
                onDateTimeChanged: (v) => tempDate = v,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to safely get parent title for the UI
  String _getParentTitle(int id) {
    try {
      return widget.allTasks.firstWhere((t) => t.id == id).title;
    } catch (_) {
      return "Title Pending";
    }
  }

  void _openBlockerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final eligibleTasks = widget.allTasks.where((t) => t.id != widget.taskToEdit?.id).toList();
            final filteredTasks = eligibleTasks.where((t) => 
              t.title.toLowerCase().contains(searchQuery.toLowerCase()) || 
              t.id.toString().contains(searchQuery)
            ).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    child: Column(
                      children: [
                        Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                        const SizedBox(height: 16),
                        const Text("Select Parent Task", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 16),
                        TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "Search by ID or Title...",
                            prefixIcon: const Icon(Icons.search),
                            filled: true, fillColor: Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) => setModalState(() => searchQuery = v),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTasks.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            leading: const Icon(Icons.clear, color: Colors.red),
                            title: const Text("Clear Selection / No Blocker", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            onTap: () {
                              setState(() => _blockedById = null);
                              Navigator.pop(context);
                            },
                          );
                        }
                        final t = filteredTasks[index - 1];
                        return Card(
                          elevation: 0, color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.blue[50], child: Text("${t.id}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))),
                            title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Status: ${t.status}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            onTap: () {
                              setState(() => _blockedById = t.id);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  bool _isSameMinute(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day && d1.hour == d2.hour && d1.minute == d2.minute;
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Title is required"), backgroundColor: Colors.red[900]));
      return;
    }

    if (_blockedById != null) {
      try {
        final parent = widget.allTasks.firstWhere((t) => t.id == _blockedById);
        if (_isSameMinute(_dueDate, DateTime.parse(parent.dueDate).toLocal())) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Conflict: Deadline cannot exactly match the Blocker's deadline."), backgroundColor: Colors.red[900]));
          return;
        }
      } catch (_) {}
    }

    if (widget.taskToEdit != null) {
      final children = widget.allTasks.where((t) => t.blockedById == widget.taskToEdit!.id);
      for (var child in children) {
        if (_isSameMinute(_dueDate, DateTime.parse(child.dueDate).toLocal())) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Conflict: Deadline matches child task ID: ${child.id}."), backgroundColor: Colors.red[900]));
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    final payload = {
      "title": _titleController.text,
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('draft_t'); await prefs.remove('draft_d');
        if (mounted) Navigator.pop(context);
      } else {
        final err = jsonDecode(response.body)['detail'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ERROR: $err"), backgroundColor: Colors.red[900]));
      }
    } catch (e) {
      debugPrint("Save Error: $e");
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
            TextField(controller: _descController, maxLines: 3, decoration: _deco("Description (Optional)", Icons.notes), onChanged: (_) => _updateDraft()),
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
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue[200]!)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("DEADLINE (LOCAL TIMEZONE)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        Text("${_dueDate.toLocal()}".split('.')[0], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _status, decoration: _deco("Initial Status", Icons.flag_outlined),
              items: ['To-Do', 'In Progress', 'Done'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 16),

            // THE PURE STATE BLOCKER SELECTOR - Physically impossible to fail if _blockedById != null
            InkWell(
              onTap: _openBlockerPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: _blockedById != null ? Colors.indigo : Colors.redAccent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Parent ID / Blocker", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text(
                            _blockedById != null ? "ID: $_blockedById - ${_getParentTitle(_blockedById!)}" : "No Blocker Selected (Tap to Search)",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _blockedById != null ? Colors.indigo : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.search, color: Colors.blueGrey, size: 20),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _recurring, decoration: _deco("Auto-Repeat Engine", Icons.sync_rounded),
              items: ['None', 'Daily', 'Weekly', 'Monthly', 'Yearly'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _recurring = v!),
            ),

            const SizedBox(height: 40),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _saveTask,
                child: _isLoading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                  : const Text("AUTHENTICATE & SAVE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}