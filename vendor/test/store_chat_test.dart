import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/lang/app_ar.dart';
import 'package:vendor/lang/app_de.dart';
import 'package:vendor/lang/app_en.dart';
import 'package:vendor/lang/app_fr.dart';
import 'package:vendor/lang/app_hi.dart';
import 'package:vendor/lang/app_ja.dart';
import 'package:vendor/lang/app_pt.dart';
import 'package:vendor/lang/app_ru.dart';
import 'package:vendor/lang/app_zh.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/models/permission_model.dart';
import 'package:vendor/utils/store_chat.dart';

/// Store employees use the store's chats as the store (report 69,
/// lib/utils/store_chat.dart).
void main() {
  const String owner = 'owner-uid';
  const String employee = 'employee-uid';

  List<PermissionModel> fullRole({bool? chat = true}) => [
    PermissionModel(title: 'Manage Order', isActive: true),
    PermissionModel(title: 'Manage Products', isActive: true),
    if (chat != null) PermissionModel(title: 'Chat', isActive: chat),
  ];

  group('permission gate', () {
    test('the owner may always chat, with or without a role', () {
      expect(StoreChat.allowed(role: 'vendor', permissions: null), isTrue);
      expect(StoreChat.allowed(role: 'vendor', permissions: const []), isTrue);
      expect(StoreChat.allowed(role: null, permissions: null), isTrue);
    });

    test('an employee may chat only with an active Chat permission', () {
      expect(StoreChat.allowed(role: 'employee', permissions: fullRole(chat: true)), isTrue);
      expect(StoreChat.allowed(role: 'employee', permissions: fullRole(chat: false)), isFalse);
    });

    test('the Chat title is matched case-insensitively', () {
      expect(StoreChat.allowed(role: 'employee', permissions: [PermissionModel(title: 'chat', isActive: true)]), isTrue);
      expect(StoreChat.allowed(role: 'employee', permissions: [PermissionModel(title: ' CHAT ', isActive: true)]), isTrue);
    });

    test('a role saved before the Chat entry existed is not allowed, even with every other permission', () {
      expect(StoreChat.allowed(role: 'employee', permissions: fullRole(chat: null)), isFalse);
    });

    test('an employee without a role (not loaded, deleted) may not chat', () {
      expect(StoreChat.allowed(role: 'employee', permissions: null), isFalse);
      expect(StoreChat.allowed(role: 'employee', permissions: const []), isFalse);
      expect(StoreChat.allowed(role: 'employee', permissions: [PermissionModel(title: 'Chat')]), isFalse, reason: 'isActive missing');
    });

    test('the role editor gets the Chat switch, off, on an older role; an existing entry is kept', () {
      final List<PermissionModel> older = fullRole(chat: null);
      final List<PermissionModel> edited = StoreChat.withChatPermission(older);
      expect(edited.where((p) => p.title == 'Chat').single.isActive, isFalse);
      expect(older.length, 2, reason: 'the input list is not changed');
      expect(StoreChat.withChatPermission(fullRole(chat: true)).where((p) => p.title == 'Chat').single.isActive, isTrue);
      expect(StoreChat.withChatPermission(fullRole(chat: true)).length, 3);
      expect(StoreChat.withChatPermission(null).single.title, 'Chat');
    });

    test('a new role lists the Chat permission (All covers it)', () {
      final String controller = File('lib/controller/add_edit_role_controller.dart').readAsStringSync();
      expect(RegExp(r'PermissionModel\(title: StoreChat\.permission, isActive: (true|false)\)').allMatches(controller).length, 2);
      expect(StoreChat.permission, 'Chat', reason: 'the title the store panel saves');
    });
  });

  group('identity', () {
    test('the owner is the store: their own uid, their own name', () {
      final StoreChatIdentity id = StoreChatIdentity.of(uid: owner, role: 'vendor', actorName: 'Olivia Owner', ownPhoto: 'o.png');
      expect(id.storeId, owner);
      expect(id.isEmployee, isFalse);
      expect(id.canChat, isTrue);
      expect(id.ready, isTrue);
      expect(id.displayName, 'Olivia Owner');
      expect(id.photo, 'o.png');
      expect(id.auditFields, isEmpty, reason: "the owner's messages are unchanged");
    });

    test("an employee is the store: the owner's uid and the store's name", () {
      final StoreChatIdentity id = StoreChatIdentity.of(
        uid: employee,
        role: 'employee',
        actorName: 'Eve Employee',
        storeOwnerId: owner,
        ownerName: 'Olivia Owner',
        storeName: 'Pizza Place',
        storePhoto: 'store.png',
        permissions: fullRole(),
      );
      expect(id.storeId, owner);
      expect(id.actorId, employee);
      expect(id.isEmployee, isTrue);
      expect(id.ready, isTrue);
      expect(id.displayName, 'Pizza Place');
      expect(id.photo, 'store.png');
      expect(id.auditFields, {'sentByUserId': employee, 'sentByName': 'Eve Employee'});
    });

    test("an employee's name falls back to the owner's when the store has none", () {
      final StoreChatIdentity id = StoreChatIdentity.of(uid: employee, role: 'employee', storeOwnerId: owner, ownerName: 'Olivia Owner', storeName: '  ', permissions: fullRole());
      expect(id.displayName, 'Olivia Owner');
    });

    test("an employee whose store owner is unknown never uses their own uid", () {
      expect(StoreChat.storeChatId(role: 'employee', uid: employee, storeOwnerId: null), '');
      expect(StoreChat.storeChatId(role: 'employee', uid: employee, storeOwnerId: ' '), '');
      final StoreChatIdentity id = StoreChatIdentity.of(uid: employee, role: 'employee', permissions: fullRole());
      expect(id.storeId, '');
      expect(id.ready, isFalse);
    });

    test('an employee without the permission is not ready', () {
      final StoreChatIdentity id = StoreChatIdentity.of(uid: employee, role: 'employee', storeOwnerId: owner, permissions: fullRole(chat: false));
      expect(id.storeId, owner);
      expect(id.canChat, isFalse);
      expect(id.ready, isFalse);
    });
  });

  group('queries and writes use the store identity', () {
    final StoreChatIdentity staff = StoreChatIdentity.of(uid: employee, role: 'employee', actorName: 'Eve', storeOwnerId: owner, storeName: 'Pizza Place', permissions: fullRole());
    final StoreChatIdentity boss = StoreChatIdentity.of(uid: owner, role: 'vendor', actorName: 'Olivia');

    test('inbox, unread badge, seen, support thread, admin inbox and sender are all the owner', () {
      for (final StoreChatIdentity id in [staff, boss]) {
        expect(id.inboxMemberId, owner);
        expect(id.unreadReceiverId, owner);
        expect(id.supportThreadId, owner);
        expect(id.adminInboxStoreId, owner);
        expect(id.senderId, owner);
      }
    });

    test("the store's own messages: the owner's, and the employee's older ones", () {
      expect(staff.isStoreSide(owner), isTrue);
      expect(staff.isStoreSide(employee), isTrue);
      expect(staff.isStoreSide('customer'), isFalse);
      expect(staff.isStoreSide(''), isFalse);
      expect(boss.isStoreSide(owner), isTrue);
      expect(boss.isStoreSide('customer'), isFalse);
    });

    test('the audit fields are written only when set', () {
      final Map<String, dynamic> ownerMessage = ConversationModel(id: 'm', senderId: owner, receiverId: 'c').toJson();
      expect(ownerMessage.containsKey('sentByUserId'), isFalse);
      expect(ownerMessage.containsKey('sentByName'), isFalse);
      final Map<String, dynamic> staffMessage = ConversationModel(id: 'm', senderId: staff.senderId, receiverId: 'c', sentByUserId: staff.auditFields['sentByUserId'], sentByName: staff.auditFields['sentByName']).toJson();
      expect(staffMessage['senderId'], owner);
      expect(staffMessage['sentByUserId'], employee);
      expect(staffMessage['sentByName'], 'Eve');
      expect(ConversationModel.fromJson(staffMessage).sentByUserId, employee);
    });

    group('wiring (source checks)', () {
      String read(String path) => File(path).readAsStringSync();

      test('the restaurant inbox lists, counts and opens by the store identity', () {
        final String inbox = read('lib/app/chat_screens/restaurant_inbox_screen.dart');
        expect(inbox.contains('FireStoreUtils.storeOrderInboxQuery(store.inboxMemberId)'), isTrue);
        expect(inbox.contains('receiverId: store.unreadReceiverId'), isTrue);
        expect(inbox.contains('"senderId": store.storeId'), isTrue);
        expect(inbox.contains('arrayContains: FireStoreUtils.getCurrentUid()'), isFalse);
        final String utils = read('lib/utils/fire_store_utils.dart');
        expect(utils.contains('.where("sender_receiver_id", arrayContains: storeChatId.trim())'), isTrue);
      });

      test('the admin inbox and Help & Support use the store identity', () {
        expect(read('lib/app/chat_screens/admin_inbox_screen.dart').contains('isEqualTo: store.adminInboxStoreId'), isTrue);
        final String help = read('lib/app/help_support_screen/help_support_screen.dart');
        expect(help.contains('.doc(controller.threadId.value)'), isTrue);
        expect(help.contains('.doc(FireStoreUtils.getCurrentUid())'), isFalse);
        expect(read('lib/controller/help_support_controller.dart').contains('FireStoreUtils.setSeen(threadId: threadId.value)'), isTrue);
      });

      test('the chat screen writes, marks seen and pushes as the store', () {
        final String chat = read('lib/controller/chat_controller.dart');
        expect(chat.contains('senderId: _writerId'), isTrue);
        expect(chat.contains("'senderId': _writerId"), isTrue);
        expect(chat.contains('senderId.value = me.senderId'), isTrue);
        expect(read('lib/app/chat_screens/chat_screen.dart').contains('controller.isStoreSide(chatmodel.senderId)'), isTrue);
      });
    });
  });

  test('the new labels are translated in every language', () {
    for (final lang in [enUS, lnAr, deGR, trFR, hiIN, jaJP, ptPO, ruRU, zhCH]) {
      expect(lang['You don’t have permission to view chats.'], isNotNull);
      expect(lang['Chat'], isNotNull);
    }
  });
}
