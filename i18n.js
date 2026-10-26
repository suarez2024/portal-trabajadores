const SUPPORTED = ['en', 'es'];
const DEFAULT_LANG = 'en';
const STORAGE_KEY = 'kg_lang';
const cache = new Map();

let current = DEFAULT_LANG;
let messages = {};
let fallback = {};

function normalizeLang(value) {
  const raw = String(value || '').toLowerCase().split(/[-_]/)[0];
  return SUPPORTED.includes(raw) ? raw : null;
}

export function detectLanguage() {
  const stored = normalizeLang(localStorage.getItem(STORAGE_KEY));
  if (stored) return stored;

  const fromUrl = normalizeLang(new URLSearchParams(location.search).get('lang'));
  if (fromUrl) return fromUrl;

  for (const candidate of navigator.languages || [navigator.language]) {
    const lang = normalizeLang(candidate);
    if (lang) return lang;
  }

  return DEFAULT_LANG;
}

function unescapeValue(value) {
  return value
    .replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/\\n/g, '\n')
    .replace(/\\t/g, '\t')
    .replace(/\\r/g, '\r')
    .replace(/\\\\/g, '\\');
}

export function parseProperties(text) {
  const result = {};
  const lines = String(text || '').replace(/^\uFEFF/, '').split(/\r?\n/);
  let buffer = '';

  for (const rawLine of lines) {
    const line = buffer + rawLine;
    buffer = '';

    if (/\\$/.test(line) && !/\\\\$/.test(line)) {
      buffer = line.slice(0, -1);
      continue;
    }

    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#') || trimmed.startsWith('!')) continue;

    let index = -1;
    for (let i = 0; i < line.length; i += 1) {
      if (line[i] === '\\') {
        i += 1;
        continue;
      }
      if (line[i] === '=' || line[i] === ':') {
        index = i;
        break;
      }
    }

    if (index === -1) continue;

    const key = line.slice(0, index).trim();
    const value = line.slice(index + 1).trim();
    if (!key) continue;
    result[key] = unescapeValue(value);
  }

  return result;
}

async function loadLocale(lang) {
  if (cache.has(lang)) return cache.get(lang);

  const response = await fetch(`i18n/messages_${lang}.properties`, { cache: 'no-cache' });
  if (!response.ok) throw new Error(`Could not load locale ${lang}`);

  const parsed = parseProperties(await response.text());
  cache.set(lang, parsed);
  return parsed;
}

export function t(key, params = {}) {
  const template = messages[key] ?? fallback[key] ?? key;
  return String(template).replace(/\{(\w+)\}/g, (match, name) => (
    Object.prototype.hasOwnProperty.call(params, name) ? String(params[name]) : match
  ));
}

export function applyI18n(root = document) {
  root.querySelectorAll('[data-i18n]').forEach(el => {
    el.textContent = t(el.getAttribute('data-i18n'));
  });

  root.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
    el.setAttribute('placeholder', t(el.getAttribute('data-i18n-placeholder')));
  });

  root.querySelectorAll('[data-i18n-title]').forEach(el => {
    el.setAttribute('title', t(el.getAttribute('data-i18n-title')));
  });

  root.querySelectorAll('[data-i18n-aria]').forEach(el => {
    el.setAttribute('aria-label', t(el.getAttribute('data-i18n-aria')));
  });

  updateLanguageControls();
}

function closeLanguagePicker(picker) {
  picker.classList.remove('open');
  picker.querySelector('.lang-picker-button')?.setAttribute('aria-expanded', 'false');
  const menu = picker.querySelector('.lang-picker-menu');
  if (menu) menu.hidden = true;
}

function ensureLanguagePicker() {
  let picker = document.querySelector('.lang-picker');
  if (picker) return picker;

  picker = document.createElement('div');
  picker.className = 'lang-picker';
  picker.innerHTML = [
    '<button type="button" class="lang-picker-button" aria-haspopup="listbox" aria-expanded="false">',
    '<span class="lang-picker-value"></span>',
    '<span class="lang-picker-caret" aria-hidden="true"></span>',
    '</button>',
    '<div class="lang-picker-menu" role="listbox" hidden>',
    '<button type="button" class="lang-picker-option" role="option"></button>',
    '</div>'
  ].join('');
  document.body.appendChild(picker);

  const button = picker.querySelector('.lang-picker-button');
  const menu = picker.querySelector('.lang-picker-menu');
  const option = picker.querySelector('.lang-picker-option');

  button.addEventListener('click', event => {
    event.stopPropagation();
    if (menu.hidden) {
      picker.classList.add('open');
      button.setAttribute('aria-expanded', 'true');
      menu.hidden = false;
      option.focus();
    } else {
      closeLanguagePicker(picker);
    }
  });

  option.addEventListener('click', () => {
    const next = option.getAttribute('data-lang');
    closeLanguagePicker(picker);
    if (next) setLanguage(next);
  });

  document.addEventListener('click', event => {
    if (!picker.contains(event.target)) closeLanguagePicker(picker);
  });

  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !menu.hidden) {
      closeLanguagePicker(picker);
      button.focus();
    }
  });

  return picker;
}

function updateLanguageControls() {
  const picker = ensureLanguagePicker();
  const button = picker.querySelector('.lang-picker-button');
  const value = picker.querySelector('.lang-picker-value');
  const menu = picker.querySelector('.lang-picker-menu');
  const option = picker.querySelector('.lang-picker-option');
  const other = current === 'es' ? 'en' : 'es';

  value.textContent = current.toUpperCase();
  option.textContent = other.toUpperCase();
  option.setAttribute('data-lang', other);

  const label = t('common.language');
  button.setAttribute('aria-label', label);
  button.setAttribute('title', label);
  menu.setAttribute('aria-label', label);
}

export async function initI18n() {
  current = detectLanguage();

  const [active, base] = await Promise.all([
    loadLocale(current),
    current === DEFAULT_LANG ? Promise.resolve(null) : loadLocale(DEFAULT_LANG)
  ]);

  messages = active;
  fallback = base || active;

  document.documentElement.lang = current;
  applyI18n();
  bindLanguageControls();
  return current;
}

export async function setLanguage(lang) {
  const next = normalizeLang(lang) || DEFAULT_LANG;
  current = next;
  localStorage.setItem(STORAGE_KEY, next);
  messages = await loadLocale(next);
  if (!fallback || Object.keys(fallback).length === 0) {
    fallback = next === DEFAULT_LANG ? messages : await loadLocale(DEFAULT_LANG);
  }

  document.documentElement.lang = next;
  applyI18n();
  window.dispatchEvent(new CustomEvent('kg:lang', { detail: { lang: next } }));
}

export function bindLanguageControls() {
  updateLanguageControls();
}

export function getLang() {
  return current;
}

export function locale() {
  return current === 'es' ? 'es-MX' : 'en-US';
}

export function formatDate(value, options = {}) {
  if (!value) return '-';
  const date = value instanceof Date ? value : new Date(`${value}T00:00:00`);
  if (Number.isNaN(date.getTime())) return '-';
  return new Intl.DateTimeFormat(locale(), {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    ...options
  }).format(date);
}

export function formatNumber(value, options = {}) {
  return new Intl.NumberFormat(locale(), options).format(Number(value) || 0);
}

export function formatCurrency(value, currency = 'USD', options = {}) {
  return new Intl.NumberFormat(locale(), {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
    ...options
  }).format(Number(value) || 0);
}

export { SUPPORTED, DEFAULT_LANG };
