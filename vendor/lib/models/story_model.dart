import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  String? videoThumbnail;
  List<dynamic> videoUrl = [];
  String? vendorID;
  String? sectionID;
  Timestamp? createdAt;

  StoryModel({this.videoThumbnail, this.videoUrl = const [], this.vendorID, this.createdAt, this.sectionID});

  StoryModel.fromJson(Map<String, dynamic> json) {
    videoThumbnail = json['videoThumbnail'] ?? '';
    videoUrl = json['videoUrl'] ?? [];
    vendorID = json['vendorID'] ?? '';
    sectionID = json['sectionID'] ?? '';
    createdAt = json['createdAt'] ?? Timestamp.now();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['videoThumbnail'] = videoThumbnail;
    data['videoUrl'] = videoUrl;
    data['vendorID'] = vendorID;
    data['sectionID'] = sectionID;
    data['createdAt'] = createdAt;
    return data;
  }
}
