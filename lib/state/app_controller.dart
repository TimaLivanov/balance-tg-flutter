import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/state_service.dart';
import '../services/telegram_service.dart';

/// Контроллер приложения — аналог глобального state + recalc() + синхронизации из HTML.
class AppController extends ChangeNotifier {
  AppController()
      : _api = ApiService(),
        _auth = AuthService(ApiService()),
        _stateService = StateService(ApiService());

  final ApiService _api;
  final AuthService _auth;
  final StateService _stateService;
  SharedPreferences? _prefs;

  AppState _state = AppState.empty();
  AppState get state => _state;

  bool _guest = false;
  bool get guest => _guest;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  String? _email;
  String? get email => _email;

  bool _authenticated = false;
  bool get authenticated => _authenticated;

  /// Приложение открыто внутри Telegram Mini App.
  bool get inTelegram => readTelegramInfo() != null;

  String? _telegramError;
  String? get telegramError => _telegramError;

  bool _telegramLinked = false;
  bool get telegramLinked => _telegramLinked;

  /// Результат пересчёта (аналог R из HTML).
  CalcResult _calc = CalcResult.empty();
  CalcResult get calc => _calc;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      _prefs = await SharedPreferences.getInstance();
      final res = await _auth.me();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = _json(res.body);
        if (body['authenticated'] == true && body['user'] is Map) {
          _authenticated = true;
          _email = body['user']['email']?.toString();
          final loaded = await _stateService.load();
          _state = loaded ?? AppState.empty();
          if (loaded == null) {
            // Как в HTML: при первом входе сохраняем начальное состояние
            await _stateService.save(_state);
          }
          _guest = false;
        }
      }
      if (!_authenticated) {
        _guest = true;
        _state = _loadGuestState();
      }
      _recalc();
      if (_authenticated) _autoLinkTelegram();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _guest = true;
      _state = _loadGuestState();
      _recalc();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final res = await _auth.login(email.trim(), password);
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      _authenticated = true;
      _email = email.trim();
      _guest = false;
      final loaded = await _stateService.load();
      _state = loaded ?? AppState.empty();
      if (loaded == null) await _stateService.save(_state);
      _recalc();
      notifyListeners();
      _autoLinkTelegram();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    try {
      final res = await _auth.register(email.trim(), password);
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      return await login(email, password);
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (_) {}
    _authenticated = false;
    _email = null;
    _guest = false;
    _state = AppState.empty();
    _recalc();
    notifyListeners();
  }

  void _autoLinkTelegram() {
    if (!inTelegram) return;
    linkTelegram();
  }

  /// Привязать текущий аккаунт к Telegram (как в HTML-версии).
  /// Возвращает null при успехе, иначе текст ошибки.
  Future<String?> linkTelegram() async {
    if (!_authenticated) return 'Сначала войдите в аккаунт';
    final info = readTelegramInfo();
    if (info == null) return 'Откройте приложение через бота Telegram';
    try {
      final res = await _api.post('/api/telegram/link', {'initData': info.initData});
      final body = _json(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300 && body['error'] == null) {
        _telegramLinked = true;
        _telegramError = null;
        notifyListeners();
        return null;
      }
      _telegramError = body['error']?.toString() ?? 'Не удалось привязать Telegram';
      notifyListeners();
      return _telegramError;
    } catch (e) {
      _telegramError = e.toString();
      notifyListeners();
      return _telegramError;
    }
  }

  /// Отправить тестовое сообщение в привязанный Telegram.
  Future<String?> testTelegram() async {
    if (!_authenticated) return 'Сначала войдите в аккаунт';
    try {
      final res = await _api.post('/api/telegram/test');
      final body = _json(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300 && body['error'] == null) {
        return null;
      }
      return body['error']?.toString() ?? 'Не удалось отправить сообщение';
    } catch (e) {
      return e.toString();
    }
  }

  /// Показать экран входа из гостевого режима, не теряя сохранённые данные.
  Future<void> openLogin() async {
    _authenticated = false;
    _guest = false;
    notifyListeners();
  }

  Future<void> enterGuest() async {
    _guest = true;
    _authenticated = false;
    _state = _loadGuestState();
    _recalc();
    notifyListeners();
  }

  /// Изменение состояния с автосохранением (аналог update() из HTML).
  void update(AppState newState, {bool save = true}) {
    _state = newState;
    _recalc();
    notifyListeners();
    if (save) _persist();
  }

  /// Удобный вызов после прямого изменения полей состояния.
  void commit() {
    _recalc();
    notifyListeners();
    _persist();
  }

  void _persist() {
    if (_guest) {
      _prefs?.setString('balance-tg-state-v1', jsonEncode(_state.toJson()));
    } else {
      _stateService.save(_state).catchError((_) {});
    }
  }

  AppState _loadGuestState() {
    final raw = _prefs?.getString('balance-tg-state-v1');
    if (raw == null || raw.isEmpty) return AppState.empty();
    try {
      return AppState.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return AppState.empty();
    }
  }

  // ---- CRUD-операции (аналог функций из HTML) ----

  void addCategory(String name, {required bool need, required bool rare, double plan = 0, String planDate = ''}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _state.cats.add(Category(
      id: id,
      name: name.trim().isEmpty ? 'Категория' : name.trim(),
      need: need,
      rare: rare,
      plan: plan > 0 ? Plan(amount: plan, date: planDate) : null,
    ));
    commit();
  }

  void updateCategory(String id, {String? name, bool? need, bool? rare, bool? archived, double? plan, String? planDate}) {
    final idx = _state.cats.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final c = _state.cats[idx];
    _state.cats[idx] = Category(
      id: c.id,
      name: name ?? c.name,
      need: need ?? c.need,
      rare: rare ?? c.rare,
      archived: archived ?? c.archived,
      resetDate: c.resetDate,
      spentBase: c.spentBase,
      plan: plan != null && plan > 0
          ? Plan(amount: plan, date: planDate ?? c.plan?.date ?? '')
          : null,
    );
    commit();
  }

  void deleteCategory(String id) {
    _state.cats.removeWhere((c) => c.id == id);
    commit();
  }

  void addDebt(String name, double amount, {String due = '', double rate = 0}) {
    _state.debts.add(Debt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Долг' : name.trim(),
      amount: amount,
      due: due,
      rate: rate,
    ));
    commit();
  }

  void updateDebt(String id, {String? name, double? amount, String? due, bool? archived}) {
    final idx = _state.debts.indexWhere((d) => d.id == id);
    if (idx < 0) return;
    final d = _state.debts[idx];
    _state.debts[idx] = Debt(
      id: d.id,
      name: name ?? d.name,
      amount: amount ?? d.amount,
      due: due ?? d.due,
      date: d.date,
      rate: d.rate,
      archived: archived ?? d.archived,
      archivedAt: d.archivedAt,
    );
    commit();
  }

  void deleteDebt(String id) {
    _state.debts.removeWhere((d) => d.id == id);
    _state.history.removeWhere((h) => h.debtId == id);
    commit();
  }

  void addSavings(String name, double target, {String kind = 'goal', String date = ''}) {
    _state.savings.add(SavingsGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Накопление' : name.trim(),
      kind: kind,
      plan: target > 0 ? Plan(amount: target, date: date) : null,
    ));
    commit();
  }

  void deleteSavings(String id) {
    _state.savings.removeWhere((g) => g.id == id);
    commit();
  }

  void addAutoPay(String name, double amount, {String mode = 'daily', int day = 1}) {
    _state.autopay.add(AutoPay(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Автоплатёж' : name.trim(),
      amount: amount,
      mode: mode,
      day: day,
    ));
    commit();
  }

  void deleteAutoPay(String id) {
    _state.autopay.removeWhere((a) => a.id == id);
    commit();
  }

  void saveDayEntry({
    required String date,
    required double income,
    required Map<String, double> expenses,
    required Map<String, double> debtPays,
    required Map<String, double> savings,
    double cushIn = 0,
    double cushOut = 0,
    String note = '',
    String? editingId,
  }) {
    final id = editingId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final entry = Entry(
      id: id,
      type: 'day',
      date: date,
      income: income,
      expenses: expenses,
      debtPays: debtPays,
      savings: savings,
      savSpend: {},
      cushIn: cushIn,
      cushOut: cushOut,
      note: note,
      autoItems: [],
      autoMk: [],
    );
    final idx = _state.history.indexWhere((h) => h.id == id);
    if (idx >= 0) {
      _state.history[idx] = entry;
    } else {
      _state.history.add(entry);
    }
    commit();
  }

  void deleteEntry(String id) {
    _state.history.removeWhere((h) => h.id == id);
    commit();
  }

  void updateSetting(void Function(AppState s) fn) {
    fn(_state);
    commit();
  }

  Future<String> askAi(String question, String context) async {
    try {
      final res = await _api.post('/api/ai', {
        'question': question,
        'context': context,
        'behavior': _state.aiBehavior,
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = _json(res.body);
        return (body['answer'] ?? body['reply'] ?? 'Ответ получен').toString();
      }
      return 'Ошибка сервера: ${res.statusCode}';
    } catch (_) {
      return 'AI недоступен. Проверьте соединение.';
    }
  }

  String buildAiContext() {
    final c = _calc;
    final topExp = <MapEntry<String, double>>[];
    for (final e in _state.history) {
      if (e.type != 'day') continue;
      e.expenses.forEach((k, v) {
        final name = _state.cats.where((x) => x.id == k).map((x) => x.name).firstOrNull ?? k;
        final idx = topExp.indexWhere((x) => x.key == name);
        if (idx >= 0) {
          topExp[idx] = MapEntry(name, topExp[idx].value + v);
        } else {
          topExp.add(MapEntry(name, v));
        }
      });
    }
    topExp.sort((a, b) => b.value.compareTo(a.value));
    final exp = topExp.take(8).map((e) => '${e.key}: ${e.value.toStringAsFixed(0)}').join(', ');
    final debts = _state.debts
        .where((d) => !d.archived)
        .take(12)
        .map((d) => '${d.name}: ${d.amount.toStringAsFixed(0)}')
        .join(', ');
    return 'Баланс: ${c.balance.toStringAsFixed(0)}\n'
        'Наличные: ${c.cash.toStringAsFixed(0)}\n'
        'Подушка: ${c.cushion.toStringAsFixed(0)} из ${c.cushionGoal.toStringAsFixed(0)}\n'
        'Долги: ${c.debtTotal.toStringAsFixed(0)}\n'
        'Доходы: ${c.income.toStringAsFixed(0)}\n'
        'Расходы: ${c.expenses.toStringAsFixed(0)}\n'
        'Топ трат: $exp\n'
        'Долги: $debts\n'
        'Окно среднего: ${_state.windowDays} дней\n'
        'Режим: ${_state.aiBehavior}';
  }

  Future<String> loadAiMemory() async {
    if (_guest) return 'Войдите в аккаунт, чтобы использовать память ИИ';
    try {
      final res = await _api.get('/api/ai/memory');
      final body = _json(res.body);
      return (body['content'] ?? '').toString();
    } catch (_) {
      return 'Не удалось загрузить память';
    }
  }

  Future<String> saveAiMemory(String content) async {
    if (_guest) return 'Войдите в аккаунт';
    try {
      final res = await _api.put('/api/ai/memory', {'content': content});
      return res.statusCode >= 200 && res.statusCode < 300
          ? 'Память сохранена'
          : 'Ошибка сохранения: ${res.statusCode}';
    } catch (_) {
      return 'Ошибка сохранения';
    }
  }

  Future<String> clearAiMemory() async {
    if (_guest) return 'Войдите в аккаунт';
    try {
      final res = await _api.delete('/api/ai/memory');
      return res.statusCode >= 200 && res.statusCode < 300
          ? 'Память очищена'
          : 'Ошибка: ${res.statusCode}';
    } catch (_) {
      return 'Ошибка очистки';
    }
  }

  Future<List<Map<String, String>>> loadAiHistory() async {
    if (_guest) return [];
    try {
      final res = await _api.get('/api/ai/history?limit=20');
      final body = _json(res.body);
      final raw = body['history'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => {
                'role': (e['role'] ?? 'user').toString(),
                'content': (e['content'] ?? e['message'] ?? '').toString(),
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _recalc() {
    _calc = recalc(_state);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  static Map<String, dynamic> _json(String body) {
    if (body.isEmpty) return {};
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

/// Результат пересчёта финансов (упрощённая копия recalc() из HTML).
class CalcResult {
  final double cash;
  final double cushion;
  final double savingsTotal;
  final double debtTotal;
  final double balance;
  final double income;
  final double expenses;
  final double cushionGoal;
  final double cushionPct;
  final double cushionRecPerDay;
  final double cushionRemaining;
  final List<DailyPoint> points;

  CalcResult({
    required this.cash,
    required this.cushion,
    required this.savingsTotal,
    required this.debtTotal,
    required this.balance,
    required this.income,
    required this.expenses,
    required this.cushionGoal,
    required this.cushionPct,
    required this.cushionRecPerDay,
    required this.cushionRemaining,
    required this.points,
  });

  factory CalcResult.empty() => CalcResult(
        cash: 0,
        cushion: 0,
        savingsTotal: 0,
        debtTotal: 0,
        balance: 0,
        income: 0,
        expenses: 0,
        cushionGoal: 0,
        cushionPct: 0,
        cushionRecPerDay: 0,
        cushionRemaining: 0,
        points: [],
      );
}

class DailyPoint {
  final String date;
  final double balance;
  final double open;
  final double high;
  final double low;
  final double close;
  DailyPoint({
    required this.date,
    required this.balance,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

CalcResult recalc(AppState s) {
  final entries = List<Entry>.from(s.history)..sort((a, b) {
    if (a.date == b.date) return a.id.compareTo(b.id);
    return a.date.compareTo(b.date);
  });

  double cash = s.startCash;
  double cushion = s.startCushion;
  double savings = 0;
  double debts = 0;
  double income = 0;
  double expenses = 0;

  // Активные долги (без события создания в истории) учитываются с начала.
  final debtEventIds = entries
      .where((e) => e.type == 'debt' && e.debtId != null)
      .map((e) => e.debtId.toString())
      .toSet();
  for (final d in s.debts) {
    if (!d.archived && !debtEventIds.contains(d.id)) debts += d.amount;
  }

  final points = <DailyPoint>[];
  var prevBal = s.startCash + s.startCushion - debts;

  for (final e in entries) {
    final open = prevBal;
    var high = open;
    var low = open;

    void touch() {
      final b = cash + cushion + savings - debts;
      if (b > high) high = b;
      if (b < low) low = b;
    }

    if (e.type == 'debt') {
      final d = s.debts.where((x) => x.id == e.debtId).firstOrNull;
      if (d != null) {
        final amt = e.debtAmt > 0 ? e.debtAmt : d.amount;
        if (e.creditCash) {
          cash += amt;
        } else {
          debts += amt;
        }
        touch();
      }
    } else {
      income += e.income;
      cash += e.income;
      touch();
      for (final v in e.expenses.values) {
        expenses += v;
        cash -= v;
        touch();
      }
      for (final v in e.savings.values) {
        savings += v;
        cash -= v;
        touch();
      }
      for (final v in e.savSpend.values) {
        savings -= v;
        cash += v;
        touch();
      }
      for (final v in e.debtPays.values) {
        debts -= v;
        cash -= v;
        touch();
      }
      cushion += e.cushIn;
      cushion -= e.cushOut;
      if (e.cushOut > 0) {
        cash += e.cushOut;
      }
      touch();
    }
    final close = cash + cushion + savings - debts;
    points.add(DailyPoint(
      date: e.date,
      balance: close,
      open: open,
      high: high,
      low: low,
      close: close,
    ));
    prevBal = close;
  }

  final balance = cash + cushion + savings - debts;

  // Цель подушки (аналог cushionMonthBase/cushionAnalysis).
  final monthlyBase = _monthlyBase(s, entries);
  final goal = monthlyBase * s.cushionMonths;
  final remaining = goal - cushion;
  final pct = goal > 0 ? (cushion / goal * 100).clamp(0, 100).toDouble() : 0.0;
  final recPerDay = remaining > 0 ? remaining / (s.cushionMonths * 30) : 0.0;

  return CalcResult(
    cash: cash,
    cushion: cushion,
    savingsTotal: savings,
    debtTotal: debts,
    balance: balance,
    income: income,
    expenses: expenses,
    cushionGoal: goal,
    cushionPct: pct,
    cushionRecPerDay: recPerDay,
    cushionRemaining: remaining,
    points: points,
  );
}

double _monthlyBase(AppState s, List<Entry> entries) {
  if (s.windowDays <= 0) return 0;

  final today = DateTime.now();
  final todayStr = _dateKey(today);
  final from = today.subtract(Duration(days: s.windowDays - 1));
  final fromStr = _dateKey(from);

  bool pick(Category c) {
    if (s.cushionInclude == 'all') return true;
    if (s.cushionInclude == 'need_rare') return c.need || c.rare;
    return c.need;
  }

  final cats = s.cats.where((c) => !c.archived && pick(c)).toList();
  final dayEntries = entries.where((e) => e.type == 'day').toList();
  double month = 0;

  for (final cat in cats) {
    double spentWin = 0;
    double allTime = 0;
    final daysWith = <String>{};
    for (final e in dayEntries) {
      final v = e.expenses[cat.id] ?? 0;
      if (v <= 0) continue;
      allTime += v;
      if (e.date.compareTo(fromStr) >= 0 && e.date.compareTo(todayStr) <= 0) {
        spentWin += v;
        daysWith.add(e.date);
      }
    }
    final span = daysWith.isEmpty
        ? s.windowDays < dayEntries.length
            ? s.windowDays
            : (dayEntries.isEmpty ? 1 : dayEntries.length)
        : daysWith.length;
    final avgDay = spentWin / span;
    final base = cat.spentBase > allTime ? allTime : cat.spentBase;
    final totalSpent = (allTime - base) > 0 ? allTime - base : 0.0;

    double? minDay;
    final plan = cat.plan;
    if (plan != null && plan.amount > 0) {
      final remaining = plan.amount - totalSpent > 0 ? plan.amount - totalSpent : 0.0;
      if (remaining > 0 && plan.date.isNotEmpty) {
        final due = DateTime.tryParse(plan.date);
        if (due != null) {
          final daysLeft = _dayDiff(today, due) + 1 < 1 ? 1 : _dayDiff(today, due) + 1;
          minDay = remaining / daysLeft;
        }
      }
    }

    if (s.cushionBase == 'min') {
      if (minDay != null && minDay > 0) {
        month += minDay * 30;
      } else if (avgDay > 0) {
        month += avgDay * 30;
      }
    } else if (s.cushionBase == 'rec') {
      if (avgDay > 0) {
        month += avgDay * 30;
      } else if (minDay != null && minDay > 0) {
        month += minDay * 30;
      }
    } else {
      month += avgDay * 30;
    }
  }
  return month;
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _dayDiff(DateTime a, DateTime b) =>
    DateTime(a.year, a.month, a.day).difference(DateTime(b.year, b.month, b.day)).inDays;
