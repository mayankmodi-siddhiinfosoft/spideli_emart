class AdminCommissionModel {
  int? commission;
  bool? enable;
  String? type;

  AdminCommissionModel({this.commission, this.enable, this.type});

  AdminCommissionModel.fromJson(Map<String, dynamic> json) {
    commission = json['commission'];
    enable = json['enable'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['commission'] = commission;
    data['enable'] = enable;
    data['type'] = type;
    return data;
  }
}
