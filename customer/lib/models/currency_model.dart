class CurrencyModel {
  String code;
  int decimal;
  String id;
  bool isactive;
  num rounding;
  String name;
  String symbol;
  bool symbolatright;

  CurrencyModel({
    this.code = '',
    this.decimal = 0,
    this.isactive = false,
    this.id = '',
    this.name = '',
    this.rounding = 0,
    this.symbol = '',
    this.symbolatright = false,
  });

  factory CurrencyModel.fromJson(Map<String, dynamic> parsedJson) {
    // Tolerant parsing: the admin panel writes `decimal_degits`, some rows
    // carry `decimalDigits`, and numbers may arrive as strings.
    final dynamic digits = parsedJson['decimal_degits'] ?? parsedJson['decimalDigits'];
    final dynamic rounding = parsedJson['rounding'];
    return CurrencyModel(
      code: parsedJson['code']?.toString() ?? '',
      decimal: digits is num ? digits.toInt() : int.tryParse(digits?.toString() ?? '') ?? 0,
      isactive: parsedJson['isActive'] == true,
      id: parsedJson['id']?.toString() ?? '',
      name: parsedJson['name']?.toString() ?? '',
      rounding: rounding is num ? rounding : num.tryParse(rounding?.toString() ?? '') ?? 0,
      symbol: parsedJson['symbol']?.toString() ?? '',
      symbolatright: parsedJson['symbolAtRight'] == true,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'decimal_degits': decimal,
      'isActive': isactive,
      'rounding': rounding,
      'id': id,
      'name': name,
      'symbol': symbol,
      'symbolAtRight': symbolatright,
    };
  }
}
