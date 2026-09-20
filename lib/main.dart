import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
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
    final sj = p.getString('students');
    final dj = p.getString('disciplines');
    if (sj != null) {
      students
        ..clear()
        ..addAll((jsonDecode(sj) as List)
            .map((x) => Student.fromJson(Map<String, dynamic>.from(x))));
      final currentMonth = _monthKey(DateTime.now());
      for (final student in students) {
        if (student.feeMonth.isEmpty) {
          student.feeMonth = currentMonth;
          if (student.monthlyFee <= 0) student.monthlyFee = student.participation;
        } else if (student.feeMonth != currentMonth) {
          // La quota mensile si rinnova automaticamente all'inizio del nuovo mese.
          student.feeMonth = currentMonth;
          student.participation = student.monthlyFee;
        }
      }
    }
    if (dj != null) {
      disciplines
        ..clear()
        ..addAll((jsonDecode(dj) as List)
            .map((x) => Discipline.fromJson(Map<String, dynamic>.from(x))));
    }
    if (mounted) setState(() => loading = false);
  }

  String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('students', jsonEncode(students.map((s) => s.toJson()).toList()));
    await p.setString('disciplines', jsonEncode(disciplines.map((d) => d.toJson()).toList()));
  }

  Future<Map<String, dynamic>> _backupData() async {
    return {
      'format': 'dynamique_ballet_studio_backup_v2',
      'exportedAt': DateTime.now().toIso8601String(),
      'students': students.map((s) => s.toJson()).toList(),
      'disciplines': disciplines.map((d) => d.toJson()).toList(),
    };
  }

  Future<void> exportBackup() async {
    final data = await _backupData();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final fileName = 'dynamique_ballet_backup_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.json';
    await Share.shareXFiles([
      XFile.fromData(utf8.encode(json), name: fileName, mimeType: 'application/json'),
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

  Future<void> openStudent([Student? existing]) async {
    final result = await showDialog<Student>(
      context: context,
      builder: (_) => StudentDialog(student: existing, disciplines: disciplines),
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
      Dashboard(students: students, onAdd: openStudent, onBackup: exportBackup, onImport: importBackupMerge),
      StudentsPage(
        students: students,
        onEdit: openStudent,
        onDelete: (s) {
          setState(() => students.remove(s));
          save();
        },
      ),
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

class Dashboard extends StatelessWidget {
  final List<Student> students;
  final Future<void> Function([Student?]) onAdd;
  final VoidCallback onBackup;
  final VoidCallback onImport;
  const Dashboard({super.key, required this.students, required this.onAdd, required this.onBackup, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final total = students.fold<double>(0, (sum, s) => sum + s.total);
    final paid = students.fold<double>(0, (sum, s) => sum + s.paid);
    final balance = total - paid;
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
                  StatCard('Iscritti', '${students.length}', Icons.people),
                  StatCard('Totale quote', '\u20AC ${total.toStringAsFixed(2)}', Icons.euro),
                  StatCard('Incassato', '\u20AC ${paid.toStringAsFixed(2)}', Icons.payments),
                  StatCard('Da incassare', '\u20AC ${balance.toStringAsFixed(2)}', Icons.account_balance_wallet),
                ],
              ),
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
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(onPressed: () => onAdd(), icon: const Icon(Icons.person_add), label: const Text('NUOVO ISCRITTO')),
                          OutlinedButton.icon(onPressed: onBackup, icon: const Icon(Icons.backup), label: const Text('CREA BACKUP')),
                          OutlinedButton.icon(onPressed: onImport, icon: const Icon(Icons.file_download), label: const Text('IMPORTA / AGGIORNA')),
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

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const StatCard(this.title, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    return SizedBox(
      width: compact ? (MediaQuery.sizeOf(context).width - 36) / 2 : 220,
      child: Card(
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
    );
  }
}

class StudentsPage extends StatefulWidget {
  final List<Student> students;
  final Future<void> Function(Student?) onEdit;
  final void Function(Student) onDelete;
  const StudentsPage({super.key, required this.students, required this.onEdit, required this.onDelete});
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
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final s = list[index];
                    return Card(
                      child: ListTile(
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${s.disciplines.join(' • ')}\nTotale \u20AC ${s.total.toStringAsFixed(2)}  •  Versato \u20AC ${s.paid.toStringAsFixed(2)}  •  Saldo \u20AC ${s.balance.toStringAsFixed(2)}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          children: [
                            IconButton(onPressed: () => widget.onEdit(s), icon: const Icon(Icons.edit, color: kRed)),
                            IconButton(onPressed: () => widget.onDelete(s), icon: const Icon(Icons.delete_outline)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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
  const StudentDialog({super.key, this.student, required this.disciplines});
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
    await Share.shareXFiles([
      XFile.fromData(bytes, name: 'ricevuta_acconto_$safeName.pdf', mimeType: 'application/pdf'),
    ], subject: 'Ricevuta acconto - ${name.text.trim()}', text: phone.text.trim().isEmpty ? 'Ricevuta acconto Dynamique Ballet Studio' : 'Ricevuta acconto Dynamique Ballet Studio per ${name.text.trim()} - ${phone.text.trim()}');
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
                  onPressed: () {
                    final amount = valueOf(payment);
                    if (amount <= 0) return;
                    setState(() {
                      final newPayment = Payment(amount: amount, date: _today());
                      payments.add(newPayment);
                      payment.clear();
                      Future.microtask(() => _createReceiptAndShare(newPayment));
                    });
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
                      onPressed: () => setState(() => payments.removeAt(entry.key)),
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
