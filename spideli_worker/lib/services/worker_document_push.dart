import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:spideliworker/services/push_message.dart';
import 'package:spideliworker/services/send_notification.dart';

/// The push to the worker's PROVIDER when the worker sends a document for
/// review: `dynamic_notification` template `worker_document_submitted`
/// (`{workerName}`, `{documentTitle}`). A tap opens that worker's review
/// screen in the Provider app (data `workerId`).
class WorkerDocumentPush {
  WorkerDocumentPush._();

  /// The push data: the type, the worker, the provider and the document.
  static Map<String, String> submittedData({required String workerId, required String providerId, required String documentId}) {
    final Map<String, String> out = {'type': WorkerDocumentPushType.submitted};
    void put(String key, String value) {
      final String text = value.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') out[key] = text;
    }

    put('workerId', workerId);
    put('providerId', providerId);
    put('documentId', documentId);
    return out;
  }

  /// The template's placeholder values.
  static Map<String, String> submittedValues({required String workerName, required String documentTitle}) => {
        'workerName': workerName.trim(),
        'documentTitle': documentTitle.trim(),
      };

  /// Sends it without holding up the upload: the document is saved whether
  /// the push goes out or not. No provider on the worker: nothing to do.
  static void notifyProvider({required String providerId, required String workerId, required String workerName, required String documentId, required String documentTitle}) {
    if (providerId.trim().isEmpty) return;
    unawaited(() async {
      try {
        final String token = await SendNotification.tokenForUser(providerId);
        await SendNotification.sendTemplatePush(
          WorkerDocumentPushType.submitted,
          token: token,
          recipient: PushRecipient.provider,
          values: submittedValues(workerName: workerName, documentTitle: documentTitle),
          payload: submittedData(workerId: workerId, providerId: providerId, documentId: documentId),
        );
      } catch (e) {
        debugPrint('worker_document_submitted not sent: $e');
      }
    }());
  }
}
