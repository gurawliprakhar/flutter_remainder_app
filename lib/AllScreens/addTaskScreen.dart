import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:todo_list/Helper/sqliteHelper.dart';
import 'package:todo_list/Models/taskModel.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:todo_list/main.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:todo_list/Widgets/expandableFab.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class AddTask extends StatefulWidget {
  final TaskModel? task;
  final Function updateTaskList;
  final Function? updateTasks;
  final int? num;

  AddTask({required this.updateTaskList, this.task, this.updateTasks, this.num});

  @override
  _AddTaskState createState() => _AddTaskState();
}

class _AddTaskState extends State<AddTask> {
  late String _task;
  String? _category;
  late DateTime _reminder;
  late bool _reminderStatus;
  late DateTime _date;
  late TimeOfDay _time;
  late String _timeHolder;
  late List<String> _categories;
  final _formKey = GlobalKey<FormState>();
  final _addCategoryForm = GlobalKey<FormState>();
  final DateFormat _dateFormat = DateFormat('MMM, dd, yyyy');
  final String _cat = "categories";
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    SharedPreferences.getInstance().then((prefs) {
      if (!prefs.containsKey(_cat)) {
        prefs.setStringList(_cat, ["Personal", "Work", "Business"]);
      }
      _categories = prefs.getStringList(_cat)!;

      if (widget.task != null) {
        _initializeForExistingTask();
      } else {
        _initializeForNewTask();
      }
    });
  }

  void _initializeForExistingTask() {
    _task = widget.task!.task;
    _date = widget.task!.date;
    _reminder = widget.task!.reminder;
    _reminderStatus = widget.task!.isreminder == 1;
    _category = widget.task!.category;
    _dateController.text = _dateFormat.format(_date);
    _timeHolder = _formatTime(_reminder);
    if (!_categories.contains(_category)) {
      _categories.add(_category!);
      SharedPreferences.getInstance().then((prefs) {
        prefs.setStringList(_cat, _categories);
      });
    }
  }

  void _initializeForNewTask() {
    _task = "";
    _date = DateTime.now();
    _reminder = DateTime.now();
    _reminderStatus = false;
    _dateController.text = _dateFormat.format(_date);
    _timeHolder = _formatTime(_reminder);
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  void _updateCategoryList(String cat) {
    setState(() {
      _categories.add(cat);
      SharedPreferences.getInstance().then((prefs) {
        prefs.setStringList(_cat, _categories);
      });
    });
  }

  Future<void> _handleDatePicker() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date != null && date != _date) {
      setState(() {
        _date = date;
        _reminder = DateTime(date.year, date.month, date.day, _reminder.hour, _reminder.minute);
        _dateController.text = _dateFormat.format(date);
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      TaskModel task = TaskModel(
        task: _task,
        category: _category!,
        date: _date,
        reminder: _reminder,
        iscomplete: widget.task?.iscomplete ?? 0,
        isreminder: _reminderStatus ? 1 : 0,
      );

      if (widget.task == null) {
        await SqliteHelper.instance.insertTask(task);
      } else {
        task.id = widget.task!.id;
        await SqliteHelper.instance.updateTask(task);
      }

      widget.num != null ? widget.updateTasks!() : widget.updateTaskList();
      Navigator.pop(context);
    }
  }

  Future<void> _showNotification(int id) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'channel id',
      'channel name',
      'channel description',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      visibility: NotificationVisibility.public,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Task',
      _task,
      tz.TZDateTime.now(tz.local).add(_reminder.difference(DateTime.now())),
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _createNotification(int id) {
    _showNotification(id);
    final snackBar = SnackBar(content: Text(_stringBuilder(_reminder)));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _showTimePicker(BuildContext context) async {
    final TimeOfDay? timePicked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
    );

    if (timePicked != null) {
      setState(() {
        _time = timePicked;
        _reminder = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
        _timeHolder = _formatTime(_reminder);
      });
      _scheduleOrCancelNotification();
    }
  }

  void _scheduleOrCancelNotification() {
    int id = widget.task?.id ?? 0;
    DateTime now = DateTime.now();
    int secs = _reminder.difference(now).inSeconds;

    if (secs <= 0) {
      _showErrorMessage('Please select future time');
      if (_reminderStatus) {
        setState(() {
          _reminderStatus = !_reminderStatus;
        });
      }
    } else {
      if (_reminderStatus) {
        _cancelNotification(id);
      } else {
        _createNotification(id);
      }
      setState(() {
        _reminderStatus = !_reminderStatus;
      });
    }
  }

  void _showErrorMessage(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _delete() {
    SqliteHelper.instance.deleteTask(widget.task!.id);
    widget.updateTaskList();
    Navigator.pop(context);
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final TextEditingController _categoryController = TextEditingController();
    return showDialog<void>(
        context: context,
        builder: (context) {
      return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add Category",
                style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 15.0),
              ),
              Form(
                key: _addCategoryForm,
                child: TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(hintText: "Category"),
                  validator: (value) => value!.isEmpty ? 'Invalid category' : null,
                ),
              ),
            ],
          ),
          actions: [
      TextButton(
      child: Text("Cancel", style: TextStyle(color: Theme.of(context).primaryColor)),
    onPressed: () {
    Navigator.of(context).pop();
    },
    ),
    TextButton(
    onPressed: () {  },
    child: Text("Save", style: TextStyle(color: Theme.of(context).


