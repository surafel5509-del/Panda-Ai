import 'package:flutter_test/flutter_test.dart';
import 'package:panda_ai_studio/data/models/models.dart';

void main() {
  group('extractList', () {
    test('accepts a bare list', () {
      final List<dynamic> result = extractList(<dynamic>[
        <String, dynamic>{'id': 'a'},
      ]);
      expect(result.length, 1);
    });

    test('unwraps known keys', () {
      final List<dynamic> result = extractList(<String, dynamic>{
        'voices': <dynamic>[
          <String, dynamic>{'id': 'v1'},
        ],
      });
      expect(result.length, 1);
    });

    test('unwraps nested data envelopes', () {
      final List<dynamic> result = extractList(<String, dynamic>{
        'data': <String, dynamic>{
          'voices': <dynamic>['x', 'y'],
        },
      });
      expect(result.length, 2);
    });

    test('returns empty for unexpected shapes', () {
      expect(extractList(<String, dynamic>{'nope': 1}), isEmpty);
      expect(extractList(null), isEmpty);
    });
  });

  group('Voice.fromJson', () {
    test('parses documented field names', () {
      final Voice v = Voice.fromJson(<String, dynamic>{
        'voice_id': 'voice-123456',
        'name': 'Aria',
        'gender': 'female',
        'description': 'Warm and clear',
        'style': 'narration',
        'language': 'en',
      });
      expect(v.id, 'voice-123456');
      expect(v.name, 'Aria');
      expect(v.isFemale, isTrue);
      expect(v.isMale, isFalse);
    });

    test('handles bare string voices', () {
      final Voice v = Voice.fromJson('voice-abcdef');
      expect(v.id, 'voice-abcdef');
      expect(v.name, 'voice-abcdef');
    });

    test('normalizes gender spellings', () {
      expect(Voice.fromJson(<String, dynamic>{'id': 'x', 'gender': 'Male'}).isMale, isTrue);
      expect(Voice.fromJson(<String, dynamic>{'id': 'x', 'gender': 'F'}).isFemale, isTrue);
    });
  });

  group('ChatResult.fromJson', () {
    test('parses a simple reply shape', () {
      final ChatResult r = ChatResult.fromJson(<String, dynamic>{
        'reply': 'Hello!',
        'session_id': 's-1',
      });
      expect(r.reply, 'Hello!');
      expect(r.sessionId, 's-1');
    });

    test('parses OpenAI-style choices', () {
      final ChatResult r = ChatResult.fromJson(<String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'message': <String, dynamic>{'role': 'assistant', 'content': 'Hi there'},
          },
        ],
      });
      expect(r.reply, 'Hi there');
    });

    test('handles a bare string payload', () {
      expect(ChatResult.fromJson('plain answer').reply, 'plain answer');
    });
  });

  group('LibraryItem', () {
    test('round-trips through JSON', () {
      final LibraryItem item = LibraryItem(
        id: '1',
        title: 'Demo',
        text: 'Hello world',
        voiceId: 'voice-1',
        voiceName: 'Aria',
        style: 'natural',
        model: 's1',
        speed: 1.0,
        volume: 0.0,
        filePath: '/tmp/a.mp3',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final LibraryItem copy = LibraryItem.fromJson(item.toJson());
      expect(copy.id, item.id);
      expect(copy.title, item.title);
      expect(copy.speed, 1.0);
      expect(copy.createdAt, item.createdAt);
    });
  });

  group('ChatMessage', () {
    test('round-trips through JSON string', () {
      final ChatMessage m = ChatMessage.user('test message');
      final ChatMessage copy = ChatMessage.fromJsonString(m.toJsonString());
      expect(copy.content, 'test message');
      expect(copy.isUser, isTrue);
    });
  });
}
