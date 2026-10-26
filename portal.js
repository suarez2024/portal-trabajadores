import { hydrateIcons, setLoading, toast, initials, fmtDate, fmtTime, hoursText, money } from './app.js';
import { applyI18n, t } from './i18n.js';

export function updateUserAvatar(profile) {
  const avatarEl = document.getElementById('user-avatar');
  if (!avatarEl || !profile) return;
  const name = profile.company || profile.full_name || profile.first_name || profile.contact_name || profile.username || '';
  avatarEl.textContent = initials(name);
  const url = String(profile.photo_url || '').trim();
  if (!url) return;
  const img = document.createElement('img');
  img.src = url;
  img.alt = '';
  img.addEventListener('error', () => { avatarEl.textContent = initials(name); }, { once: true });
  avatarEl.replaceChildren(img);
}

export function initShell({ session, role, activeNav, onLogout }) {
  hydrateIcons();
  applyI18n();

  const sidebar = document.getElementById('sidebar');
  const mobileToggle = document.getElementById('mobile-toggle');
  const scrim = document.getElementById('scrim');
  const logoutBtn = document.getElementById('logout-btn');

  mobileToggle?.addEventListener('click', () => {
    sidebar?.classList.add('open');
    scrim?.classList.add('open');
  });

  scrim?.addEventListener('click', () => {
    sidebar?.classList.remove('open');
    scrim?.classList.remove('open');
  });

  document.querySelectorAll('.nav-item').forEach(item => {
    item.classList.toggle('active', item.dataset.nav === activeNav);
  });

  if (session?.profile) {
    const nameEl = document.getElementById('user-name');
    const roleEl = document.getElementById('user-role');
    if (nameEl) {
      nameEl.textContent = session.profile.company || session.profile.full_name || session.profile.first_name || session.profile.contact_name || session.profile.username || '-';
    }
    if (roleEl) roleEl.textContent = t(role === 'admin' ? 'portal.role_admin' : role === 'client' ? 'portal.role_client' : 'portal.role_assistant');
    updateUserAvatar(session.profile);
  }

  logoutBtn?.addEventListener('click', async () => {
    if (onLogout) await onLogout();
  });

  window.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
      sidebar?.classList.remove('open');
      scrim?.classList.remove('open');
    }
  });
}

export function setSection(name) {
  document.querySelectorAll('.page-section').forEach(section => {
    section.classList.toggle('active', section.dataset.section === name);
  });
  document.querySelectorAll('.nav-item[data-section]').forEach(item => {
    item.classList.toggle('active', item.dataset.section === name);
  });
}

export function showView(id) {
  document.getElementById(id)?.classList.remove('hidden');
}

export function hideView(id) {
  document.getElementById(id)?.classList.add('hidden');
}

export function fillSelect(select, items, getLabel, getValue) {
  if (!select) return;
  select.innerHTML = '';
  for (const item of items) {
    const option = document.createElement('option');
    option.value = getValue(item);
    option.textContent = getLabel(item);
    select.appendChild(option);
  }
}

export function renderTable(tbody, rows, renderRow) {
  if (!tbody) return;
  tbody.innerHTML = '';
  if (!rows.length) {
    const tr = document.createElement('tr');
    tr.innerHTML = '<td colspan="99" class="muted center">-</td>';
    tbody.appendChild(tr);
    return;
  }
  for (const row of rows) {
    tbody.appendChild(renderRow(row));
  }
}

export function openDialog(id) {
  const dialog = document.getElementById(id);
  dialog?.showModal?.();
}

export function closeDialog(id) {
  const dialog = document.getElementById(id);
  dialog?.close?.();
}

export function getCheckedValues(form, name) {
  return [...form.querySelectorAll(`input[name="${name}"]:checked`)].map(el => Number(el.value));
}

export { hydrateIcons, setLoading, toast, initials, fmtDate, fmtTime, hoursText, money, applyI18n, t };
