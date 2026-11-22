/// MetaPOS bilingual string definitions.
///
/// Bengali (bn) is the PRIMARY language. English (en) is the fallback.
/// Add all UI-visible strings here — never hardcode in widgets.
abstract final class AppStrings {
  // ─── App Shell ───────────────────────────────────────────────────────────
  static const Map<String, String> appName = {'bn': 'মেটাপস', 'en': 'MetaPOS'};
  static const Map<String, String> langToggleBn = {'bn': 'বাং', 'en': 'বাং'};
  static const Map<String, String> langToggleEn = {'bn': 'EN', 'en': 'EN'};

  // ─── Session / Login ─────────────────────────────────────────────────────
  static const Map<String, String> loginTitle = {'bn': 'সাইন ইন', 'en': 'Sign In'};
  static const Map<String, String> serverUrl = {'bn': 'সার্ভার ঠিকানা', 'en': 'Server URL'};
  static const Map<String, String> database = {'bn': 'ডেটাবেস', 'en': 'Database'};
  static const Map<String, String> username = {'bn': 'ব্যবহারকারী', 'en': 'Username'};
  static const Map<String, String> password = {'bn': 'পাসওয়ার্ড', 'en': 'Password'};
  static const Map<String, String> selectRegister = {'bn': 'রেজিস্টার বেছে নিন', 'en': 'Select Register'};
  static const Map<String, String> openingFloat = {'bn': 'প্রারম্ভিক নগদ', 'en': 'Opening Float'};
  static const Map<String, String> offlineMode = {'bn': 'অফলাইন মোড', 'en': 'Offline Mode'};
  static const Map<String, String> openTerminal = {'bn': 'টার্মিনাল খুলুন', 'en': 'Open Terminal'};
  static const Map<String, String> sessionOpen = {'bn': 'সেশন চলছে', 'en': 'Session Open'};
  static const Map<String, String> sessionClosed = {'bn': 'সেশন বন্ধ', 'en': 'Session Closed'};
  static const Map<String, String> connectedTo = {'bn': 'সংযুক্ত:', 'en': 'Connected to:'};
  static const Map<String, String> bookFairMode = {'bn': 'বইমেলা মোড সক্রিয়', 'en': 'Book Fair Mode Active'};
  static const Map<String, String> loginError = {'bn': 'লগইন ব্যর্থ হয়েছে', 'en': 'Login failed'};
  static const Map<String, String> loggingIn = {'bn': 'লগইন হচ্ছে…', 'en': 'Logging in…'};

  // ─── Catalog ─────────────────────────────────────────────────────────────
  static const Map<String, String> catalogTitle = {'bn': 'পণ্য তালিকা', 'en': 'Catalog'};
  static const Map<String, String> searchHint = {'bn': 'ISBN বা নাম, লেখক দিয়ে খুঁজুন…', 'en': 'Search ISBN, title, author…'};
  static const Map<String, String> scanBarcode = {'bn': 'বারকোড স্ক্যান', 'en': 'Scan Barcode'};
  static const Map<String, String> allBooks = {'bn': 'সব বই', 'en': 'All Books'};
  static const Map<String, String> addToCart = {'bn': 'যোগ করুন', 'en': 'Add'};
  static const Map<String, String> viewCart = {'bn': 'কার্ট দেখুন', 'en': 'View Cart'};
  static const Map<String, String> inStock = {'bn': 'মজুদ আছে', 'en': 'In Stock'};
  static const Map<String, String> outOfStock = {'bn': 'স্টক শেষ', 'en': 'Out of Stock'};
  static const Map<String, String> lowStock = {'bn': 'কম মজুদ', 'en': 'Low Stock'};
  static const Map<String, String> loadingProducts = {'bn': 'পণ্য লোড হচ্ছে…', 'en': 'Loading products…'};
  static const Map<String, String> noProducts = {'bn': 'কোনো পণ্য পাওয়া যায়নি', 'en': 'No products found'};

