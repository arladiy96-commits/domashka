import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'ai_service.dart';
import 'models.dart';
import 'store.dart';

const ink = Color(0xff142b50);
const accent = Color(0xff246af3);
const muted = Color(0xff71819c);

void message(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text),
    behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)));
}

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = Colors.white});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: const Color(0xff254b84).withOpacity(.055),
        blurRadius: 23, offset: const Offset(0, 7))]), child: child);
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink)),
    if (subtitle != null) ...[const SizedBox(height: 5), Text(subtitle!,
      style: const TextStyle(color: muted, fontSize: 13))]
  ]);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController anim;
  @override
  void initState() {
    super.initState();
    anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..forward();
    Future<void>.delayed(const Duration(milliseconds: 2450), () {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => HomeShell(store: widget.store)));
    });
  }
  @override
  void dispose() { anim.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(body: AnimatedBuilder(
    animation: anim, builder: (context, _) {
      final t = Curves.easeOutCubic.transform(anim.value);
      return Stack(children: [
        const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient:
          LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xfffcfdff), Color(0xffeaf3ff), Color(0xffeae6ff)])))),
        Positioned(top: 92, left: 26, child: Opacity(opacity: t,
          child: Transform.translate(offset: Offset(-38 * (1 - t), 0),
            child: const Text('✦    ✧    ✦', style: TextStyle(color: Color(0xff4b9df1), fontSize: 26))))),
        Positioned(bottom: 125, right: 25, child: Opacity(opacity: t,
          child: Transform.translate(offset: Offset(38 * (1 - t), 0),
            child: const Text('✿     ✦    ✧', style: TextStyle(color: Color(0xffef9b68), fontSize: 28))))),
        Center(child: Transform.scale(scale: .72 + .28 * t,
          child: Opacity(opacity: t, child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              Container(width: 190, height: 190,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(50),
                  boxShadow: [BoxShadow(color: accent.withOpacity(.18), blurRadius: 38,
                    offset: const Offset(0, 19))]),
                child: ClipRRect(borderRadius: BorderRadius.circular(50),
                  child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover))),
              const SizedBox(height: 25),
              const Text('Домашка', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900,
                color: ink, letterSpacing: -.8)),
              const SizedBox(height: 7),
              const Text('Учиться легко, когда всё понятно',
                style: TextStyle(color: muted, fontSize: 14)),
            ])))),
        Positioned(left: 75, right: 75, bottom: 65, child: LinearProgressIndicator(
          minHeight: 3, borderRadius: BorderRadius.circular(10), value: t,
          backgroundColor: const Color(0xffd9e6ff))),
      ]);
    }));
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final AppStore store;
  @override
  State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: widget.store,
    builder: (context, _) => Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: [
        HomeDashboard(store: widget.store, selectTab: (v) => setState(() => tab = v)),
        LibraryPage(store: widget.store),
        LearningPage(store: widget.store),
        HistoryPage(store: widget.store),
        SettingsPage(store: widget.store),
      ])),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, elevation: 0,
        backgroundColor: Colors.white, indicatorColor: const Color(0xffe5f0ff),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Учебники'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Обучение'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'История'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ещё'),
        ])));
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key, required this.store, required this.selectTab});
  final AppStore store;
  final ValueChanged<int> selectTab;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 17, 20, 30), children: [
    Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('ПРИВЕТ! 👋', style: TextStyle(fontSize: 12, letterSpacing: 1.2,
        color: accent, fontWeight: FontWeight.w800)), SizedBox(height: 4),
        Text('Что сегодня учим?', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: ink))])),
      CircleAvatar(backgroundColor: const Color(0xffe2eeff), radius: 24,
        child: IconButton(onPressed: () => selectTab(4), icon: const Icon(Icons.tune, color: accent)))]),
    const SizedBox(height: 19),
    Container(height: 220, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff132f6a), Color(0xff426ff0)]),
        borderRadius: BorderRadius.circular(26)),
      child: Stack(children: [
        const Positioned(top: -35, right: -27, child: Icon(Icons.auto_awesome,
          color: Color(0x55ffffff), size: 135)),
        Positioned(right: 5, bottom: -5, child: Image.asset('assets/images/app_icon.png', width: 160)),
        Positioned(left: 20, top: 22, right: 130, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ТВОЙ ПОМОЩНИК', style: TextStyle(color: Color(0xffcbdfff),
              fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.1)),
            const SizedBox(height: 12),
            const Text('Домашка\nбез сложностей', style: TextStyle(color: Colors.white,
              fontSize: 23, fontWeight: FontWeight.w900, height: 1.12)),
            const SizedBox(height: 13),
            Text('Поймём, решим\nи закрепим ✨', style: TextStyle(
              color: Colors.white.withOpacity(.82), fontSize: 13, height: 1.45)),
          ])),
      ])),
    const SizedBox(height: 27),
    const SectionHead('Начнём?', subtitle: 'Выбери удобный способ решить задание'),
    const SizedBox(height: 15),
    ActionTile(icon: Icons.menu_book_rounded, iconColor: const Color(0xff2877f5),
      tint: const Color(0xffeaf3ff), title: 'Открыть учебник',
      subtitle: 'Найти страницу и номер задания', onTap: () => selectTab(1)),
    const SizedBox(height: 11),
    ActionTile(icon: Icons.document_scanner_rounded, iconColor: const Color(0xffd642b5),
      tint: const Color(0xffffe8f8), title: 'Фото карточки',
      subtitle: 'Прочитаем и решим все упражнения', onTap: () => openPhotoChoice(context, store)),
    const SizedBox(height: 11),
    ActionTile(icon: Icons.calculate_rounded, iconColor: const Color(0xff7144e6),
      tint: const Color(0xfff0eaff), title: 'Решить вручную',
      subtitle: 'Введи пример или условие задачи', onTap: () => openManual(context, store)),
    const SizedBox(height: 11),
    ActionTile(icon: Icons.psychology_alt_rounded, iconColor: const Color(0xff00a586),
      tint: const Color(0xffe4faf3), title: 'Потренироваться',
      subtitle: 'Правила, объяснения и похожие задания', onTap: () => selectTab(2)),
    if (store.history.isNotEmpty) ...[
      const SizedBox(height: 27), const SectionHead('Недавно решали'),
      const SizedBox(height: 12),
      ActionTile(icon: Icons.task_alt, iconColor: accent, tint: const Color(0xffeaf3ff),
        title: store.history.first.problem.replaceAll('\n', ' '),
        subtitle: store.history.first.source,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => SolutionPage(result: store.history.first))))
    ],
  ]);
}

