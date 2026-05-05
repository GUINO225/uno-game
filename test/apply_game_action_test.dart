import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/services/supabase_game_service.dart';

Map<String, dynamic> baseState() => <String, dynamic>{
  'players': <String>['u1', 'u2'],
  'hands': <String, dynamic>{'u1': <String>['2♥', '8♣'], 'u2': <String>['5♦']},
  'drawPile': <String>['9♠', 'JK♣'],
  'discardPile': <String>['4♥'],
  'topDiscard': '4♥',
  'currentTurn': 'u1',
  'requiredSuit': null,
  'pendingDrawCount': 0,
  'winnerId': null,
  'revision': 0,
};

void main() {
  test('playCard removes card and changes discard/turn', () {
    final state = applyGameAction(baseState(), {'type': 'playCard', 'actorId': 'u1', 'cardId': '2♥'});
    expect((state['hands'] as Map)['u1'], isNot(contains('2♥')));
    expect(state['topDiscard'], '2♥');
    expect((state['discardPile'] as List).last, '2♥');
    expect(state['currentTurn'], 'u2');
  });

  test('drawCard adds card', () {
    final state = applyGameAction(baseState(), {'type': 'drawCard', 'actorId': 'u1'});
    expect(((state['hands'] as Map)['u1'] as List).length, 3);
  });

  test('2 and joker increase pending draw', () {
    final s1 = applyGameAction(baseState(), {'type': 'playCard', 'actorId': 'u1', 'cardId': '2♥'});
    expect(s1['pendingDrawCount'], 2);
    final s2 = applyGameAction(baseState(), {'type': 'playCard', 'actorId': 'u1', 'cardId': 'JK♣'});
    expect(s2['pendingDrawCount'], 8);
  });

  test('8 chooses suit', () {
    final s = applyGameAction(baseState(), {'type': 'playCard', 'actorId': 'u1', 'cardId': '8♣', 'chosenSuit': '♠'});
    expect(s['requiredSuit'], '♠');
  });

  test('J and 10 grant extra turn', () {
    final sJ = applyGameAction(baseState(), {'type': 'playCard', 'actorId': 'u1', 'cardId': 'J♥'});
    expect(sJ['currentTurn'], 'u1');
    final s10 = applyGameAction(baseState(), {'type': 'playCard', 'actorId': 'u1', 'cardId': '10♥'});
    expect(s10['currentTurn'], 'u1');
  });

  test('winner when hand empty', () {
    final state = baseState();
    state['hands'] = {'u1': ['2♥'], 'u2': ['5♦']};
    final s = applyGameAction(state, {'type': 'playCard', 'actorId': 'u1', 'cardId': '2♥'});
    expect(s['winnerId'], 'u1');
  });
}
