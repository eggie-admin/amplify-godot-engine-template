# KAI 9000 Lum Spell Agent

Testing-lane bridge for LuHm OS that turns explicit Final Fantasy-inspired spell commands into structured AI coding doctrine.

This is an homage-style command vocabulary only. It is not affiliated with or endorsed by Square Enix or any Final Fantasy wiki.

## Architecture

Browser/WebView chat -> `jquery.lum-spell-agent.js` -> `/api/lum/cast` -> OpenAI Agents SDK Lum agent -> bounded tools.

The browser never receives an OpenAI API key. The service reads `OPENAI_API_KEY` from its server environment.

## KAI MAGE syntax

Only explicit command forms are parsed as spells. Ordinary chat remains ordinary chat.

```text
CAST SCAN ON repo
@Lum CAST CURE ON game/Main.gd WITH scope=testing
/cast protect /api/lum/cast
CAST PHOENIX ON checkpoint:KAI9000_ACODEX_SECURE_COCKPIT_GATE_20260906
CAST ULTIMA ON proposed/jrpg-dating-sim
```

High-risk names do not grant high-risk permission. `METEOR` and `ULTIMA` are proposal-only, and `PHOENIX` requires an explicit checkpoint.

Promotion remains:

```text
testing/jrpg-dating-sim
        -> proposed/jrpg-dating-sim
        -> LuHm-OS
```

## RSS reference lane

Default source:

```text
https://finalfantasywiki.com/wiki/Special:RecentChanges?feed=rss
```

The feed path follows MediaWiki Recent Changes RSS conventions and can be replaced with `LUM_RSS_URL` if the wiki changes routing.

RSS ingestion is intentionally metadata-only:

- allowlisted HTTPS host
- 7 second request timeout
- 1 MB response ceiling
- maximum 10 items
- title/link/date/creator
- maximum 280 character sanitized summary excerpt
- no article-body scraping

## Run

```bash
cd kai9000/ai/lum-spell-agent
npm install
npm test
npm start
```

Optional environment variables:

```text
OPENAI_API_KEY       server-side API credential
OPENAI_MODEL         model override
HOST                 defaults to 127.0.0.1
PORT                 defaults to 8788
LUM_ALLOWED_ORIGIN   optional exact browser/WebView origin
LUM_RSS_URL          optional allowlisted Final Fantasy Wiki feed URL
```

## jQuery/WebView hookup

Load jQuery and `kai9000/web/jquery.lum-spell-agent.js`, then bind a chat container:

```javascript
$('#lum-chat').lumSpellAgent({
  output: '#lum-output',
  endpoint: '/api/lum/cast',
  includeRss: function (message) {
    return /wiki|lore|final fantasy/i.test(message);
  },
  context: function () {
    return {
      lane: 'testing/jrpg-dating-sim',
      target: 'LuHm-OS'
    };
  }
});
```

Events emitted by the plugin:

```text
lum:before
lum:reply
lum:error
```

## Current safety boundary

The first bridge has one external tool: sanitized RSS recent changes. It deliberately has no shell, GitHub-write, deploy, or filesystem-write tool. Mutation spells therefore produce plans and patch guidance until a later reviewed adapter explicitly grants a bounded write capability.
