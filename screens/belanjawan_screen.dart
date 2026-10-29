import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mykasih_header.dart';
import '../widgets/donut_chart.dart';

class BelanjawanScreen extends StatefulWidget {
  const BelanjawanScreen({
    super.key,
    required this.apiService,
    required this.user,
    required this.onLogout,
    this.onOpenNotifications,
    this.isAdmin = false,
    this.onToggleAdmin,
    this.onNavigateTab,
  });

  final ApiService apiService;
  final AppUser user;
  final VoidCallback onLogout;
  final VoidCallback? onOpenNotifications;
  final bool isAdmin;
  final VoidCallback? onToggleAdmin;
  final ValueChanged<int>? onNavigateTab;

  @override
  State<BelanjawanScreen> createState() => _BelanjawanScreenState();
}

class _BelanjawanScreenState extends State<BelanjawanScreen> {
  BudgetPlan? _plan;
  bool _loading = true;
  String? _error;

  bool _showAddIncome = false;
  bool _showAddCommitment = false;
  bool _showAddExpense = false;
  bool _showSetCategoryBudget = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await widget.apiService.getBudget(widget.user.userId);
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuatkan belanjawan.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          MyKasihHeader(
            userName: widget.user.name,
            onLogout: widget.onLogout,
            onOpenNotifications: widget.onOpenNotifications,
            isAdmin: widget.isAdmin,
            onToggleAdmin: widget.onToggleAdmin,
            child: _buildHeaderContent(),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeaderContent() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = lastDay - now.day;
    final monthLabel = DateFormat('MMMM yyyy', 'ms').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white, size: 20),
            const SizedBox(width: 6),
            const Text('Pengurusan & Perancangan Kewangan',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text('$monthLabel • $daysLeft hari lagi dalam bulan ini',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Cuba Lagi')),
          ],
        ),
      );
    }
    final plan = _plan!;
    final categoryColors = {
      'Makanan & Minuman': AppColors.chartGreen,
      'Pengangkutan': AppColors.chartGold,
      'Utiliti': AppColors.chartBlue,
      'Kesihatan': const Color(0xFFE11D48),
      'Lain-lain': const Color(0xFF8B5CF6),
    };
    final byCategory = plan.byCategory;
    final slices = byCategory.entries
        .map((e) => DonutSlice(
              label: e.key,
              value: e.value,
              color: categoryColors[e.key] ??
                  Colors.primaries[byCategory.keys.toList().indexOf(e.key) %
                      Colors.primaries.length],
            ))
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Executive Financial Summary & Disposable Income Card
          _buildExecutiveSummary(plan),
          const SizedBox(height: 16),

          // 2. Multi-Source Income Section (Formula 1 & User requirement)
          _buildIncomeCard(plan),
          const SizedBox(height: 16),

          // 3. Fixed Commitments Section
          _buildCommitmentsCard(plan),
          const SizedBox(height: 16),

          // 4. Category Budget Utilization Section (Formula 3: Actual / Budget * 100)
          _buildCategoryBudgetsCard(plan),
          const SizedBox(height: 16),

          // 5. Categorical Expense Donut Chart
          _buildDonutChartCard(slices),
          const SizedBox(height: 16),

          // 6. Monthly Expenses Tracking List
          _buildExpensesCard(plan),
          const SizedBox(height: 16),

          // 7. Intelligent Recommendations & Reminders (Rules 4, 18, 23)
          _buildSmartSuggestionsCard(plan),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildExecutiveSummary(BudgetPlan plan) {
    final daysLeft = daysLeftInMonth();
    final dailyAvailable =
        (plan.balance / daysLeft).clamp(0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Aliran Tunai Bulanan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryBlock(
                  icon: Icons.trending_up,
                  iconColor: AppColors.primary,
                  value: 'RM${plan.totalIncome.toStringAsFixed(0)}',
                  label: 'Jumlah Pendapatan',
                ),
              ),
              Expanded(
                child: _SummaryBlock(
                  icon: Icons.lock_outline,
                  iconColor: const Color(0xFFD97706),
                  value: 'RM${plan.totalCommitments.toStringAsFixed(0)}',
                  label: 'Komitmen Tetap',
                ),
              ),
              Expanded(
                child: _SummaryBlock(
                  icon: Icons.account_balance,
                  iconColor: const Color(0xFF2563EB),
                  value: 'RM${plan.disposableIncome.toStringAsFixed(0)}',
                  label: 'Pendapatan Boleh Guna',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Perbelanjaan Semasa:',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    Text('RM${plan.totalExpenses.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Baki Bersih:',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    Text('RM${plan.balance.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: plan.balance >= 0
                                ? AppColors.primary
                                : AppColors.danger)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kadar Penggunaan:',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    Text('${plan.usagePercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.chartGold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (plan.usagePercent / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: AppColors.primaryLight,
              valueColor: AlwaysStoppedAnimation(
                plan.usagePercent > 85 ? AppColors.danger : AppColors.chartGold,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('💡 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Had Baki Harian: RM${dailyAvailable.toStringAsFixed(0)} / hari',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Formula: Baki Bersih (RM${plan.balance.toStringAsFixed(0)}) ÷ $daysLeft hari baki',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeCard(BudgetPlan plan) {
    return _IncomeManagementCard(
      totalIncome: plan.totalIncome,
      incomes: plan.incomes,
      showAddForm: _showAddIncome,
      onToggleAdd: () => setState(() => _showAddIncome = !_showAddIncome),
      onAddIncome: (source, amount, date, isRecurring) async {
        final updated = await widget.apiService.addIncome(
          widget.user.userId,
          source,
          amount,
          date: date,
          isRecurring: isRecurring,
        );
        if (!mounted) return;
        setState(() {
          _plan = updated;
          _showAddIncome = false;
        });
      },
      onDeleteIncome: (id) async {
        final updated =
            await widget.apiService.deleteIncome(widget.user.userId, id);
        if (!mounted) return;
        setState(() => _plan = updated);
      },
    );
  }

  Widget _buildCommitmentsCard(BudgetPlan plan) {
    return _ExpenseListCard(
      title: 'Komitmen Tetap Bulanan',
      subtitle: 'Sewa, ansuran pinjaman, utiliti tetap',
      total: plan.totalCommitments,
      items: plan.commitments,
      showAddForm: _showAddCommitment,
      onToggleAdd: () =>
          setState(() => _showAddCommitment = !_showAddCommitment),
      onAdd: (name, amount) async {
        final updated = await widget.apiService
            .addCommitment(widget.user.userId, name, amount);
        if (!mounted) return;
        setState(() {
          _plan = updated;
          _showAddCommitment = false;
        });
      },
      onDelete: (id) async {
        final updated =
            await widget.apiService.deleteCommitment(widget.user.userId, id);
        if (!mounted) return;
        setState(() => _plan = updated);
      },
    );
  }

  Widget _buildCategoryBudgetsCard(BudgetPlan plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kadar Penggunaan Bajet Kategori',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              IconButton(
                icon: Icon(
                    _showSetCategoryBudget
                        ? Icons.close
                        : Icons.tune_outlined,
                    size: 18,
                    color: AppColors.primary),
                tooltip: 'Ubah Had Bajet Kategori',
                onPressed: () => setState(
                    () => _showSetCategoryBudget = !_showSetCategoryBudget),
              ),
            ],
          ),
          const Text('Formula: Perbelanjaan Sebenar ÷ Had Bajet × 100',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          if (_showSetCategoryBudget) ...[
            const SizedBox(height: 12),
            _SetBudgetInlineForm(
              onSave: (category, amount) async {
                final updated = await widget.apiService
                    .setCategoryBudget(widget.user.userId, category, amount);
                if (!mounted) return;
                setState(() {
                  _plan = updated;
                  _showSetCategoryBudget = false;
                });
              },
            ),
          ],
          const SizedBox(height: 14),
          ...plan.categoryBudgets.map((cb) {
            final isOver = cb.isOverBudget;
            final isNear = cb.isNearLimit;
            final color = isOver
                ? AppColors.danger
                : (isNear ? AppColors.chartGold : AppColors.primary);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(cb.category,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        'RM${cb.spentAmount.toStringAsFixed(0)} / RM${cb.budgetAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${cb.utilizationPercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: cb.budgetAmount > 0
                          ? (cb.spentAmount / cb.budgetAmount).clamp(0, 1)
                          : 0,
                      minHeight: 6,
                      backgroundColor: AppColors.primaryLight,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDonutChartCard(List<DonutSlice> slices) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pecahan Perbelanjaan Mengikut Kategori',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          Center(child: DonutChart(slices: slices)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: slices
                .map((s) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: s.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${s.label} (RM${s.value.toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesCard(BudgetPlan plan) {
    return _ExpenseListCard(
      title: 'Rekod Perbelanjaan Harian',
      subtitle: 'Catatan perbelanjaan barang dapur, makan, bil',
      total: plan.totalExpenses,
      items: plan.monthlyExpenses,
      showAddForm: _showAddExpense,
      withCategory: true,
      onToggleAdd: () => setState(() => _showAddExpense = !_showAddExpense),
      onAddWithCategory: (name, amount, category) async {
        final updated = await widget.apiService
            .addExpense(widget.user.userId, name, amount, category);
        if (!mounted) return;
        setState(() {
          _plan = updated;
          _showAddExpense = false;
        });
      },
      onDelete: (id) async {
        final updated =
            await widget.apiService.deleteExpense(widget.user.userId, id);
        if (!mounted) return;
        setState(() => _plan = updated);
      },
    );
  }

  Widget _buildSmartSuggestionsCard(BudgetPlan plan) {
    if (plan.suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline,
                  color: Color(0xFFD79A3B), size: 20),
              SizedBox(width: 8),
              Text('Cadangan & Amaran Kewangan Pintar',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5)),
            ],
          ),
          const SizedBox(height: 12),
          ...plan.suggestions.map((s) {
            final isFoodWarning = s.contains('makanan');
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFoodWarning
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFoodWarning
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s,
                      style: const TextStyle(fontSize: 12.5, height: 1.4)),
                  if (isFoodWarning && widget.onNavigateTab != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => widget.onNavigateTab!(1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.storefront, size: 14),
                          label: const Text('Lihat Jualan Rahmah',
                              style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => widget.onNavigateTab!(0),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.inventory_2, size: 14),
                          label: const Text('Pusat MyKasih',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  int daysLeftInMonth() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final left = lastDay - now.day;
    return left <= 0 ? 1 : left;
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
      ],
    );
  }
}

class _IncomeManagementCard extends StatefulWidget {
  const _IncomeManagementCard({
    required this.totalIncome,
    required this.incomes,
    required this.showAddForm,
    required this.onToggleAdd,
    required this.onAddIncome,
    required this.onDeleteIncome,
  });

  final double totalIncome;
  final List<IncomeItem> incomes;
  final bool showAddForm;
  final VoidCallback onToggleAdd;
  final Function(String source, double amount, String date, bool isRecurring)
      onAddIncome;
  final Function(String id) onDeleteIncome;

  @override
  State<_IncomeManagementCard> createState() => _IncomeManagementCardState();
}

class _IncomeManagementCardState extends State<_IncomeManagementCard> {
  final _sourceController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isRecurring = true;

  @override
  void dispose() {
    _sourceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final src = _sourceController.text.trim();
    final amt = double.tryParse(_amountController.text.trim());
    if (src.isEmpty || amt == null) return;
    widget.onAddIncome(
      src,
      amt,
      DateFormat('yyyy-MM-dd').format(DateTime.now()),
      _isRecurring,
    );
    _sourceController.clear();
    _amountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sumber Pendapatan Bulanan (RM${widget.totalIncome.toStringAsFixed(0)})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Text('Gaji hakiki, kerja sambilan, bantuan',
                      style:
                          TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
              InkWell(
                onTap: widget.onToggleAdd,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.showAddForm ? Icons.close : Icons.add,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (widget.showAddForm) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _sourceController,
                    decoration: const InputDecoration(
                      hintText: 'Sumber (Cth: Gaji Pokok, Grab, Elaun)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'Jumlah (RM)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _isRecurring,
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setState(() => _isRecurring = v ?? true),
                      ),
                      const Text('Pendapatan Tetap Bulanan (Berulang)',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Tambah Pendapatan'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onToggleAdd,
                          child: const Text('Batal'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...widget.incomes.map((inc) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inc.source,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            inc.isRecurring ? 'Bulanan Berulang' : 'Sekali Sahaja',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+RM${inc.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.textMuted),
                      onPressed: () => widget.onDeleteIncome(inc.id),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _SetBudgetInlineForm extends StatefulWidget {
  const _SetBudgetInlineForm({required this.onSave});
  final Function(String category, double amount) onSave;

  @override
  State<_SetBudgetInlineForm> createState() => _SetBudgetInlineFormState();
}

class _SetBudgetInlineFormState extends State<_SetBudgetInlineForm> {
  String _category = 'Makanan & Minuman';
  final _controller = TextEditingController();

  static const categories = [
    'Makanan & Minuman',
    'Pengangkutan',
    'Utiliti',
    'Kesihatan',
    'Lain-lain'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _category,
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(hintText: 'Had Bajet Bulanan (RM)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_controller.text.trim());
              if (val != null) widget.onSave(_category, val);
            },
            child: const Text('Simpan Had Bajet'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseListCard extends StatefulWidget {
  const _ExpenseListCard({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.items,
    required this.showAddForm,
    required this.onToggleAdd,
    required this.onDelete,
    this.withCategory = false,
    this.onAdd,
    this.onAddWithCategory,
  });

  final String title;
  final String subtitle;
  final double total;
  final List<ExpenseItem> items;
  final bool showAddForm;
  final bool withCategory;
  final VoidCallback onToggleAdd;
  final Future<void> Function(String name, double amount)? onAdd;
  final Future<void> Function(String name, double amount, String category)?
      onAddWithCategory;
  final Future<void> Function(String id) onDelete;

  @override
  State<_ExpenseListCard> createState() => _ExpenseListCardState();
}

class _ExpenseListCardState extends State<_ExpenseListCard> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'Makanan & Minuman';

  static const categories = [
    'Makanan & Minuman',
    'Pengangkutan',
    'Utiliti',
    'Kesihatan',
    'Lain-lain'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (name.isEmpty || amount == null) return;
    if (widget.withCategory) {
      await widget.onAddWithCategory?.call(name, amount, _category);
    } else {
      await widget.onAdd?.call(name, amount);
    }
    _nameController.clear();
    _amountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.title} (RM${widget.total.toStringAsFixed(0)})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(widget.subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
              InkWell(
                onTap: widget.onToggleAdd,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.showAddForm ? Icons.close : Icons.add,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (widget.showAddForm) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: widget.withCategory
                          ? 'Nama perbelanjaan'
                          : 'Nama komitmen tetap',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'Jumlah (RM)'),
                  ),
                  if (widget.withCategory) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _category,
                      items: categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Simpan'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onToggleAdd,
                          child: const Text('Batal'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          ...widget.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: const TextStyle(fontSize: 13)),
                          if (item.category != null)
                            Text(item.category!,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Text('RM${item.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.textMuted),
                      onPressed: () => widget.onDelete(item.id),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