class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.iconColor,
    required this.tint, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color iconColor, tint;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap,
    borderRadius: BorderRadius.circular(22), child: Surface(child: Row(children: [
      Container(width: 55, height: 55, decoration: BoxDecoration(color: tint,
        borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: iconColor, size: 28)),
      const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 5), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 12))])),
      const Icon(Icons.chevron_right, color: muted),
    ])));
}

Future<void> openManual(BuildContext context, AppStore store) async {
  final ctrl = TextEditingController();
  await showModalBottomSheet<void>(context: context, isScrollControlled: true,
    backgroundColor: const Color(0xfff5f8fe),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheet) => Padding(padding: EdgeInsets.fromLTRB(20, 25, 20,
      MediaQuery.viewInsetsOf(sheet).bottom + 26), child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHead('Введи задание', subtitle: 'Пример, уравнение или текст задачи'),
        const SizedBox(height: 17), TextField(controller: ctrl, maxLines: 4, minLines: 2,
          autofocus: true, decoration: const InputDecoration(hintText: 'Например: 64 − 28 = ?')),
        const SizedBox(height: 15), SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () { final text = ctrl.text.trim(); if (text.isEmpty) return;
            Navigator.pop(sheet); startSolve(context, store, text, source: 'Вручную'); },
          icon: const Icon(Icons.auto_awesome), label: const Text('Решить и объяснить'))),
      ])));
  ctrl.dispose();
}

Future<void> openPhotoChoice(BuildContext context, AppStore store) async {
  final source = await showModalBottomSheet<ImageSource>(context: context,
    builder: (sheet) => SafeArea(child: Padding(padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SectionHead('Добавить карточку'), const SizedBox(height: 17),
        ListTile(leading: const Icon(Icons.photo_camera_outlined, color: accent),
          title: const Text('Сфотографировать'), onTap: () => Navigator.pop(sheet, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined, color: accent),
          title: const Text('Выбрать из галереи'), onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
      ]))));
  if (source == null || !context.mounted) return;
  try {
    final image = await ImagePicker().pickImage(source: source,
      maxWidth: 1800, imageQuality: 86);
    if (image == null || !context.mounted) return;
    final bytes = await image.readAsBytes();
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingImagePage(store: store, image: bytes)));
  } catch (error) { if (context.mounted) message(context, '$error'); }
}

Future<void> startSolve(BuildContext context, AppStore store, String text, {
  required String source, String? bookId, int? page, String? number}) async {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ProcessingPage(
    store: store, text: text, source: source, bookId: bookId, page: page, number: number)));
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.store});
  final AppStore store;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}
