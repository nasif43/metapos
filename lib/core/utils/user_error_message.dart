/// Translates raw technical, network, or backend exceptions into clear,
/// user-friendly messages suitable for POS cashiers and store managers.
class UserErrorMessage {
  UserErrorMessage._();

  /// Converts any [error] object into a concise, non-technical message.
  static String format(Object? error, {bool isBangla = true}) {
    if (error == null) {
      return isBangla
          ? 'কাজটি সম্পন্ন করা যায়নি। অনুগ্রহ করে আবার চেষ্টা করুন।'
          : 'Unable to complete this request. Please try again.';
    }

    final raw = error.toString().toLowerCase();

    // 1. Network / Connectivity / Timeout errors
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection refused') ||
        raw.contains('connection reset') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection timed out') ||
        raw.contains('timeout') ||
        raw.contains('connection error') ||
        raw.contains('handshakeexception')) {
      return isBangla
          ? 'ইন্টারনেট সংযোগে সমস্যা হচ্ছে। অনুগ্রহ করে সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।'
          : 'Unable to reach the server. Please check your internet connection and try again.';
    }

    // 2. Authentication / Credentials / Session expired
    if (raw.contains('access denied') ||
        raw.contains('invalid login') ||
        raw.contains('wrong login') ||
        raw.contains('authentication') ||
        raw.contains('401') ||
        raw.contains('session expired') ||
        raw.contains('uid')) {
      return isBangla
          ? 'ইউজারনেম বা পাসওয়ার্ড সঠিক নয়, অথবা লগইন মেয়াদ শেষ হয়েছে। অনুগ্রহ করে আবার লগইন করুন।'
          : 'Incorrect username or password, or your login expired. Please sign in again.';
    }

    // 3. Closed or inactive POS register session
    if (raw.contains('closed') ||
        raw.contains('খোল') ||
        raw.contains('missingerror') ||
        raw.contains('no active pos session') ||
        raw.contains('session')) {
      return isBangla
          ? 'কাউন্টার সেশন চালু নেই। অনুগ্রহ করে সেশন চালু করে আবার চেষ্টা করুন।'
          : 'Your counter session is not active. Please open the counter session and try again.';
    }

    // 4. Payment method mismatch or invalid payment
    if (raw.contains('payment') || raw.contains('journal')) {
      return isBangla
          ? 'নির্বাচিত পেমেন্ট পদ্ধতি এই কাউন্টারে সক্রিয় নয়। অনুগ্রহ করে অন্য পদ্ধতি নির্বাচন করুন।'
          : 'This payment method is not enabled for the selected counter. Please choose another method.';
    }

    // 5. Validation / Stock / Return bounds
    if (raw.contains('refundable') ||
        raw.contains('exceeds') ||
        raw.contains('quantity') ||
        raw.contains('no items selected')) {
      return isBangla
          ? 'পণ্যের পরিমাণ সঠিক নয়। অনুগ্রহ করে সংখ্যা যাচাই করুন।'
          : 'Please check the selected item quantities and try again.';
    }

    // 6. Generic clean fallback (never expose stack traces, JSON, or Python errors)
    return isBangla
        ? 'এই মুহূর্তে কাজটি সম্পন্ন করা যায়নি। অনুগ্রহ করে একটু পর আবার চেষ্টা করুন।'
        : 'Something went wrong while completing this request. Please try again.';
  }
}
