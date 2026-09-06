import { readFile } from 'node:fs/promises';

const doctrineUrl = new URL('../doctrine.json', import.meta.url);
export const doctrine = JSON.parse(await readFile(doctrineUrl, 'utf8'));

function parseOptions(raw = '') {
  const options = {};
  if (!raw.trim()) return options;

  for (const part of raw.split(',')) {
    const entry = part.trim();
    if (!entry) continue;
    const eq = entry.indexOf('=');
    if (eq === -1) {
      options[entry] = true;
      continue;
    }
    const key = entry.slice(0, eq).trim();
    let value = entry.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (key) options[key] = value;
  }
  return options;
}

function splitTargetAndOptions(raw = '') {
  const parts = raw.split(/\s+WITH\s+/i);
  return {
    target: (parts.shift() || '').replace(/^ON\s+/i, '').trim() || 'workspace',
    options: parseOptions(parts.join(' WITH ')),
  };
}

export function parseSpellMessage(message) {
  if (typeof message !== 'string') return null;
  const raw = message.trim();
  if (!raw) return null;

  const patterns = [
    /^\/(?:cast|spell)\s+([A-Z][A-Z0-9_-]*)(?:\s+(.*))?$/i,
    /^CAST\s+([A-Z][A-Z0-9_-]*)(?:\s+(.*))?$/i,
    /^@LUM\s+(?:CAST\s+)?([A-Z][A-Z0-9_-]*)(?:\s+(.*))?$/i,
  ];

  let match = null;
  for (const pattern of patterns) {
    match = raw.match(pattern);
    if (match) break;
  }
  if (!match) return null;

  const requested = match[1].toUpperCase();
  const spellName = doctrine.aliases?.[requested] || requested;
  const spell = doctrine.spells?.[spellName];
  if (!spell) return null;

  const { target, options } = splitTargetAndOptions(match[2] || '');

  return {
    schema: doctrine.schema,
    spell: spellName,
    alias: requested === spellName ? null : requested,
    target,
    options,
    intent: spell.intent,
    risk: spell.risk,
    approval: spell.approval,
    apply: spell.apply === true,
    raw,
  };
}

export function explainSpell(name) {
  const requested = String(name || '').toUpperCase();
  const spellName = doctrine.aliases?.[requested] || requested;
  const spell = doctrine.spells?.[spellName];
  if (!spell) return null;
  return { name: spellName, ...spell };
}

export function listSpells() {
  return Object.entries(doctrine.spells).map(([name, value]) => ({ name, ...value }));
}