class _LibraryPageState extends State<LibraryPage> {
  String search = '';
  Future<void> import() async {
    try {
      final book = await widget.store.importBook();
      if (book != null && mounted) Navigator.push(context, MaterialPageRoute(
        builder: (_) => BookReader(store: widget.store, book: book)));
    } catch (e) { if (mounted) message(context, 'Ошибка загрузки PDF: $e'); }
  }
  @override
  Widget build(BuildContext context) {
    final books = widget.store.books.where((e) =>
      e.title.toLowerCase().contains(search.toLowerCase())).toList();
    return Stack(children: [ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), children: [
      Row(children: [const Expanded(child: SectionHead('Мои учебники',
        subtitle: 'Настоящие страницы всегда под рукой')),
        IconButton.filled(onPressed: widget.store.busy ? null : import,
          icon: const Icon(Icons.add_rounded))]),
      const SizedBox(height: 19),
      TextField(onChanged: (v) => setState(() => search = v),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
          hintText: 'Поиск по названию...')),
      const SizedBox(height: 20),
      if (books.isEmpty) Surface(child: Column(children: [
        const SizedBox(height: 18), const Icon(Icons.menu_book_rounded,
          color: Color(0xff538df1), size: 65), const SizedBox(height: 14),
        const Text('Добавим первый учебник?', style: TextStyle(color: ink,
          fontWeight: FontWeight.w800, fontSize: 18)), const SizedBox(height: 8),
        const Text('Выбери PDF. Домашка откроет страницы и построит указатель текста.',
          textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.45)),
        const SizedBox(height: 16), FilledButton.icon(onPressed: import,
          icon: const Icon(Icons.upload_file), label: const Text('Загрузить PDF')),
        const SizedBox(height: 14),
      ])) else GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,
          crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: .73),
        itemCount: books.length, itemBuilder: (context, i) {
          final book = books[i];
          final colors = [const Color(0xffb5e9ff), const Color(0xffffdbbd),
            const Color(0xffe6daff), const Color(0xffd0f5dc)];
          return InkWell(borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              BookReader(store: widget.store, book: book))),
            onLongPress: () => _confirmDelete(book),
            child: Surface(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Container(width: double.infinity,
                decoration: BoxDecoration(color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(14)),
                child: Stack(children: [
                  Center(child: Icon(Icons.auto_stories_rounded, size: 73,
                    color: ink.withOpacity(.68))),
                  const Positioned(top: 10, right: 10,
                    child: Icon(Icons.stars_rounded, color: Colors.white, size: 27)),
                ]))), const SizedBox(height: 10),
              Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 13)),
              const SizedBox(height: 4), Text('${book.pageCount} страниц · PDF',
                style: const TextStyle(color: muted, fontSize: 11)),
            ])));
        }),
    ]),
      if (widget.store.busy) Container(color: Colors.black.withOpacity(.25),
        child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 35),
          child: Surface(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_stories_rounded, color: accent, size: 45),
            const SizedBox(height: 15), Text(widget.store.activity,
              style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 15), LinearProgressIndicator(value: widget.store.importProgress),
            const SizedBox(height: 10), Text('${(widget.store.importProgress * 100).round()}%'),
          ]))))),
    ]);
  }

  Future<void> _confirmDelete(BookRecord book) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Удалить учебник?'), content: Text(book.title),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog, false),
        child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Удалить'))]));
    if (confirmed == true) await widget.store.deleteBook(book);
  }
}

