import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cross_file/cross_file.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

const kRed = Color(0xFFC62828);
const kDark = Color(0xFF424242);
const kGrey = Color(0xFFF1F1F1);

void main() => runApp(const DynamiqueApp());

class DynamiqueApp extends StatelessWidget {
  const DynamiqueApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dynamique Ballet Studio',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kGrey,
        colorScheme: ColorScheme.fromSeed(seedColor: kRed),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const HomePage(),
    );
  }
}

class Payment {
  double amount;
  String date;
  Payment({required this.amount, required this.date});
  Map<String, dynamic> toJson() => {'amount': amount, 'date': date};
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: j['date']?.toString() ?? '',
      );
}

class CashEntry {
  String id;
  double amount;
  String description;
  String date;
  CashEntry({required this.id, required this.amount, required this.description, required this.date});
  Map<String, dynamic> toJson() => {'id': id, 'amount': amount, 'description': description, 'date': date};
  factory CashEntry.fromJson(Map<String, dynamic> j) => CashEntry(
    id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    description: j['description']?.toString() ?? '',
    date: j['date']?.toString() ?? '',
  );
}

class ReceiptRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String date;
  final List<int> bytes;
  ReceiptRecord({required this.id, required this.studentId, required this.studentName, required this.date, required this.bytes});
  Map<String, dynamic> toJson() => {'id': id, 'studentId': studentId, 'studentName': studentName, 'date': date, 'bytes': base64Encode(bytes)};
  factory ReceiptRecord.fromJson(Map<String, dynamic> j) => ReceiptRecord(
    id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
    studentId: j['studentId']?.toString() ?? '',
    studentName: j['studentName']?.toString() ?? '',
    date: j['date']?.toString() ?? '',
    bytes: base64Decode(j['bytes']?.toString() ?? ''),
  );
}

class Discipline {
  String name;
  double fee;
  Discipline(this.name, this.fee);
  Map<String, dynamic> toJson() => {'name': name, 'fee': fee};
  factory Discipline.fromJson(Map<String, dynamic> j) => Discipline(
        j['name']?.toString() ?? '',
        (j['fee'] as num?)?.toDouble() ?? 0,
      );
}

class Student {
  String id;
  String name;
  String phone;
  String email;
  String notes;
  List<String> disciplines;
  double participation;
  double monthlyFee;
  double arrears;
  String feeMonth;
  double showCost;
  double clothesCost;
  List<Payment> payments;

  Student({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.disciplines = const [],
    this.participation = 0,
    this.monthlyFee = 0,
    this.arrears = 0,
    this.feeMonth = '',
    this.showCost = 0,
    this.clothesCost = 0,
    this.payments = const [],
  });

  double get total => participation + showCost + clothesCost;
  double get paid => payments.fold(0, (sum, p) => sum + p.amount);
  double get balance => total - paid;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'notes': notes,
        'disciplines': disciplines,
        'participation': participation,
        'monthlyFee': monthlyFee,
        'arrears': arrears,
        'feeMonth': feeMonth,
        'showCost': showCost,
        'clothesCost': clothesCost,
        'payments': payments.map((p) => p.toJson()).toList(),
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: j['name']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        notes: j['notes']?.toString() ?? '',
        disciplines: List<String>.from(j['disciplines'] ?? const []),
        participation: (j['participation'] as num?)?.toDouble() ?? 0,
        monthlyFee: (j['monthlyFee'] as num?)?.toDouble() ?? (j['participation'] as num?)?.toDouble() ?? 0,
        arrears: (j['arrears'] as num?)?.toDouble() ?? 0,
        feeMonth: j['feeMonth']?.toString() ?? '',
        showCost: (j['showCost'] as num?)?.toDouble() ?? 0,
        clothesCost: (j['clothesCost'] as num?)?.toDouble() ?? 0,
        payments: (j['payments'] as List? ?? const [])
            .map((x) => Payment.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  bool loading = true;
  final List<Student> students = [];
  final List<ReceiptRecord> receipts = [];
  final List<CashEntry> extraIncome = [];
  final List<CashEntry> expenses = [];
  final List<Map<String, dynamic>> monthlyReports = [];
  final List<Discipline> disciplines = [
    Discipline('Danza classica', 0),
    Discipline('Danza moderna', 0),
    Discipline('Hip Hop', 0),
    Discipline('Contemporaneo', 0),
    Discipline('Salsa New York', 0),
    Discipline('Salsa cubana', 0),
    Discipline('Bachata', 0),
    Discipline('Hells', 0),
    Discipline('Aerial Hoop', 0),
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final currentMonth = _monthKey(DateTime.now());
    final lastMonth = p.getString('activeMonth') ?? '';
    final sj = p.getString('students');
    final dj = p.getString('disciplines');
    if (sj != null) {
      students
        ..clear()
        ..addAll((jsonDecode(sj) as List)
            .map((x) => Student.fromJson(Map<String, dynamic>.from(x))));
      if (lastMonth.isNotEmpty && lastMonth != currentMonth) {
        await _closePreviousMonth(lastMonth, p);
      }
      for (final student in students) {
        if (student.feeMonth.isEmpty) {
          student.feeMonth = currentMonth;
          if (student.monthlyFee <= 0) student.monthlyFee = student.participation;
        } else if (student.feeMonth != currentMonth) {
          student.feeMonth = currentMonth;
          student.participation = student.monthlyFee;
        }
      }
      await p.setString('activeMonth', currentMonth);
    }
    if (dj != null) {
      disciplines
        ..clear()
        ..addAll((jsonDecode(dj) as List)
            .map((x) => Discipline.fromJson(Map<String, dynamic>.from(x))));
    }
    final rj = p.getString('receipts');
    if (rj != null) {
      receipts
        ..clear()
        ..addAll((jsonDecode(rj) as List).map((x) => ReceiptRecord.fromJson(Map<String, dynamic>.from(x))));
    }
    final ej = p.getString('extraIncome');
    if (ej != null) {
      extraIncome
        ..clear()
        ..addAll((jsonDecode(ej) as List).map((x) => CashEntry.fromJson(Map<String, dynamic>.from(x))));
    }
    final xj = p.getString('expenses');
    if (xj != null) {
      expenses
        ..clear()
        ..addAll((jsonDecode(xj) as List).map((x) => CashEntry.fromJson(Map<String, dynamic>.from(x))));
    }
    final mr = p.getString('monthlyReports');
    if (mr != null) {
      monthlyReports
        ..clear()
        ..addAll((jsonDecode(mr) as List).map((x) => Map<String, dynamic>.from(x)));
    }
    if (mounted) setState(() => loading = false);
    if (lastMonth.isNotEmpty && lastMonth != currentMonth && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLatestReport());
    }
  }

