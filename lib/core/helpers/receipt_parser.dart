/// Hasil tebakan dari teks OCR sebuah struk/screenshot transaksi.
///
/// Semua field bersifat "best guess" — pengguna tetap harus meninjau
/// ulang sebelum menyimpan transaksi, jadi tidak ada yang otomatis
/// disimpan tanpa konfirmasi.
class ReceiptParseResult {
  const ReceiptParseResult({
    this.amount,
    this.date,
    this.hour,
    this.minute,
    this.merchant,
    required this.rawText,
  });

  final int? amount;
  final DateTime? date;
  final int? hour;
  final int? minute;
  final String? merchant;
  final String rawText;

  bool get hasAnyMatch => amount != null || date != null || merchant != null;
}

/// Menebak nominal, tanggal, dan nama merchant/penerima dari teks mentah
/// hasil OCR. Dirancang untuk format struk & screenshot transfer yang umum
/// dipakai di Indonesia (GoPay, DANA, OVO, mobile banking, e-commerce, dll).
class ReceiptParser {
  ReceiptParser._();

  static final RegExp _amountPattern = RegExp(
    r'Rp\.?\s?([0-9][0-9.,]{2,})',
    caseSensitive: false,
  );

  // Kata kunci yang sering mendahului nominal utama pada struk/screenshot,
  // dipakai untuk menaikkan prioritas kandidat saat ada beberapa angka.
  static const List<String> _totalKeywords = [
    'total bayar',
    'total belanja',
    'total transaksi',
    'total pembayaran',
    'jumlah bayar',
    'jumlah transfer',
    'nominal',
    'total',
    'grand total',
    'bayar',
  ];

  static const List<String> _monthNames = [
    'jan',
    'feb',
    'mar',
    'apr',
    'mei',
    'jun',
    'jul',
    'agu',
    'sep',
    'okt',
    'nov',
    'des',
  ];

  static ReceiptParseResult parse(String text) {
    final normalized = text.replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final amount = _guessAmount(lines);
    final date = _guessDate(normalized);
    final time = _guessTime(normalized);
    final merchant = _guessMerchant(lines);

    return ReceiptParseResult(
      amount: amount,
      date: date,
      hour: time?.$1,
      minute: time?.$2,
      merchant: merchant,
      rawText: normalized,
    );
  }

  static int? _guessAmount(List<String> lines) {
    final candidates = <_AmountCandidate>[];

    for (final line in lines) {
      for (final match in _amountPattern.allMatches(line)) {
        final raw = match.group(1);
        if (raw == null) continue;
        final value = _parseAmountString(raw);
        if (value == null || value <= 0) continue;

        final lower = line.toLowerCase();
        var priority = 0;
        for (var i = 0; i < _totalKeywords.length; i++) {
          if (lower.contains(_totalKeywords[i])) {
            priority = _totalKeywords.length - i;
            break;
          }
        }
        candidates.add(_AmountCandidate(value: value, priority: priority));
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return b.value.compareTo(a.value);
    });

    return candidates.first.value;
  }

  static int? _parseAmountString(String raw) {
    var cleaned = raw.trim();
    // Format Indonesia: titik sebagai pemisah ribuan, koma sebagai desimal.
    // Buang bagian desimal (,00 / .00) lalu buang semua pemisah ribuan.
    cleaned = cleaned.replaceAll(RegExp(r'[.,]00$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[.,]-$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  static DateTime? _guessDate(String text) {
    final lower = text.toLowerCase();

    // Format numerik: 14/09/2026, 14-09-2026, 14/09/26
    final numeric = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})');
    final numericMatch = numeric.firstMatch(lower);
    if (numericMatch != null) {
      final day = int.tryParse(numericMatch.group(1)!);
      final month = int.tryParse(numericMatch.group(2)!);
      var year = int.tryParse(numericMatch.group(3)!);
      if (day != null && month != null && year != null && month <= 12 && day <= 31) {
        if (year < 100) year += 2000;
        try {
          return DateTime(year, month, day);
        } catch (_) {
          // fallthrough
        }
      }
    }

    // Format nama bulan: 14 Sep 2026 / 14 September 2026
    // Spasi dibuat opsional (\s*) karena OCR kadang ngilangin spasi,
    // terutama di screenshot dengan kerning rapat.
    final monthPattern = _monthNames.join('|');
    final named = RegExp(
      r'(\d{1,2})\s*(' + monthPattern + r')[a-z]*\.?\s*,?\s*(\d{4})',
    );
    final namedMatch = named.firstMatch(lower);
    if (namedMatch != null) {
      final day = int.tryParse(namedMatch.group(1)!);
      final monthAbbr = namedMatch.group(2)!;
      final year = int.tryParse(namedMatch.group(3)!);
      final month = _monthNames.indexOf(monthAbbr) + 1;
      if (day != null && year != null && month > 0 && day <= 31) {
        try {
          return DateTime(year, month, day);
        } catch (_) {
          // fallthrough
        }
      }
    }

    return null;
  }

  static (int, int)? _guessTime(String text) {
    // Format 24 jam: 17:51, 17.51.
    final pattern = RegExp(r'\b([01]?\d|2[0-3])[:.]([0-5]\d)\b');
    const timeKeywords = ['waktu', 'jam', 'pukul', 'time'];
    final lines = text.split('\n');

    // Prioritas 1: baris yang eksplisit mengandung kata kunci waktu,
    // misalnya "Waktu 17:51".
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (timeKeywords.any((keyword) => lower.contains(keyword))) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final hour = int.tryParse(match.group(1)!);
          final minute = int.tryParse(match.group(2)!);
          if (hour != null && minute != null) return (hour, minute);
        }
      }
    }

    // Prioritas 2 (fallback): baris pertama screenshot biasanya jam
    // status bar HP (misal "2.41"), bukan waktu transaksi — jadi
    // baris pertama dilewati, baru cari kecocokan pertama sesudahnya.
    for (var i = 1; i < lines.length; i++) {
      final match = pattern.firstMatch(lines[i]);
      if (match != null) {
        final hour = int.tryParse(match.group(1)!);
        final minute = int.tryParse(match.group(2)!);
        if (hour != null && minute != null) return (hour, minute);
      }
    }

    return null;
  }

  static String? _guessMerchant(List<String> lines) {
    if (lines.isEmpty) return null;

    const skipKeywords = [
      'rp',
      'total',
      'berhasil',
      'sukses',
      'pending',
      'gagal',
      'bukti',
      'transfer',
      'pembayaran',
      'struk',
      'invoice',
      'tanggal',
      'waktu',
      'jam',
      'no. referensi',
      'nomor referensi',
      'id transaksi',
    ];

    for (final line in lines.take(6)) {
      final lower = line.toLowerCase();
      if (line.length < 3) continue;
      if (RegExp(r'^\d+$').hasMatch(line)) continue;
      if (skipKeywords.any((keyword) => lower.contains(keyword))) continue;
      return line;
    }

    return null;
  }
}

class _AmountCandidate {
  const _AmountCandidate({required this.value, required this.priority});

  final int value;
  final int priority;
}
