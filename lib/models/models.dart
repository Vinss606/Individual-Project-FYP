import 'package:flutter/material.dart';

/// Logged-in user returned by POST /auth/login
class AppUser {
  final String userId;
  final String name;
  final String icNumber;
  final String role; // "user" | "admin"
  final String token;

  AppUser({
    required this.userId,
    required this.name,
    required this.icNumber,
    this.role = 'user',
    required this.token,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        userId: json['user_id'] as String,
        name: json['name'] as String,
        icNumber: json['ic_number'] as String,
        role: (json['role'] as String?) ?? 'user',
        token: json['token'] as String,
      );
}

/// 4 Verification Statuses
class VerificationStatusHelper {
  static const String verified = 'VERIFIED';
  static const String pending = 'PENDING_REVIEW';
  static const String notVerified = 'NOT_VERIFIED';
  static const String expired = 'EXPIRED';

  static String getLabel(String status) {
    switch (status.toUpperCase()) {
      case verified:
        return 'Disahkan Rasmi';
      case pending:
        return 'Dalam Semakan';
      case notVerified:
        return 'Tidak Sah';
      case expired:
        return 'Telah Berakhir';
      default:
        return status;
    }
  }

  static Color getBadgeColor(String status) {
    switch (status.toUpperCase()) {
      case verified:
        return const Color(0xFF059669); // Emerald Green
      case pending:
        return const Color(0xFFD97706); // Amber
      case notVerified:
        return const Color(0xFFDC2626); // Red
      case expired:
        return const Color(0xFF4B5563); // Gray
      default:
        return const Color(0xFF6B7280);
    }
  }