  String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('students', jsonEncode(students.map((s) => s.toJson()).toList()));
    await p.setString('disciplines', jsonEncode(disciplines.map((d) => d.toJson()).toList()));
    await p.setString('receipts', jsonEncode(receipts.map((r) => r.toJson()).toList()));
    await p.setString('extraIncome', jsonEncode(extraIncome.map((e) => e.toJson()).toList()));
    await p.setString('expenses', jsonEncode(expenses.map((e) => e.toJson()).toList()));
    await p.setString('monthlyReports', jsonEncode(monthlyReports));
    await p.setString('activeMonth', _monthKey(DateTime.now()));
  }

  Future<Map<String, dynamic>> _backupData() async {
    return {
      'format': 'dynamique_ballet_studio_backup_v2',
      'exportedAt': DateTime.now().toIso8601String(),
      'students': students.map((s) => s.toJson()).toList(),
      'disciplines': disciplines.map((d) => d.toJson()).toList(),
      'receipts': receipts.map((r) => r.toJson()).toList(),
      'extraIncome': extraIncome.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
    };
  }

  DateTime _monthStart(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
  }

  String _monthLabel(String key) {
    final d = _monthStart(key);
    const names = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno','Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
    return '${names[d.month - 1]} ${d.year}';
  }

  double _paymentsForMonth(Student s, String month) {
    double total = 0;
    for (final pay in s.payments) {
      final iso = DateTime.tryParse(pay.date);
      DateTime? d = iso;
      if (d == null) {
        final parts = pay.date.split('/');
        if (parts.length == 3) d = DateTime.tryParse('${parts[2]}-${parts[1].padLeft(2,'0')}-${parts[0].padLeft(2,'0')}');
      }
      if (d != null && _monthKey(d) == month) total += pay.amount;
    }
    return total;
  }

  Future<void> _closePreviousMonth(String month, SharedPreferences p) async {
    final totalFees = students.fold<double>(0, (sum, s) => sum + s.monthlyFee);
    final paidFees = students.fold<double>(0, (sum, s) => sum + _paymentsForMonth(s, month));
    final extra = extraIncome.where((e) => e.date.startsWith(month)).fold<double>(0, (sum, e) => sum + e.amount);
    final spent = expenses.where((e) => e.date.startsWith(month)).fold<double>(0, (sum, e) => sum + e.amount);
    for (final student in students) {
      final fee = student.monthlyFee > 0 ? student.monthlyFee : student.participation;
      final paid = _paymentsForMonth(student, month);
      final due = (fee - paid).clamp(0, double.infinity).toDouble();
      student.arrears += due;
    }
    final report = <String, dynamic>{
      'month': month,
      'label': _monthLabel(month),
      'totalFees': totalFees,
      'paidFees': paidFees,
      'extra': extra,
      'expenses': spent,
      'net': paidFees + extra - spent,
      'createdAt': DateTime.now().toIso8601String(),
    };
    monthlyReports.removeWhere((r) => r['month']?.toString() == month);
    monthlyReports.add(report);
    extraIncome.removeWhere((e) => e.date.startsWith(month));
    expenses.removeWhere((e) => e.date.startsWith(month));
    await p.setString('students', jsonEncode(students.map((s) => s.toJson()).toList()));
    await p.setString('monthlyReports', jsonEncode(monthlyReports));
    await p.setString('extraIncome', jsonEncode(extraIncome.map((e) => e.toJson()).toList()));
    await p.setString('expenses', jsonEncode(expenses.map((e) => e.toJson()).toList()));
  }

  Future<Uint8List> _reportPdf(Map<String, dynamic> r) async {
    final doc = pw.Document();
    final label = r['label']?.toString() ?? r['month'].toString();
    final unpaid = students
        .where((s) => s.arrears > 0)
        .map((s) => '${s.name}: € ${s.arrears.toStringAsFixed(2)}')
        .toList();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Dynamique Ballet Studio',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Resoconto incassi - $label',
                  style: pw.TextStyle(fontSize: 17),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Incassi rette: € ${(r['paidFees'] as num).toDouble().toStringAsFixed(2)}'),
                pw.Text('Incassi extra: € ${(r['extra'] as num).toDouble().toStringAsFixed(2)}'),
                pw.Text('Spese: - € ${(r['expenses'] as num).toDouble().toStringAsFixed(2)}'),
                pw.Divider(),
                pw.Text(
                  'Incassato netto: € ${(r['net'] as num).toDouble().toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Insoluti riportati al mese successivo',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (unpaid.isEmpty)
                  pw.Text('Nessun insoluto.')
                else
                  ...unpaid.map(
                    (x) => pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 5),
                      child: pw.Text(x),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  Future<void> _showLatestReport() async {
    if (monthlyReports.isEmpty) return;
    final r = monthlyReports.last;
    if (!mounted) return;
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Resoconto ${r['label']}'),
      content: Text('Incassi rette: € ${(r['paidFees'] as num).toDouble().toStringAsFixed(2)}\nIncassi extra: € ${(r['extra'] as num).toDouble().toStringAsFixed(2)}\nSpese: € ${(r['expenses'] as num).toDouble().toStringAsFixed(2)}\n\nIl resoconto è stato archiviato e gli insoluti sono stati riportati al mese corrente.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CHIUDI')),
        FilledButton.icon(onPressed: () async { final bytes = await _reportPdf(r); final name = 'resoconto_${r['month']}.pdf'; await Share.shareXFiles([XFile.fromData(bytes, name: name, mimeType: 'application/pdf')], subject: 'Resoconto ${r['label']}'); }, icon: const Icon(Icons.print), label: const Text('STAMPA / CONDIVIDI')),
      ],
    ));
  }

  Future<void> exportBackup() async {
    final data = await _backupData();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final fileName = 'dynamique_ballet_backup_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.json';
    await Share.shareXFiles([
      XFile.fromData(Uint8List.fromList(utf8.encode(json)), name: fileName, mimeType: 'application/json'),
    ], subject: 'Backup Dynamique Ballet Studio');
  }

  Future<void> importBackupMerge() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    try {
      final data = jsonDecode(utf8.decode(result.files.single.bytes!)) as Map<String, dynamic>;
      final importedDisciplines = (data['disciplines'] as List? ?? const [])
          .map((x) => Discipline.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      for (final incoming in importedDisciplines) {
        final idx = disciplines.indexWhere((d) => d.name.toLowerCase() == incoming.name.toLowerCase());
        if (idx >= 0) {
          disciplines[idx].fee = incoming.fee;
          disciplines[idx].name = incoming.name;
        } else {
          disciplines.add(incoming);
        }
      }
      final importedReceipts = (data['receipts'] as List? ?? const [])
          .map((x) => ReceiptRecord.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      for (final incoming in importedReceipts) {
        final idx = receipts.indexWhere((r) => r.id == incoming.id);
        if (idx >= 0) {
          receipts[idx] = incoming;
        } else {
          receipts.add(incoming);
        }
      }
      final importedExtraIncome = (data['extraIncome'] as List? ?? const [])
          .map((x) => CashEntry.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      for (final incoming in importedExtraIncome) {
        final idx = extraIncome.indexWhere((e) => e.id == incoming.id);
        if (idx >= 0) { extraIncome[idx] = incoming; } else { extraIncome.add(incoming); }
      }
      final importedExpenses = (data['expenses'] as List? ?? const [])
          .map((x) => CashEntry.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      for (final incoming in importedExpenses) {
        final idx = expenses.indexWhere((e) => e.id == incoming.id);
        if (idx >= 0) { expenses[idx] = incoming; } else { expenses.add(incoming); }
      }
      final importedStudents = (data['students'] as List? ?? const [])
          .map((x) => Student.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      for (final incoming in importedStudents) {
        final idx = students.indexWhere((s) => s.id == incoming.id || (s.name.trim().toLowerCase() == incoming.name.trim().toLowerCase() && s.phone.trim() == incoming.phone.trim()));
        if (idx >= 0) {
          students[idx] = incoming; // aggiorna il record esistente, non lo sostituisce globalmente
        } else {
          students.add(incoming);
        }
      }
      await save();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup importato come aggiornamento: i dati esistenti sono stati mantenuti.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup non valido o non leggibile.')));
    }
  }

  Future<void> _addCashEntry(List<CashEntry> target, String title) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final result = await showDialog<CashEntry>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nuovo $title'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrizione')),
          const SizedBox(height: 12),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importo €')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULLA')),
          FilledButton(onPressed: () {
            final value = double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
            if (value <= 0) return;
            Navigator.pop(ctx, CashEntry(id: DateTime.now().microsecondsSinceEpoch.toString(), amount: value, description: description.text.trim().isEmpty ? title : description.text.trim(), date: DateTime.now().toIso8601String()));
          }, child: const Text('SALVA')),
        ],
      ),
    );
    description.dispose(); amount.dispose();
    if (result != null) { setState(() => target.add(result)); await save(); }
  }

  Future<void> _deleteCashEntry(List<CashEntry> target, CashEntry entry) async {
    setState(() => target.remove(entry));
    await save();
  }

  Future<void> openStudent([Student? existing]) async {
    final result = await showDialog<Student>(
      context: context,
      builder: (_) => StudentDialog(student: existing, disciplines: disciplines, onReceiptCreated: (receipt) async { receipts.add(receipt); await save(); if (mounted) setState(() {}); }, onStudentChanged: (updated) async {
        if (existing == null) return;
        final index = students.indexWhere((s) => s.id == updated.id);
        if (index >= 0) {
          students[index] = updated;
          await save();
          if (mounted) setState(() {});
        }
      }),
    );
    if (result == null) return;
    setState(() {
      if (existing == null) {
        students.add(result);
      } else {
        final index = students.indexOf(existing);
        if (index >= 0) students[index] = result;
      }
    });
    await save();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = <Widget>[
      Dashboard(
        students: students,
        extraIncome: extraIncome,
        expenses: expenses,
        monthlyReports: monthlyReports,
        onOpenReports: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MonthlyReportsPage(
                reports: monthlyReports,
                onPrint: (r) async {
                  final bytes = await _reportPdf(r);
                  final name = 'resoconto_${r['month']}.pdf';
                  await Share.shareXFiles(
                    [XFile.fromData(bytes, name: name, mimeType: 'application/pdf')],
                    subject: 'Resoconto ${r['label']}',
                  );
                },
              ),
            ),
          );
        },
        onAddExtra: () => _addCashEntry(extraIncome, 'Incasso extra'),
        onAddExpense: () => _addCashEntry(expenses, 'Spesa'),
        onDeleteExtra: (e) => _deleteCashEntry(extraIncome, e),
        onDeleteExpense: (e) => _deleteCashEntry(expenses, e),
        onAdd: openStudent,
        onBackup: exportBackup,
        onImport: importBackupMerge,
        onOpenStudents: () => setState(() => tab = 1),
      ),
      StudentsPage(
        students: students,
        groupedByDiscipline: true,
        onEdit: openStudent,
        onDelete: (s) {
          setState(() => students.remove(s));
          save();
        },
      ),
      ReceiptsPage(receipts: receipts, onDelete: (r) async { receipts.remove(r); await save(); setState(() {}); }),
      DisciplinesPage(
        disciplines: disciplines,
        onChanged: () {
          setState(() {});
          save();
        },
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        if (compact) {
          return Scaffold(
            body: SafeArea(child: pages[tab]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Riepilogo'),
                NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Iscritti'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Ricevute'),
                NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Discipline'),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: tab,
                onDestinationSelected: (i) => setState(() => tab = i),
                labelType: NavigationRailLabelType.all,
                backgroundColor: kDark,
                selectedIconTheme: const IconThemeData(color: Colors.white),
                unselectedIconTheme: const IconThemeData(color: Colors.white70),
                selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
                destinations: const [
                  NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Riepilogo')),
                  NavigationRailDestination(icon: Icon(Icons.people), label: Text('Iscritti')),
                  NavigationRailDestination(icon: Icon(Icons.receipt_long), label: Text('Ricevute')),
                  NavigationRailDestination(icon: Icon(Icons.menu_book), label: Text('Discipline')),
                ],
              ),
              Expanded(child: pages[tab]),
            ],
          ),
        );
      },
    );
  }
}