class BookReader extends StatefulWidget {
  const BookReader({super.key, required this.store, required this.book});
  final AppStore store;
  final BookRecord book;
  @override
  State<BookReader> createState() => _BookReaderState();
}
class _BookReaderState extends State<BookReader> {
  final viewer = PdfViewerController();
  final printed = TextEditingController(text: '1');
  final exercise = TextEditingController();
  int current = 1;
  bool looking = false;
  @override
  void initState() {
    super.initState();
    current = (1 + widget.book.offset).clamp(1, widget.book.pageCount).toInt();
    printed.text = (current - widget.book.offset).toString();
    viewer.addListener(_listenViewer);
  }
  void _listenViewer() {
    if (!viewer.isReady) return;
    final page = viewer.pageNumber;
    if (page != null && page != current && mounted) {
      setState(() { current = page; printed.text = (page - widget.book.offset).toString(); });
    }
  }
  @override
  void dispose() {
    viewer.removeListener(_listenViewer); viewer.dispose();
    printed.dispose(); exercise.dispose(); super.dispose();
  }
  void jump(int pdfPage) {
    if (pdfPage < 1 || pdfPage > widget.book.pageCount) {
      message(context, 'Нет такой страницы PDF. Проверь смещение нумерации.'); return;
    }
    setState(() { current = pdfPage; printed.text = (pdfPage - widget.book.offset).toString(); });
    if (viewer.isReady) viewer.setCurrentPageNumber(pdfPage);
    FocusManager.instance.primaryFocus?.unfocus();
  }
  Future<void> find() async {
    final input = int.tryParse(printed.text.trim());
    if (input == null) { message(context, 'Укажите номер страницы.'); return; }
    final page = widget.book.pdfPage(input);
    if (page < 1 || page > widget.book.pageCount) {
      message(context, 'Печатная страница не соответствует PDF. Уточните смещение.'); return;
    }
    jump(page);
    final num = exercise.text.trim();
    if (num.isEmpty) { message(context, 'Введите номер задания.'); return; }
    final pageText = widget.book.textAt(page);
    final matched = extractExercise(pageText, num);
    if (matched != null && matched.trim().isNotEmpty) {
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) =>
        ConfirmExercisePage(store: widget.store, book: widget.book,
          printedPage: input, exercise: Exercise(num, matched),
          uncertain: !RegExp('(?:^|\\s)${RegExp.escape(num)}\\s*[.)№:]', multiLine: true).hasMatch(pageText))));
      return;
    }
    if (widget.store.geminiKey.isEmpty) {
      message(context, 'Текст страницы не найден. Добавьте Gemini в настройках, чтобы прочитать скан.');
      return;
    }
    setState(() => looking = true);
    try {
      final candidates = await AiService(widget.store).readPdfPage(widget.book.path, page);
      if (!mounted) return;
      final found = candidates.where((e) => e.number.replaceAll(RegExp(r'\D'), '') ==
        num.replaceAll(RegExp(r'\D'), '')).toList();
      final choice = found.isNotEmpty ? found.first : null;
      if (choice != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmExercisePage(
          store: widget.store, book: widget.book,
          printedPage: input, exercise: choice, uncertain: false)));
      } else if (candidates.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseSelectionPage(
          store: widget.store, exercises: candidates, source: 'Учебник: ${widget.book.title}',
          bookId: widget.book.id, printedPage: input)));
      } else {
        message(context, 'Gemini не нашёл заданий на этой странице.');
      }
    } catch (error) { if (mounted) message(context, '$error'); }
    finally { if (mounted) setState(() => looking = false); }
  }

  Future<void> changeOffset() async {
    final controller = TextEditingController(text: widget.book.offset.toString());
    final value = await showDialog<int>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Смещение нумерации'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Если в файле PDF печатная страница 10 находится на 13-й странице, укажи +3.'),
        const SizedBox(height: 10), TextField(controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(labelText: 'Смещение')),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(dialog),
        child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(dialog,
          int.tryParse(controller.text)), child: const Text('Сохранить'))]));
    controller.dispose();
    if (value != null) { widget.book.offset = value; await widget.store.save();
      if (mounted) setState(() => printed.text = (current - value).toString()); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [IconButton(onPressed: changeOffset,
        tooltip: 'Нумерация страниц', icon: const Icon(Icons.tune_rounded))]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), child: Row(children: [
        IconButton(onPressed: () => jump(current - 1), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(child: Center(child: Text('Страница PDF $current / ${widget.book.pageCount}',
          style: const TextStyle(color: ink, fontWeight: FontWeight.w700)))),
        IconButton(onPressed: () => jump(current + 1), icon: const Icon(Icons.chevron_right_rounded)),
      ])),
      Expanded(child: PdfViewer.file(widget.book.path, controller: viewer,
        initialPageNumber: current, params: const PdfViewerParams(
          backgroundColor: Color(0xffe9eef7)))),
      Surface(padding: const EdgeInsets.fromLTRB(14, 15, 14, 20), child: Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: printed, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Страница', isDense: true))),
          const SizedBox(width: 9),
          Expanded(child: TextField(controller: exercise,
            decoration: const InputDecoration(labelText: '№ задания', isDense: true))),
        ]), const SizedBox(height: 11),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: looking ? null : find,
          icon: looking ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(
            color: Colors.white, strokeWidth: 2)) : const Icon(Icons.search),
          label: Text(looking ? 'Читаем страницу...' : 'Найти задание'))),
      ])),
    ]));
}

String? extractExercise(String text, String number) {
  if (text.trim().isEmpty) return null;
  final pattern = RegExp('(?:^|\\s)${RegExp.escape(number)}\\s*[.)№:]\\s*', multiLine: true);
  final match = pattern.firstMatch(text);
  if (match == null) return null;
  final next = RegExp(r'(?:^|\n|\s)\d{1,3}\s*[.)]\s+', multiLine: true);
  final rest = text.substring(match.end);
  final end = next.firstMatch(rest);
  final selection = end == null ? rest : rest.substring(0, end.start);
  return selection.trim().length > 550 ? selection.trim().substring(0, 550) : selection.trim();
}

