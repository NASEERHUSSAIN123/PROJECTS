import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/task_model.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Task> _archiveTasks = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchArchive();
  }

  Future<void> _fetchArchive() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/tasks'));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _archiveTasks = data
              .map((t) => Task.fromJson(t))
              .where((t) => t.status == "Done")
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      _showTelemetry("Network Exception: Workspace engine unreachable.");
      setState(() => _isLoading = false);
    }
  }

  // --- REFINED TELEMETRY ENGINE ---
  void _showTelemetry(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, 
              color: Colors.white, 
              size: 20
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message, 
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)
              )
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFF7F1D1D) : const Color(0xFF064E3B),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredArchive = _archiveTasks
        .where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Vault Archive", style: TextStyle(fontWeight: FontWeight.w900)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchArchive,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search archived intents...",
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : filteredArchive.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredArchive.length,
                        itemBuilder: (context, index) => _buildArchiveCard(filteredArchive[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? "Archive Vault Empty" : "No matching intents found",
            style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveCard(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 6, color: Colors.grey[400]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ID: ${task.id} • v${task.version}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 4),
                    Text(
                      task.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, decoration: TextDecoration.lineThrough, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.indigo),
              onPressed: () => _restoreTask(task),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () => _confirmDelete(task),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreTask(Task task) async {
    _showTelemetry("State Sync: Restoring intent to workspace...", isError: false);
    
    // FIX: Instead of task.status = "To-Do", we modify the JSON payload
    final Map<String, dynamic> updateData = task.toJson();
    updateData['status'] = "To-Do";

    try {
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/tasks/${task.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        _fetchArchive();
      }
    } catch (e) {
      _showTelemetry("Server Fault: Restoration failed.");
    }
  }

  Future<void> _confirmDelete(Task task) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permanent Purge"),
        content: const Text("This action will remove the intent from the database permanently."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTask(task.id);
            },
            child: const Text("PURGE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(int id) async {
    try {
      final response = await http.delete(Uri.parse('http://127.0.0.1:8000/tasks/$id'));
      if (response.statusCode == 200) {
        _fetchArchive();
        _showTelemetry("State Sync: Intent purged.", isError: false);
      }
    } catch (e) {
      _showTelemetry("Server Fault: Purge operation failed.");
    }
  }
}