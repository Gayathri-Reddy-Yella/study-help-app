import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _forest = Color(0xFF285744);
const _forestDeep = Color(0xFF193D31);
const _mint = Color(0xFFE6F0E8);
const _coral = Color(0xFFEA785F);
const _paper = Color(0xFFF6F8F4);
const _ink = Color(0xFF20332A);
const _muted = Color(0xFF78857C);
const _line = Color(0xFFE5EAE4);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DaylightApp());
}

class DaylightApp extends StatelessWidget {
  const DaylightApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme);
    return MaterialApp(
      title: 'Daylight | Study Help',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
          primary: _forest,
          surface: Colors.white,
          onSurface: _ink,
        ),
        textTheme: textTheme.copyWith(
          displaySmall: GoogleFonts.dmSerifDisplay(
            color: _ink,
            fontSize: 38,
            height: 1.08,
          ),
          headlineMedium: GoogleFonts.dmSerifDisplay(
            color: _ink,
            fontSize: 30,
            height: 1.12,
          ),
          titleLarge: textTheme.titleLarge?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: textTheme.titleMedium?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: textTheme.bodyMedium?.copyWith(color: _ink, height: 1.45),
        ),
        dividerColor: _line,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _paper,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _forest, width: 1.5),
          ),
        ),
      ),
      home: const _AppShell(),
    );
  }
}

class _TaskItem {
  const _TaskItem({
    required this.id,
    required this.title,
    required this.category,
    required this.day,
    this.isDone = false,
  });

  final String id;
  final String title;
  final String category;
  final String day;
  final bool isDone;

  _TaskItem copyWith({bool? isDone}) => _TaskItem(
        id: id,
        title: title,
        category: category,
        day: day,
        isDone: isDone ?? this.isDone,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'day': day,
        'isDone': isDone,
      };

  factory _TaskItem.fromJson(Map<String, dynamic> json) => _TaskItem(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        day: json['day'] as String,
        isDone: json['isDone'] as bool? ?? false,
      );
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  static const _tasksKey = 'daylight.tasks.v1';
  static const _moodPrefix = 'daylight.mood.';
  static const _reflectionPrefix = 'daylight.reflection.';

  int _selectedPage = 0;
  List<_TaskItem> _tasks = [];
  String? _mood;
  String _reflection = '';
  bool _isLoading = true;