  // ─── Book Genre Categories ────────────────────────────────────────────────
  static const Map<String, String> catNovel = {'bn': 'উপন্যাস', 'en': 'Novel'};
  static const Map<String, String> catPoetry = {'bn': 'কবিতা ও ছড়া', 'en': 'Poetry'};
  static const Map<String, String> catThriller = {'bn': 'থ্রিলার ও রহস্য', 'en': 'Thriller'};
  static const Map<String, String> catScifi = {'bn': 'বিজ্ঞান কল্পকাহিনী', 'en': 'Sci-Fi'};
  static const Map<String, String> catHistory = {'bn': 'ইতিহাস ও মুক্তিযুদ্ধ', 'en': 'History'};
  static const Map<String, String> catBiography = {'bn': 'জীবনী', 'en': 'Biography'};
  static const Map<String, String> catYoungAdult = {'bn': 'কিশোর সাহিত্য', 'en': 'Young Adult'};

  // ─── Cart ────────────────────────────────────────────────────────────────
  static const Map<String, String> cartTitle = {'bn': 'বর্তমান অর্ডার', 'en': 'Current Order'};
  static const Map<String, String> clearCart = {'bn': 'কার্ট মুছুন', 'en': 'Clear Cart'};
  static const Map<String, String> subtotal = {'bn': 'উপমোট', 'en': 'Subtotal'};
  static const Map<String, String> discount = {'bn': 'ছাড়', 'en': 'Discount'};
  static const Map<String, String> tax = {'bn': 'ভ্যাট ১০%', 'en': 'VAT 10%'};
  static const Map<String, String> grandTotal = {'bn': 'মোট পরিমাণ', 'en': 'Grand Total'};
  static const Map<String, String> proceedToPayment = {'bn': 'পেমেন্টে যান', 'en': 'Proceed to Payment'};
  static const Map<String, String> holdOrder = {'bn': 'অর্ডার রাখুন', 'en': 'Hold Order'};
  static const Map<String, String> walkInCustomer = {'bn': 'সাধারণ ক্রেতা', 'en': 'Walk-in Customer'};
  static const Map<String, String> changeCustomer = {'bn': 'ক্রেতা পরিবর্তন', 'en': 'Change Customer'};
  static const Map<String, String> emptyCart = {'bn': 'কার্ট খালি', 'en': 'Cart is empty'};
  static const Map<String, String> fairDiscount = {'bn': 'মেলা ছাড়', 'en': 'Fair Discount'};
  static const Map<String, String> customDiscount = {'bn': 'কাস্টম %', 'en': 'Custom %'};
  static const Map<String, String> itemNote = {'bn': 'নোট', 'en': 'Note'};

  // ─── Customer ────────────────────────────────────────────────────────────
  static const Map<String, String> customerTitle = {'bn': 'ক্রেতা নির্বাচন', 'en': 'Select Customer'};
  static const Map<String, String> searchCustomer = {'bn': 'ফোন বা নাম দিয়ে খুঁজুন…', 'en': 'Search by phone or name…'};
  static const Map<String, String> addCustomer = {'bn': 'নতুন ক্রেতা যোগ করুন', 'en': 'Add New Customer'};
  static const Map<String, String> guestCustomer = {'bn': 'সাধারণ গেস্ট', 'en': 'Guest / Walk-in'};
  static const Map<String, String> customerName = {'bn': 'পুরো নাম', 'en': 'Full Name'};
  static const Map<String, String> customerPhone = {'bn': 'মোবাইল নম্বর', 'en': 'Mobile Number'};
  static const Map<String, String> customerEmail = {'bn': 'ইমেইল ঐচ্ছিক', 'en': 'Email optional'};
  static const Map<String, String> customerAddress = {'bn': 'ঠিকানা ঐচ্ছিক', 'en': 'Address optional'};
  static const Map<String, String> saveAndAssign = {'bn': 'সংরক্ষণ করুন', 'en': 'Save & Assign'};
  static const Map<String, String> required = {'bn': 'আবশ্যক', 'en': 'Required'};

