class PlatformFeeModel {
  String? fee;
  bool? enable;

  PlatformFeeModel({this.fee, this.enable});

  PlatformFeeModel.fromJson(Map<String, dynamic> json) {
    fee = json['fee']?.toString() ?? '0.0';
    enable = json['enable'] == true || json['enable']?.toString() == 'true';
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['fee'] = fee;
    data['enable'] = enable;
    return data;
  }
}
