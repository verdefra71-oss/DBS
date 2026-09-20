import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kRed = Color(0xFFB51F2B);
const kDark = Color(0xFF424242);
const kLight = Color(0xFFF1F1F1);

void main() => runApp(const DynamiqueApp());

class DynamiqueApp extends StatelessWidget {
  const DynamiqueApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dynamique Ballet Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kRed, primary: kRed),
        scaffoldBackgroundColor: kLight,
        appBarTheme: const AppBarTheme(backgroundColor: kDark, foregroundColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Payment {
  final double amount;
  final String date;
  Payment({required this.amount, required this.date});
  Map<String, dynamic> toJson() => {'amount': amount, 'date': date};
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(amount: (j['amount'] ?? 0).toDouble(), date: j['date'] ?? '');
}

class Student {
  String id, name, phone, email, notes;
  List<String> disciplines;
  double participation, showCost, clothesCost;
  List<Payment> payments;
  Student({required this.id, required this.name, this.phone='', this.email='', this.notes='', this.disciplines=const [], this.participation=0, this.showCost=0, this.clothesCost=0, this.payments=const []});
  double get total => participation + showCost + clothesCost;
  double get paid => payments.fold(0, (s, p) => s + p.amount);
  double get balance => total - paid;
  Map<String, dynamic> toJson() => {'id': id,'name': name,'phone': phone,'email': email,'notes': notes,'disciplines': disciplines,'participation': participation,'showCost': showCost,'clothesCost': clothesCost,'payments': payments.map((p)=>p.toJson()).toList()};
  factory Student.fromJson(Map<String,dynamic> j) => Student(id:j['id'], name:j['name'], phone:j['phone']??'', email:j['email']??'', notes:j['notes']??'', disciplines:List<String>.from(j['disciplines']??[]), participation:(j['participation']??0).toDouble(), showCost:(j['showCost']??0).toDouble(), clothesCost:(j['clothesCost']??0).toDouble(), payments:(j['payments'] as List? ?? []).map((p)=>Payment.fromJson(Map<String,dynamic>.from(p))).toList());
}

class Discipline { String name; double fee; Discipline(this.name,this.fee); Map<String,dynamic> toJson()=>{'name':name,'fee':fee}; factory Discipline.fromJson(Map<String,dynamic> j)=>Discipline(j['name'],(j['fee']??0).toDouble()); }

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int tab=0;
  List<Student> students=[];
  List<Discipline> disciplines=[Discipline('Danza classica',45),Discipline('Danza moderna',45),Discipline('Hip Hop',40),Discipline('Contemporaneo',45),Discipline('Salsa New York',45),Discipline('Salsa cubana',45),Discipline('Bachata',45),Discipline('Hells',45),Discipline('Aerial Hoop',50)];
  bool loading=true;
  @override void initState(){super.initState(); load();}
  Future<void> load() async { final p=await SharedPreferences.getInstance(); final s=p.getString('students'); final d=p.getString('disciplines'); setState(() { if(s!=null) students=(jsonDecode(s) as List).map((x)=>Student.fromJson(Map<String,dynamic>.from(x))).toList(); if(d!=null) disciplines=(jsonDecode(d) as List).map((x)=>Discipline.fromJson(Map<String,dynamic>.from(x))).toList(); loading=false; }); }
  Future<void> save() async { final p=await SharedPreferences.getInstance(); await p.setString('students',jsonEncode(students.map((s)=>s.toJson()).toList())); await p.setString('disciplines',jsonEncode(disciplines.map((d)=>d.toJson()).toList())); }
  @override Widget build(BuildContext context){ if(loading) return const Scaffold(body:Center(child:CircularProgressIndicator())); final pages=[Dashboard(students:students,onAdd:()=>openStudent()),StudentsPage(students:students,disciplines:disciplines,onEdit:openStudent,onDelete:(s){setState(()=>students.remove(s));save();}),DisciplinesPage(disciplines:disciplines,onChanged:(){setState((){});save();})]; return Scaffold(body:Row(children:[NavigationRail(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),labelType:NavigationRailLabelType.all,backgroundColor:kDark,selectedIconTheme:const IconThemeData(color:Colors.white),unselectedIconTheme:const IconThemeData(color:Colors.white70),selectedLabelTextStyle:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold),unselectedLabelTextStyle:const TextStyle(color:Colors.white70),destinations:const [NavigationRailDestination(icon:Icon(Icons.dashboard),label:Text('Riepilogo')),NavigationRailDestination(icon:Icon(Icons.people),label:Text('Iscritti')),NavigationRailDestination(icon:Icon(Icons.menu_book),label:Text('Discipline'))]),Expanded(child:pages[tab])])) ; }
  Future<void> openStudent([Student? existing]) async { final result=await showDialog<Student>(context:context,builder:(_)=>StudentDialog(student:existing,disciplines:disciplines)); if(result!=null){setState(()=>existing==null?students.add(result):students[students.indexOf(existing)]=result);await save();}}
}

