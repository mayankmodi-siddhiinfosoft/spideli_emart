import 'dart:async';

/// One conversation of an order inbox: the order thread
/// (`chat/{threadId}/thread`) and the other party. The store and driver chats
/// of one order (and the provider and worker chats of one booking) share the
/// thread, so the peer is part of the conversation's identity.
typedef InboxThread = ({String threadId, String peerId});

/// Live totals built from live per-item counts: the aggregate unread badges
/// of the profile screen (`.claude/CUSTOMER-NOTIFICATIONS.md` §2). Pure (no
/// Firebase), so it is unit tested with fake streams.
abstract final class UnreadSum {
  /// The conversations of an inbox, from its inbox documents (`chat/{orderId}`:
  /// `orderId`, `senderId`, `receiverId`), exactly as the inbox screens build
  /// their rows: the thread is the order id, the peer is whichever of the two
  /// ids is not [uid]. A document without an order id has no thread (its row
  /// shows no badge) and is skipped; duplicates are dropped.
  static List<InboxThread> threadsOf(Iterable<Map<String, dynamic>> inboxDocs, String uid) {
    final Set<InboxThread> threads = <InboxThread>{};
    for (final Map<String, dynamic> doc in inboxDocs) {
      final String threadId = _string(doc['orderId']).trim();
      if (threadId.isEmpty) continue;
      final String receiverId = _string(doc['receiverId']);
      final String peerId = receiverId == uid ? _string(doc['senderId']) : receiverId;
      threads.add((threadId: threadId, peerId: peerId.trim()));
    }
    return threads.toList();
  }

  static String _string(Object? value) => value is String ? value : (value?.toString() ?? '');

  /// The live sum of `countOf(key)` over the keys [keys] currently lists.
  ///
  /// Each new key gets one subscription to its count stream; a key that leaves
  /// the list is cancelled and stops counting; all of them are cancelled when
  /// the result's listener cancels. A count stream that fails counts 0 (a
  /// failed badge listener shows nothing); a failing [keys] stream drops
  /// every count. Emits once the first key list arrives (0 for an empty list),
  /// then only when the total changes.
  static Stream<int> sumOf<K>(Stream<Iterable<K>> keys, Stream<int> Function(K key) countOf) {
    late final StreamController<int> out;
    StreamSubscription<Iterable<K>>? keysSub;
    final Map<K, StreamSubscription<int>> subs = <K, StreamSubscription<int>>{};
    final Map<K, int> counts = <K, int>{};
    final Set<K> finished = <K>{};
    bool keysDone = false;
    int? last;

    void emit() {
      if (out.isClosed) return;
      int total = 0;
      for (final int n in counts.values) {
        if (n > 0) total += n;
      }
      if (total == last) return;
      last = total;
      out.add(total);
    }

    void closeIfDone() {
      if (keysDone && finished.containsAll(subs.keys) && !out.isClosed) out.close();
    }

    void drop(K key) {
      subs.remove(key)?.cancel();
      counts.remove(key);
      finished.remove(key);
    }

    void dropAll() {
      for (final StreamSubscription<int> sub in subs.values) {
        sub.cancel();
      }
      subs.clear();
      counts.clear();
      finished.clear();
    }

    void setKeys(Iterable<K> list) {
      final Set<K> wanted = list.toSet();
      for (final K key in subs.keys.where((k) => !wanted.contains(k)).toList()) {
        drop(key);
      }
      for (final K key in wanted) {
        if (subs.containsKey(key)) continue;
        counts[key] = 0;
        Stream<int> stream;
        try {
          stream = countOf(key);
        } catch (_) {
          stream = Stream<int>.value(0);
        }
        subs[key] = stream.listen(
          (n) {
            if (!subs.containsKey(key)) return;
            counts[key] = n;
            emit();
          },
          onError: (Object _) {
            if (!subs.containsKey(key)) return;
            counts[key] = 0;
            emit();
          },
          onDone: () {
            // Keeps its last count; the total ends when every source has.
            if (!subs.containsKey(key)) return;
            finished.add(key);
            closeIfDone();
          },
        );
      }
      emit();
    }

    out = StreamController<int>(
      onListen: () {
        keysSub = keys.listen(
          setKeys,
          onError: (Object _) {
            dropAll();
            emit();
          },
          onDone: () {
            keysDone = true;
            closeIfDone();
          },
        );
      },
      onCancel: () async {
        await keysSub?.cancel();
        dropAll();
      },
    );
    return out.stream;
  }

  /// [countFor] the signed-in user, following [uids] (an auth state stream):
  /// 0 while signed out (null or empty uid), and the old user's listeners are
  /// cancelled when the user changes or signs out.
  static Stream<int> perUser(Stream<String?> uids, Stream<int> Function(String uid) countFor) {
    return sumOf<String>(
      uids.map((uid) {
        final String id = uid?.trim() ?? '';
        return id.isEmpty ? const <String>[] : <String>[id];
      }),
      countFor,
    );
  }
}
