// Полная модель состояния BitBalance — аналог defaultState/migrate() из HTML-приложения.

class Budget {
  final double needs;
  final double wants;
  final double goals;
  final double cushion;
  Budget({
    this.needs = 50,
    this.wants = 30,
    this.goals = 10,
    this.cushion = 10,
  });
  factory Budget.fromJson(Map<dynamic, dynamic>? j) {
    j ??= {};
    return Budget(
      needs: _num(j['needs']) == 0 ? 50 : _num(j['needs']),
      wants: _num(j['wants']) == 0 ? 30 : _num(j['wants']),
      goals: _num(j['goals']) == 0 ? 10 : _num(j['goals']),
      cushion: _num(j['cushion']) == 0 ? 10 : _num(j['cushion']),
    );
  }
  Map<String, dynamic> toJson() => {
    'needs': needs,
    'wants': wants,
    'goals': goals,
    'cushion': cushion,
  };
}

class Health {
  final double needsMax;
  final double saveMin;
  final double runwayMin;
  final double debtMonths;
  Health({
    this.needsMax = 50,
    this.saveMin = 20,
    this.runwayMin = 30,
    this.debtMonths = 12,
  });
  factory Health.fromJson(Map<dynamic, dynamic>? j) {
    j ??= {};
    return Health(
      needsMax: _num(j['needsMax']) == 0 ? 50 : _num(j['needsMax']),
      saveMin: _num(j['saveMin']) == 0 ? 20 : _num(j['saveMin']),
      runwayMin: _num(j['runwayMin']) == 0 ? 30 : _num(j['runwayMin']),
      debtMonths: _num(j['debtMonths']) == 0 ? 12 : _num(j['debtMonths']),
    );
  }
  Map<String, dynamic> toJson() => {
    'needsMax': needsMax,
    'saveMin': saveMin,
    'runwayMin': runwayMin,
    'debtMonths': debtMonths,
  };
}

class Category {
  final String id;
  final String name;
  final String icon;
  final bool need;
  final bool rare;
  final bool archived;
  final String resetDate;
  final double spentBase;
  final Plan? plan;
  Category({
    required this.id,
    required this.name,
    this.icon = '',
    this.need = false,
    this.rare = false,
    this.archived = false,
    this.resetDate = '',
    this.spentBase = 0,
    this.plan,
  });
  factory Category.fromJson(Map<dynamic, dynamic> j) => Category(
    id: str(j['id']),
    name: (j['name'] ?? 'Категория').toString(),
    icon: (j['icon'] ?? '').toString(),
    need: j['need'] == true,
    rare: j['rare'] == true,
    archived: j['archived'] == true,
    resetDate: (j['resetDate'] ?? '').toString(),
    spentBase: _num(j['spentBase']),
    plan: j['plan'] is Map
        ? Plan.fromJson(j['plan'] as Map<dynamic, dynamic>)
        : null,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'need': need,
    'rare': rare,
    'archived': archived,
    'resetDate': resetDate,
    'spentBase': spentBase,
    'plan': plan?.toJson(),
  };
}