class ReadingImagePage extends StatefulWidget {
  const ReadingImagePage({super.key, required this.store, required this.image});
  final AppStore store;
  final Uint8List image;
  @override
  State<ReadingImagePage> createState() => _ReadingImagePageState();
}
class _ReadingImagePageState extends State<ReadingImagePage> {
  bool loading = true;
  String? error;
  List<Exercise> exercises = [];
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => read()); }
  Future<void> read() async {
    setState(() { loading = true; error = null; });
    try { final found = await AiService(widget.store).readImage(widget.image);
      if (mounted) setState(() => exercises = found);
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Фото задания')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(widget.image,
        height: 200, fit: BoxFit.cover)),
      const SizedBox(height: 20),
      if (loading) const Surface(child: Column(children: [
        CircularProgressIndicator(), SizedBox(height: 14),
        Text('Gemini читает карточку...'),
      ])) else if (error != null) Surface(child: Column(children: [
        const Icon(Icons.wifi_off_rounded, color: accent, size: 42),
        const SizedBox(height: 10), Text(error!),
        const SizedBox(height: 14), FilledButton(onPressed: read,
          child: const Text('Повторить')),
      ])) else if (exercises.isEmpty) const Surface(child: Text('Упражнения на фотографии не найдены.'))
      else Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead('Прочитано: ${exercises.length} заданий',
          subtitle: 'Проверь распознанный текст перед решением'),
        const SizedBox(height: 13),
        ...exercises.map((task) => Padding(padding: const EdgeInsets.only(bottom: 11),
          child: ActionTile(icon: Icons.checklist_rounded, iconColor: accent,
            tint: const Color(0xffeaf3ff), title: 'Задание ${task.number}',
            subtitle: task.text,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              ConfirmExercisePage(store: widget.store, exercise: task)))))),
        FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ExerciseSelectionPage(store: widget.store, exercises: exercises,
            source: 'Карточка'))), icon: const Icon(Icons.auto_awesome),
          label: const Text('Посмотреть все задания')),
      ]),
    ]));
}

class ExerciseSelectionPage extends StatelessWidget {
  const ExerciseSelectionPage({super.key, required this.store, required this.exercises,
    required this.source, this.bookId, this.printedPage});
  final AppStore store;
  final List<Exercise> exercises;
  final String source;
  final String? bookId;
  final int? printedPage;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Найденные задания')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const SectionHead('Проверь задания', subtitle: 'Выбери то, которое нужно решить'),
      const SizedBox(height: 15),
      ...exercises.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ConfirmExercisePage(store: store, exercise: e,
            bookId: bookId, printedPage: printedPage, source: source))),
          child: Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('Задание ${e.number}', style: const TextStyle(color: accent,
              fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(e.text,
              style: const TextStyle(color: ink, height: 1.5))]))))),
    ]));
}

class ConfirmExercisePage extends StatefulWidget {
  const ConfirmExercisePage({super.key, required this.store, required this.exercise,
    this.book, this.bookId, this.printedPage, this.source, this.uncertain = false});
  final AppStore store;
  final Exercise exercise;
  final BookRecord? book;
  final String? bookId, source;
  final int? printedPage;
  final bool uncertain;
  @override
  State<ConfirmExercisePage> createState() => _ConfirmExercisePageState();
}
class _ConfirmExercisePageState extends State<ConfirmExercisePage> {
  late final TextEditingController text;
  @override
  void initState() { super.initState(); text = TextEditingController(text: widget.exercise.text); }
  @override
  void dispose() { text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Подтверждение')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const SectionHead('Всё правильно?', subtitle: 'Перед решением проверь, что все числа и знаки точны'),
      const SizedBox(height: 15),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ЗАДАНИЕ ${widget.exercise.number}', style: const TextStyle(
          color: accent, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 13),
        TextField(controller: text, maxLines: null, minLines: 5,
          style: const TextStyle(color: ink, fontSize: 16, height: 1.5),
          decoration: const InputDecoration(hintText: 'Условие задания')),
      ])),
      const SizedBox(height: 14),
      if (widget.uncertain) const Surface(color: Color(0xfffff4e5),
        child: Text('Не получилось уверенно отделить номер задания от текста. '
          'Проверь и при необходимости исправь условие.',
          style: TextStyle(color: Color(0xff85510b)))) ,
      const SizedBox(height: 15),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: () { if (text.text.trim().isEmpty) { message(context, 'Введи условие.'); return; }
          startSolve(context, widget.store, text.text.trim(),
            source: widget.source ?? (widget.book != null ? 'Учебник: ${widget.book!.title}' : 'Карточка'),
            bookId: widget.book?.id ?? widget.bookId,
            page: widget.printedPage, number: widget.exercise.number); },
        icon: const Icon(Icons.auto_awesome), label: const Text('Подтвердить и решить'))),
      const SizedBox(height: 12),
      const Text('Изображения и учебник не изменяются. Исправленный текст используется только для этого решения.',
        textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
    ]));
}

