import { api, hydrateIcons, toast } from './app.js';
import { t } from './i18n.js';

export function bindProfilePhoto({ input, preview, box, clear, label, initialUrl = '', savePhoto, onUpdated }) {
  let currentUrl = String(initialUrl || '').trim();
  let busy = false;

  function setLabel(key) {
    if (!label) return;
    label.dataset.i18n = key;
    label.textContent = t(key);
  }

  function renderPreview(url) {
    if (!preview) return;
    if (url) {
      const img = document.createElement('img');
      img.src = url;
      img.alt = t('common.photo');
      preview.replaceChildren(img);
      return;
    }
    const icon = document.createElement('span');
    icon.className = 'icon';
    icon.dataset.icon = 'user';
    icon.dataset.size = '34';
    preview.replaceChildren(icon);
    hydrateIcons(preview);
  }

  function renderClear() {
    clear?.classList.toggle('hidden', !currentUrl);
  }

  function setIdleLabel() {
    setLabel(currentUrl ? 'auth.signup.photo_change' : 'auth.signup.photo_pick');
  }

  function setBusy(value) {
    busy = value;
    if (box) {
      box.classList.toggle('is-busy', value);
      box.setAttribute('aria-busy', String(value));
    }
    if (input) input.disabled = value;
    if (clear) clear.disabled = value;
  }

  function applyUrl(url) {
    currentUrl = String(url || '').trim();
    renderPreview(currentUrl);
    renderClear();
    setIdleLabel();
  }

  function setUrl(url) {
    if (busy) return;
    applyUrl(url);
  }

  function getUrl() {
    return currentUrl;
  }

  input?.addEventListener('change', async () => {
    const file = input.files?.[0];
    if (!file || busy) return;
    const previous = currentUrl;
    setBusy(true);
    setLabel('common.photo_uploading');
    try {
      const url = await api.uploadAvatar(file);
      const result = await savePhoto(url);
      applyUrl(url);
      toast(t('common.photo_saved'), 'ok');
      onUpdated?.(url, result);
    } catch (error) {
      renderPreview(previous);
      setIdleLabel();
      toast(error.message || t('common.photo_failed'), 'err');
    } finally {
      input.value = '';
      setBusy(false);
    }
  });

  clear?.addEventListener('click', async () => {
    if (busy || !currentUrl) return;
    const previous = currentUrl;
    setBusy(true);
    setLabel('common.photo_uploading');
    try {
      const result = await savePhoto(null);
      applyUrl('');
      toast(t('common.photo_removed'), 'ok');
      onUpdated?.(null, result);
    } catch (error) {
      renderPreview(previous);
      setIdleLabel();
      toast(error.message || t('common.photo_failed'), 'err');
    } finally {
      setBusy(false);
    }
  });

  applyUrl(currentUrl);

  return {
    setUrl,
    getUrl,
    isBusy: () => busy
  };
}
