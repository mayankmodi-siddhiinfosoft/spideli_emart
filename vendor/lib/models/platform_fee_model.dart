class PlatformFeeModel {
  String? fee;
  bool? enable;

  PlatformFeeModel({this.fee, this.enable});

  PlatformFeeModel.fromJson(Map<String, dynamic> json) {
    fee = json['fee'].toString();
    enable = json['enable'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['fee'] = fee;
    data['enable'] = enable;
    return data;
  }
}
