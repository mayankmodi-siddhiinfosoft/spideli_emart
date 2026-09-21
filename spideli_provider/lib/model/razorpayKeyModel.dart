class RazorPayModel {
  String razorpayKey;
  String razorpaySecret;
  bool? isEnabled;
  bool? isSandboxEnabled;
  bool? isWithdrawEnabled;

  RazorPayModel({
    this.razorpayKey = '',
    this.razorpaySecret = '',
     this.isEnabled,
     this.isSandboxEnabled,
     this.isWithdrawEnabled,
  });

  factory RazorPayModel.fromJson(Map<String, dynamic> parsedJson) {
    return RazorPayModel(
      razorpayKey: parsedJson['razorpayKey'] ?? '',
      razorpaySecret: parsedJson['razorpaySecret'] ?? '',
      isSandboxEnabled: parsedJson['isSandboxEnabled'],
      isEnabled: parsedJson['isEnabled'],
      isWithdrawEnabled: parsedJson['isWithdrawEnabled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'razorpayKey': this.razorpayKey,
      'razorpaySecret': this.razorpaySecret,
      'isEnabled': this.isEnabled,
      'isSandboxEnabled': this.isSandboxEnabled,
      'isWithdrawEnabled': this.isWithdrawEnabled,
    };
  }
}