  DateTime get _now => DateTime.now();
  String get _todayKey => DateFormat('yyyy-MM-dd').format(_now);
  List<_TaskItem> get _todayTasks =>
      _tasks.where((task) => task.day == _todayKey).toList();
  int get _doneCount => _todayTasks.where((task) => task.isDone).length;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedData());
  }

  Future<void> _loadSavedData() async {
    final preferences = await SharedPreferences.getInstance();
    final savedTasks = preferences.getString(_tasksKey);
    List<_TaskItem> loadedTasks;
    if (savedTasks == null) {
      loadedTasks = [
        _TaskItem(
          id: 'welcome-study',
          title: 'Study for 25 focused minutes',
          category: 'Study',
          day: _todayKey,
        ),
        _TaskItem(
          id: 'welcome-break',
          title: 'Take a proper screen break',
          category: 'Wellbeing',
          day: _todayKey,
        ),
        _TaskItem(
          id: 'welcome-plan',
          title: "Choose tomorrow's first step",
          category: 'Personal',
          day: _todayKey,
        ),
      ];
      await preferences.setString(
        _tasksKey,
        jsonEncode(loadedTasks.map((task) => task.toJson()).toList()),
      );
    } else {
      try {
        loadedTasks = (jsonDecode(savedTasks) as List<dynamic>)
            .map((item) => _TaskItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } on Object {
        loadedTasks = [];
      }
    }
    if (!mounted) return;
    setState(() {
      _tasks = loadedTasks;
      _mood = preferences.getString('$_moodPrefix$_todayKey');
      _reflection =
          preferences.getString('$_reflectionPrefix$_todayKey') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _persistTasks() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _tasksKey,
      jsonEncode(_tasks.map((task) => task.toJson()).toList()),
    );
  }

  void _setPage(int page) => setState(() => _selectedPage = page);

  Future<void> _addTask() async {
    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (context) => const _AddTaskDialog(),
    );
    if (draft == null || draft.title.trim().isEmpty) return;
    final task = _TaskItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: draft.title.trim(),
      category: draft.category,
      day: _todayKey,
    );
    setState(() => _tasks = [..._tasks, task]);
    await _persistTasks();
  }

  Future<void> _toggleTask(_TaskItem task) async {
    setState(() {
      _tasks = _tasks
          .map((item) => item.id == task.id
              ? item.copyWith(isDone: !item.isDone)
              : item)
          .toList();
    });
    await _persistTasks();
  }

  Future<void> _deleteTask(_TaskItem task) async {
    setState(() => _tasks = _tasks.where((item) => item.id != task.id).toList());
    await _persistTasks();
  }

  Future<void> _chooseMood(String mood) async {
    setState(() => _mood = mood);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_moodPrefix$_todayKey', mood);
  }

  Future<void> _saveReflection(String reflection) async {
    setState(() => _reflection = reflection);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_reflectionPrefix$_todayKey', reflection);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _forest)),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: isWide
                ? Row(
                    children: [
                      _SideNavigation(
                        selectedPage: _selectedPage,
                        onSelected: _setPage,
                      ),
                      Expanded(child: _buildCurrentPage()),
                    ],
                  )
                : _buildCurrentPage(),
          ),
          bottomNavigationBar: isWide
              ? null
              : _BottomNavigation(
                  selectedPage: _selectedPage,
                  onSelected: _setPage,
                ),
        );
      },
    );
  }

  Widget _buildCurrentPage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (_selectedPage) {
        0 => _TodayPage(
            key: const ValueKey('today'),
            now: _now,
            tasks: _todayTasks,
            doneCount: _doneCount,
            mood: _mood,
            onAddTask: _addTask,
            onToggleTask: _toggleTask,
            onDeleteTask: _deleteTask,
            onSelectCheckIn: () => _setPage(2),
          ),
        1 => _TasksPage(
            key: const ValueKey('tasks'),
            now: _now,
            tasks: _tasks,
            onAddTask: _addTask,
            onToggleTask: _toggleTask,
            onDeleteTask: _deleteTask,
          ),
        _ => _CheckInPage(
            key: const ValueKey('check-in'),
            now: _now,
            mood: _mood,
            reflection: _reflection,
            onChooseMood: _chooseMood,
            onSaveReflection: _saveReflection,
          ),
      },
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.selectedPage, required this.onSelected});

  final int selectedPage;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 246,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 28, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _forest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wb_sunny_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('daylight',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 19,
                            height: 1,
                          )),
                  const SizedBox(height: 4),
                  Text('STUDY + SELF CARE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            fontSize: 9,
                          )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          Text('YOUR SPACE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  )),
          const SizedBox(height: 12),
          _NavItem(
            icon: Icons.today_outlined,
            label: 'Today',
            selected: selectedPage == 0,
            onTap: () => onSelected(0),
          ),
          _NavItem(
            icon: Icons.checklist_rounded,
            label: 'My tasks',
            selected: selectedPage == 1,
            onTap: () => onSelected(1),
          ),
          _NavItem(
            icon: Icons.spa_outlined,
            label: 'Check-in',
            selected: selectedPage == 2,
            onTap: () => onSelected(2),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _mint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.eco_outlined, color: _forest, size: 21),
                const SizedBox(height: 12),
                Text('Small steps count.',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 4),
                Text('Make space for progress at your own pace.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _muted,
                          height: 1.4,
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: ListTile(
        onTap: onTap,
        selected: selected,
        selectedTileColor: _mint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
        leading: Icon(icon, size: 21, color: selected ? _forest : _muted),
        title: Text(label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? _forest : _ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.selectedPage, required this.onSelected});

  final int selectedPage;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedPage,
      onDestinationSelected: onSelected,
      backgroundColor: Colors.white,
      indicatorColor: _mint,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today_rounded),
          label: 'Today',
        ),
        NavigationDestination(
          icon: Icon(Icons.checklist_outlined),
          selectedIcon: Icon(Icons.checklist_rounded),
          label: 'Tasks',
        ),
        NavigationDestination(
          icon: Icon(Icons.spa_outlined),
          selectedIcon: Icon(Icons.spa_rounded),
          label: 'Check-in',
        ),
      ],
    );
  }
}