class Header extends StatelessWidget { final String title; const Header({super.key,required this.title}); @override Widget build(BuildContext c)=>Container(color:kDark,padding:const EdgeInsets.fromLTRB(28,18,28,18),child:Row(children:[Image.asset('assets/logo.jpg',height:70,width:190,fit:BoxFit.cover),const SizedBox(width:24),Expanded(child:Text(title,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.bold))),]); }

class Dashboard extends StatelessWidget { final List<Student> students; final VoidCallback onAdd; const Dashboard({super.key,required this.students,required this.onAdd}); @override Widget build(BuildContext c){final total=students.fold(0.0,(s,x)=>s+x.total),paid=students.fold(0.0,(s,x)=>s+x.paid),bal=total-paid; return Column(children:[Header(title:'Gestione Scuola di Danza'),Expanded(child:ListView(padding:const EdgeInsets.all(28),children:[Row(children:[StatCard('Iscritti','${students.length}',Icons.people),StatCard('Totale quote','€ ${total.toStringAsFixed(2)}',Icons.euro),StatCard('Incassato','€ ${paid.toStringAsFixed(2)}',Icons.payments),StatCard('Da incassare','€ ${bal.toStringAsFixed(2)}',Icons.account_balance_wallet)]),const SizedBox(height:24),Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Gestione iscrizioni',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:8),const Text('Inserisci nuovi allievi, assegna le discipline e registra quota, acconti, saggio e vestiti.'),const SizedBox(height:18),FilledButton.icon(onPressed:onAdd,icon:const Icon(Icons.person_add),label:const Text('INSERISCI NUOVO ISCRITTO'))]))),const SizedBox(height:16),if(students.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(24),child:Text('Nessun iscritto inserito.'))) else ...students.take(8).map((s)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:kRed,foregroundColor:Colors.white,child:Text(s.name.isEmpty?'?':s.name[0].toUpperCase())),title:Text(s.name),subtitle:Text(s.disciplines.join(' • ')),trailing:Text('Saldo € ${s.balance.toStringAsFixed(2)}',style:TextStyle(fontWeight:FontWeight.bold,color:s.balance<=0?Colors.green:kRed)))))]))]);}}
class StatCard extends StatelessWidget { final String a,b; final IconData icon; const StatCard(this.a,this.b,this.icon,{super.key}); @override Widget build(BuildContext c)=>Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:kRed,size:30),const SizedBox(height:8),Text(a,style:const TextStyle(color:kDark)),Text(b,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))])))); }

class StudentsPage extends StatefulWidget { final List<Student> students; final List<Discipline> disciplines; final Future<void> Function(Student?) onEdit; final void Function(Student) onDelete; const StudentsPage({super.key,required this.students,required this.disciplines,required this.onEdit,required this.onDelete}); @override State<StudentsPage> createState()=>_StudentsPageState(); }
class _StudentsPageState extends State<StudentsPage>{String q=''; @override Widget build(BuildContext c){final list=widget.students.where((s)=>s.name.toLowerCase().contains(q.toLowerCase())).toList();return Column(children:[Header(title:'Iscritti'),Padding(padding:const EdgeInsets.all(20),child:Row(children:[Expanded(child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Cerca iscritto...'),onChanged:(v)=>setState(()=>q=v))),const SizedBox(width:12),FilledButton.icon(onPressed:()=>widget.onEdit(null),icon:const Icon(Icons.add),label:const Text('Nuovo iscritto'))])),Expanded(child:list.isEmpty?const Center(child:Text('Nessun risultato')):ListView.builder(padding:const EdgeInsets.symmetric(horizontal:20),itemCount:list.length,itemBuilder:(c,i){final s=list[i];return Card(child:ListTile(title:Text(s.name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${s.disciplines.join(' • ')}\nTotale € ${s.total.toStringAsFixed(2)}  •  Versato € ${s.paid.toStringAsFixed(2)}  •  Saldo € ${s.balance.toStringAsFixed(2)}'),isThreeLine:true,trailing:Wrap(children:[IconButton(onPressed:()=>widget.onEdit(s),icon:const Icon(Icons.edit,color:kRed)),IconButton(onPressed:()=>widget.onDelete(s),icon:const Icon(Icons.delete_outline))])));})]);}}