class Header extends StatelessWidget {
  final String title;
  const Header({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    return Container(
      color: kDark,
      padding: EdgeInsets.fromLTRB(compact ? 14 : 24, compact ? 10 : 16, compact ? 14 : 24, compact ? 10 : 16),
      child: Row(
        children: [
          Image.asset('assets/logo.jpg', height: compact ? 44 : 62, width: compact ? 118 : 165, fit: BoxFit.contain),
          SizedBox(width: compact ? 10 : 18),
          Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: compact ? 17 : 24, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}


class MonthlyReportsPage extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final Future<void> Function(Map<String, dynamic>) onPrint;
  const MonthlyReportsPage({super.key, required this.reports, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    final sorted = [...reports]..sort((a, b) => (b['month'] ?? '').toString().compareTo((a['month'] ?? '').toString()));
    return Scaffold(
      appBar: AppBar(title: const Text('Resoconto mensile')),
      body: sorted.isEmpty
          ? const Center(child: Text('Nessun resoconto mensile disponibile.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (_, i) {
                final r = sorted[i];
                final paid = (r['paidFees'] as num?)?.toDouble() ?? 0;
                final extra = (r['extra'] as num?)?.toDouble() ?? 0;
                final expenses = (r['expenses'] as num?)?.toDouble() ?? 0;
                final net = (r['net'] as num?)?.toDouble() ?? paid + extra - expenses;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.calendar_month),
                        const SizedBox(width: 10),
                        Expanded(child: Text(r['label']?.toString() ?? r['month'].toString(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
                        IconButton(onPressed: () => onPrint(r), icon: const Icon(Icons.print), tooltip: 'Stampa / condividi PDF'),
                      ]),
                      const Divider(),
                      Text('Incassi rette: € ${paid.toStringAsFixed(2)}'),
                      Text('Incassi extra: € ${extra.toStringAsFixed(2)}'),
                      Text('Spese: - € ${expenses.toStringAsFixed(2)}'),
                      const SizedBox(height: 6),
                      Text('Incassato netto: € ${net.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: () => onPrint(r), icon: const Icon(Icons.picture_as_pdf), label: const Text('STAMPA / CONDIVIDI PDF')),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class Dashboard extends StatelessWidget {
  final List<Student> students;
  final List<CashEntry> extraIncome;
  final List<CashEntry> expenses;
  final List<Map<String, dynamic>> monthlyReports;
  final VoidCallback onOpenReports;
  final VoidCallback onAddExtra;
  final VoidCallback onAddExpense;
  final ValueChanged<CashEntry> onDeleteExtra;
  final ValueChanged<CashEntry> onDeleteExpense;
  final Future<void> Function([Student?]) onAdd;
  final VoidCallback onBackup;
  final VoidCallback onImport;
  final VoidCallback onOpenStudents;
  const Dashboard({super.key, required this.students, required this.extraIncome, required this.expenses, required this.monthlyReports, required this.onOpenReports, required this.onAddExtra, required this.onAddExpense, required this.onDeleteExtra, required this.onDeleteExpense, required this.onAdd, required this.onBackup, required this.onImport, required this.onOpenStudents});

  @override
  Widget build(BuildContext context) {
    final currentMonth = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    double currentPaid(Student s) => s.payments.fold<double>(0, (sum, p) {
      final d = DateTime.tryParse(p.date) ?? (() { final x=p.date.split('/'); return x.length==3 ? DateTime.tryParse('${x[2]}-${x[1].padLeft(2,'0')}-${x[0].padLeft(2,'0')}') : null; })();
      return d != null && '${d.year}-${d.month.toString().padLeft(2,'0')}' == currentMonth ? sum + p.amount : sum;
    });
    final total = students.fold<double>(0, (sum, s) => sum + (s.monthlyFee > 0 ? s.monthlyFee : s.participation) + s.arrears + s.showCost + s.clothesCost);
    final paid = students.fold<double>(0, (sum, s) => sum + currentPaid(s));
    final balance = total - paid;
    final extra = extraIncome.fold<double>(0, (sum, e) => sum + e.amount);
    final spent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final adjustedCash = paid + extra - spent;
    return Column(
      children: [
        const Header(title: 'Gestione Scuola di Danza'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 650 ? 12 : 24),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  StatCard('Iscritti', '${students.length}', Icons.people, onTap: onOpenStudents),
                  StatCard('Totale quote', '\u20AC ${total.toStringAsFixed(2)}', Icons.euro),
                  StatCard('Incassato', '\u20AC ${paid.toStringAsFixed(2)}', Icons.payments),
                  StatCard('Incassi extra', '\u20AC ${extra.toStringAsFixed(2)}', Icons.add_circle_outline, onTap: onAddExtra),
                  StatCard('Spese', '- \u20AC ${spent.toStringAsFixed(2)}', Icons.remove_circle_outline, onTap: onAddExpense),
                  StatCard('Incassato netto', '\u20AC ${adjustedCash.toStringAsFixed(2)}', Icons.account_balance_wallet),
                  StatCard('Da incassare', '\u20AC ${balance.toStringAsFixed(2)}', Icons.pending_actions),
                ],
              ),
              const SizedBox(height: 16),
              _UnpaidMonthlyFeesCard(students: students),
              const SizedBox(height: 12),
              StatCard(
                'Resoconto mensile',
                monthlyReports.isEmpty ? 'Nessun resoconto' : monthlyReports.last['label']?.toString() ?? 'Apri',
                Icons.assessment_outlined,
                onTap: onOpenReports,
              ),
              if (extraIncome.isNotEmpty || expenses.isNotEmpty) ...[
                const SizedBox(height: 16),
                CashSummaryCard(title: 'Movimenti extra', entries: extraIncome, icon: Icons.add_circle_outline, onDelete: onDeleteExtra),
                const SizedBox(height: 10),
                CashSummaryCard(title: 'Spese', entries: expenses, icon: Icons.remove_circle_outline, onDelete: onDeleteExpense),
              ],
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gestione iscrizioni', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Inserisci nuovi allievi, assegna le discipline e registra quota, acconti, saggio e vestiti.'),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: FilledButton.icon(onPressed: () => onAdd(), icon: const Icon(Icons.person_add), label: const Text('NUOVO ISCRITTO'))),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            tooltip: 'Backup dati',
                            icon: const Icon(Icons.more_horiz),
                            onSelected: (v) { if (v == 'backup') onBackup(); if (v == 'import') onImport(); },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'backup', child: ListTile(leading: Icon(Icons.backup), title: Text('Crea backup'), dense: true)),
                              PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.file_download), title: Text('Importa / aggiorna'), dense: true)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (students.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Nessun iscritto inserito.')))
              else
                ...students.take(8).map(
                      (s) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: kRed,
                            foregroundColor: Colors.white,
                            child: Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase()),
                          ),
                          title: Text(s.name),
                          subtitle: Text(s.disciplines.join(' • ')),
                          trailing: Text(
                            'Saldo \u20AC ${s.balance.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: s.balance <= 0 ? Colors.green : kRed),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnpaidMonthlyFeesCard extends StatelessWidget {
  final List<Student> students;
  const _UnpaidMonthlyFeesCard({required this.students});

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  DateTime? _parsePaymentDate(String value) {
    // I pagamenti vengono salvati normalmente come dd/MM/yyyy.
    // Supportiamo anche il formato ISO yyyy-MM-dd per i dati più vecchi.
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;

    final parts = value.trim().split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  double _paidThisMonth(Student student, String month) {
    double total = 0;
    for (final payment in student.payments) {
      final parsed = _parsePaymentDate(payment.date);
      if (parsed != null && _monthKey(parsed) == month) {
        total += payment.amount;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = _monthKey(DateTime.now());
    final unpaid = students.where((student) {
      final fee = student.monthlyFee > 0 ? student.monthlyFee : student.participation;
      if (fee <= 0) return false;
      return _paidThisMonth(student, currentMonth) < (fee + student.arrears);
    }).toList();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: unpaid.isEmpty
            ? null
            : () {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: kRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Rette non pagate - ${unpaid.length}'),
                        ),
                      ],
                    ),
                    content: SizedBox(
                      width: 420,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: unpaid.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final student = unpaid[index];
                          final fee = student.monthlyFee > 0
                              ? student.monthlyFee
                              : student.participation;
                          final paid = _paidThisMonth(student, currentMonth);
                          final remaining = (fee + student.arrears) - paid;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: kRed,
                              foregroundColor: Colors.white,
                              child: Text(
                                student.name.isEmpty
                                    ? '?'
                                    : student.name[0].toUpperCase(),
                              ),
                            ),
                            title: Text(
                              student.name.isEmpty
                                  ? 'Nome non indicato'
                                  : student.name,
                            ),
                            subtitle: Text(
                              paid > 0
                                  ? 'Versato questo mese: € ${paid.toStringAsFixed(2)} • Mancano: € ${remaining.toStringAsFixed(2)}'
                                  : 'Nessun pagamento registrato questo mese • Dovuto: € ${(fee + student.arrears).toStringAsFixed(2)}',
                            ),
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('CHIUDI'),
                      ),
                    ],
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: unpaid.isEmpty
                      ? Colors.green.withOpacity(0.12)
                      : kRed.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  unpaid.isEmpty
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: unpaid.isEmpty ? Colors.green : kRed,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rette mensili non pagate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unpaid.isEmpty
                          ? 'Tutti gli iscritti hanno pagato la retta di questo mese.'
                          : 'Ci sono ${unpaid.length} ${unpaid.length == 1 ? 'iscritto' : 'iscritti'} inadempienti. Tocca per vedere i nomi.',
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: unpaid.isEmpty ? Colors.green : kRed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${unpaid.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (unpaid.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CashSummaryCard extends StatelessWidget {
  final String title;
  final List<CashEntry> entries;
  final IconData icon;
  final ValueChanged<CashEntry> onDelete;
  const CashSummaryCard({super.key, required this.title, required this.entries, required this.icon, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (sum, e) => sum + e.amount);
    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: kRed),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text('€ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        children: entries.map((e) => ListTile(
          title: Text(e.description),
          subtitle: Text(_displayDate(e.date)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('€ ${e.amount.toStringAsFixed(2)}'),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(e),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
  String _displayDate(String value) { final d = DateTime.tryParse(value); return d == null ? value : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'; }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  const StatCard(this.title, this.value, this.icon, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    return SizedBox(
      width: compact ? (MediaQuery.sizeOf(context).width - 36) / 2 : 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: kRed, size: 30),
            const SizedBox(height: 8),
            Text(title),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
          ),
        ),
      ),
    );
  }
}

class ReceiptsPage extends StatelessWidget {
  final List<ReceiptRecord> receipts;
  final Future<void> Function(ReceiptRecord) onDelete;
  const ReceiptsPage({super.key, required this.receipts, required this.onDelete});
  Future<void> _share(ReceiptRecord r) async {
    await Share.shareXFiles([XFile.fromData(Uint8List.fromList(r.bytes), name: 'ricevuta_acconto_${r.studentName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')}.pdf', mimeType: 'application/pdf')], subject: 'Ricevuta acconto - ${r.studentName}');
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    const Header(title: 'Ricevute acconti'),
    Expanded(child: receipts.isEmpty ? const Center(child: Text('Nessuna ricevuta conservata.')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: receipts.length, itemBuilder: (_, i) {
      final r = receipts[receipts.length - 1 - i];
      return Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf, color: kRed), title: Text(r.studentName), subtitle: Text('Ricevuta del ${r.date}'), trailing: Wrap(children: [IconButton(tooltip: 'Invia', onPressed: () => _share(r), icon: const Icon(Icons.share)), IconButton(tooltip: 'Elimina', onPressed: () => onDelete(r), icon: const Icon(Icons.delete_outline))])));
    }))
  ]);
}

class StudentsPage extends StatefulWidget {
  final List<Student> students;
  final Future<void> Function(Student?) onEdit;
  final void Function(Student) onDelete;
  final bool groupedByDiscipline;
  const StudentsPage({super.key, required this.students, required this.onEdit, required this.onDelete, this.groupedByDiscipline = false});
  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.students.where((s) => s.name.toLowerCase().contains(query.toLowerCase())).toList();
    return Column(
      children: [
        const Header(title: 'Iscritti'),
        Padding(
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 650 ? 12 : 20),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cerca iscritto...'),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(onPressed: () => widget.onEdit(null), icon: const Icon(Icons.add), label: const Text('Nuovo iscritto')),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Nessun risultato'))
              : widget.groupedByDiscipline
                  ? _GroupedStudentsList(students: list, onEdit: widget.onEdit, onDelete: widget.onDelete)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final s = list[index];
                        return _StudentTile(student: s, onEdit: widget.onEdit, onDelete: widget.onDelete);
                      },
                    ),
        ),
      ],
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  final Future<void> Function(Student?) onEdit;
  final void Function(Student) onDelete;
  const _StudentTile({required this.student, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${student.disciplines.join(' • ')}\nTotale \u20AC ${student.total.toStringAsFixed(2)}  •  Versato \u20AC ${student.paid.toStringAsFixed(2)}  •  Saldo \u20AC ${student.balance.toStringAsFixed(2)}'),
      isThreeLine: true,
      trailing: Wrap(children: [
        IconButton(onPressed: () => onEdit(student), icon: const Icon(Icons.edit, color: kRed)),
        IconButton(onPressed: () => onDelete(student), icon: const Icon(Icons.delete_outline)),
      ]),
    ),
  );
}

