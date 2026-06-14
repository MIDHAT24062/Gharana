import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _sb = Supabase.instance.client;

const _memberColors = [
  Color(0xFFB85C38),
  Color(0xFF6B8F71),
  Color(0xFF8B6BAE),
  Color(0xFF4A90D9),
  Color(0xFFD4A853),
];

enum MemberRole { admin, manager, spender }

MemberRole _roleFromString(String r) {
  switch (r) {
    case 'admin':   return MemberRole.admin;
    case 'manager': return MemberRole.manager;
    default:        return MemberRole.spender;
  }
}

String _roleToString(MemberRole r) {
  switch (r) {
    case MemberRole.admin:   return 'admin';
    case MemberRole.manager: return 'manager';
    case MemberRole.spender: return 'spender';
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────
class AppMember {
  final String id;
  final String name;
  final String phone;
  final String householdId;
  final MemberRole role;
  final Color color;

  AppMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.householdId,
    required this.role,
    required this.color,
  });

  factory AppMember.fromMap(Map<String, dynamic> m, {int colorIndex = 0}) => AppMember(
    id:          m['id'] as String,
    name:        m['name'] as String,
    phone:       m['phone'] as String,
    householdId: m['household_id'] as String,
    role:        _roleFromString(m['role'] as String? ?? 'spender'),
    color:       _memberColors[colorIndex % _memberColors.length],
  );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get roleLabel {
    switch (role) {
      case MemberRole.admin:   return 'Admin';
      case MemberRole.manager: return 'Manager';
      case MemberRole.spender: return 'Spender';
    }
  }

  AppMember copyWith({String? name, String? phone, MemberRole? role}) => AppMember(
    id: id, name: name ?? this.name, phone: phone ?? this.phone,
    householdId: householdId, role: role ?? this.role, color: color,
  );
}

class AppTransaction {
  final String id;
  final double amount;
  final String category;
  final String memberId;
  final DateTime date;
  final bool isIncome;
  final String note;

  AppTransaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.memberId,
    required this.date,
    required this.isIncome,
    this.note = '',
  });

  factory AppTransaction.fromMap(Map<String, dynamic> m) => AppTransaction(
    id:       m['id'] as String,
    amount:   (m['amount'] as num).toDouble(),
    category: m['category'] as String,
    memberId: m['member_id'] as String,
    date:     DateTime.parse(m['date'] as String),
    isIncome: m['is_income'] as bool? ?? false,
    note:     m['note'] as String? ?? '',
  );
}

class AppBudget {
  final String id;
  final String category;
  final double limit;

  AppBudget({required this.id, required this.category, required this.limit});

  factory AppBudget.fromMap(Map<String, dynamic> m) => AppBudget(
    id:       m['id'] as String,
    category: m['category'] as String,
    limit:    (m['limit_amount'] as num).toDouble(),
  );

  AppBudget copyWith({String? category, double? limit}) =>
      AppBudget(id: id, category: category ?? this.category, limit: limit ?? this.limit);
}

class AppHousehold {
  final String id;
  final String name;
  final String inviteCode;
  final String city;

  AppHousehold({required this.id, required this.name, required this.inviteCode, required this.city});

  factory AppHousehold.fromMap(Map<String, dynamic> m) => AppHousehold(
    id:         m['id'] as String,
    name:       m['name'] as String,
    inviteCode: m['invite_code'] as String,
    city:       m['city'] as String? ?? '',
  );
}

// ─── App State ────────────────────────────────────────────────────────────────
class AppState extends ChangeNotifier {
  AppMember?    _currentUser;
  AppHousehold? _household;
  final List<AppMember>      _members      = [];
  final List<AppTransaction> _transactions = [];
  final List<AppBudget>      _budgets      = [];
  bool   _loading = false;
  String _error   = '';

  AppMember?    get currentUser => _currentUser;
  AppHousehold? get household   => _household;
  bool          get isLoggedIn  => _currentUser != null;
  bool          get isLoading   => _loading;
  String        get error       => _error;

  List<AppMember>      get members      => List.unmodifiable(_members);
  List<AppTransaction> get transactions => List.unmodifiable(_transactions);
  List<AppBudget>      get budgets      => List.unmodifiable(_budgets);

  static const List<String> categories = [
    'Ration', 'Bijli Bill', 'Gas Bill', 'Rickshaw', 'School Fee',
    'Medicine', 'Internet', 'Salary', 'Freelance', 'Mobile Credit',
    'Clothes', 'Eating Out', 'Petrol', 'Rent', 'Other',
  ];