class _TodayPage extends StatelessWidget {
  const _TodayPage({
    super.key,
    required this.now,
    required this.tasks,
    required this.doneCount,
    required this.mood,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onDeleteTask,
    required this.onSelectCheckIn,
  });

  final DateTime now;
  final List<_TaskItem> tasks;
  final int doneCount;
  final String? mood;
  final VoidCallback onAddTask;
  final ValueChanged<_TaskItem> onToggleTask;
  final ValueChanged<_TaskItem> onDeleteTask;
  final VoidCallback onSelectCheckIn;

  @override
  Widget build(BuildContext context) {
    final progress = tasks.isEmpty ? 0.0 : doneCount / tasks.length;
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeading(
            eyebrow: DateFormat('EEEE, MMMM d').format(now).toUpperCase(),
            title: 'A steadier day starts here.',
            subtitle: 'Choose what matters. Leave room to breathe.',
            action: FilledButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Add a task'),
              style: FilledButton.styleFrom(
                backgroundColor: _forest,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _FocusBanner(onTap: onSelectCheckIn),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Column(
                  children: [
                    _TodayTaskList(
                      tasks: tasks,
                      onToggleTask: onToggleTask,
                      onDeleteTask: onDeleteTask,
                    ),
                    const SizedBox(height: 18),
                    _ProgressPanel(
                        doneCount: doneCount,
                        totalCount: tasks.length,
                        progress: progress),
                    const SizedBox(height: 18),
                    _MoodPanel(mood: mood, onTap: onSelectCheckIn),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _TodayTaskList(
                      tasks: tasks,
                      onToggleTask: onToggleTask,
                      onDeleteTask: onDeleteTask,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _ProgressPanel(
                            doneCount: doneCount,
                            totalCount: tasks.length,
                            progress: progress),
                        const SizedBox(height: 16),
                        _MoodPanel(mood: mood, onTap: onSelectCheckIn),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: child,
        ),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eyebrow,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _forest,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.15,
                    )),
            const SizedBox(height: 9),
            Text(title, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _muted,
                    )),
          ],
        );
        if (action == null) return text;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 16), action!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [Expanded(child: text), action!],
        );
      },
    );
  }
}