class ProcessingPage extends StatefulWidget {
  const ProcessingPage({super.key, required this.store, required this.text,
    required this.source, this.bookId, this.page, this.number});
  final AppStore store;
  final String text, source;
  final String? bookId, number;
  final int? page;
  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}
class _ProcessingPageState extends State<ProcessingPage> {
  String? error;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => process()); }
  Future<void> process() async {
    try {
      final result = await AiService(widget.store).solve(widget.text, source: widget.source,
        bookId: widget.bookId, page: widget.page, number: widget.number);
      await widget.store.remember(result);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SolutionPage(result: result)));
    } catch (e) { if (mounted) setState(() => error = '$e'); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Решаем задание')),
    body: Center(child: Padding(padding: const EdgeInsets.all(23), child: Surface(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (error == null) ...[
          const Icon(Icons.psychology_rounded, size: 74, color: accent),
          const SizedBox(height: 13), const CircularProgressIndicator(),
          const SizedBox(height: 15), const Text('Решаем и проверяем...', style: TextStyle(
            color: ink, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 9), const Text('Математический движок · Grok · Gemini',
            style: TextStyle(color: muted), textAlign: TextAlign.center),
        ] else ...[
          const Icon(Icons.error_outline_rounded, color: Colors.orange, size: 50),
          const SizedBox(height: 9), Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 12), FilledButton(onPressed: () => Navigator.pop(context),
            child: const Text('Вернуться')),
        ]
      ])))));
}

class SolutionPage extends StatefulWidget {
  const SolutionPage({super.key, required this.result});
  final StudyResult result;
  @override
  State<SolutionPage> createState() => _SolutionPageState();
}
class _SolutionPageState extends State<SolutionPage> {
  int view = 0;
  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(appBar: AppBar(title: const Text('Готовое решение')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.assignment_outlined, color: accent),
            const SizedBox(width: 9), Expanded(child: Text(result.source,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w700))) ,
            Icon(result.verified ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: result.verified ? const Color(0xff13b78a) : Colors.amber[700])]),
          const SizedBox(height: 15), Text(result.problem, style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: ink, height: 1.45)),
        ])),
        const SizedBox(height: 13),
        if (result.answer.isNotEmpty) Surface(color: const Color(0xffe6f8f1),
          child: Row(children: [const CircleAvatar(backgroundColor: Color(0xff15b889),
            child: Icon(Icons.check, color: Colors.white)), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ответ', style: TextStyle(fontSize: 12, color: Color(0xff238e70))),
              Text(result.answer, style: const TextStyle(fontWeight: FontWeight.w900,
                fontSize: 20, color: Color(0xff0d6a54))),
            ]))])),
        if (result.warning.isNotEmpty) ...[
          const SizedBox(height: 12), Surface(color: const Color(0xfffff2df),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xff9c670d)),
              const SizedBox(width: 10), Expanded(child: Text(result.warning,
                style: const TextStyle(color: Color(0xff80520b), fontSize: 13))),
            ])),
        ],
        const SizedBox(height: 20), SegmentedButton<int>(showSelectedIcon: false,
          style: SegmentedButton.styleFrom(selectedBackgroundColor: const Color(0xffdfeaff)),
          segments: const [ButtonSegment(value: 0, label: Text('Решение')),
            ButtonSegment(value: 1, label: Text('Объяснение')),
            ButtonSegment(value: 2, label: Text('Правило'))],
          selected: {view}, onSelectionChanged: (values) => setState(() => view = values.first)),
        const SizedBox(height: 14),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(['Как в тетради', 'Поймём вместе', 'Запомни правило'][view],
            style: const TextStyle(fontSize: 18, color: ink, fontWeight: FontWeight.w900)),
            const Spacer(), if (view == 0) IconButton(tooltip: 'Скопировать',
              onPressed: () { Clipboard.setData(ClipboardData(text: result.notebook));
                message(context, 'Решение скопировано'); },
              icon: const Icon(Icons.copy_rounded, color: accent))]),
          const SizedBox(height: 10),
          Text([result.notebook, result.explanation, result.rule][view].isEmpty
            ? 'Здесь пока нет готового объяснения. Для сложной задачи подключите Grok.'
            : [result.notebook, result.explanation, result.rule][view],
            style: const TextStyle(fontSize: 16, height: 1.6, color: ink)),
        ])),
        const SizedBox(height: 22),
        if (result.practice.isNotEmpty) ...[
          const SectionHead('Закрепим тему?', subtitle: 'Попробуйте решить три похожих задания'),
          const SizedBox(height: 13), PracticePanel(tasks: result.practice),
        ] else const Surface(child: Text('Похожие задания появятся после решения '
          'поддерживаемого примера или при подключении Grok.',
          style: TextStyle(color: muted))),
      ]));
  }
}