class DisciplinesPage extends StatelessWidget { final List<Discipline> disciplines; final VoidCallback onChanged; const DisciplinesPage({super.key,required this.disciplines,required this.onChanged}); @override Widget build(BuildContext c)=>Column(children:[Header(title:'Discipline e quote mensili'),Expanded(child:ListView(padding:const EdgeInsets.all(20),children:[...disciplines.map((d)=>Card(child:ListTile(leading:const Icon(Icons.music_note,color:kRed),title:Text(d.name),trailing:Text('€ ${d.fee.toStringAsFixed(2)} / mese',style:const TextStyle(fontWeight:FontWeight.bold))))),const SizedBox(height:12),FilledButton.icon(onPressed:()async{final n=TextEditingController(),f=TextEditingController();final ok=await showDialog<bool>(context:c,builder:(_)=>AlertDialog(title:const Text('Nuova disciplina'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Nome disciplina')),const SizedBox(height:12),TextField(controller:f,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quota mensile (€)'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annulla')),FilledButton(onPressed:(){if(n.text.trim().isNotEmpty){disciplines.add(Discipline(n.text.trim(),double.tryParse(f.text.replaceAll(',','.'))??0));Navigator.pop(c,true);}},child:const Text('Salva'))]));if(ok==true)onChanged();},icon:const Icon(Icons.add),label:const Text('Aggiungi disciplina'))]))]); }

class StudentDialog extends StatefulWidget { final Student? student; final List<Discipline> disciplines; const StudentDialog({super.key,this.student,required this.disciplines}); @override State<StudentDialog> createState()=>_StudentDialogState(); }
class _StudentDialogState extends State<StudentDialog>{late TextEditingController name,phone,email,notes,participation,show,clothes,payment;late List<String> selected;late List<Payment> payments; @override void initState(){super.initState();final s=widget.student;name=TextEditingController(text:s?.name??'');phone=TextEditingController(text:s?.phone??'');email=TextEditingController(text:s?.email??'');notes=TextEditingController(text:s?.notes??'');participation=TextEditingController(text:s?.participation.toString()??'');show=TextEditingController(text:s?.showCost.toString()??'');clothes=TextEditingController(text:s?.clothesCost.toString()??'');payment=TextEditingController();selected=[...(s?.disciplines??[])];payments=[...(s?.payments??[])];}
  double num(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'))??0;
  @override Widget build(BuildContext c)=>AlertDialog(title:Text(widget.student==null?'Inserisci nuovo iscritto':'Modifica iscritto'),content:SizedBox(width:700,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nome e cognome *')),const SizedBox(height:10),Row(children:[Expanded(child:TextField(controller:phone,decoration:const InputDecoration(labelText:'Telefono'))),const SizedBox(width:10),Expanded(child:TextField(controller:email,decoration:const InputDecoration(labelText:'Email')))]),const SizedBox(height:16),const Text('Discipline',style:TextStyle(fontWeight:FontWeight.bold)),Wrap(spacing:8,children:widget.disciplines.map((d)=>FilterChip(label:Text(d.name),selected:selected.contains(d.name),onSelected:(v)=>setState(()=>v?selected.add(d.name):selected.remove(d.name)))).toList()),const SizedBox(height:16),const Text('Costi',style:TextStyle(fontWeight:FontWeight.bold)),Row(children:[Expanded(child:TextField(controller:participation,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quota partecipazione (€)'))),const SizedBox(width:10),Expanded(child:TextField(controller:show,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Costo saggio (€)'))),const SizedBox(width:10),Expanded(child:TextField(controller:clothes,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Vestiti (€)')))]),const SizedBox(height:18),Row(children:[Expanded(child:TextField(controller:payment,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Importo acconto (€)'))),const SizedBox(width:10),FilledButton.icon(onPressed:(){final v=num(payment);if(v>0){setState((){payments.add(Payment(amount:v,date:DateTime.now().toString().substring(0,10)));payment.clear();});}},icon:const Icon(Icons.add),label:const Text('Aggiungi acconto'))]),if(payments.isNotEmpty) ...[const SizedBox(height:8),...payments.asMap().entries.map((e)=>ListTile(dense:true,leading:const Icon(Icons.payments,color:kRed),title:Text('Acconto € ${e.value.amount.toStringAsFixed(2)}'),subtitle:Text(e.value.date),trailing:IconButton(onPressed:()=>setState(()=>payments.removeAt(e.key)),icon:const Icon(Icons.delete_outline))))],const SizedBox(height:12),Text('Totale: € ${(num(participation)+num(show)+num(clothes)).toStringAsFixed(2)}    Versato: € ${payments.fold(0.0,(x,p)=>x+p.amount).toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:12),TextField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Note'))])),),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Annulla')),FilledButton(onPressed:(){if(name.text.trim().isEmpty)return;Navigator.pop(c,Student(id:widget.student?.id??DateTime.now().microsecondsSinceEpoch.toString(),name:name.text.trim(),phone:phone.text.trim(),email:email.text.trim(),notes:notes.text.trim(),disciplines:selected,participation:num(participation),showCost:num(show),clothesCost:num(clothes),payments:payments));},child:const Text('SALVA'))]);}
  @override void dispose(){for(final x in [name,phone,email,notes,participation,show,clothes,payment])x.dispose();super.dispose();}
}