class _FocusBanner extends StatelessWidget {
  const _FocusBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _forestDeep,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final message = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A GENTLE REMINDER',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFB8D6C2),
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: 8),
                  Text('You do not have to do it all at once.',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          )),
                  const SizedBox(height: 7),
                  Text('Take one clear step, then check in with yourself.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFD1E1D5),
                          )),
                ],
              );
              final action = TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.spa_outlined, size: 18),
                label: const Text('Pause for a moment'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  side: const BorderSide(color: Color(0xFF648575)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [message, const SizedBox(height: 14), action],
                );
              }
              return Row(
                children: [
                  Expanded(child: message),
                  const SizedBox(width: 16),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TodayTaskList extends StatelessWidget {
  const _TodayTaskList({
    required this.tasks,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  final List<_TaskItem> tasks;
  final ValueChanged<_TaskItem> onToggleTask;
  final ValueChanged<_TaskItem> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Today's plan",
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Text('${tasks.length} ${tasks.length == 1 ? 'item' : 'items'}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: _muted)),
            ],
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            const _EmptyTasks()
          else
            ...tasks.map(
              (task) => _TaskRow(
                task: task,
                onToggle: () => onToggleTask(task),
                onDelete: () => onDeleteTask(task),
              ),
            ),
        ],
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final _TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final categoryColor = switch (task.category) {
      'Study' => _forest,
      'Wellbeing' => _coral,
      _ => const Color(0xFF4F7B9C),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Checkbox(
              value: task.isDone,
              onChanged: (_) => onToggle(),
              activeColor: _forest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: task.isDone ? _muted : _ink,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 74),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              task.category,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: categoryColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Delete task',
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: _muted,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.done_all_rounded, color: _forest, size: 30),
            const SizedBox(height: 9),
            Text('A little breathing room.',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Add a task when you are ready for one.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _muted)),
          ],
        ),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.doneCount,
    required this.totalCount,
    required this.progress,
  });

  final int doneCount;
  final int totalCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final allDone = totalCount > 0 && doneCount == totalCount;
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A little progress',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 17),
          Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: _mint,
                      color: _forest,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text('${(progress * 100).round()}%',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _forest,
                                  )),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$doneCount of $totalCount done',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      allDone
                          ? 'You showed up for yourself today.'
                          : 'Every small step counts.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: _mint,
              color: _coral,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodPanel extends StatelessWidget {
  const _MoodPanel({required this.mood, required this.onTap});
  final String? mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4E9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  mood == null ? Icons.spa_outlined : _moodIcon(mood!),
                  color: _coral,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mood == null ? 'How are you, really?' : 'You checked in',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(mood ?? 'Make a little space for yourself.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: _muted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: _forest, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _TasksPage extends StatefulWidget {
  const _TasksPage({
    super.key,
    required this.now,
    required this.tasks,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  final DateTime now;
  final List<_TaskItem> tasks;
  final VoidCallback onAddTask;
  final ValueChanged<_TaskItem> onToggleTask;
  final ValueChanged<_TaskItem> onDeleteTask;

  @override
  State<_TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<_TasksPage> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final visibleTasks = widget.tasks.where((task) {
      if (_filter == 'To do') return !task.isDone;
      if (_filter == 'Done') return task.isDone;
      return true;
    }).toList()
      ..sort((a, b) {
        final dayOrder = b.day.compareTo(a.day);
        return dayOrder == 0 ? a.isDone.toString().compareTo(b.isDone.toString()) : dayOrder;
      });
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeading(
            eyebrow: 'YOUR LIST, YOUR PACE',
            title: 'My tasks',
            subtitle: 'A clear list makes the next step easier to see.',
            action: FilledButton.icon(
              onPressed: widget.onAddTask,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Add a task'),
              style: FilledButton.styleFrom(
                backgroundColor: _forest,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('All your steps',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Text('${widget.tasks.length} total',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: _muted)),
                  ],
                ),
                const SizedBox(height: 17),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'All', label: Text('All')),
                    ButtonSegment(value: 'To do', label: Text('To do')),
                    ButtonSegment(value: 'Done', label: Text('Done')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selection) =>
                      setState(() => _filter = selection.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (visibleTasks.isEmpty)
                  const _EmptyTasks()
                else
                  ...visibleTasks.map(
                    (task) => _TaskRow(
                      task: task,
                      onToggle: () => widget.onToggleTask(task),
                      onDelete: () => widget.onDeleteTask(task),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Tasks stay on this device and are ready when you are.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _muted)),
        ],
      ),
    );
  }
}

class _CheckInPage extends StatefulWidget {
  const _CheckInPage({
    super.key,
    required this.now,
    required this.mood,
    required this.reflection,
    required this.onChooseMood,
    required this.onSaveReflection,
  });

  final DateTime now;
  final String? mood;
  final String reflection;
  final ValueChanged<String> onChooseMood;
  final ValueChanged<String> onSaveReflection;

  @override
  State<_CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<_CheckInPage> {
  late final TextEditingController _reflectionController;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _reflectionController = TextEditingController(text: widget.reflection);
  }

