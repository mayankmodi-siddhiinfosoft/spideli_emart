import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  String? id;
  String? senderId;
  String? receiverId;
  String? orderId;
  String? message;
  String? messageType;
  String? videoThumbnail;
  Url? url;
  Timestamp? createdAt;
  bool? seen;
  int? recordingTimer;

  /// Audit only, set on a message a store EMPLOYEE writes: the employee's own
  /// uid and name. [senderId] is then the store's chat id (the owner's uid),
  /// which is what every reader filters and draws on; these two are never
  /// read for that, and are left out of the document when empty, so the
  /// owner's messages are unchanged (lib/utils/store_chat.dart).
  String? sentByUserId;
  String? sentByName;

  ConversationModel({this.id, this.senderId, this.receiverId, this.orderId, this.message, this.messageType, this.videoThumbnail, this.url, this.createdAt, this.seen, this.recordingTimer, this.sentByUserId, this.sentByName});

  factory ConversationModel.fromJson(Map<String, dynamic> parsedJson) {
    return ConversationModel(
      id: parsedJson['id'] ?? '',
      senderId: parsedJson['senderId'] ?? '',
      receiverId: parsedJson['receiverId'] ?? '',
      orderId: parsedJson['orderId'] ?? '',
      message: parsedJson['message'] ?? '',
      messageType: parsedJson['messageType'] ?? '',
      videoThumbnail: parsedJson['videoThumbnail'] ?? '',
      url: parsedJson.containsKey('url')
          ? parsedJson['url'] != null
                ? Url.fromJson(parsedJson['url'])
                : null
          : Url(),
      createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
      seen: parsedJson['seen'],
      recordingTimer: parsedJson['recordingTimer'],
      sentByUserId: parsedJson['sentByUserId']?.toString(),
      sentByName: parsedJson['sentByName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      if (orderId != null && orderId != '') 'orderId': orderId,
      'message': message,
      'messageType': messageType,
      'videoThumbnail': videoThumbnail,
      'url': url?.toJson(),
      'createdAt': createdAt,
      if (seen != null) 'seen': seen,
      'recordingTimer': recordingTimer,
      if ((sentByUserId ?? '').isNotEmpty) 'sentByUserId': sentByUserId,
      if ((sentByName ?? '').isNotEmpty) 'sentByName': sentByName,
    };
  }
}

class Url {
  String mime;

  String url;

  Url({this.mime = '', this.url = ''});

  factory Url.fromJson(Map<dynamic, dynamic> parsedJson) {
    return Url(mime: parsedJson['mime'] ?? '', url: parsedJson['url'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'mime': mime, 'url': url};
  }
}