class IncomeCategory {
  final String id;
  final String name;
  IncomeCategory({required this.id, required this.name});
  factory IncomeCategory.fromJson(Map<dynamic, dynamic> j) =>
      IncomeCategory(id: str(j['id']), name: (j['name'] ?? 'Доход').toString());
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class Debt {
  final String id;
  final String name;
  final double amount;
  final String due;
  final String date;
  final double rate;
  final bool archived;
  final String archivedAt;
  Debt({
    required this.id,
    required this.name,
    this.amount = 0,
    this.due = '',
    this.date = '',
    this.rate = 0,
    this.archived = false,
    this.archivedAt = '',
  });
  factory Debt.fromJson(Map<dynamic, dynamic> j) => Debt(
    id: str(j['id']),
    name: (j['name'] ?? 'Долг').toString(),
    amount: _num(j['amount']),
    due: (j['due'] ?? '').toString(),
    date: (j['date'] ?? '').toString(),
    rate: _num(j['rate']),
    archived: j['archived'] == true,
    archivedAt: (j['archivedAt'] ?? '').toString(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'due': due,
    'date': date,
    'rate': rate,
    'archived': archived,
    'archivedAt': archivedAt,
  };
}

class Plan {
  final double amount;
  final String date;
  final String start;
  Plan({this.amount = 0, this.date = '', this.start = ''});
  factory Plan.fromJson(Map<dynamic, dynamic> j) => Plan(
    amount: _num(j['amount'] ?? j['target']),
    date: (j['date'] ?? '').toString(),
    start: (j['start'] ?? '').toString(),
  );
  Map<String, dynamic> toJson() => {
    'amount': amount,
    'date': date,
    'start': start,
  };
}

class SavingsGoal {
  final String id;
  final String name;
  final String kind; // goal / invest
  final bool archived;
  final String closedAt;
  final String closedAs;
  final double closedAmount;
  final double closedFunded;
  final Plan? plan;
  SavingsGoal({
    required this.id,
    required this.name,
    this.kind = 'goal',
    this.archived = false,
    this.closedAt = '',
    this.closedAs = '',
    this.closedAmount = 0,
    this.closedFunded = 0,
    this.plan,
  });
  factory SavingsGoal.fromJson(Map<dynamic, dynamic> j) => SavingsGoal(
    id: str(j['id']),
    name: (j['name'] ?? 'Накопление').toString(),
    kind: j['kind'] == 'invest' ? 'invest' : 'goal',
    archived: j['archived'] == true,
    closedAt: (j['closedAt'] ?? '').toString(),
    closedAs: (j['closedAs'] ?? '').toString(),
    closedAmount: _num(j['closedAmount']),
    closedFunded: _num(j['closedFunded']),
    plan: j['plan'] is Map
        ? Plan.fromJson(j['plan'] as Map<dynamic, dynamic>)
        : null,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'archived': archived,
    'closedAt': closedAt,
    'closedAs': closedAs,
    'closedAmount': closedAmount,
    'closedFunded': closedFunded,
    'plan': plan?.toJson(),
  };
}

class AutoPay {
  final String id;
  final String name;
  final double amount;
  final String mode; // monthly / daily
  final int day;
  final String time;
  final String? catId;
  final String lastApplied;
  AutoPay({
    required this.id,
    required this.name,
    this.amount = 0,
    this.mode = 'daily',
    this.day = 1,
    this.time = '07:00',
    this.catId,
    this.lastApplied = '',
  });
  factory AutoPay.fromJson(Map<dynamic, dynamic> j) => AutoPay(
    id: str(j['id']),
    name: (j['name'] ?? '').toString(),
    amount: _num(j['amount']),
    mode: j['mode'] == 'monthly' ? 'monthly' : 'daily',
    day: _int(j['day'], fallback: 1).clamp(1, 31),
    time: (j['time'] ?? '07:00').toString(),
    catId: j['catId']?.toString(),
    lastApplied: (j['lastApplied'] ?? '').toString(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'mode': mode,
    'day': day,
    'time': time,
    'catId': catId,
    'lastApplied': lastApplied,
  };
}

class Entry {
  final String id;
  final String type; // day / debt
  final String date;
  final double income;
  final String? incomeCat;
  final Map<String, double> expenses;
  final Map<String, double> debtPays;
  final Map<String, double> savings;
  final Map<String, double> savSpend;
  final double cushOut;
  final double cushIn;
  final String note;
  final String? debtId;
  final double debtAmt;
  final bool creditCash;
  final List<dynamic> autoItems;
  final List<dynamic> autoMk;
  Entry({
    required this.id,
    required this.type,
    required this.date,
    this.income = 0,
    this.incomeCat,
    required this.expenses,
    required this.debtPays,
    required this.savings,
    required this.savSpend,
    this.cushOut = 0,
    this.cushIn = 0,
    this.note = '',
    this.debtId,
    this.debtAmt = 0,
    this.creditCash = false,
    required this.autoItems,
    required this.autoMk,
  });
  factory Entry.fromJson(Map<dynamic, dynamic> j) {
    if (j['type'] == 'debt') {
      return Entry(
        id: str(j['id']),
        type: 'debt',
        date: (j['date'] ?? '').toString(),
        expenses: {},
        debtPays: {},
        savings: {},
        savSpend: {},
        note: (j['note'] ?? '').toString(),
        debtId: j['debtId']?.toString(),
        debtAmt: _num(j['debtAmt']),
        creditCash: j['creditCash'] == true,
        autoItems: [],
        autoMk: [],
      );
    }
    return Entry(
      id: str(j['id']),
      type: 'day',
      date: (j['date'] ?? '').toString(),
      income: _num(j['income']),
      incomeCat: j['incomeCat']?.toString(),
      expenses: _numMap(j['expenses']),
      debtPays: _numMap(j['debtPays']),
      savings: _numMap(j['savings']),
      savSpend: _numMap(j['savSpend']),
      cushOut: _num(j['cushOut']),
      cushIn: _num(j['cushIn']),
      note: (j['note'] ?? '').toString(),
      autoItems: j['autoItems'] is List
          ? List<dynamic>.from(j['autoItems'])
          : [],
      autoMk: j['autoMk'] is List ? List<dynamic>.from(j['autoMk']) : [],
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'date': date,
    'income': income,
    'incomeCat': incomeCat,
    'expenses': expenses,
    'debtPays': debtPays,
    'savings': savings,
    'savSpend': savSpend,
    'cushOut': cushOut,
    'cushIn': cushIn,
    'note': note,
    'debtId': debtId,
    'debtAmt': debtAmt,
    'creditCash': creditCash,
    'autoItems': autoItems,
    'autoMk': autoMk,
  };
}

class AppState {
  int v;
  double startCash;
  double startCushion;
  int cushionMonths;
  String cushionInclude; // need / need_rare / all
  String cushionBase; // avg / rec / min
  int windowDays;
  String strategy; // snow / aval / order
  bool hideBal;
  String chartMode; // candle / line
  String tf; // day / week / month / year
  String fontSize;
  String accent;
  String theme; // light / dark
  String toastMode;
  int toastSec;
  bool toastSticky;
  int remindDays;
  int recentOpsLimit;
  List<IncomeCategory> incomeCats;
  List<Category> cats;
  List<Debt> debts;
  List<AutoPay> autopay;
  List<SavingsGoal> savings;
  List<Entry> history;
  String cutLevel;
  String preset;
  Budget budget;
  Health health;
  Map<String, dynamic> profile;
  String aiBehavior;
  String aiNotifyTime;
  String aiQuietStart;
  String aiQuietEnd;
  int aiMaxNotifications;
  List<dynamic> aiNotifications;
  List<String> tgNotifyTimes;
  double? tzOffset;
  String tgMessageMode;

  AppState({
    this.v = 12,
    this.startCash = 0,
    this.startCushion = 0,
    this.cushionMonths = 3,
    this.cushionInclude = 'need',
    this.cushionBase = 'avg',
    this.windowDays = 30,
    this.strategy = 'snow',
    this.hideBal = false,
    this.chartMode = 'candle',
    this.tf = 'day',
    this.fontSize = 'm',
    this.accent = 'indigo',
    this.theme = 'light',
    this.toastMode = 'auto',
    this.toastSec = 6,
    this.toastSticky = false,
    this.remindDays = 2,
    this.recentOpsLimit = 10,
    required this.incomeCats,
    required this.cats,
    required this.debts,
    required this.autopay,
    required this.savings,
    required this.history,
    this.cutLevel = 'eff',
    this.preset = '50/30/20',
    required this.budget,
    required this.health,
    required this.profile,
    this.aiBehavior = 'balanced',
    this.aiNotifyTime = '09:00',
    this.aiQuietStart = '22:00',
    this.aiQuietEnd = '08:00',
    this.aiMaxNotifications = 3,
    required this.aiNotifications,
    required this.tgNotifyTimes,
    this.tzOffset,
    this.tgMessageMode = 'smart',
  });

  factory AppState.empty() => AppState(
    incomeCats: [IncomeCategory(id: '1', name: 'Работа')],
    cats: [],
    debts: [],
    autopay: [],
    savings: [],
    history: [],
    budget: Budget(),
    health: Health(),
    profile: {},
    aiNotifications: [],
    tgNotifyTimes: ['07:00', '12:00', '19:00'],
  );

  factory AppState.fromJson(Map<String, dynamic> json) {
    final incomeCats = _list(json['incomeCats'])
        .map((e) => IncomeCategory.fromJson(e as Map<dynamic, dynamic>))
        .toList();
    if (incomeCats.isEmpty) {
      incomeCats.add(IncomeCategory(id: '1', name: 'Работа'));
    }
    final tgTimes = _list(json['tgNotifyTimes'])
        .map((e) => e.toString())
        .toList();
    while (tgTimes.length < 10) {
      tgTimes.add(const ['07:00', '12:00', '19:00'][tgTimes.length % 3]);
    }
    return AppState(
      v: _int(json['v'], fallback: 12),
      startCash: _num(json['startCash']),
      startCushion: _num(json['startCushion']),
      cushionMonths: _int(json['cushionMonths'], fallback: 3).clamp(1, 12),
      cushionInclude:
          ['need', 'need_rare', 'all'].contains(json['cushionInclude'])
          ? json['cushionInclude'] as String
          : 'need',
      cushionBase: ['avg', 'rec', 'min'].contains(json['cushionBase'])
          ? json['cushionBase'] as String
          : 'avg',
      windowDays: _int(json['windowDays'], fallback: 30) < 1
          ? 30
          : _int(json['windowDays'], fallback: 30),
      strategy: ['snow', 'aval', 'order'].contains(json['strategy'])
          ? json['strategy'] as String
          : 'snow',
      hideBal: json['hideBal'] == true,
      chartMode: json['chartMode'] == 'line' ? 'line' : 'candle',
      tf: ['day', 'week', 'month', 'year'].contains(json['tf'])
          ? json['tf'] as String
          : 'day',
      fontSize: (json['fontSize'] ?? 'm').toString(),
      accent: (json['accent'] ?? 'indigo').toString(),
      theme: ['light', 'dark'].contains(json['theme'])
          ? json['theme'] as String
          : 'light',
      toastMode: (json['toastMode'] ?? 'auto').toString(),
      toastSec: _int(json['toastSec'], fallback: 6) < 1
          ? 6
          : _int(json['toastSec'], fallback: 6),
      toastSticky: json['toastSticky'] == true,
      remindDays: _int(json['remindDays'], fallback: 2),
      recentOpsLimit:
          [5, 10, 30].contains(_int(json['recentOpsLimit'], fallback: 10))
          ? _int(json['recentOpsLimit'], fallback: 10)
          : 10,
      incomeCats: incomeCats,
      cats: _list(json['cats'])
          .map((e) => Category.fromJson(e as Map<dynamic, dynamic>))
          .toList(),
      debts: _list(json['debts'])
          .map((e) => Debt.fromJson(e as Map<dynamic, dynamic>))
          .toList(),
      autopay: _list(json['autopay'])
          .map((e) => AutoPay.fromJson(e as Map<dynamic, dynamic>))
          .toList(),
      savings: _list(json['savings'])
          .map((e) => SavingsGoal.fromJson(e as Map<dynamic, dynamic>))
          .toList(),
      history: _list(json['history'])
          .map((e) => Entry.fromJson(e as Map<dynamic, dynamic>))
          .toList(),
      cutLevel: (json['cutLevel'] ?? 'eff').toString(),
      preset: (json['preset'] ?? '50/30/20').toString(),
      budget: Budget.fromJson(
        json['budget'] is Map ? json['budget'] as Map : null,
      ),
      health: Health.fromJson(
        json['health'] is Map ? json['health'] as Map : null,
      ),
      profile: json['profile'] is Map
          ? Map<String, dynamic>.from(json['profile'] as Map)
          : {},
      aiBehavior:
          [
            'balanced',
            'strict',
            'coach',
            'analyst',
            'choleric',
          ].contains(json['aiBehavior'])
          ? json['aiBehavior'] as String
          : 'balanced',
      aiNotifyTime: (json['aiNotifyTime'] ?? '09:00').toString(),
      aiQuietStart: (json['aiQuietStart'] ?? '22:00').toString(),
      aiQuietEnd: (json['aiQuietEnd'] ?? '08:00').toString(),
      aiMaxNotifications: _int(json['aiMaxNotifications'], fallback: 3),
      aiNotifications: _list(json['aiNotifications']),
      tgNotifyTimes: tgTimes,
      tzOffset: json['tzOffset'] is num
          ? (json['tzOffset'] as num).toDouble()
          : null,
      tgMessageMode: ['smart', 'ai'].contains(json['tgMessageMode'])
          ? json['tgMessageMode'] as String
          : 'smart',
    );
  }

  Map<String, dynamic> toJson() => {
    'v': v,
    'startCash': startCash,
    'startCushion': startCushion,
    'cushionMonths': cushionMonths,
    'cushionInclude': cushionInclude,
    'cushionBase': cushionBase,
    'windowDays': windowDays,
    'strategy': strategy,
    'hideBal': hideBal,
    'chartMode': chartMode,
    'tf': tf,
    'fontSize': fontSize,
    'accent': accent,
    'theme': theme,
    'toastMode': toastMode,
    'toastSec': toastSec,
    'toastSticky': toastSticky,
    'remindDays': remindDays,
    'recentOpsLimit': recentOpsLimit,
    'incomeCats': incomeCats.map((e) => e.toJson()).toList(),
    'cats': cats.map((e) => e.toJson()).toList(),
    'debts': debts.map((e) => e.toJson()).toList(),
    'autopay': autopay.map((e) => e.toJson()).toList(),
    'savings': savings.map((e) => e.toJson()).toList(),
    'history': history.map((e) => e.toJson()).toList(),
    'cutLevel': cutLevel,
    'preset': preset,
    'budget': budget.toJson(),
    'health': health.toJson(),
    'profile': profile,
    'aiBehavior': aiBehavior,
    'aiNotifyTime': aiNotifyTime,
    'aiQuietStart': aiQuietStart,
    'aiQuietEnd': aiQuietEnd,
    'aiMaxNotifications': aiMaxNotifications,
    'aiNotifications': aiNotifications,
    'tgNotifyTimes': tgNotifyTimes,
    'tzOffset': tzOffset,
    'tgMessageMode': tgMessageMode,
  };
}

// ---- helpers (аналог JS-функций num/isObj/uid) ----

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _int(dynamic v, {int fallback = 0}) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

List<dynamic> _list(dynamic v) =>
    v is List ? List<dynamic>.from(v) : <dynamic>[];

Map<String, double> _numMap(dynamic v) {
  if (v is! Map) return {};
  final out = <String, double>{};
  v.forEach((key, value) => out[key.toString()] = _num(value));
  return out;
}

String str(dynamic v) => v == null ? '' : v.toString();