  @override
  void didUpdateWidget(covariant _CheckInPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reflection != widget.reflection &&
        widget.reflection != _reflectionController.text) {
      _reflectionController.text = widget.reflection;
    }
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeading(
            eyebrow: DateFormat('EEEE, MMMM d').format(widget.now).toUpperCase(),
            title: 'Check in with yourself.',
            subtitle: 'No score to chase. Just a moment to notice.',
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final reflection = _ReflectionPanel(
                controller: _reflectionController,
                saved: _saved,
                onChanged: () => setState(() => _saved = false),
                onSave: () {
                  widget.onSaveReflection(_reflectionController.text.trim());
                  setState(() => _saved = true);
                },
              );
              final mood = _MoodPicker(
                selectedMood: widget.mood,
                onChoose: (value) {
                  widget.onChooseMood(value);
                  setState(() => _saved = true);
                },
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  children: [mood, const SizedBox(height: 18), reflection],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: mood),
                  const SizedBox(width: 18),
                  Expanded(flex: 7, child: reflection),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _BreathingPrompt(),
        ],
      ),
    );
  }
}

class _MoodPicker extends StatelessWidget {
  const _MoodPicker({required this.selectedMood, required this.onChoose});
  final String? selectedMood;
  final ValueChanged<String> onChoose;

  static const _moods = [
    ('Low', Icons.sentiment_very_dissatisfied_outlined, Color(0xFF567994)),
    ('Tense', Icons.sentiment_dissatisfied_outlined, Color(0xFFB06C55)),
    ('Okay', Icons.sentiment_neutral_outlined, Color(0xFF8A7B47)),
    ('Good', Icons.sentiment_satisfied_outlined, Color(0xFF568269)),
    ('Great', Icons.sentiment_very_satisfied_outlined, Color(0xFF36745C)),
  ];

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How are you feeling?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Pick the closest word. It does not have to be perfect.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _muted)),
          const SizedBox(height: 20),
          ..._moods.map((mood) {
            final selected = selectedMood == mood.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                onTap: () => onChoose(mood.$1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: selected ? mood.$3.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? mood.$3 : _line,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(mood.$2, color: mood.$3, size: 22),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(mood.$1,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight:
                                      selected ? FontWeight.w700 : FontWeight.w500,
                                )),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            color: mood.$3, size: 19),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ReflectionPanel extends StatelessWidget {
  const _ReflectionPanel({
    required this.controller,
    required this.saved,
    required this.onChanged,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saved;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A few words for yourself',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('What would help you feel a little more supported today?',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _muted)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            minLines: 7,
            maxLines: 10,
            maxLength: 1200,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              hintText: 'Start wherever you are. There is no right answer.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  saved ? 'Saved on this device.' : 'Only you can see this note.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: saved ? _forest : _muted),
                ),
              ),
              FilledButton.icon(
                onPressed: onSave,
                icon: Icon(saved ? Icons.check_rounded : Icons.bookmark_outline,
                    size: 18),
                label: Text(saved ? 'Saved' : 'Save note'),
                style: FilledButton.styleFrom(
                  backgroundColor: _forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreathingPrompt extends StatelessWidget {
  const _BreathingPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.air_rounded, color: _forest, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Unclench your jaw. Drop your shoulders. Take one slow breath.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _forestDeep,
                      fontWeight: FontWeight.w500,
                    )),
          ),
        ],
      ),
    );
  }
}

class _TaskDraft {
  const _TaskDraft(this.title, this.category);
  final String title;
  final String category;
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _controller = TextEditingController();
  String _category = 'Study';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add a small step',
          style: Theme.of(context).textTheme.titleLarge),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 90,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What would you like to do?',
                hintText: 'For example, review biology notes',
              ),
              onSubmitted: (_) => _submit(context),
            ),
            const SizedBox(height: 8),
            Text('AREA',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              children: ['Study', 'Wellbeing', 'Personal'].map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                  selectedColor: _mint,
                  side: BorderSide(
                      color: _category == category ? _forest : _line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                  showCheckmark: false,
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          style: FilledButton.styleFrom(backgroundColor: _forest),
          child: const Text('Add task'),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(_TaskDraft(title, _category));
  }
}

IconData _moodIcon(String mood) => switch (mood) {
      'Low' => Icons.sentiment_very_dissatisfied_outlined,
      'Tense' => Icons.sentiment_dissatisfied_outlined,
      'Okay' => Icons.sentiment_neutral_outlined,
      'Good' => Icons.sentiment_satisfied_outlined,
      _ => Icons.sentiment_very_satisfied_outlined,
    };