  static Color getBadgeBgColor(String status) {
    switch (status.toUpperCase()) {
      case verified:
        return const Color(0xFFD1FAE5);
      case pending:
        return const Color(0xFFFEF3C7);
      case notVerified:
        return const Color(0xFFFEE2E2);
      case expired:
        return const Color(0xFFF3F4F6);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  static IconData getBadgeIcon(String status) {
    switch (status.toUpperCase()) {
      case verified:
        return Icons.verified;
      case pending:
        return Icons.pending_outlined;
      case notVerified:
        return Icons.cancel_outlined;
      case expired:
        return Icons.event_busy;
      default:
        return Icons.help_outline;
    }
  }
}

/// A MyKasih distribution point / participating merchant.
class MyKasihLocation {
  final String id;
  final String name;
  final String address;
  final String state;
  final String district;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int quotaTotal;
  final int quotaRemaining;
  final List<String> items;
  final String verificationStatus;
  final String sourceName;
  final String sourceUrl;
  final String lastVerified;

  MyKasihLocation({
    required this.id,
    required this.name,
    required this.address,
    this.state = 'Pulau Pinang',
    this.district = 'Seberang Perai',
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.quotaTotal,
    required this.quotaRemaining,
    required this.items,
    this.distanceKm,
    this.verificationStatus = 'VERIFIED',
    this.sourceName = 'Yayasan MyKasih / Rakan Niaga SARA',
    this.sourceUrl = 'https://www.mykasih.com.my/ms/about-us/merchant-partners/',
    this.lastVerified = '2026-09-10',
  });

  factory MyKasihLocation.fromJson(Map<String, dynamic> json) =>
      MyKasihLocation(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        state: (json['state'] as String?) ?? 'Pulau Pinang',
        district: (json['district'] as String?) ?? 'Seberang Perai',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceKm: json['distance_km'] == null
            ? null
            : (json['distance_km'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        quotaTotal: json['quota_total'] as int,
        quotaRemaining: json['quota_remaining'] as int,
        items: List<String>.from(json['items'] as List? ?? []),
        verificationStatus:
            (json['verification_status'] as String?) ?? 'VERIFIED',
        sourceName:
            (json['source_name'] as String?) ?? 'Yayasan MyKasih / Rakan Niaga SARA',
        sourceUrl:
            (json['source_url'] as String?) ?? 'https://www.mykasih.com.my/ms/about-us/merchant-partners/',
        lastVerified: (json['last_verified'] as String?) ?? '2026-09-10',
      );
}

/// A price item inside a Jualan Rahmah Madani listing.
class PriceItem {
  final String name;
  final double controlledPrice;
  final double marketPrice;

  PriceItem({
    required this.name,
    required this.controlledPrice,
    required this.marketPrice,
  });

  double get savings => (marketPrice - controlledPrice).clamp(0, double.infinity);

  double get discountPercent =>
      marketPrice > 0 ? ((marketPrice - controlledPrice) / marketPrice) * 100 : 0;

  factory PriceItem.fromJson(Map<String, dynamic> json) => PriceItem(
        name: json['name'] as String,
        controlledPrice: (json['controlled_price'] as num).toDouble(),
        marketPrice: (json['market_price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'controlled_price': controlledPrice,
        'market_price': marketPrice,
      };
}

/// A Jualan Rahmah Madani sale event.
class JualanRahmahListing {
  final String id;
  final String name;
  final String organiser;
  final String address;
  final String state;
  final String district;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int targetFamilies;
  final List<PriceItem> priceList;
  final String verificationStatus;
  final String sourceName;
  final String sourceUrl;
  final String lastVerified;
  final double? matchScore;
  final bool rescheduled;
  final String? officialDate;

  JualanRahmahListing({
    required this.id,
    required this.name,
    required this.organiser,
    required this.address,
    this.state = 'Pulau Pinang',
    this.district = 'Seberang Perai',
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.targetFamilies,
    required this.priceList,
    this.distanceKm,
    this.verificationStatus = 'VERIFIED',
    this.sourceName = 'Portal Rasmi PJRM (KPDN)',
    this.sourceUrl = 'https://pjrm.kpdn.gov.my/',
    this.lastVerified = '2026-09-10',
    this.matchScore = 100.0,
    this.rescheduled = false,
    this.officialDate,
  });

  bool get isExpired =>
      verificationStatus == 'EXPIRED' ||
      date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  factory JualanRahmahListing.fromJson(Map<String, dynamic> json) =>
      JualanRahmahListing(
        id: json['id'] as String,
        name: json['name'] as String,
        organiser: json['organiser'] as String,
        address: json['address'] as String,
        state: (json['state'] as String?) ?? 'Pulau Pinang',
        district: (json['district'] as String?) ?? 'Seberang Perai',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceKm: json['distance_km'] == null
            ? null
            : (json['distance_km'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        targetFamilies: json['target_families'] as int,
        priceList: (json['price_list'] as List? ?? [])
            .map((e) => PriceItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        verificationStatus:
            (json['verification_status'] as String?) ?? 'VERIFIED',
        sourceName:
            (json['source_name'] as String?) ?? 'Portal Rasmi PJRM (KPDN)',
        sourceUrl:
            (json['source_url'] as String?) ?? 'https://pjrm.kpdn.gov.my/',
        lastVerified: (json['last_verified'] as String?) ?? '2026-09-10',
        matchScore: json['match_score'] == null
            ? null
            : (json['match_score'] as num).toDouble(),
        rescheduled: (json['rescheduled'] as bool?) ?? false,
        officialDate: json['official_date'] as String?,
      );
}

/// An income line item (supports recurring and side incomes).
class IncomeItem {
  final String id;
  final String source;
  final double amount;
  final String date;
  final bool isRecurring;

  IncomeItem({
    required this.id,
    required this.source,
    required this.amount,
    required this.date,
    this.isRecurring = true,
  });

  factory IncomeItem.fromJson(Map<String, dynamic> json) => IncomeItem(
        id: json['id'] as String,
        source: json['source'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: (json['date'] as String?) ?? '',
        isRecurring: (json['is_recurring'] as bool?) ?? true,
      );
}

/// A single commitment or expense line item.
class ExpenseItem {
  final String id;
  final String name;
  final double amount;
  final String? category;

  ExpenseItem({
    required this.id,
    required this.name,
    required this.amount,
    this.category,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        if (category != null) 'category': category,
      };
}

/// Category Budget with utilisation rate.
class CategoryBudget {
  final String category;
  final double budgetAmount;
  final double spentAmount;
  final double utilizationPercent;

  CategoryBudget({
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.utilizationPercent,
  });

  bool get isOverBudget => spentAmount > budgetAmount && budgetAmount > 0;
  bool get isNearLimit => utilizationPercent >= 80 && !isOverBudget;

  factory CategoryBudget.fromJson(Map<String, dynamic> json) => CategoryBudget(
        category: json['category'] as String,
        budgetAmount: (json['budget_amount'] as num).toDouble(),
        spentAmount: (json['spent_amount'] as num).toDouble(),
        utilizationPercent: (json['utilization_percent'] as num).toDouble(),
      );
}

/// Full budget plan including multi-source income, disposable income, and budgets.
class BudgetPlan {
  final double monthlySalary;
  final List<IncomeItem> incomes;
  final double totalIncome;
  final List<ExpenseItem> commitments;
  final double totalCommitments;
  final double disposableIncome;
  final List<ExpenseItem> monthlyExpenses;
  final double totalExpenses;
  final double balance;
  final List<CategoryBudget> categoryBudgets;
  final List<String> suggestions;

  BudgetPlan({
    required this.monthlySalary,
    required this.incomes,
    required this.totalIncome,
    required this.commitments,
    required this.totalCommitments,
    required this.disposableIncome,
    required this.monthlyExpenses,
    required this.totalExpenses,
    required this.balance,
    required this.categoryBudgets,
    required this.suggestions,
  });

  double get totalSpent => totalCommitments + totalExpenses;

  double get usagePercent =>
      totalIncome <= 0 ? 0 : ((totalSpent / totalIncome).clamp(0, 1)) * 100;

  /// Groups monthlyExpenses by category for the donut chart.
  Map<String, double> get byCategory {
    final map = <String, double>{};
    for (final e in monthlyExpenses) {
      final key = e.category ?? 'Lain-lain';
      map[key] = (map[key] ?? 0) + e.amount;
    }
    return map;
  }

  factory BudgetPlan.fromJson(Map<String, dynamic> json) {
    final incomesList = (json['incomes'] as List? ?? [])
        .map((e) => IncomeItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final commitmentsList = (json['commitments'] as List? ?? [])
        .map((e) => ExpenseItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final expensesList = (json['monthly_expenses'] as List? ?? [])
        .map((e) => ExpenseItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final catBudgetsList = (json['category_budgets'] as List? ?? [])
        .map((e) => CategoryBudget.fromJson(e as Map<String, dynamic>))
        .toList();

    return BudgetPlan(
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble() ?? 0.0,
      incomes: incomesList,
      totalIncome: (json['total_income'] as num?)?.toDouble() ??
          (json['monthly_salary'] as num?)?.toDouble() ??
          0.0,
      commitments: commitmentsList,
      totalCommitments: (json['total_commitments'] as num?)?.toDouble() ??
          commitmentsList.fold(0.0, (sum, c) => sum + c.amount),
      disposableIncome: (json['disposable_income'] as num?)?.toDouble() ?? 0.0,
      monthlyExpenses: expensesList,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ??
          expensesList.fold(0.0, (sum, e) => sum + e.amount),
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      categoryBudgets: catBudgetsList,
      suggestions: List<String>.from(json['suggestions'] as List? ?? []),
    );
  }
}

/// In-app Notification model.
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // "BUDGET_WARNING" | "SCHEDULE_UPDATE" | "RESOURCE_ALERT" | "INFO"
  final String createdAt;
  final bool isRead;
  final String? actionRoute;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.actionRoute,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        userId: (json['user_id'] as String?) ?? '',
        title: json['title'] as String,
        message: json['message'] as String,
        type: (json['type'] as String?) ?? 'INFO',
        createdAt: (json['created_at'] as String?) ?? '',
        isRead: (json['is_read'] as bool?) ?? false,
        actionRoute: json['action_route'] as String?,
      );
}

/// Official Source Verification Score Report.
class VerificationReport {
  final String status;
  final double score;
  final String source;
  final String? sourceUrl;
  final String lastVerified;
  final String details;
  final Map<String, dynamic> breakdown;
  final bool rescheduled;
  final String? officialDate;

  VerificationReport({
    required this.status,
    required this.score,
    required this.source,
    this.sourceUrl,
    required this.lastVerified,
    required this.details,
    required this.breakdown,
    this.rescheduled = false,
    this.officialDate,
  });

  factory VerificationReport.fromJson(Map<String, dynamic> json) =>
      VerificationReport(
        status: json['status'] as String,
        score: (json['score'] as num).toDouble(),
        source: json['source'] as String,
        sourceUrl: json['source_url'] as String?,
        lastVerified: json['last_verified'] as String,
        details: json['details'] as String,
        breakdown: Map<String, dynamic>.from(json['breakdown'] as Map? ?? {}),
        rescheduled: (json['rescheduled'] as bool?) ?? false,
        officialDate: json['official_date'] as String?,
      );
}