  // ─── Checkout ────────────────────────────────────────────────────────────
  static const Map<String, String> checkoutTitle = {'bn': 'পেমেন্ট', 'en': 'Payment'};
  static const Map<String, String> totalDue = {'bn': 'পরিশোধযোগ্য মোট', 'en': 'Total Due'};
  static const Map<String, String> payByCash = {'bn': 'নগদ', 'en': 'Cash'};
  static const Map<String, String> payByCard = {'bn': 'কার্ড', 'en': 'Card'};
  static const Map<String, String> payByBkash = {'bn': 'বিকাশ', 'en': 'bKash'};
  static const Map<String, String> payByNagad = {'bn': 'নগদ ডিজিটাল', 'en': 'Nagad'};
  static const Map<String, String> tenderAmount = {'bn': 'প্রদত্ত পরিমাণ', 'en': 'Tendered Amount'};
  static const Map<String, String> changeReturn = {'bn': 'ফেরত', 'en': 'Change'};
  static const Map<String, String> remaining = {'bn': 'বাকি', 'en': 'Remaining'};
  static const Map<String, String> exactAmount = {'bn': 'সঠিক পরিমাণ', 'en': 'Exact'};
  static const Map<String, String> transactionId = {'bn': 'ট্র্যানজেকশন আইডি', 'en': 'Transaction ID'};
  static const Map<String, String> cardLastFour = {'bn': 'কার্ডের শেষ ৪ সংখ্যা', 'en': 'Card Last 4 Digits'};
  static const Map<String, String> completeSale = {'bn': 'বিক্রয় সম্পন্ন করুন', 'en': 'Complete Sale'};
  static const Map<String, String> submittingOrder = {'bn': 'অর্ডার জমা হচ্ছে…', 'en': 'Submitting order…'};
  static const Map<String, String> orderFailed = {'bn': 'অর্ডার ব্যর্থ হয়েছে', 'en': 'Order submission failed'};

  // ─── Receipt ─────────────────────────────────────────────────────────────
  static const Map<String, String> receiptTitle = {'bn': 'বিক্রয় সম্পন্ন!', 'en': 'Sale Complete!'};
  static const Map<String, String> orderRef = {'bn': 'অর্ডার নম্বর', 'en': 'Order Ref'};
  static const Map<String, String> ticketCode = {'bn': 'টিকেট কোড', 'en': 'Ticket Code'};
  static const Map<String, String> printReceipt = {'bn': 'রিসিট প্রিন্ট করুন', 'en': 'Print Receipt'};
  static const Map<String, String> shareReceipt = {'bn': 'শেয়ার করুন', 'en': 'Share Receipt'};
  static const Map<String, String> newSale = {'bn': 'নতুন বিক্রয়', 'en': 'New Sale'};
  static const Map<String, String> cashier = {'bn': 'ক্যাশিয়ার', 'en': 'Cashier'};
  static const Map<String, String> register = {'bn': 'রেজিস্টার', 'en': 'Register'};
  static const Map<String, String> amountPaid = {'bn': 'পরিশোধিত', 'en': 'Paid'};
  static const Map<String, String> offlineQueued = {
    'bn': 'অফলাইন মোড: অর্ডার স্থানীয়ভাবে সংরক্ষিত। সংযোগ ফিরলে স্বয়ংক্রিয়ভাবে সিঙ্ক হবে।',
    'en': 'Offline: Order saved locally. Will sync automatically when online.',
  };
  static const Map<String, String> syncedOnline = {'bn': 'সার্ভারে সংরক্ষিত', 'en': 'Synced to server'};

