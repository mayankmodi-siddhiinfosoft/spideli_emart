class FlutterWaveSettingData {
  String publicKey;
  String secretKey;
  String encryptionKey;
  bool? isEnable;
  bool? isSandbox;
  bool? isWithdrawEnabled;

  FlutterWaveSettingData({
    this.publicKey = '',
    this.encryptionKey = '',
    this.secretKey = '',
     this.isSandbox,
     this.isEnable,
     this.isWithdrawEnabled,
  });

  factory FlutterWaveSettingData.fromJson(Map<String, dynamic> parsedJson) {
    return FlutterWaveSettingData(
      publicKey: parsedJson['publicKey'] ?? '',
      encryptionKey: parsedJson['encryptionKey'] ?? '',
      isSandbox: parsedJson['isSandbox'] ?? false,
      isEnable: parsedJson['isEnable'] ?? false,
      secretKey: parsedJson['secretKey'] ?? '',
      isWithdrawEnabled: parsedJson['isWithdrawEnabled'] ??false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'secretKey': this.secretKey,
      'encryptionKey': this.encryptionKey,
      'isEnable': this.isEnable,
      'isSandbox': this.isSandbox,
      'publicKey': this.publicKey,
      'isWithdrawEnabled': this.isWithdrawEnabled,
    };
  }
}
