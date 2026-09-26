import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samepace/models/message.dart';
import 'package:samepace/screens/group/message_row.dart';

ChatMessage _msg(String id, String text, {String? replyTo}) => ChatMessage(
  id: id,
  groupId: 'g',
  senderId: 'anna',
  content: text,
  createdAt: DateTime(2026, 9, 26, 18, 5),
  replyTo: replyTo,
);

void main() {
  testWidgets('reply quote, reactions, double tap and swipe to reply', (
    tester,
  ) async {
    var replied = 0;
    var doubleTapped = 0;
    String? tappedReaction;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageRow(
            message: _msg('2', 'Passt, bis dann!', replyTo: '1'),
            mine: false,
            hasReply: true,
            quoted: _msg('1', 'Samstag 18 Uhr im Prater?'),
            quotedName: 'Anna',
            reactions: const [
              MessageReaction(messageId: '2', userId: 'a', emoji: '❤️'),
              MessageReaction(messageId: '2', userId: 'b', emoji: '❤️'),
              MessageReaction(messageId: '2', userId: 'c', emoji: '😂'),
            ],
            myEmoji: '❤️',
            onReply: () => replied++,
            onLongPress: () {},
            onDoubleTap: () => doubleTapped++,
            onReactionTap: (e) => tappedReaction = e,
          ),
        ),
      ),
    );

    // The quoted message sits in the bubble.
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Samstag 18 Uhr im Prater?'), findsOneWidget);
    // Same emoji from two people shows once with a count.
    expect(find.text('❤️ 2'), findsOneWidget);
    expect(find.text('😂'), findsOneWidget);

    await tester.tap(find.text('😂'));
    expect(tappedReaction, '😂');

    await tester.tap(find.text('Passt, bis dann!'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Passt, bis dann!'));
    await tester.pumpAndSettle();
    expect(doubleTapped, 1);

    await tester.drag(find.text('Passt, bis dann!'), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(replied, 1);
  });

  testWidgets('a reply to a deleted message says so', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageRow(
            message: _msg('2', 'ok', replyTo: 'gone'),
            mine: true,
            hasReply: true,
            quoted: null,
            quotedName: null,
            reactions: const [],
            myEmoji: null,
            onReply: () {},
            onLongPress: () {},
            onDoubleTap: () {},
            onReactionTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Nachricht nicht mehr verfügbar'), findsOneWidget);
  });
}
