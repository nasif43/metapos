/// Dashboard model representing metrics returned by Odoo 19 `book.fair.dashboard`.
class DashboardModel {
  final double revenue;
  final int orders;
  final int bookCopies;
  final int titles;
  final double avgBasket;
  final double discounts;
  final int customers;
  final double booksPerOrder;
  final List<HourlyStat> hourly;
  final List<DailyStat> daily;
  final int openSessions;
  final int totalCatalogBooks;

  // Rich Odoo Telemetry details
  final double revenueUntaxed;
  final double refunds;
  final List<DashboardPaymentStat> payments;
  final List<DashboardTopTitle> topTitles;
  final List<DashboardGenreStat> genres;
  final List<DashboardSessionStat> sessions;
  final double previousRevenue;
  final int previousOrders;
  final double previousAvgBasket;
  final double previousDiscounts;

  const DashboardModel({
    required this.revenue,
    required this.orders,
    required this.bookCopies,
    required this.titles,
    required this.avgBasket,
    required this.discounts,
    required this.customers,
    required this.booksPerOrder,
    this.hourly = const [],
    this.daily = const [],
    this.openSessions = 0,
    this.totalCatalogBooks = 0,
    this.revenueUntaxed = 0.0,
    this.refunds = 0.0,
    this.payments = const [],
    this.topTitles = const [],
    this.genres = const [],
    this.sessions = const [],
    this.previousRevenue = 0.0,
    this.previousOrders = 0,
    this.previousAvgBasket = 0.0,
    this.previousDiscounts = 0.0,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final kpis = (json['kpis'] as Map<String, dynamic>?) ?? {};
    final previous = (json['previous'] as Map<String, dynamic>?) ?? {};
    final catalogue = (json['catalogue'] as Map<String, dynamic>?) ?? {};

    final rawHourly = json['hourly'];
    final List<HourlyStat> parsedHourly = [];
    if (rawHourly is List) {
      for (final item in rawHourly) {
        if (item is Map<String, dynamic>) {
          parsedHourly.add(HourlyStat.fromJson(item));
        }
      }
    }

    final rawDaily = json['daily'];
    final List<DailyStat> parsedDaily = [];
    if (rawDaily is List) {
      for (final item in rawDaily) {
        if (item is Map<String, dynamic>) {
          parsedDaily.add(DailyStat.fromJson(item));
        }
      }
    }

    final rawPayments = json['payments'];
    final List<DashboardPaymentStat> parsedPayments = [];
    if (rawPayments is List) {
      for (final item in rawPayments) {
        if (item is Map<String, dynamic>) {
          parsedPayments.add(DashboardPaymentStat.fromJson(item));
        }
      }
    }

    final rawTopTitles = json['top_titles'];
    final List<DashboardTopTitle> parsedTopTitles = [];
    if (rawTopTitles is List) {
      for (final item in rawTopTitles) {
        if (item is Map<String, dynamic>) {
          parsedTopTitles.add(DashboardTopTitle.fromJson(item));
        }
      }
    }

    final rawGenres = json['genres'];
    final List<DashboardGenreStat> parsedGenres = [];
    if (rawGenres is List) {
      for (final item in rawGenres) {
        if (item is Map<String, dynamic>) {
          parsedGenres.add(DashboardGenreStat.fromJson(item));
        }
      }
    }

    final rawSessions = json['sessions'];
    final List<DashboardSessionStat> parsedSessions = [];
    if (rawSessions is List) {
      for (final item in rawSessions) {
        if (item is Map<String, dynamic>) {
          parsedSessions.add(DashboardSessionStat.fromJson(item));
        }
      }
    }

    return DashboardModel(
      revenue: (kpis['revenue'] as num?)?.toDouble() ?? 0.0,
      orders: (kpis['orders'] as num?)?.toInt() ?? 0,
      bookCopies: (kpis['book_copies'] as num?)?.toInt() ??
          (kpis['copies'] as num?)?.toInt() ??
          0,
      titles: (kpis['titles'] as num?)?.toInt() ?? 0,
      avgBasket: (kpis['avg_basket'] as num?)?.toDouble() ?? 0.0,
      discounts: (kpis['discounts'] as num?)?.toDouble() ?? 0.0,
      customers: (kpis['customers'] as num?)?.toInt() ?? 0,
      booksPerOrder: (kpis['books_per_order'] as num?)?.toDouble() ?? 0.0,
      hourly: parsedHourly,
      daily: parsedDaily,
      openSessions: (json['open_sessions'] as num?)?.toInt() ?? 0,
      totalCatalogBooks: (catalogue['books'] as num?)?.toInt() ?? 0,
      revenueUntaxed: (kpis['revenue_untaxed'] as num?)?.toDouble() ?? 0.0,
      refunds: (kpis['refunds'] as num?)?.toDouble() ?? 0.0,
      payments: parsedPayments,
      topTitles: parsedTopTitles,
      genres: parsedGenres,
      sessions: parsedSessions,
      previousRevenue: (previous['revenue'] as num?)?.toDouble() ?? 0.0,
      previousOrders: (previous['orders'] as num?)?.toInt() ?? 0,
      previousAvgBasket: (previous['avg_basket'] as num?)?.toDouble() ?? 0.0,
      previousDiscounts: (previous['discounts'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory DashboardModel.empty() {
    return const DashboardModel(
      revenue: 0.0,
      orders: 0,
      bookCopies: 0,
      titles: 0,
      avgBasket: 0.0,
      discounts: 0.0,
      customers: 0,
      booksPerOrder: 0.0,
      hourly: [],
      daily: [],
      openSessions: 0,
      totalCatalogBooks: 0,
      revenueUntaxed: 0.0,
      refunds: 0.0,
      payments: [],
      topTitles: [],
      genres: [],
      sessions: [],
      previousRevenue: 0.0,
      previousOrders: 0,
      previousAvgBasket: 0.0,
      previousDiscounts: 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'revenue': revenue,
      'orders': orders,
      'book_copies': bookCopies,
      'titles': titles,
      'avg_basket': avgBasket,
      'discounts': discounts,
      'customers': customers,
      'books_per_order': booksPerOrder,
      'hourly': hourly.map((h) => h.toJson()).toList(),
      'daily': daily.map((d) => d.toJson()).toList(),
      'open_sessions': openSessions,
      'total_catalog_books': totalCatalogBooks,
      'revenue_untaxed': revenueUntaxed,
      'refunds': refunds,
      'payments': payments.map((p) => p.toJson()).toList(),
      'top_titles': topTitles.map((t) => t.toJson()).toList(),
      'genres': genres.map((g) => g.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'previous_revenue': previousRevenue,
      'previous_orders': previousOrders,
      'previous_avg_basket': previousAvgBasket,
      'previous_discounts': previousDiscounts,
    };
  }
}

/// Payment method breakdown from Odoo.
class DashboardPaymentStat {
  final int id;
  final String name;
  final int orders;
  final double amount;

  const DashboardPaymentStat({
    required this.id,
    required this.name,
    required this.orders,
    required this.amount,
  });

  factory DashboardPaymentStat.fromJson(Map<String, dynamic> json) {
    return DashboardPaymentStat(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '') as String,
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'orders': orders,
        'amount': amount,
      };
}

/// Top selling title item from Odoo.
class DashboardTopTitle {
  final int id;
  final String name;
  final String? isbn;
  final String? authors;
  final double qty;
  final double revenue;

  const DashboardTopTitle({
    required this.id,
    required this.name,
    this.isbn,
    this.authors,
    required this.qty,
    required this.revenue,
  });

  factory DashboardTopTitle.fromJson(Map<String, dynamic> json) {
    return DashboardTopTitle(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '') as String,
      isbn: json['isbn'] as String?,
      authors: json['authors'] as String?,
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isbn': isbn,
        'authors': authors,
        'qty': qty,
        'revenue': revenue,
      };
}

/// Genre and category breakdown from Odoo.
class DashboardGenreStat {
  final int id;
  final String name;
  final double qty;
  final double revenue;

  const DashboardGenreStat({
    required this.id,
    required this.name,
    required this.qty,
    required this.revenue,
  });

  factory DashboardGenreStat.fromJson(Map<String, dynamic> json) {
    return DashboardGenreStat(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '') as String,
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'qty': qty,
        'revenue': revenue,
      };
}

/// Active and past POS session metadata from Odoo.
class DashboardSessionStat {
  final int id;
  final String name;
  final String config;
  final String user;
  final String state;
  final String stateLabel;
  final String startAt;
  final int orders;
  final double revenue;

  const DashboardSessionStat({
    required this.id,
    required this.name,
    required this.config,
    required this.user,
    required this.state,
    required this.stateLabel,
    required this.startAt,
    required this.orders,
    required this.revenue,
  });

  factory DashboardSessionStat.fromJson(Map<String, dynamic> json) {
    return DashboardSessionStat(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '') as String,
      config: (json['config'] ?? '') as String,
      user: (json['user'] ?? '') as String,
      state: (json['state'] ?? '') as String,
      stateLabel: (json['state_label'] ?? '') as String,
      startAt: (json['start_at'] ?? '') as String,
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'config': config,
        'user': user,
        'state': state,
        'state_label': stateLabel,
        'start_at': startAt,
        'orders': orders,
        'revenue': revenue,
      };
}

/// Hourly statistic bucket for histogram display.
class HourlyStat {
  final int hour;
  final int orders;
  final double revenue;

  const HourlyStat({
    required this.hour,
    required this.orders,
    required this.revenue,
  });

  factory HourlyStat.fromJson(Map<String, dynamic> json) {
    return HourlyStat(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'orders': orders,
      'revenue': revenue,
    };
  }

  /// Formats hour into 12h/24h string e.g. "13:00" or "1 PM"
  String get hourLabel => '${hour.toString().padLeft(2, '0')}:00';
  String get hourLabelBn {
    final bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    final hStr = hour.toString().padLeft(2, '0');
    return '${hStr.split('').map((d) => bnDigits[int.parse(d)]).join('')}:০০';
  }
}

/// Daily statistic bucket for daily histogram display.
class DailyStat {
  final String day;
  final int orders;
  final double revenue;

  const DailyStat({
    required this.day,
    required this.orders,
    required this.revenue,
  });

  factory DailyStat.fromJson(Map<String, dynamic> json) {
    return DailyStat(
      day: (json['day'] ?? '') as String,
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'orders': orders,
      'revenue': revenue,
    };
  }
}
