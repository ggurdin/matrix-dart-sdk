/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
 *   Copyright (C) 2019, 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:convert';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/encryption.dart';
import 'package:famedlysdk/src/event.dart';
import 'package:test/test.dart';

import 'fake_matrix_api.dart';
import 'fake_matrix_localizations.dart';

void main() {
  /// All Tests related to the Event
  group('Event', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = '!4fsdfjisjf:server.abc';
    final senderID = '@alice:server.abc';
    final type = 'm.room.message';
    final msgtype = 'm.text';
    final body = 'Hello World';
    final formatted_body = '<b>Hello</b> World';

    final contentJson =
        '{"msgtype":"$msgtype","body":"$body","formatted_body":"$formatted_body","m.relates_to":{"m.in_reply_to":{"event_id":"\$1234:example.com"}}}';

    var jsonObj = <String, dynamic>{
      'event_id': id,
      'sender': senderID,
      'origin_server_ts': timestamp,
      'type': type,
      'room_id': '1234',
      'status': 2,
      'content': contentJson,
    };
    var client = Client('testclient', debug: true, httpClient: FakeMatrixApi());
    var event = Event.fromJson(
        jsonObj, Room(id: '!localpart:server.abc', client: client));

    test('Create from json', () async {
      jsonObj.remove('status');
      jsonObj['content'] = json.decode(contentJson);
      expect(event.toJson(), jsonObj);
      jsonObj['content'] = contentJson;

      expect(event.eventId, id);
      expect(event.senderId, senderID);
      expect(event.status, 2);
      expect(event.text, body);
      expect(event.formattedText, formatted_body);
      expect(event.body, body);
      expect(event.type, EventTypes.Message);
      expect(event.isReply, true);
      jsonObj['state_key'] = '';
      var state = Event.fromJson(jsonObj, null);
      expect(state.eventId, id);
      expect(state.stateKey, '');
      expect(state.status, 2);
    });
    test('Test all EventTypes', () async {
      Event event;

      jsonObj['type'] = 'm.room.avatar';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomAvatar);

      jsonObj['type'] = 'm.room.name';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomName);

      jsonObj['type'] = 'm.room.topic';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomTopic);

      jsonObj['type'] = 'm.room.aliases';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomAliases);

      jsonObj['type'] = 'm.room.canonical_alias';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomCanonicalAlias);

      jsonObj['type'] = 'm.room.create';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomCreate);

      jsonObj['type'] = 'm.room.join_rules';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomJoinRules);

      jsonObj['type'] = 'm.room.member';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomMember);

      jsonObj['type'] = 'm.room.power_levels';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomPowerLevels);

      jsonObj['type'] = 'm.room.guest_access';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.GuestAccess);

      jsonObj['type'] = 'm.room.history_visibility';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.HistoryVisibility);

      jsonObj['type'] = 'm.room.message';
      jsonObj['content'] = json.decode(jsonObj['content']);

      jsonObj['content'].remove('m.relates_to');
      jsonObj['content']['msgtype'] = 'm.notice';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Notice);

      jsonObj['content']['msgtype'] = 'm.emote';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Emote);

      jsonObj['content']['msgtype'] = 'm.image';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Image);

      jsonObj['content']['msgtype'] = 'm.video';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Video);

      jsonObj['content']['msgtype'] = 'm.audio';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Audio);

      jsonObj['content']['msgtype'] = 'm.file';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.File);

      jsonObj['content']['msgtype'] = 'm.location';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Location);

      jsonObj['type'] = 'm.room.message';
      jsonObj['content']['msgtype'] = 'm.text';
      jsonObj['content']['m.relates_to'] = {};
      jsonObj['content']['m.relates_to']['m.in_reply_to'] = {
        'event_id': '1234',
      };
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Reply);
    });

    test('redact', () async {
      final redactJsonObj = Map<String, dynamic>.from(jsonObj);
      final testTypes = [
        EventTypes.RoomMember,
        EventTypes.RoomCreate,
        EventTypes.RoomJoinRules,
        EventTypes.RoomPowerLevels,
        EventTypes.RoomAliases,
        EventTypes.HistoryVisibility,
      ];
      for (final testType in testTypes) {
        redactJsonObj['type'] = testType;
        final room =
            Room(id: '1234', client: Client('testclient', debug: true));
        final redactionEventJson = {
          'content': {'reason': 'Spamming'},
          'event_id': '143273582443PhrSn:example.org',
          'origin_server_ts': 1432735824653,
          'redacts': id,
          'room_id': '1234',
          'sender': '@example:example.org',
          'type': 'm.room.redaction',
          'unsigned': {'age': 1234}
        };
        var redactedBecause = Event.fromJson(redactionEventJson, room);
        var event = Event.fromJson(redactJsonObj, room);
        event.setRedactionEvent(redactedBecause);
        expect(event.redacted, true);
        expect(event.redactedBecause.toJson(), redactedBecause.toJson());
        expect(event.content.isEmpty, true);
        redactionEventJson.remove('redacts');
        expect(event.unsigned['redacted_because'], redactionEventJson);
      }
    });

    test('remove', () async {
      var event = Event.fromJson(
          jsonObj, Room(id: '1234', client: Client('testclient', debug: true)));
      final removed1 = await event.remove();
      event.status = 0;
      final removed2 = await event.remove();
      expect(removed1, false);
      expect(removed2, true);
    });

    test('sendAgain', () async {
      var matrix =
          Client('testclient', debug: true, httpClient: FakeMatrixApi());
      await matrix.checkServer('https://fakeServer.notExisting');
      await matrix.login('test', '1234');

      var event = Event.fromJson(
          jsonObj, Room(id: '!1234:example.com', client: matrix));
      final resp1 = await event.sendAgain();
      event.status = -1;
      final resp2 = await event.sendAgain(txid: '1234');
      expect(resp1, null);
      expect(resp2.startsWith('\$event'), true);

      await matrix.dispose(closeDatabase: true);
    });

    test('requestKey', () async {
      var matrix =
          Client('testclient', debug: true, httpClient: FakeMatrixApi());
      await matrix.checkServer('https://fakeServer.notExisting');
      await matrix.login('test', '1234');

      var event = Event.fromJson(
          jsonObj, Room(id: '!1234:example.com', client: matrix));
      String exception;
      try {
        await event.requestKey();
      } catch (e) {
        exception = e;
      }
      expect(exception, 'Session key not unknown');

      var event2 = Event.fromJson({
        'event_id': id,
        'sender': senderID,
        'origin_server_ts': timestamp,
        'type': 'm.room.encrypted',
        'room_id': '1234',
        'status': 2,
        'content': json.encode({
          'msgtype': 'm.bad.encrypted',
          'body': DecryptError.UNKNOWN_SESSION,
          'algorithm': 'm.megolm.v1.aes-sha2',
          'ciphertext': 'AwgAEnACgAkLmt6qF84IK++J7UDH2Za1YVchHyprqTqsg...',
          'device_id': 'RJYKSTBOIE',
          'sender_key': 'IlRMeOPX2e0MurIyfWEucYBRVOEEUMrOHqn/8mLqMjA',
          'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ'
        }),
      }, Room(id: '!1234:example.com', client: matrix));

      await event2.requestKey();

      await matrix.dispose(closeDatabase: true);
    });
    test('requestKey', () async {
      jsonObj['state_key'] = '@alice:example.com';
      var event = Event.fromJson(
          jsonObj, Room(id: '!localpart:server.abc', client: client));
      expect(event.stateKeyUser.id, '@alice:example.com');
    });
    test('canRedact', () async {
      expect(event.canRedact, true);
    });
    test('getLocalizedBody', () async {
      final matrix =
          Client('testclient', debug: true, httpClient: FakeMatrixApi());
      final room = Room(id: '!1234:example.com', client: matrix);
      var event = Event.fromJson({
        'content': {
          'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
          'displayname': 'Alice Margatroid',
          'membership': 'join'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'age': 1234,
          'redacted_because': {
            'content': {'reason': 'Spamming'},
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'redacts': '\$143273582443PhrSn:example.org',
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'type': 'm.room.redaction',
            'unsigned': {'age': 1234}
          }
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'Landing',
          'info': {
            'h': 200,
            'mimetype': 'image/png',
            'size': 73602,
            'thumbnail_info': {
              'h': 200,
              'mimetype': 'image/png',
              'size': 73602,
              'w': 140
            },
            'thumbnail_url': 'mxc://matrix.org/sHhqkFCvSkFwtmvtETOtKnLP',
            'w': 140
          },
          'url': 'mxc://matrix.org/sHhqkFCvSkFwtmvtETOtKnLP'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.sticker',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'reason': 'Spamming'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'redacts': '\$143273582443PhrSn:example.org',
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.redaction',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'aliases': ['#somewhere:example.org', '#another:example.org']
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': 'example.org',
        'type': 'm.room.aliases',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'aliases': ['#somewhere:example.org', '#another:example.org']
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': 'example.org',
        'type': 'm.room.aliases',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'alias': '#somewhere:localhost'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.canonical_alias',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'creator': '@example:example.org',
          'm.federate': true,
          'predecessor': {
            'event_id': '\$something:example.org',
            'room_id': '!oldroom:example.org'
          },
          'room_version': '1'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.create',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'This room has been replaced',
          'replacement_room': '!newroom:example.org'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.tombstone',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'join_rule': 'public'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.join_rules',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
          'displayname': 'Alice Margatroid',
          'membership': 'join'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'invite'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member'
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'leave'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'join'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'ban'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'join'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'join'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'invite'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'invite'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'join'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'leave'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'invite'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'leave'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@alice:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'invite'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'ban': 50,
          'events': {'m.room.name': 100, 'm.room.power_levels': 100},
          'events_default': 0,
          'invite': 50,
          'kick': 50,
          'notifications': {'room': 20},
          'redact': 50,
          'state_default': 50,
          'users': {'@example:localhost': 100},
          'users_default': 0
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.power_levels',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'name': 'The room name'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.name',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'topic': 'A room topic'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.topic',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'info': {'h': 398, 'mimetype': 'image/jpeg', 'size': 31037, 'w': 394},
          'url': 'mxc://example.org/JWEIFJgwEIhweiWJE'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.avatar',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'history_visibility': 'shared'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.history_visibility',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'rotation_period_ms': 604800000,
          'rotation_period_msgs': 100
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.encryption',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()),
          'Example activatedEndToEndEncryption. needPantalaimonWarning');

      event = Event.fromJson({
        'content': {
          'body': 'This is an example text message',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<b>This is an example text message</b>',
          'msgtype': 'm.text'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()),
          'This is an example text message');

      event = Event.fromJson({
        'content': {
          'body': 'thinks this is an example emote',
          'format': 'org.matrix.custom.html',
          'formatted_body': 'thinks <b>this</b> is an example emote',
          'msgtype': 'm.emote'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()),
          '* thinks this is an example emote');

      event = Event.fromJson({
        'content': {
          'body': 'This is an example notice',
          'format': 'org.matrix.custom.html',
          'formatted_body': 'This is an <strong>example</strong> notice',
          'msgtype': 'm.notice'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()),
          'This is an example notice');

      event = Event.fromJson({
        'content': {
          'body': 'filename.jpg',
          'info': {'h': 398, 'mimetype': 'image/jpeg', 'size': 31037, 'w': 394},
          'msgtype': 'm.image',
          'url': 'mxc://example.org/JWEIFJgwEIhweiWJE'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'something-important.doc',
          'filename': 'something-important.doc',
          'info': {'mimetype': 'application/msword', 'size': 46144},
          'msgtype': 'm.file',
          'url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'Bee Gees - Stayin Alive',
          'info': {
            'duration': 2140786,
            'mimetype': 'audio/mpeg',
            'size': 1563685
          },
          'msgtype': 'm.audio',
          'url': 'mxc://example.org/ffed755USFFxlgbQYZGtryd'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'Big Ben, London, UK',
          'geo_uri': 'geo:51.5008,0.1247',
          'info': {
            'thumbnail_info': {
              'h': 300,
              'mimetype': 'image/jpeg',
              'size': 46144,
              'w': 300
            },
            'thumbnail_url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe'
          },
          'msgtype': 'm.location'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'Gangnam Style',
          'info': {
            'duration': 2140786,
            'h': 320,
            'mimetype': 'video/mp4',
            'size': 1563685,
            'thumbnail_info': {
              'h': 300,
              'mimetype': 'image/jpeg',
              'size': 46144,
              'w': 300
            },
            'thumbnail_url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe',
            'w': 480
          },
          'msgtype': 'm.video',
          'url': 'mxc://example.org/a526eYUSFFxlgbQYZmo442'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);
    });
  });
}
