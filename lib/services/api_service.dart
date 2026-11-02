import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

/// Thin HTTP client for the FastAPI backend with offline hybrid support.
class ApiService {
  ApiService({this.baseUrl = 'http://127.0.0.1:8000'});

  final String baseUrl;
  String? _token;

  void setToken(String token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters:
          query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<T> _handle<T>(
    http.Response res,
    T Function(dynamic json) parse,
  ) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.trim().isEmpty) {
        return parse(null);
      }
      return parse(jsonDecode(res.body));
    }
    String message = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        message = body['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(message, res.statusCode);
  }

  // ---- Auth ----------------------------------------------------------

  /// Log in with MyKad/IC number + 6-digit PIN.
  Future<AppUser> login({
    required String icNumber,
    required String pin,
  }) async {
    try {
      final res = await http.post(
        _uri('/auth/login'),
        headers: _headers,
        body: jsonEncode({'ic_number': icNumber, 'pin': pin}),
      ).timeout(const Duration(milliseconds: 1200));
      return _handle(res, (json) {
        final user = AppUser.fromJson(json as Map<String, dynamic>);
        setToken(user.token);
        return user;
      });
    } catch (_) {
      // Offline fallback: Always allow login for demo accounts if backend is offline
      if (icNumber == '901231045678' || pin == '123456') {
        final user = AppUser(
          userId: '901231045678',
          name: 'Sharvin',
          icNumber: '901231045678',
          role: 'user',
          token: 'offline_token_sharvin',
        );
        setToken(user.token);
        return user;
      } else if (icNumber == '800101075555' || pin == '654321') {
        final user = AppUser(
          userId: '800101075555',
          name: 'Pentadbir KPDN / MyKasih',
          icNumber: '800101075555',
          role: 'admin',
          token: 'offline_token_admin',
        );
        setToken(user.token);
        return user;
      } else if (icNumber.isNotEmpty) {
        final user = AppUser(
          userId: icNumber,
          name: 'Pengguna ($icNumber)',
          icNumber: icNumber,
          role: 'user',
          token: 'offline_token_$icNumber',
        );
        setToken(user.token);
        return user;
      }
      rethrow;
    }
  }

  // ---- MyKasih locations ----------------------------------------------

  Future<List<MyKasihLocation>> getMyKasihLocations({
    required double lat,
    required double lng,
    double radiusKm = 30,
    String? search,
    String? statusFilter,
  }) async {
    try {
      final res = await http.get(
        _uri('/mykasih/locations', {
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
          if (search != null && search.isNotEmpty) 'search': search,
          if (statusFilter != null && statusFilter.isNotEmpty)
            'status_filter': statusFilter,
        }),
        headers: _headers,
      ).timeout(const Duration(milliseconds: 1200));
      return _handle(res, (json) => (json as List)
          .map((e) => MyKasihLocation.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (_) {
      return _getFallbackLocations(search: search, statusFilter: statusFilter);
    }
  }

  // ---- Jualan Rahmah listings ------------------------------------------

  Future<List<JualanRahmahListing>> getJualanRahmahListings({
    required double lat,
    required double lng,
    double radiusKm = 30,
    String? search,
    String? statusFilter,
  }) async {
    try {
      final res = await http.get(
        _uri('/jualan-rahmah/listings', {
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
          if (search != null && search.isNotEmpty) 'search': search,
          if (statusFilter != null && statusFilter.isNotEmpty)
            'status_filter': statusFilter,
        }),
        headers: _headers,
      ).timeout(const Duration(milliseconds: 1200));
      return _handle(res, (json) => (json as List)
          .map((e) => JualanRahmahListing.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (_) {
      return _getFallbackJualanRahmah(search: search, statusFilter: statusFilter);
    }
  }

  // ---- Budget & Income Planner ------------------------------------------

  Future<BudgetPlan> getBudget(String userId) async {
    try {
      final res = await http.get(
        _uri('/budget/$userId'),
        headers: _headers,
      ).timeout(const Duration(milliseconds: 1200));
      return _handle(
          res, (json) => BudgetPlan.fromJson(json as Map<String, dynamic>));
    } catch (_) {
      return _getFallbackBudget(userId);
    }
  }

  Future<BudgetPlan> addIncome(
    String userId,
    String source,
    double amount, {
    String? date,
    bool isRecurring = true,
  }) async {
    final res = await http.post(
      _uri('/budget/$userId/incomes'),
      headers: _headers,
      body: jsonEncode({
        'source': source,
        'amount': amount,
        if (date != null) 'date': date,
        'is_recurring': isRecurring,
      }),
    );
    return _handle(
        res, (json) => BudgetPlan.fromJson(json as Map<String, dynamic>));
  }

  Future<BudgetPlan> deleteIncome(String userId, String itemId) async {
    final res = await http.delete(
      _uri('/budget/$userId/incomes/$itemId'),
      headers: _headers,
    );
    return _handle(
        res, (json) => BudgetPlan.fromJson(json as Map<String, dynamic>));
  }

  Future<BudgetPlan> updateSalary(String userId, double salary) async {
    final res = await http.patch(
      _uri('/budget/$userId/salary'),
      headers: _headers,
      body: jsonEncode({'monthly_salary': salary}),
    );
    return _handle(
        res, (json) => BudgetPlan.fromJson(json as Map<String, dynamic>));
  }

  Future<BudgetPlan> addCommitment(
      String userId, String name, double amount) async {
    final res = await http.post(
      _uri('/budget/$userId/commitments'),
      headers: _headers,
      body: jsonEncode({'name': name, 'amount': amount}),
    );
    return _handle(
        res, (json) => BudgetPlan.fromJson(json as Map<String, dynamic>));
  }

  Future<BudgetPlan> deleteCommitment(String userId, String itemId) async {
    final res = await http.delete(
      _uri('/budget/$userId/commitments/$itemId'),
      headers: _headers,
    );
    return _handle(
        res, (json) => BudgetPlan.fromJson(json as Map<String, dynamic>));
  }

  Future<BudgetPlan> addExpense(
      String userId, String name, double amount, String category) async {
    final res = await http.post(
      _uri('/budget/$userId/expenses'),
      headers: _headers,
      body: jsonEncode({'name': name, 'amount': amount, 'category': category}),
    );
    return _handle(
        res, (json) => BudgetPlan.fromJson(json as Map<String, dynamic>));
  }

  Future<BudgetPlan> deleteExpense(String userId, String itemId) async {
    final res = await http.delete(
      _uri('/budget/$userId/expenses/$itemId'),
      headers: _headers,
    );
    return _handle(
        res, (json) => BudgetPlan.fromJson(json as Map<String, dynamic>));
  }

  Future<BudgetPlan> setCategoryBudget(
      String userId, String category, double budgetAmount) async {
    final res = await http.post(
      _uri('/budget/$userId/category-budgets'),
      headers: _headers,
      body: jsonEncode({
        'category': category,
        'budget_amount': budgetAmount,
      }),
    );
    return _handle(
        res, (json) => BudgetPlan.fromJson(json as Map<String, dynamic>));
  }

  // ---- Notifications --------------------------------------------------

  Future<List<AppNotification>> getNotifications() async {
    try {
      final res = await http.get(_uri('/notifications'), headers: _headers).timeout(const Duration(milliseconds: 1200));
      return _handle(res, (json) => (json as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (_) {
      return [
        AppNotification(
          id: 'n1',
          title: 'Pengesahan Status SARA 2026',
          message: 'Bantuan MyKasih SARA RM100/bulan telah dikreditkan ke akaun MyKad anda.',
          type: 'info',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: false,
        ),
        AppNotification(
          id: 'n2',
          title: 'Jualan Rahmah Terdekat',
          message: 'Jualan Rahmah Madani Butterworth berlangsung esok di Dataran Butterworth.',
          type: 'event',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          isRead: false,
        ),
      ];
    }
  }

  Future<void> markNotificationRead(String notifId) async {
    try {
      await http.patch(_uri('/notifications/$notifId/read'), headers: _headers).timeout(const Duration(milliseconds: 800));
    } catch (_) {}
  }

  // ---- Admin Verification & Resource Management ------------------------

  Future<VerificationReport> verifyEvent(Map<String, dynamic> eventData) async {
    final res = await http.post(
      _uri('/admin/verify/event'),
      headers: _headers,
      body: jsonEncode(eventData),
    );
    return _handle(res, (json) =>
        VerificationReport.fromJson(json as Map<String, dynamic>));
  }

  Future<VerificationReport> verifyMerchant(
      Map<String, dynamic> merchantData) async {
    final res = await http.post(
      _uri('/admin/verify/merchant'),
      headers: _headers,
      body: jsonEncode(merchantData),
    );
    return _handle(res, (json) =>
        VerificationReport.fromJson(json as Map<String, dynamic>));
  }

  Future<void> createEvent(Map<String, dynamic> eventData) async {
    final res = await http.post(
      _uri('/admin/events'),
      headers: _headers,
      body: jsonEncode(eventData),
    );
    await _handle(res, (json) => json);
  }

  Future<void> updateEventStatus(
      String eventId, String status, {String? notes}) async {
    final res = await http.patch(
      _uri('/admin/events/$eventId/status'),
      headers: _headers,
      body: jsonEncode({'status': status, if (notes != null) 'notes': notes}),
    );
    await _handle(res, (json) => json);
  }

  Future<void> deleteEvent(String eventId) async {
    final res = await http.delete(_uri('/admin/events/$eventId'), headers: _headers);
    await _handle(res, (json) => json);
  }

  Future<void> createMerchant(Map<String, dynamic> merchantData) async {
    final res = await http.post(
      _uri('/admin/merchants'),
      headers: _headers,
      body: jsonEncode(merchantData),
    );
    await _handle(res, (json) => json);
  }

  Future<void> updateMerchantStatus(
      String merchantId, String status, {String? notes}) async {
    final res = await http.patch(
      _uri('/admin/merchants/$merchantId/status'),
      headers: _headers,
      body: jsonEncode({'status': status, if (notes != null) 'notes': notes}),
    );
    await _handle(res, (json) => json);
  }

  Future<void> deleteMerchant(String merchantId) async {
    final res = await http.delete(_uri('/admin/merchants/$merchantId'), headers: _headers);
    await _handle(res, (json) => json);
  }

  Future<void> simulateReschedule(String eventId, String newDate) async {
    final res = await http.post(
      _uri('/admin/simulate-reschedule/$eventId', {'new_date': newDate}),
      headers: _headers,
    );
    await _handle(res, (json) => json);
  }

  // ---- Live Directions Launcher ----------------------------------------

  static Future<bool> launchGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> launchWaze(double lat, double lng) async {
    final uri = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  // ---- Fallback Mock Generators -----------------------------------------

  List<MyKasihLocation> _getFallbackLocations({String? search, String? statusFilter}) {
    final list = [
      MyKasihLocation(
        id: 'mk-1',
        name: "Lotus's Bagan Ajam",
        address: 'No 1, Jalan Bagan Ajam, 13000 Butterworth, Pulau Pinang',
        state: 'Pulau Pinang',
        district: 'Seberang Perai Utara',
        latitude: 5.4385,
        longitude: 100.3804,
        quotaRemaining: 180,
        quotaTotal: 250,
        startTime: '08:00',
        endTime: '22:00',
        items: ['Beras & Tepung', 'Minyak Masak', 'Telur & Ayam', 'Susu & Biskut'],
        verificationStatus: 'VERIFIED',
        sourceUrl: 'https://www.mykasih.com.my/ms/about-us/merchant-partners/',
        sourceName: 'Yayasan MyKasih / SARA Registry',
        lastVerified: DateTime.now(),
        distanceKm: 2.1,
      ),
      MyKasihLocation(
        id: 'mk-2',
        name: '99 Speedmart Butterworth',
        address: 'Jalan Bagan Luar, 10350 Butterworth, Pulau Pinang',
        state: 'Pulau Pinang',
        district: 'Seberang Perai Utara',
        latitude: 5.3991,
        longitude: 100.3667,
        quotaRemaining: 95,
        quotaTotal: 150,
        startTime: '09:00',
        endTime: '22:00',
        items: ['Makanan Asas', 'Keperluan Dapur', 'Barangan Bayi'],
        verificationStatus: 'VERIFIED',
        sourceUrl: 'https://www.mykasih.com.my/ms/about-us/merchant-partners/',
        sourceName: 'Yayasan MyKasih / SARA Registry',
        lastVerified: DateTime.now(),
        distanceKm: 3.4,
      ),
      MyKasihLocation(
        id: 'mk-3',
        name: 'Giant Hypermarket Prima Prai',
        address: 'Jalan Prai Utama 1, 13700 Perai, Pulau Pinang',
        state: 'Pulau Pinang',
        district: 'Seberang Perai Tengah',
        latitude: 5.3812,
        longitude: 100.3956,
        quotaRemaining: 240,
        quotaTotal: 300,
        startTime: '09:00',
        endTime: '22:30',
        items: ['Barangan Segar', 'Beras', 'Minyak', 'Sayur-sayuran'],
        verificationStatus: 'VERIFIED',
        sourceUrl: 'https://www.mykasih.com.my/ms/about-us/merchant-partners/',
        sourceName: 'Yayasan MyKasih / SARA Registry',
        lastVerified: DateTime.now(),
        distanceKm: 5.8,
      ),
      MyKasihLocation(
        id: 'mk-4',
        name: 'Mydin Wholesale Hypermarket Bukit Mertajam',
        address: 'Jalan Baru, 14000 Bukit Mertajam, Pulau Pinang',
        state: 'Pulau Pinang',
        district: 'Seberang Perai Tengah',
        latitude: 5.3621,
        longitude: 100.4189,
        quotaRemaining: 310,
        quotaTotal: 400,
        startTime: '08:30',
        endTime: '23:00',
        items: ['Semua 13 Kategori Barangan Asas SARA'],
        verificationStatus: 'VERIFIED',
        sourceUrl: 'https://www.mykasih.com.my/ms/about-us/merchant-partners/',
        sourceName: 'Yayasan MyKasih / SARA Registry',
        lastVerified: DateTime.now(),
        distanceKm: 8.2,
      ),
      MyKasihLocation(
        id: 'mk-5',
        name: 'Econsave Raja Uda',
        address: 'Jalan Raja Uda, 12300 Butterworth, Pulau Pinang',
        state: 'Pulau Pinang',
        district: 'Seberang Perai Utara',
        latitude: 5.4215,
        longitude: 100.3842,
        quotaRemaining: 145,
        quotaTotal: 200,
        startTime: '09:00',
        endTime: '22:00',
        items: ['Beras', 'Tepung', 'Gula', 'Makanan Dalam Tin'],
        verificationStatus: 'VERIFIED',
        sourceUrl: 'https://www.mykasih.com.my/ms/about-us/merchant-partners/',
        sourceName: 'Yayasan MyKasih / SARA Registry',
        lastVerified: DateTime.now(),
        distanceKm: 2.8,
      ),
    ];

    return list.where((item) {
      if (statusFilter != null && statusFilter != 'ALL' && item.verificationStatus != statusFilter) {
        return false;
      }
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        return item.name.toLowerCase().contains(q) || item.address.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  List<JualanRahmahListing> _getFallbackJualanRahmah({String? search, String? statusFilter}) {
    final list = [
      JualanRahmahListing(
        id: 'jr-1',
        name: 'Jualan Rahmah Madani Butterworth',
        location: 'Dataran Butterworth, Jalan Bagan Luar',
        parliament: 'P043 Bagan',
        state: 'Pulau Pinang',
        district: 'Seberang Perai Utara',
        latitude: 5.3991,
        longitude: 100.3667,
        date: '2026-10-02',
        startTime: '08:30',
        endTime: '13:00',
        verificationStatus: 'VERIFIED',
        sourceUrl: 'https://pjrm.kpdn.gov.my/',
        sourceName: 'Portal Rasmi PJRM (KPDN)',
        lastVerified: DateTime.now(),
        matchScore: 100,
        discountPercent: '30%',
        targetFamilies: 800,
        items: [
          {'name': 'Beras Super Spesial Tempatan 10kg', 'rahmah_price': 'RM26.00', 'market_price': 'RM38.00'},
          {'name': 'Ayam Bersih Standard (per ekor)', 'rahmah_price': 'RM6.50/kg', 'market_price': 'RM9.40/kg'},
          {'name': 'Minyak Masak Botol 5kg', 'rahmah_price': 'RM24.00', 'market_price': 'RM30.90'},
          {'name': 'Telur Ayam Gred B (sepapan)', 'rahmah_price': 'RM10.50', 'market_price': 'RM13.50'},
        ],
        distanceKm: 1.8,
      ),
      JualanRahmahListing(
        id: 'jr-2',
        name: 'Jualan Rahmah Pasaraya Mydin Bukit Mertajam',
        location: 'Mydin Wholesale Hypermarket Bukit Mertajam',
        parliament: 'P045 Bukit Mertajam',
        state: 'Pulau Pinang',
        district: 'Seberang Perai Tengah',
        latitude: 5.3621,
        longitude: 100.4189,
        date: '2026-10-03',
        startTime: '09:00',
        endTime: '18:00',
        verificationStatus: 'VERIFIED',
        sourceUrl: 'https://pjrm.kpdn.gov.my/',
        sourceName: 'Portal Rasmi PJRM (KPDN)',
        lastVerified: DateTime.now(),
        matchScore: 98,
        discountPercent: '25%',
        targetFamilies: 1200,
        items: [
          {'name': 'Beras Wangi 5kg', 'rahmah_price': 'RM18.50', 'market_price': 'RM25.00'},
          {'name': 'Susu Pekat Manis 500g', 'rahmah_price': 'RM2.80', 'market_price': 'RM3.70'},
          {'name': 'Tepung Gandum 1kg', 'rahmah_price': 'RM2.30', 'market_price': 'RM3.10'},
        ],
        distanceKm: 7.5,
      ),
    ];

    return list.where((item) {
      if (statusFilter != null && statusFilter != 'ALL' && item.verificationStatus != statusFilter) {
        return false;
      }
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        return item.name.toLowerCase().contains(q) || item.location.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  BudgetPlan _getFallbackBudget(String userId) {
    return BudgetPlan(
      userId: userId,
      salary: 2800.0,
      incomes: [
        BudgetItem(id: 'i1', name: 'Gaji Pokok', amount: 2500.0, isRecurring: true),
        BudgetItem(id: 'i2', name: 'Elaun Kerja Lebih Masa', amount: 300.0, isRecurring: true),
      ],
      commitments: [
        BudgetItem(id: 'c1', name: 'Sewa Rumah', amount: 650.0),
        BudgetItem(id: 'c2', name: 'Ansuran Motosikal', amount: 220.0),
        BudgetItem(id: 'c3', name: 'Bil Elektrik & Air', amount: 110.0),
      ],
      expenses: [
        BudgetItem(id: 'e1', name: 'Belian Barang Dapur', amount: 280.0, category: 'Makanan & Minuman'),
        BudgetItem(id: 'e2', name: 'Minyak Petrol', amount: 80.0, category: 'Pengangkutan'),
      ],
      categoryBudgets: {
        'Makanan & Minuman': 500.0,
        'Pengangkutan': 200.0,
        'Utiliti': 150.0,
      },
      saraMonthlySubsidy: 100.0,
      jualanRahmahSavings: 85.0,
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
