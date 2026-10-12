class DocumentModel {
  bool? backSide;
  bool? enable;
  bool? expireAt;
  String? id;
  bool? frontSide;
  String? title;
  String? type;

  DocumentModel({this.backSide, this.enable, this.id, this.frontSide, this.title, this.expireAt, this.type});

  DocumentModel.fromJson(Map<String, dynamic> json) {
    backSide = json['backSide'];
    enable = json['enable'];
    id = json['id'];
    frontSide = json['frontSide'];
    title = json['title'];
    expireAt = json['expireAt'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['backSide'] = backSide;
    data['enable'] = enable;
    data['id'] = id;
    data['frontSide'] = frontSide;
    data['title'] = title;
    data['expireAt'] = expireAt;
    data['type'] = type;
    return data;
  }
}