  // ─── Common Actions ───────────────────────────────────────────────────────
  static const Map<String, String> retry = {'bn': 'পুনরায় চেষ্টা করুন', 'en': 'Retry'};
  static const Map<String, String> cancel = {'bn': 'বাতিল', 'en': 'Cancel'};
  static const Map<String, String> confirm = {'bn': 'নিশ্চিত করুন', 'en': 'Confirm'};
  static const Map<String, String> close = {'bn': 'বন্ধ করুন', 'en': 'Close'};
  static const Map<String, String> loading = {'bn': 'লোড হচ্ছে…', 'en': 'Loading…'};
  static const Map<String, String> error = {'bn': 'ত্রুটি', 'en': 'Error'};
  static const Map<String, String> success = {'bn': 'সফল', 'en': 'Success'};
  static const Map<String, String> online = {'bn': 'অনলাইন', 'en': 'Online'};
  static const Map<String, String> offline = {'bn': 'অফলাইন', 'en': 'Offline'};
  static const Map<String, String> left = {'bn': 'বাকি', 'en': 'left'};

  // ─── Dashboard ────────────────────────────────────────────────────────────
  static const Map<String, String> dashboardTitle = {'bn': 'বইমেলা ড্যাশবোর্ড', 'en': 'Book Fair Dashboard'};
  static const Map<String, String> dashboardSubtitle = {'bn': 'লাইভ বিক্রয় ও পারফরম্যান্স পরিসংখ্যান', 'en': 'Live Sales & Performance Statistics'};
  static const Map<String, String> openPos = {'bn': 'পয়েন্ট অব সেল', 'en': 'Point of Sale'};
  static const Map<String, String> openPosShort = {'bn': 'পিওএস বিক্রয়', 'en': 'POS Register'};
  static const Map<String, String> kpiTitle = {'bn': 'মূল পরিসংখ্যান', 'en': 'Key Performance Indicators'};
  static const Map<String, String> kpiRevenue = {'bn': 'মোট বিক্রয়', 'en': 'Total Revenue'};
  static const Map<String, String> kpiOrders = {'bn': 'মোট অর্ডার', 'en': 'Total Orders'};
  static const Map<String, String> kpiCopies = {'bn': 'মোট বই বিক্রি', 'en': 'Copies Sold'};
  static const Map<String, String> kpiTitles = {'bn': 'বিক্রিত শিরোনাম', 'en': 'Unique Titles'};
  static const Map<String, String> kpiAvgBasket = {'bn': 'গড় অর্ডার মূল্য', 'en': 'Avg Basket'};
  static const Map<String, String> kpiDiscounts = {'bn': 'মোট মেলা ছাড়', 'en': 'Total Discounts'};
  static const Map<String, String> kpiCustomers = {'bn': 'মোট ক্রেতা', 'en': 'Customers'};
  static const Map<String, String> kpiBooksPerOrder = {'bn': 'প্রতি অর্ডারে বই', 'en': 'Books Per Order'};
  static const Map<String, String> histHourlyRevenue = {'bn': 'ঘণ্টা প্রতি বিক্রয়', 'en': 'Hourly Sales'};
  static const Map<String, String> histHourlyOrders = {'bn': 'ঘণ্টা প্রতি অর্ডার', 'en': 'Hourly Orders'};
  static const Map<String, String> stallName = {'bn': 'বইমেলা স্টল নং ১', 'en': 'Book Fair Stall #1'};
  static const Map<String, String> lastUpdated = {'bn': 'সর্বশেষ আপডেট:', 'en': 'Last updated:'};
  static const Map<String, String> refresh = {'bn': 'রিফ্রেশ', 'en': 'Refresh'};
  static const Map<String, String> ordersCountSuffix = {'bn': ' টি', 'en': ''};
  static const Map<String, String> copiesCountSuffix = {'bn': ' কপি', 'en': ' copies'};
  static const Map<String, String> customersCountSuffix = {'bn': ' জন', 'en': ''};
  static const Map<String, String> goToDashboard = {'bn': 'ড্যাশবোর্ডে ফিরুন', 'en': 'Back to Dashboard'};
  static const Map<String, String> backToDashboard = {'bn': 'ড্যাশবোর্ড', 'en': 'Dashboard'};

  // ─── Helper to resolve locale string ─────────────────────────────────────
  /// Returns the string for the given locale code ('bn' or 'en').
  /// Falls back to English if the key is missing for the requested locale.
  static String of(Map<String, String> map, String locale) {
    return map[locale] ?? map['en'] ?? '';
  }
}