class PracticePanel extends StatefulWidget {
  const PracticePanel({super.key, required this.tasks});
  final List<PracticeTask> tasks;
  @override
  State<PracticePanel> createState() => _PracticePanelState();
}
class _PracticePanelState extends State<PracticePanel> {
  final answers = <int, String>{};
  final checked = <int, bool>{};
  @override
  Widget build(BuildContext context) => Column(children: [
    for (var i = 0; i < widget.tasks.length; i++) Padding(
      padding: const EdgeInsets.only(bottom: 10), child: Surface(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}.  ${widget.tasks[i].question}',
            style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 9), Row(children: [
            Expanded(child: TextFormField(key: ValueKey('practice-$i'),
              onChanged: (text) => answers[i] = text,
              decoration: const InputDecoration(hintText: 'Твой ответ', isDense: true))),
            const SizedBox(width: 9), IconButton.filledTonal(
              onPressed: () => setState(() { checked[i] = _isCorrect(
                answers[i] ?? '', widget.tasks[i].answer); }),
              icon: const Icon(Icons.check)),
          ]),
          if (checked.containsKey(i)) ...[
            const SizedBox(height: 8), Text(checked[i]!
              ? '✓ Верно! Отличная работа.'
              : 'Пока нет. Ответ для проверки: ${widget.tasks[i].answer}',
              style: TextStyle(color: checked[i]! ? const Color(0xff0a936e)
                : const Color(0xffaa6825), fontSize: 13)),
          ],
        ]))),
  ]);
  bool _isCorrect(String a, String b) {
    final normalizedA = a.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final normalizedB = b.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedA == normalizedB) return true;
    final numberA = RegExp(r'-?\d+').firstMatch(normalizedA)?.group(0);
    final numberB = RegExp(r'-?\d+').firstMatch(normalizedB)?.group(0);
    return numberA != null && numberB != null && numberA == numberB;
  }
}

