import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key});
  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> with TickerProviderStateMixin {
  late AnimationController _barCtrl;
  late AnimationController _donutCtrl;
  late Animation<double> _barAnim;
  late Animation<double> _donutAnim;
  int _selectedMember = -1;

  @override
  void initState() {
    super.initState();
    _barCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _donutCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _barAnim   = CurvedAnimation(parent: _barCtrl,   curve: Curves.easeOutCubic);
    _donutAnim = CurvedAnimation(parent: _donutCtrl, curve: Curves.easeOutCubic);
    _barCtrl.forward();
    _donutCtrl.forward();
  }

  @override
  void dispose() { _barCtrl.dispose(); _donutCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state   = StateProvider.of(context);
    final members = state.members;
    final spends  = members.map((m) => state.spentByMember(m.id)).toList();
    final grand   = spends.fold(0.0, (s, v) => s + v);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Spending')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [

          // ── Donut card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C1810), Color(0xFF4A2C1A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Family Spending', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('June 2025', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(state.formatAmount(grand),
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
              const SizedBox(height: 24),

              // Donut
              AnimatedBuilder(
                animation: _donutAnim,
                builder: (_, __) => SizedBox(
                  height: 190,
                  child: Stack(alignment: Alignment.center, children: [
                    CustomPaint(
                      size: const Size(190, 190),
                      painter: _DonutPainter(
                        values: spends, colors: members.map((m) => m.color).toList(),
                        progress: _donutAnim.value, selectedIndex: _selectedMember,
                      ),
                    ),
                    // center label
                    _selectedMember >= 0
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            AvatarWidget(initials: members[_selectedMember].initials,
                                color: members[_selectedMember].color, size: 38),
                            const SizedBox(height: 6),
                            Text(members[_selectedMember].name.split(' ')[0],
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            Text(state.formatAmount(spends[_selectedMember]),
                                style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          ])
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.people_rounded, color: Colors.white38, size: 22),
                            const SizedBox(height: 4),
                            const Text('All members', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ]),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              // Legend pills — tappable
              Wrap(
                spacing: 8, runSpacing: 8,
                alignment: WrapAlignment.center,
                children: members.asMap().entries.map((e) {
                  final m   = e.value;
                  final pct = grand > 0 ? (spends[e.key] / grand * 100) : 0.0;
                  final sel = _selectedMember == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMember = sel ? -1 : e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? m.color.withOpacity(0.25) : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? m.color.withOpacity(0.6) : Colors.transparent),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: m.color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.name.split(' ')[0],
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          Text('${pct.toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        ]),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),

          // ── Bar chart card ──────────────────────────────────────────────
          const SectionHeader(title: 'Who Spent What'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: AnimatedBuilder(
              animation: _barAnim,
              builder: (_, __) => _BarChart(
                members: members,
                spends: spends,
                progress: _barAnim.value,
                state: state,
              ),
            ),
          ),

          // ── Per-member breakdown ────────────────────────────────────────
          const SectionHeader(title: 'Category Breakdown'),
          ...members.asMap().entries.map((e) =>
              _MemberCard(member: e.value, state: state)),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Bar Chart Widget ──────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<AppMember> members;
  final List<double> spends;
  final double progress;
  final AppState state;
  const _BarChart({required this.members, required this.spends, required this.progress, required this.state});

  @override
  Widget build(BuildContext context) {
    final maxVal = spends.isEmpty ? 1.0 : spends.reduce(max);
    final grand  = spends.fold(0.0, (s, v) => s + v);

    return Column(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: members.asMap().entries.map((e) {
          final m          = e.value;
          final spend      = spends[e.key];
          final barHeight  = maxVal > 0 ? (spend / maxVal) * 150 * progress : 0.0;
          final pct        = grand > 0 ? (spend / grand * 100) : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(children: [
                Text(state.formatAmount(spend),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: m.color)),
                const SizedBox(height: 6),
                Stack(alignment: Alignment.bottomCenter, children: [
                  Container(
                    height: 150, width: double.infinity,
                    decoration: BoxDecoration(
                      color: m.color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Container(
                    height: barHeight.clamp(4.0, 150.0), width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [m.color.withOpacity(0.6), m.color],
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                AvatarWidget(initials: m.initials, color: m.color, size: 34),
                const SizedBox(height: 4),
                Text(m.name.split(' ')[0],
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}

// ─── Donut Painter ─────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double progress;
  final int selectedIndex;
  _DonutPainter({required this.values, required this.colors, required this.progress, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (s, v) => s + v);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const stroke = 26.0;
    const gap    = 0.025;
    double start = -pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * pi * progress - gap;
      if (sweep <= 0) { start += gap; continue; }
      final sel     = selectedIndex == i;
      final dimmed  = selectedIndex != -1 && !sel;
      final r       = radius - (sel ? stroke + 6 : stroke) / 2;
      final paint   = Paint()
        ..color      = dimmed ? colors[i].withOpacity(0.25) : colors[i]
        ..style      = PaintingStyle.stroke
        ..strokeWidth = sel ? stroke + 6 : stroke
        ..strokeCap  = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, false, paint);
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress || old.selectedIndex != selectedIndex;
}

// ─── Member Breakdown Card ──────────────────────────────────────────────────────
class _MemberCard extends StatefulWidget {
  final AppMember member;
  final AppState state;
  const _MemberCard({required this.member, required this.state});
  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m         = widget.member;
    final state     = widget.state;
    final breakdown = state.categoryBreakdownForMember(m.id);
    final total     = state.spentByMember(m.id);
    final sorted    = breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal    = sorted.isNotEmpty ? sorted.first.value : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _expanded ? m.color.withOpacity(0.3) : AppColors.divider),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AvatarWidget(initials: m.initials, color: m.color, size: 46),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                Row(children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: m.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(m.roleLabel, style: TextStyle(fontSize: 12, color: m.color, fontWeight: FontWeight.w500)),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(state.formatAmount(total),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.color)),
                Text('${breakdown.length} categories',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: m.color),
              ),
            ]),
          ),
        ),

        // Expanded section
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: breakdown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text('No expenses recorded for ${m.name.split(' ')[0]}.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(children: [
                    Divider(color: m.color.withOpacity(0.15), height: 1),
                    const SizedBox(height: 14),
                    ...sorted.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        CategoryIconWidget(category: entry.key, size: 32),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            Text(state.formatAmount(entry.value),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: m.color)),
                          ]),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: entry.value / maxVal,
                              backgroundColor: m.color.withOpacity(0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(m.color.withOpacity(0.6)),
                              minHeight: 5,
                            ),
                          ),
                        ])),
                      ]),
                    )),
                  ]),
                ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ]),
    );
  }
}
