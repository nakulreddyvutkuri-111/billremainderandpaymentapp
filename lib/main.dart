import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const BillApp());

class BillApp extends StatelessWidget {
  const BillApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bill Reminder & Payment',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E9AA7)),
          useMaterial3: true,
        ),
        home: const HomePage(),
      );
}

// ---------------- Model ----------------
class Bill {
  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.due,
    required this.category,
    required this.remindDays,
    this.paid = false,
    this.method,
  });

  final int id;
  final String name, category;
  final double amount;
  final DateTime due;
  final int remindDays;
  bool paid;
  String? method;

  int get daysLeft {
    final t = DateTime.now();
    return DateTime.utc(due.year, due.month, due.day)
        .difference(DateTime.utc(t.year, t.month, t.day))
        .inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'due': due.toIso8601String(),
        'category': category,
        'remindDays': remindDays,
        'paid': paid,
        'method': method,
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'],
        name: j['name'],
        amount: (j['amount'] as num).toDouble(),
        due: DateTime.parse(j['due']),
        category: j['category'],
        remindDays: j['remindDays'],
        paid: j['paid'],
        method: j['method'],
      );
}

// ---------------- Storage ----------------
class BillStore {
  static Future<List<Bill>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('bills');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Bill.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<Bill> bills) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'bills', jsonEncode(bills.map((b) => b.toJson()).toList()));
  }
}

// ---------------- Home screen ----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Bill> bills = [];
  bool showPaid = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await BillStore.load();
    if (mounted) setState(() => bills = b);
  }

  Future<void> _save() => BillStore.save(bills);

  String inr(double v) => '\u20B9${v.toStringAsFixed(0)}';

  String statusText(Bill b) {
    final d = b.daysLeft;
    if (d < 0) return 'Overdue ${-d}d';
    if (d == 0) return 'Due today';
    return 'Due in ${d}d';
  }

  Color statusColor(Bill b) {
    if (b.paid) return Colors.green.shade700;
    final d = b.daysLeft;
    if (d < 0) return Colors.red.shade700;
    if (d <= 3) return const Color(0xFFC2410C);
    return const Color(0xFF0E9AA7);
  }

  @override
  Widget build(BuildContext context) {
    final due = bills.where((b) => !b.paid).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    final paid = bills.where((b) => b.paid).toList();
    final reminders =
        due.where((b) => b.daysLeft <= b.remindDays).toList();
    final week = due
        .where((b) => b.daysLeft <= 7)
        .fold<double>(0, (s, b) => s + b.amount);
    final overdue = due.where((b) => b.daysLeft < 0).length;
    final paidTotal = paid.fold<double>(0, (s, b) => s + b.amount);
    final shown = showPaid ? paid : due;

    return Scaffold(
      appBar: AppBar(title: const Text('Bill Reminder & Payment')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBill,
        icon: const Icon(Icons.add),
        label: const Text('Add bill'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summary(week, overdue, paidTotal),
          const SizedBox(height: 8),
          for (final b in reminders) _reminderBanner(b),
          const SizedBox(height: 8),
          Row(children: [
            ChoiceChip(
              label: const Text('Upcoming'),
              selected: !showPaid,
              onSelected: (_) => setState(() => showPaid = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Paid history'),
              selected: showPaid,
              onSelected: (_) => setState(() => showPaid = true),
            ),
          ]),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Nothing here yet')),
            ),
          for (final b in shown) _billTile(b),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _summary(double week, int overdue, double paidTotal) {
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    color: Color(0xFFF5A524),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: Color(0xFFCADCFC), fontSize: 12)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F3A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        stat(inr(week), 'Due this week'),
        stat('$overdue', 'Overdue'),
        stat(inr(paidTotal), 'Paid'),
      ]),
    );
  }

  Widget _reminderBanner(Bill b) => Card(
        color: const Color(0xFFFDECE3),
        child: ListTile(
          leading: const Icon(Icons.alarm, color: Color(0xFFC2410C)),
          title: Text('${b.name} ${inr(b.amount)}',
              style: const TextStyle(color: Color(0xFF7C2D12))),
          subtitle: Text(statusText(b),
              style: const TextStyle(color: Color(0xFF7C2D12))),
        ),
      );

  Widget _billTile(Bill b) => Card(
        child: ListTile(
          onLongPress: () => _delete(b),
          leading: CircleAvatar(
            backgroundColor: statusColor(b),
            child: Text(b.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white)),
          ),
          title: Text(b.name),
          subtitle: Text(b.paid
              ? 'Paid via ${b.method ?? 'UPI'}'
              : '${b.category} \u00B7 ${statusText(b)}'),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(inr(b.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (!b.paid) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _pay(b),
                    child: const Text('Pay'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  void _delete(Bill b) {
    setState(() => bills.remove(b));
    _save();
  }

  void _addBill() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddBillSheet(onSave: (b) {
        setState(() => bills.add(b));
        _save();
      }),
    );
  }

  void _pay(Bill b) {
    var method = 'UPI';
    const modes = ['UPI', 'Card', 'Net Banking'];
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Pay ${b.name}'),
          content: Wrap(spacing: 8, children: [
            for (final m in modes)
              ChoiceChip(
                label: Text(m),
                selected: method == m,
                onSelected: (_) => setD(() => method = m),
              ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() {
                  b.paid = true;
                  b.method = method;
                });
                await _save();
              },
              child: Text('Pay ${inr(b.amount)}'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Add bill sheet ----------------
class AddBillSheet extends StatefulWidget {
  const AddBillSheet({super.key, required this.onSave});
  final void Function(Bill) onSave;

  @override
  State<AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<AddBillSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 3));
  String _cat = 'Utility';
  int _remind = 1;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _due = d);
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    widget.onSave(Bill(
      id: DateTime.now().millisecondsSinceEpoch,
      name: _name.text.trim(),
      amount: double.parse(_amount.text),
      due: DateTime(_due.year, _due.month, _due.day),
      category: _cat,
      remindDays: _remind,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add a bill',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Bill name', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Amount (\u20B9)', border: OutlineInputBorder()),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return (n == null || n <= 0) ? 'Enter a valid amount' : null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text('Due date: ${_due.day}/${_due.month}/${_due.year}'),
              trailing: TextButton(
                  onPressed: _pickDate, child: const Text('Change')),
            ),
            DropdownButtonFormField<String>(
              initialValue: _cat,
              decoration: const InputDecoration(
                  labelText: 'Category', border: OutlineInputBorder()),
              items: ['Utility', 'Rent', 'Loan', 'Credit Card', 'Other']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _cat = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _remind,
              decoration: const InputDecoration(
                  labelText: 'Remind me', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 day before')),
                DropdownMenuItem(value: 3, child: Text('3 days before')),
                DropdownMenuItem(value: 7, child: Text('7 days before')),
              ],
              onChanged: (v) => setState(() => _remind = v!),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _submit, child: const Text('Save bill')),
            ),
          ]),
        ),
      ),
    );
  }
}