class LearningPage extends StatelessWidget {
  const LearningPage({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    const lessons = [
      ['Сложение', 'Собираем числа вместе', '27 + 15'],
      ['Вычитание', 'Находим остаток и разницу', '84 − 36'],
      ['Умножение', 'Считаем равные группы', '6 × 7'],
      ['Деление', 'Делим на равные части', '48 ÷ 6'],
      ['Уравнения', 'Находим неизвестное', 'x + 17 = 42'],
    ];
    return ListView(padding: const EdgeInsets.all(20), children: [
      const SectionHead('Учимся вместе',
        subtitle: 'Простые правила и практика для закрепления'),
      const SizedBox(height: 18),
      Surface(color: const Color(0xffe9e5ff), child: Row(children: [
        const Icon(Icons.school_rounded, color: Color(0xff704dde), size: 46),
        const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: const [Text('Учимся на примерах', style: TextStyle(
            color: ink, fontWeight: FontWeight.w900, fontSize: 17)),
            SizedBox(height: 5), Text('Сначала объяснение, потом проверка себя.',
              style: TextStyle(color: muted, fontSize: 13))]))])),
      const SizedBox(height: 19),
      ...lessons.map((lesson) => Padding(padding: const EdgeInsets.only(bottom: 12),
        child: ActionTile(icon: Icons.lightbulb_rounded, iconColor: const Color(0xffc88a24),
          tint: const Color(0xfffff2d4), title: lesson[0], subtitle: lesson[1],
          onTap: () => startSolve(context, store, lesson[2], source: 'Тренировка · ${lesson[0]}')))),
      if (store.history.any((r) => r.practice.isNotEmpty)) ...[
        const SizedBox(height: 17), const SectionHead('Продолжить тренировку'),
        const SizedBox(height: 12), ActionTile(icon: Icons.fitness_center_rounded,
          iconColor: const Color(0xff1f9e82), tint: const Color(0xffe6f9f2),
          title: 'Похожие задания', subtitle: 'Повторить упражнения с прошлого занятия',
          onTap: () { final item = store.history.firstWhere((r) => r.practice.isNotEmpty);
            Navigator.push(context, MaterialPageRoute(builder: (_) =>
              Scaffold(appBar: AppBar(title: const Text('Тренировка')),
                body: ListView(padding: const EdgeInsets.all(20), children: [
                  SectionHead('Тема: ${item.problem}'), const SizedBox(height: 15),
                  PracticePanel(tasks: item.practice),
                ])))); }),
      ],
    ]);
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const SectionHead('История занятий',
      subtitle: 'Все найденные и решённые задания'),
    const SizedBox(height: 20),
    if (store.history.isEmpty) const Surface(child: Column(children: [
      Icon(Icons.history_edu_rounded, size: 63, color: accent),
      SizedBox(height: 12), Text('Здесь появятся решения',
        style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
      SizedBox(height: 8), Text('Реши первое задание — и оно сохранится автоматически.',
        textAlign: TextAlign.center, style: TextStyle(color: muted)),
    ])) else ...store.history.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10),
      child: ActionTile(icon: item.verified ? Icons.task_alt : Icons.info_outline,
        iconColor: item.verified ? const Color(0xff119970) : const Color(0xffca922b),
        tint: item.verified ? const Color(0xffe4faf0) : const Color(0xfffff5df),
        title: item.problem, subtitle: '${item.source} · ${item.createdAt.split('T').first}',
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => SolutionPage(result: item))))),
    )]);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController gemini, grok, gm, xm;
  late bool verify;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    gemini = TextEditingController(text: widget.store.geminiKey);
    grok = TextEditingController(text: widget.store.grokKey);
    gm = TextEditingController(text: widget.store.geminiModel);
    xm = TextEditingController(text: widget.store.grokModel);
    verify = widget.store.checkWithGemini;
  }
  @override
  void dispose() {
    gemini.dispose(); grok.dispose(); gm.dispose(); xm.dispose(); super.dispose();
  }
  Future<void> save() async {
    setState(() => saving = true);
    try { await widget.store.updateSettings(gemini.text, grok.text, gm.text, xm.text, verify);
      if (mounted) message(context, 'Настройки сохранены на телефоне');
    } catch (e) { if (mounted) message(context, 'Ошибка сохранения: $e'); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const SectionHead('Настройки', subtitle: 'Подключение помощников и безопасность'),
    const SizedBox(height: 20),
    Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.auto_awesome, color: accent), SizedBox(width: 10),
        Text('Gemini — чтение карточек',
          style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 10), const Text('Читает фото и сканированные страницы учебника.',
        style: TextStyle(color: muted, fontSize: 13)),
      const SizedBox(height: 15), TextField(controller: gemini, obscureText: true,
        autocorrect: false, decoration: const InputDecoration(labelText: 'Gemini API key')),
      const SizedBox(height: 10), TextField(controller: gm,
        decoration: const InputDecoration(labelText: 'Модель Gemini')),
    ])),
    const SizedBox(height: 14),
    Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.psychology_rounded, color: Color(0xff754be8)),
        SizedBox(width: 10), Text('Grok — решение и объяснение',
          style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 10), const Text('Обрабатывает сложные задачи, объясняет правила и предлагает тренировку.',
        style: TextStyle(color: muted, fontSize: 13)),
      const SizedBox(height: 15), TextField(controller: grok, obscureText: true,
        autocorrect: false, decoration: const InputDecoration(labelText: 'xAI API key')),
      const SizedBox(height: 10), TextField(controller: xm,
        decoration: const InputDecoration(labelText: 'Модель Grok')),
    ])),
    const SizedBox(height: 14),
    Surface(child: Column(children: [
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Двойная проверка Gemini',
        style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
        subtitle: const Text('Дополнительно проверять текстовые задачи, '
          'которые не может проверить калькулятор. Расходует запросы API.',
          style: TextStyle(fontSize: 12)), value: verify,
        onChanged: (v) => setState(() => verify = v)),
      const Divider(),
      const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.lock_outline, color: accent),
        title: Text('Конфиденциальность', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
        subtitle: Text('Ключи защищены хранилищем Android. Книги и история — только на этом устройстве.')),
    ])),
    const SizedBox(height: 15),
    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : save,
      icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Сохранение...' : 'Сохранить настройки'))),
    const SizedBox(height: 20),
    const Text('Бесплатно без ключей работают простые примеры, уравнения, тренировки, '
      'импорт текстовых PDF и просмотр книг. API xAI/Grok тарифицируется отдельно; '
      'доступность бесплатного лимита Gemini зависит от аккаунта и модели. '
      'Автоматическое обновление APK появится после настройки постоянной подписи.',
      textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
    const SizedBox(height: 12), const Center(child: Text('Домашка · версия 0.1.0',
      style: TextStyle(color: muted, fontSize: 12))),
    const SizedBox(height: 20),
  ]);
}