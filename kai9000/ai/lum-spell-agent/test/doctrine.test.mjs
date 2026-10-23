import test from 'node:test';
import assert from 'node:assert/strict';
import { parseSpellMessage } from '../src/doctrine.mjs';

test('parses explicit CAST syntax', () => {
  const cast = parseSpellMessage('CAST SCAN ON repo');
  assert.equal(cast.spell, 'SCAN');
  assert.equal(cast.target, 'repo');
  assert.equal(cast.risk, 'read_only');
  assert.equal(cast.apply, false);
});

test('parses @Lum syntax and WITH options', () => {
  const cast = parseSpellMessage('@Lum CAST CURE ON game/Main.gd WITH scope=testing, reason="parser bug"');
  assert.equal(cast.spell, 'CURE');
  assert.equal(cast.target, 'game/Main.gd');
  assert.equal(cast.options.scope, 'testing');
  assert.equal(cast.options.reason, 'parser bug');
  assert.equal(cast.approval, 'required_for_apply');
});

test('aliases LIBRA to SCAN', () => {
  const cast = parseSpellMessage('/cast libra service');
  assert.equal(cast.spell, 'SCAN');
  assert.equal(cast.alias, 'LIBRA');
});

test('ordinary chat is not silently treated as a command', () => {
  assert.equal(parseSpellMessage('please cure this code'), null);
});

test('ULTIMA is proposal-only and cannot auto-apply', () => {
  const cast = parseSpellMessage('CAST ULTIMA ON proposed/jrpg-dating-sim');
  assert.equal(cast.risk, 'high');
  assert.equal(cast.approval, 'proposal_only');
  assert.equal(cast.apply, false);
});
