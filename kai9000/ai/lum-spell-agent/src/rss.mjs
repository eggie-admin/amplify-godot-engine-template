import { XMLParser } from 'fast-xml-parser';
import { doctrine } from './doctrine.mjs';

const parser = new XMLParser({
  ignoreAttributes: false,
  processEntities: false,
  trimValues: true,
});

function textValue(value) {
  if (value == null) return '';
  if (typeof value === 'string' || typeof value === 'number') return String(value);
  if (typeof value === 'object') return String(value['#text'] ?? value._text ?? '');
  return '';
}

function stripMarkup(value) {
  return textValue(value)
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

function safeUrl(input) {
  const url = new URL(input);
  if (url.protocol !== 'https:') throw new Error('RSS URL must use HTTPS');
  if (!doctrine.rss.allowed_hosts.includes(url.hostname)) {
    throw new Error(`RSS host is not allowed: ${url.hostname}`);
  }
  return url;
}

function normalizeRssItem(item) {
  const max = doctrine.rss.max_summary_chars;
  return {
    title: stripMarkup(item?.title),
    link: textValue(item?.link),
    published: textValue(item?.pubDate || item?.published || item?.updated),
    creator: textValue(item?.['dc:creator'] || item?.author?.name || item?.author),
    summary_excerpt: stripMarkup(item?.description || item?.summary || item?.content).slice(0, max),
  };
}

function normalizeAtomItem(item) {
  const links = Array.isArray(item?.link) ? item.link : [item?.link].filter(Boolean);
  const alternate = links.find((link) => link?.['@_rel'] === 'alternate') || links[0];
  return {
    title: stripMarkup(item?.title),
    link: textValue(alternate?.['@_href'] || alternate),
    published: textValue(item?.published || item?.updated),
    creator: textValue(item?.author?.name || item?.author),
    summary_excerpt: stripMarkup(item?.summary || item?.content).slice(0, doctrine.rss.max_summary_chars),
  };
}

export async function fetchRecentChanges(limit = 5, feedUrl = process.env.LUM_RSS_URL || doctrine.rss.default_url) {
  const boundedLimit = Math.max(1, Math.min(Number(limit) || 5, doctrine.rss.max_items));
  const url = safeUrl(feedUrl);
  const response = await fetch(url, {
    headers: { 'user-agent': 'KAI9000-Lum-RSS/0.1' },
    signal: AbortSignal.timeout(7000),
  });

  if (!response.ok) throw new Error(`RSS fetch failed with HTTP ${response.status}`);
  const xml = await response.text();
  if (xml.length > 1_000_000) throw new Error('RSS response exceeds 1 MB limit');

  const doc = parser.parse(xml);
  let items = doc?.rss?.channel?.item;
  if (items) {
    if (!Array.isArray(items)) items = [items];
    return items.slice(0, boundedLimit).map(normalizeRssItem);
  }

  let entries = doc?.feed?.entry;
  if (entries) {
    if (!Array.isArray(entries)) entries = [entries];
    return entries.slice(0, boundedLimit).map(normalizeAtomItem);
  }

  return [];
}