  // ── Computed ──────────────────────────────────────────────────────────────
  double get totalIncome  => _transactions.where((t) => t.isIncome).fold(0.0,  (s, t) => s + t.amount);
  double get totalExpense => _transactions.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);
  double get balance      => totalIncome - totalExpense;

  double spentForBudget(AppBudget b) => _transactions
      .where((t) => !t.isIncome && t.category == b.category)
      .fold(0.0, (s, t) => s + t.amount);

  double spentByMember(String memberId) => _transactions
      .where((t) => !t.isIncome && t.memberId == memberId)
      .fold(0.0, (s, t) => s + t.amount);

  Map<String, double> categoryBreakdownForMember(String memberId) {
    final map = <String, double>{};
    for (final t in _transactions.where((t) => !t.isIncome && t.memberId == memberId)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  AppMember? memberById(String id) {
    try { return _members.firstWhere((m) => m.id == id); } catch (_) { return null; }
  }

  List<AppTransaction> filteredTransactions({
    String? type, String? categoryFilter, String? memberFilter,
    String? searchQuery, String sortBy = 'date',
  }) {
    var list = _transactions.toList();
    if (type == 'income')  list = list.where((t) => t.isIncome).toList();
    if (type == 'expense') list = list.where((t) => !t.isIncome).toList();
    if (categoryFilter != null && categoryFilter.isNotEmpty)
      list = list.where((t) => t.category == categoryFilter).toList();
    if (memberFilter != null && memberFilter.isNotEmpty)
      list = list.where((t) => t.memberId == memberFilter).toList();
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((t) =>
        t.category.toLowerCase().contains(q) ||
        t.note.toLowerCase().contains(q) ||
        (memberById(t.memberId)?.name.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (sortBy == 'amount') list.sort((a, b) => b.amount.compareTo(a.amount));
    else list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // ── REGISTER ──────────────────────────────────────────────────────────────
  Future<String?> register(String name, String phone, String password) async {
    _error = '';
    try {
      final email = '${phone.replaceAll(RegExp(r'[\s\-]'), '')}@gharana.app';
      final res   = await _sb.auth.signUp(email: email, password: password);
      if (res.user == null) { _error = 'Registration failed. Try again.'; return null; }
      await _sb.auth.updateUser(UserAttributes(data: {'name': name, 'phone': phone}));
      return res.user!.id;
    } on AuthException catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      _error = 'Error: ${e.toString()}';
      return null;
    }
  }

  // ── CREATE HOUSEHOLD ──────────────────────────────────────────────────────
  Future<bool> createHousehold(String userId, String name, String phone,
      String householdName, String city) async {
    _error = '';
    try {
      final code = _generateCode();
      final hRow = await _sb.from('households').insert({
        'name':        householdName,
        'city':        city,
        'invite_code': code,
      }).select().single();

      await _sb.from('members').insert({
        'id':           userId,
        'household_id': hRow['id'],
        'name':         name,
        'phone':        phone,
        'role':         'admin',
      });

      await _loginAfterSetup(userId);
      return true;
    } catch (e) {
      _error = 'Could not create household: ${e.toString()}';
      return false;
    }
  }

  // ── JOIN HOUSEHOLD ────────────────────────────────────────────────────────
  Future<bool> joinHousehold(String userId, String name, String phone,
      String inviteCode, MemberRole role) async {
    _error = '';
    try {
      final rows = await _sb
          .from('households')
          .select()
          .eq('invite_code', inviteCode.toUpperCase().trim())
          .timeout(const Duration(seconds: 8));

      if (rows.isEmpty) {
        _error = 'Invalid invite code. Ask your Admin for the correct code.';
        return false;
      }

      final household = rows.first as Map<String, dynamic>;

      final existing = await _sb
          .from('members')
          .select()
          .eq('id', userId)
          .timeout(const Duration(seconds: 8));

      if (existing.isNotEmpty) {
        _error = 'You are already in a household.';
        return false;
      }

      await _sb.from('members').insert({
        'id':           userId,
        'household_id': household['id'],
        'name':         name,
        'phone':        phone,
        'role':         _roleToString(role),
      });

      await _loginAfterSetup(userId);
      return true;
    } catch (e) {
      _error = 'Could not join household: ${e.toString()}';
      return false;
    }
  }

  // ── LOGIN ─────────────────────────────────────────────────────────────────
  Future<String> login(String phone, String password) async {
    _error = '';
    try {
      final email = '${phone.replaceAll(RegExp(r'[\s\-]'), '')}@gharana.app';
      final res   = await _sb.auth.signInWithPassword(email: email, password: password);
      if (res.user == null) { _error = 'Wrong phone or password.'; return 'error'; }

      final rows = await _sb
          .from('members')
          .select()
          .eq('id', res.user!.id)
          .timeout(const Duration(seconds: 8));

      if (rows.isEmpty) return 'no_household';

      await _loginAfterSetup(res.user!.id);
      return 'ok';
    } on AuthException catch (e) {
      _error = e.message;
      return 'error';
    } catch (e) {
      _error = 'Error: ${e.toString()}';
      return 'error';
    }
  }

  Future<void> _loginAfterSetup(String userId) async {
    final rows = await _sb
        .from('members')
        .select()
        .eq('id', userId)
        .timeout(const Duration(seconds: 8));
    if (rows.isEmpty) return;
    _currentUser = AppMember.fromMap(rows.first as Map<String, dynamic>, colorIndex: 0);
    await _loadAll();
  }

  Future<void> restoreSession(String userId) async {
    await _loginAfterSetup(userId);
  }

  // ── LOGOUT ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _sb.auth.signOut();
    _currentUser = null;
    _household   = null;
    _members.clear();
    _transactions.clear();
    _budgets.clear();
    notifyListeners();
  }

  // ── LOAD DATA ─────────────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    _loading = true;
    notifyListeners();
    try {
      await Future.wait([_loadHousehold(), _loadMembers(), loadTransactions(), _loadBudgets()]);
    } catch (e) {
      _error = 'Failed to load data: ${e.toString()}';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadHousehold() async {
    final rows = await _sb
        .from('households')
        .select()
        .eq('id', _currentUser!.householdId)
        .timeout(const Duration(seconds: 8));
    if (rows.isNotEmpty) _household = AppHousehold.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<void> _loadMembers() async {
    final rows = await _sb
        .from('members')
        .select()
        .eq('household_id', _currentUser!.householdId)
        .timeout(const Duration(seconds: 8));
    _members.clear();
    for (int i = 0; i < rows.length; i++) {
      _members.add(AppMember.fromMap(rows[i] as Map<String, dynamic>, colorIndex: i));
    }
  }

  Future<void> loadTransactions() async {
    final rows = await _sb
        .from('transactions')
        .select()
        .eq('household_id', _currentUser!.householdId)
        .order('date', ascending: false)
        .timeout(const Duration(seconds: 8));
    _transactions.clear();
    for (final r in rows) _transactions.add(AppTransaction.fromMap(r as Map<String, dynamic>));
  }

  Future<void> _loadBudgets() async {
    final month = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final rows  = await _sb
        .from('budgets')
        .select()
        .eq('household_id', _currentUser!.householdId)
        .eq('month', month)
        .timeout(const Duration(seconds: 8));
    _budgets.clear();
    for (final r in rows) _budgets.add(AppBudget.fromMap(r as Map<String, dynamic>));
  }

  // ── TRANSACTIONS ──────────────────────────────────────────────────────────
  Future<void> addTransaction(AppTransaction tx) async {
    await _sb.from('transactions').insert({
      'household_id': _currentUser!.householdId,
      'member_id':    tx.memberId,
      'amount':       tx.amount,
      'category':     tx.category,
      'is_income':    tx.isIncome,
      'note':         tx.note,
      'date':         tx.date.toIso8601String(),
    });
    await loadTransactions();
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    await _sb.from('transactions').delete().eq('id', id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ── BUDGETS ───────────────────────────────────────────────────────────────
  Future<void> addBudget(AppBudget b) async {
    final month = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    await _sb.from('budgets').insert({
      'household_id': _currentUser!.householdId,
      'category':     b.category,
      'limit_amount': b.limit,
      'month':        month,
    });
    await _loadBudgets();
    notifyListeners();
  }

  Future<void> updateBudget(AppBudget updated) async {
    await _sb.from('budgets').update({'limit_amount': updated.limit}).eq('id', updated.id);
    final idx = _budgets.indexWhere((b) => b.id == updated.id);
    if (idx != -1) { _budgets[idx] = updated; notifyListeners(); }
  }

  Future<void> deleteBudget(String id) async {
    await _sb.from('budgets').delete().eq('id', id);
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  // ── MEMBERS ───────────────────────────────────────────────────────────────
  Future<void> addMember(AppMember m) async {
    await _sb.from('members').insert({
      'id':           m.id,
      'household_id': _currentUser!.householdId,
      'name':         m.name,
      'phone':        m.phone,
      'role':         _roleToString(m.role),
    });
    await _loadMembers();
    notifyListeners();
  }

  Future<void> updateMember(AppMember updated) async {
    await _sb.from('members').update({
      'name':  updated.name,
      'phone': updated.phone,
      'role':  _roleToString(updated.role),
    }).eq('id', updated.id);
    await _loadMembers();
    notifyListeners();
  }

  Future<void> removeMember(String id) async {
    if (_members.length <= 1) return;
    await _sb.from('members').delete().eq('id', id);
    _members.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var n    = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[n % chars.length];
      n    ~/= chars.length;
    }
    return code;
  }

  String formatAmount(double amt) {
    final s = amt.toStringAsFixed(0);
    return 'Rs ${s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────
class StateProvider extends InheritedNotifier<AppState> {
  const StateProvider({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<StateProvider>();
    assert(p != null, 'StateProvider not found');
    return p!.notifier!;
  }
}