class _GroupedStudentsList extends StatelessWidget {
  final List<Student> students;
  final Future<void> Function(Student?) onEdit;
  final void Function(Student) onDelete;
  const _GroupedStudentsList({required this.students, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Student>>{};
    for (final s in students) {
      final ds = s.disciplines.isEmpty ? ['Senza disciplina'] : s.disciplines;
      for (final d in ds) { groups.putIfAbsent(d, () => []).add(s); }
    }
    final keys = groups.keys.toList()..sort();
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Iscritti divisi per disciplina', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
      ...keys.map((d) => Card(
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.menu_book, color: kRed),
          title: Text(d, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${groups[d]!.length} ${groups[d]!.length == 1 ? 'iscritto' : 'iscritti'}'),
          children: groups[d]!.map((s) => _StudentTile(student: s, onEdit: onEdit, onDelete: onDelete)).toList(),
        ),
      )),
    ]);
  }
}

class DisciplinesPage extends StatelessWidget {
  final List<Discipline> disciplines;
  final VoidCallback onChanged;
  const DisciplinesPage({super.key, required this.disciplines, required this.onChanged});

  Future<void> _editDiscipline(BuildContext context, Discipline d) async {
    final name = TextEditingController(text: d.name);
    final fee = TextEditingController(text: d.fee == 0 ? '' : d.fee.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(d.name.isEmpty ? 'Nuova disciplina' : 'Modifica disciplina'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome disciplina')),
            const SizedBox(height: 12),
            TextField(controller: fee, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quota mensile (\u20AC)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          FilledButton(onPressed: () {
            final newName = name.text.trim();
            if (newName.isEmpty) return;
            d.name = newName;
            d.fee = double.tryParse(fee.text.replaceAll(',', '.')) ?? 0;
            if (!disciplines.contains(d)) disciplines.add(d);
            Navigator.pop(dialogContext, true);
          }, child: const Text('Salva')),
        ],
      ),
    );
    name.dispose();
    fee.dispose();
    if (ok == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Header(title: 'Discipline e quote mensili'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 650 ? 12 : 20),
            children: [
              ...disciplines.map((d) => Card(
                child: ListTile(
                  leading: const Icon(Icons.music_note, color: kRed),
                  title: Text(d.name),
                  subtitle: Text('Quota mensile: \u20AC ${d.fee.toStringAsFixed(2)}'),
                  trailing: IconButton(icon: const Icon(Icons.edit, color: kRed), tooltip: 'Modifica', onPressed: () => _editDiscipline(context, d)),
                  onTap: () => _editDiscipline(context, d),
                ),
              )),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _editDiscipline(context, Discipline('', 0)),
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi disciplina'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StudentDialog extends StatefulWidget {
  final Student? student;
  final List<Discipline> disciplines;
  final Future<void> Function(ReceiptRecord receipt) onReceiptCreated;
  final Future<void> Function(Student student)? onStudentChanged;
  const StudentDialog({super.key, this.student, required this.disciplines, required this.onReceiptCreated, this.onStudentChanged});
  @override
  State<StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<StudentDialog> {
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController notes;
  late final TextEditingController participation;
  late final TextEditingController monthlyFee;
  late final TextEditingController showCost;
  late final TextEditingController clothes;
  late final TextEditingController payment;
  late List<String> selected;
  late List<Payment> payments;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    name = TextEditingController(text: s?.name ?? '');
    phone = TextEditingController(text: s?.phone ?? '');
    email = TextEditingController(text: s?.email ?? '');
    notes = TextEditingController(text: s?.notes ?? '');
    final initialMonthlyFee = s?.monthlyFee ?? s?.participation ?? 0;
    monthlyFee = TextEditingController(text: initialMonthlyFee == 0 ? '' : initialMonthlyFee.toStringAsFixed(2));
    participation = TextEditingController(text: s == null ? '' : s.participation.toString());
    showCost = TextEditingController(text: s == null ? '' : s.showCost.toString());
    clothes = TextEditingController(text: s == null ? '' : s.clothesCost.toString());
    payment = TextEditingController();
    selected = [...(s?.disciplines ?? const <String>[])];
    payments = [...(s?.payments ?? const <Payment>[])];
    final automaticFee = selectedMonthlyFee();
    if (automaticFee > 0) {
      monthlyFee.text = automaticFee.toStringAsFixed(2);
      participation.text = automaticFee.toStringAsFixed(2);
    }
  }

  double valueOf(TextEditingController controller) => double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

  double selectedMonthlyFee() {
    double total = 0;
    for (final name in selected) {
      final match = widget.disciplines.where((d) => d.name == name);
      if (match.isNotEmpty) total += match.first.fee;
    }
    return total;
  }

  void refreshMonthlyFee() {
    final fee = selectedMonthlyFee();
    monthlyFee.text = fee == 0 ? '' : fee.toStringAsFixed(2);
    participation.text = fee == 0 ? '' : fee.toStringAsFixed(2);
  }

  Future<void> _createReceiptAndShare(Payment p) async {
    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final euroFont = pw.Font.ttf(fontData);
    final euroSymbolData = await rootBundle.load('assets/euro_symbol.png');
    final euroSymbol = pw.MemoryImage(euroSymbolData.buffer.asUint8List());
    final doc = pw.Document();

    pw.Widget euroAmount(String label, double amount) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label, style: pw.TextStyle(font: euroFont)),
          pw.SizedBox(width: 3),
          pw.Image(euroSymbol, width: 11, height: 11),
          pw.SizedBox(width: 3),
          pw.Text(amount.toStringAsFixed(2), style: pw.TextStyle(font: euroFont)),
        ],
      );
    }
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Padding(
        padding: const pw.EdgeInsets.all(36),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('DYNAMIQUE BALLET STUDIO', style: pw.TextStyle(font: euroFont, fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Ricevuta acconto', style: pw.TextStyle(font: euroFont, fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.SizedBox(height: 18),
          pw.Text('Allievo: ${name.text.trim()}', style: pw.TextStyle(font: euroFont)),
          pw.Text('Telefono: ${phone.text.trim().isEmpty ? 'non indicato' : phone.text.trim()}', style: pw.TextStyle(font: euroFont)),
          pw.SizedBox(height: 16),
          euroAmount('Acconto ricevuto:', p.amount),
          pw.Text('Data: ${p.date}', style: pw.TextStyle(font: euroFont)),
          pw.SizedBox(height: 18),
          euroAmount('Totale versato:', payments.fold<double>(0, (sum, x) => sum + x.amount)),
          pw.SizedBox(height: 28),
          pw.Text('Grazie per il pagamento.', style: pw.TextStyle(font: euroFont)),
        ]),
      ),
    ));
    final bytes = await doc.save();
    final safeName = name.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final receipt = ReceiptRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      studentId: widget.student?.id ?? '',
      studentName: name.text.trim(),
      date: p.date,
      bytes: bytes,
    );
    await widget.onReceiptCreated(receipt);

    final recipientPhone = phone.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final whatsappText = 'Ricevuta acconto Dynamique Ballet Studio per ${name.text.trim()}';
    final whatsappUrl = recipientPhone.isEmpty
        ? null
        : Uri.parse('https://wa.me/${recipientPhone.replaceFirst('+', '')}?text=${Uri.encodeComponent(whatsappText)}');

    // Se il numero è presente, apriamo direttamente la chat WhatsApp dell'allievo.
    // Subito dopo apriamo la condivisione del PDF: su Android l'utente può scegliere
    // WhatsApp e inviare la ricevuta già pronta. Su iOS WhatsApp non consente
    // di allegare un PDF tramite il link wa.me, quindi la condivisione del file
    // avviene tramite il foglio di condivisione del sistema.
    if (whatsappUrl != null) {
      try {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Se WhatsApp non è installato o il link non è gestibile, continuiamo
        // comunque con la condivisione del PDF.
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    await Share.shareXFiles([
      XFile.fromData(bytes, name: 'ricevuta_acconto_$safeName.pdf', mimeType: 'application/pdf'),
    ], subject: 'Ricevuta acconto - ${name.text.trim()}', text: recipientPhone.isEmpty
        ? whatsappText
        : '$whatsappText\nDestinatario WhatsApp: $recipientPhone');
  }

  Student _currentStudent() {
    return Student(
      id: widget.student?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(),
      phone: phone.text.trim(),
      email: email.text.trim(),
      notes: notes.text.trim(),
      disciplines: [...selected],
      participation: valueOf(participation),
      monthlyFee: valueOf(monthlyFee),
      feeMonth: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
      showCost: valueOf(showCost),
      clothesCost: valueOf(clothes),
      payments: [...payments],
    );
  }

  Future<void> _persistPaymentChange() async {
    if (widget.student != null && widget.onStudentChanged != null) {
      await widget.onStudentChanged!(_currentStudent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = valueOf(participation) + valueOf(showCost) + valueOf(clothes);
    final paid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    return AlertDialog(
      title: Text(widget.student == null ? 'Inserisci nuovo iscritto' : 'Modifica iscritto'),
      content: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome e cognome *')),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, c) => c.maxWidth < 520
                  ? Column(children: [TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefono')), const SizedBox(height: 10), TextField(controller: email, decoration: const InputDecoration(labelText: 'Email'))])
                  : Row(children: [Expanded(child: TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefono'))), const SizedBox(width: 10), Expanded(child: TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')))])),
              const SizedBox(height: 16),
              const Text('Discipline', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.disciplines.map((d) {
                  return FilterChip(
                    label: Text(d.name),
                    selected: selected.contains(d.name),
                    onSelected: (checked) {
                      setState(() {
                        if (checked) {
                          if (!selected.contains(d.name)) selected.add(d.name);
                        } else {
                          selected.remove(d.name);
                        }
                        refreshMonthlyFee();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Costi', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                final fields = [
                  TextField(
                    controller: participation,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Quota mensile (\u20AC)', helperText: 'Calcolata automaticamente dalle discipline selezionate'),
                  ),
                  TextField(controller: showCost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Costo saggio (\u20AC)')),
                  TextField(controller: clothes, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Vestiti (\u20AC)')),
                ];
                return c.maxWidth < 520 ? Column(children: [fields[0], const SizedBox(height: 10), fields[1], const SizedBox(height: 10), fields[2]]) : Row(children: [for (int i=0;i<fields.length;i++) ...[Expanded(child: fields[i]), if(i<fields.length-1) const SizedBox(width: 10)]]);
              }),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: TextField(controller: payment, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Importo acconto (\u20AC)'))),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () async {
                    final amount = valueOf(payment);
                    if (amount <= 0) return;
                    final newPayment = Payment(amount: amount, date: _today());
                    setState(() {
                      payments.add(newPayment);
                      payment.clear();
                    });
                    await _persistPaymentChange();
                    await _createReceiptAndShare(newPayment);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi acconto'),
                ),
              ]),
              if (payments.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...payments.asMap().entries.map(
                  (entry) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.payments, color: kRed),
                    title: Text('Acconto \u20AC ${entry.value.amount.toStringAsFixed(2)}'),
                    subtitle: Text(entry.value.date),
                    trailing: IconButton(
                      onPressed: () async {
                        setState(() => payments.removeAt(entry.key));
                        await _persistPaymentChange();
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Totale: \u20AC ${total.toStringAsFixed(2)}    Versato: \u20AC ${paid.toStringAsFixed(2)}    Saldo: \u20AC ${(total - paid).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Note')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              Student(
                id: widget.student?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                phone: phone.text.trim(),
                email: email.text.trim(),
                notes: notes.text.trim(),
                disciplines: [...selected],
                participation: valueOf(participation),
                monthlyFee: valueOf(monthlyFee),
                arrears: widget.student?.arrears ?? 0,
                feeMonth: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
                showCost: valueOf(showCost),
                clothesCost: valueOf(clothes),
                payments: [...payments],
              ),
            );
          },
          child: const Text('SALVA'),
        ),
      ],
    );
  }

  String _today() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    notes.dispose();
    participation.dispose();
    monthlyFee.dispose();
    showCost.dispose();
    clothes.dispose();
    payment.dispose();
    super.dispose();
  }
}
