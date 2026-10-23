import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

export const SUPABASE_URL = 'https://zduewrigxxnpxuommnfr.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpkdWV3cmlneHhucHh1b21tbmZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3OTM2MzIsImV4cCI6MjEwODM2OTYzMn0.V33W2WuexQH85_hRAK_83Ils3SARzcRBrjqbwOz6Qfc';

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const SESSION_KEY = 'kageon_session';
const SUPPORTED_ROLES = ['admin', 'client', 'assistant'];

export class AuthError extends Error {
  constructor(message = 'Tu sesión expiró. Vuelve a entrar.') {
    super(message);
    this.name = 'AuthError';
  }
}

export function authError(message) {
  return new AuthError(message);
}

function parseSession(raw) {
  try {
    return JSON.parse(raw || 'null');
  } catch {
    return null;
  }
}

export function getSession(role = null) {
  const session = sanitizeSession(parseSession(localStorage.getItem(SESSION_KEY)));
  if (!session?.role || !session?.token || !session?.profile) return null;
  if (role && session.role !== role) return null;
  return session;
}

export function setSession(session) {
  if (!session?.role || !session?.token) return;
  localStorage.setItem(SESSION_KEY, JSON.stringify({
    role: session.role,
    token: session.token,
    profile: session.profile
  }));
}

export function clearSession() {
  localStorage.removeItem(SESSION_KEY);
}

function sanitizeSession(session) {
  if (!session) return null;
  return session;
}

export function requireRole(role, redirect = 'login.html') {
  const session = getSession(role);
  if (!session) {
    clearSession();
    location.replace(redirect);
    return null;
  }
  return session;
}

export function handleAuthFailure(error, redirect = 'login.html') {
  if (error?.message === 'AUTH' || error?.name === 'AuthError') {
    clearSession();
    location.replace(redirect);
    return true;
  }
  return false;
}

export function friendlyError(error) {
  const message = String(error?.message || error || '');
  if (/AUTH/i.test(message)) return 'Tu sesión expiró. Vuelve a entrar.';
  if (/FORBIDDEN/i.test(message)) return 'No tienes permiso para hacer esto.';
  if (/PENDING/i.test(message)) return 'Tu cuenta está pendiente de aprobación.';
  if (/REJECTED/i.test(message)) return 'Tu cuenta fue rechazada. Contacta a Kageon Global.';
  if (/SUSPENDED/i.test(message)) return 'Tu cuenta está suspendida. Contacta a Kageon Global.';
  if (/EMAIL_TAKEN/i.test(message)) return 'Ese correo ya está registrado.';
  if (/INVALID_CREDENTIALS/i.test(message)) return 'Correo o contraseña incorrectos.';
  if (/PASSWORD_WEAK/i.test(message)) return 'La contraseña debe tener al menos 8 caracteres.';
  if (/PASSWORD_MISMATCH|password.*match/i.test(message)) return 'Las contraseñas no coinciden.';
  if (/INVALID/i.test(message)) return 'Revisa la información e inténtalo de nuevo.';
  if (/NOT_FOUND/i.test(message)) return 'No encontramos ese registro.';
  if (/CONFLICT/i.test(message)) return 'La acción entra en conflicto con datos existentes.';
  if (/JOB_CLOSED/i.test(message)) return 'Esta vacante ya no está abierta.';
  if (/NO_ENGAGEMENT/i.test(message)) return 'No tienes una asignación activa.';
  if (/OVERLAP/i.test(message)) return 'Este bloque se cruza con otra entrada del mismo día.';
  if (/FUTURE_DATE/i.test(message)) return 'No puedes registrar horas en una fecha futura.';
  if (/INVALID_TIME/i.test(message)) return 'La hora de salida debe ser posterior a la de entrada.';
  if (/failed to fetch|network|load failed/i.test(message)) return 'Error de conexión. Revisa tu internet.';
  return message || 'Algo salió mal. Inténtalo de nuevo.';
}

export function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const numberFormat = new Intl.NumberFormat('en-US', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2
});

export function money(value) {
  return '$' + numberFormat.format(Number(value) || 0);
}

export function minutesToHours(value) {
  return (Number(value) || 0) / 60;
}

export function hoursText(value) {
  const hours = minutesToHours(value);
  return hours.toFixed(2) + ' h';
}

export function fmtDate(value) {
  if (!value) return '-';
  const raw = String(value);
  const datePart = raw.length >= 10 ? raw.slice(0, 10) : raw;
  const [y, m, d] = datePart.split('-');
  if (!y || !m || !d) return raw;
  return `${d}/${m}/${y}`;
}

export function fmtTime(value) {
  if (!value) return '-';
  return String(value).slice(0, 5);
}

export function todayISO() {
  const now = new Date();
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 10);
}

export function initials(name) {
  const parts = String(name || '?').trim().split(/\s+/).filter(Boolean);
  return (parts[0]?.[0] || '?') + (parts[1]?.[0] || '');
}

const ICONS = {
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  user: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  userPlus: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" x2="19" y1="8" y2="14"/><line x1="22" x2="16" y1="11" y2="11"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  wallet: '<path d="M21 12V7a2 2 0 0 0-2-2H5a2 2 0 0 0 0 4h16v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7"/><circle cx="17" cy="12" r="1"/>',
  calendar: '<rect x="3" y="4" width="18" height="18" rx="3"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  chart: '<path d="M3 3v18h18"/><path d="M7 15l4-5 3 3 5-7"/>',
  home: '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/>',
  building: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M9 15h2M13 15h2"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="M16 17l5-5-5-5"/><path d="M21 12H9"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  trash: '<path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/>',
  pencil: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
  check: '<path d="M20 6 9 17l-5-5"/>',
  alert: '<path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
  eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
  eyeOff: '<path d="M3 3l18 18"/><path d="M10.6 10.6a2 2 0 0 0 2.8 2.8"/><path d="M9.9 5.2A10.8 10.8 0 0 1 12 5c6.5 0 10 7 10 7a17.6 17.6 0 0 1-3.2 4.2"/><path d="M6.2 6.2A17.4 17.4 0 0 0 2 12s3.5 7 10 7a10.7 10.7 0 0 0 4.1-.8"/>',
  menu: '<path d="M3 6h18M3 12h18M3 18h18"/>',
  bell: '<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>',
  settings: '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3"/><path d="M2 14h4M10 8h4M18 16h4"/>',
  shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/>',
  sparkles: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4"/><path d="M6.3 6.3l2.4 2.4M15.3 15.3l2.4 2.4M17.7 6.3l-2.4 2.4M8.7 15.3l-2.4 2.4"/>',
  x: '<path d="M18 6 6 18M6 6l12 12"/>',
  arrowRight: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  send: '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
  fileText: '<path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/><polyline points="14 2 14 8 20 8"/><line x1="16" x2="8" y1="13" y2="13"/><line x1="16" x2="8" y1="17" y2="17"/><line x1="10" x2="8" y1="9" y2="9"/>'
};

export function hydrateIcons(root = document) {
  root.querySelectorAll('[data-icon]').forEach(el => {
    const name = el.getAttribute('data-icon');
    const path = ICONS[name];
    if (!path) return;
    el.innerHTML = `<svg viewBox="0 0 24 24" width="${el.dataset.size || 18}" height="${el.dataset.size || 18}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${path}</svg>`;
  });
}

export function animateNumber(el, value, format = v => numberFormat.format(v)) {
  if (!el) return;
  const target = Number(value) || 0;
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduced) {
    el.textContent = format(target);
    return;
  }
  const start = performance.now();
  const duration = 650;
  const tick = now => {
    const progress = Math.min(1, (now - start) / duration);
    const eased = 1 - Math.pow(1 - progress, 3);
    el.textContent = format(target * eased);
    if (progress < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}

export function setLoading(button, loading) {
  if (!button) return;
  button.disabled = loading;
  button.classList.toggle('loading', loading);
}

export function toast(message, type = 'ok', timeout = 4200) {
  let container = document.querySelector('.toasts');
  if (!container) {
    container = document.createElement('div');
    container.className = 'toasts';
    document.body.appendChild(container);
  }
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  const dot = document.createElement('span');
  dot.className = 'toast-dot';
  const text = document.createElement('div');
  text.textContent = message;
  el.append(dot, text);
  container.appendChild(el);
  setTimeout(() => {
    el.classList.add('leaving');
    setTimeout(() => el.remove(), 320);
  }, timeout);
}

async function rpc(functionName, args = {}) {
  const { data, error } = await supabase.rpc(functionName, args);
  if (error) {
    throw new Error(error.message || friendlyError(error.message));
  }
  if (data && typeof data === 'object' && data.ok === false) {
    throw new Error(data.error || 'No se pudo completar la operación.');
  }
  return data;
}

export const api = {
  async health() {
    try {
      return await rpc('portal_health');
    } catch {
      return null;
    }
  },

  async signupClient(payload) {
    const data = await rpc('portal_signup_client', {
      p_email: payload.email,
      p_password: payload.password,
      p_company: payload.company,
      p_contact_name: payload.contact_name,
      p_phone: payload.phone || null,
      p_country: payload.country || null,
      p_timezone: payload.timezone || null
    });
    return data;
  },

  async signupAssistant(payload) {
    const data = await rpc('portal_signup_assistant', {
      p_email: payload.email,
      p_password: payload.password,
      p_first_name: payload.first_name,
      p_full_name: payload.full_name,
      p_headline: payload.headline || null,
      p_skills: payload.skills || [],
      p_languages: payload.languages || [],
      p_certifications: payload.certifications || [],
      p_availability: payload.availability || null,
      p_photo_url: payload.photo_url || null,
      p_video_url: payload.video_url || null,
      p_phone: payload.phone || null,
      p_country: payload.country || null,
      p_timezone: payload.timezone || null
    });
    return data;
  },

  async login(email, password) {
    try {
      const data = await rpc('portal_login', { p_email: email, p_password: password });
      const session = { role: data.role, token: data.token, profile: data.profile };
      setSession(session);
      return { ok: true, session };
    } catch (error) {
      return { ok: false, error: friendlyError(error) };
    }
  },

  async adminLogin(username, password) {
    try {
      const data = await rpc('portal_admin_login', { p_username: username, p_password: password });
      const session = { role: data.role, token: data.token, profile: data.profile };
      setSession(session);
      return { ok: true, session };
    } catch (error) {
      return { ok: false, error: friendlyError(error) };
    }
  },

  async logout() {
    const session = getSession();
    if (session?.token) {
      try {
        await rpc('portal_logout', { p_token: session.token });
      } catch {}
    }
    clearSession();
  },

  async session() {
    const session = getSession();
    if (!session?.token) return null;
    try {
      const data = await rpc('portal_session', { p_token: session.token });
      const nextSession = { role: data.role, token: session.token, profile: data.profile };
      setSession(nextSession);
      return nextSession;
    } catch (error) {
      if (handleAuthFailure(error)) return null;
      throw error;
    }
  },

  async markNotifications(ids = null) {
    const session = getSession();
    if (!session?.token) throw authError();
    return await rpc('portal_mark_notifications', { p_token: session.token, p_ids: ids });
  },

  async clientDashboard() {
    const session = requireRole('client');
    try {
      return await rpc('portal_client_dashboard', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async clientCandidates() {
    const session = requireRole('client');
    try {
      return await rpc('portal_client_candidates', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async clientSelectCandidate(applicationId) {
    const session = requireRole('client');
    try {
      return await rpc('portal_client_select_candidate', { p_token: session.token, p_application_id: applicationId });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async clientEngagements() {
    const session = requireRole('client');
    try {
      return await rpc('portal_client_engagements', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async clientTime(from = null, to = null) {
    const session = requireRole('client');
    try {
      return await rpc('portal_client_time', { p_token: session.token, p_from: from, p_to: to });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async clientStatements(from = null, to = null) {
    const session = requireRole('client');
    try {
      return await rpc('portal_client_statements', { p_token: session.token, p_from: from, p_to: to });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async clientProfile() {
    const session = requireRole('client');
    try {
      return await rpc('portal_client_profile', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async clientUpdateProfile(payload) {
    const session = requireRole('client');
    try {
      return await rpc('portal_client_update_profile', {
        p_token: session.token,
        p_company: payload.company,
        p_contact_name: payload.contact_name,
        p_phone: payload.phone || null,
        p_country: payload.country || null,
        p_timezone: payload.timezone || null
      });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantDashboard() {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_dashboard', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantProfile() {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_profile', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantUpdateProfile(payload) {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_update_profile', {
        p_token: session.token,
        p_first_name: payload.first_name,
        p_full_name: payload.full_name,
        p_headline: payload.headline || null,
        p_skills: payload.skills || [],
        p_languages: payload.languages || [],
        p_certifications: payload.certifications || [],
        p_availability: payload.availability || null,
        p_photo_url: payload.photo_url || null,
        p_video_url: payload.video_url || null,
        p_phone: payload.phone || null,
        p_country: payload.country || null,
        p_timezone: payload.timezone || null
      });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantJobs() {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_jobs', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantApply(jobId, note = null) {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_apply', { p_token: session.token, p_job_id: jobId, p_note: note });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantApplications() {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_applications', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantTime(from = null, to = null) {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_time', { p_token: session.token, p_from: from, p_to: to });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantAddTime(payload) {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_add_time', {
        p_token: session.token,
        p_date: payload.date,
        p_start: payload.start,
        p_end: payload.end,
        p_engagement_id: payload.engagement_id || null
      });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantDeleteTime(entryId) {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_delete_time', { p_token: session.token, p_entry_id: entryId });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantIgnoreMissing(engagementId, date) {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_ignore_missing', { p_token: session.token, p_engagement_id: engagementId, p_date: date });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async assistantEarnings(from = null, to = null) {
    const session = requireRole('assistant');
    try {
      return await rpc('portal_assistant_earnings', { p_token: session.token, p_from: from, p_to: to });
    } catch (error) {
      if (handleAuthFailure(error, 'login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminDashboard() {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_dashboard', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminClients() {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_clients', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminClientSave(payload) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_client_save', {
        p_token: session.token,
        p_client_id: payload.client_id,
        p_company: payload.company,
        p_contact_name: payload.contact_name,
        p_phone: payload.phone || null,
        p_country: payload.country || null,
        p_timezone: payload.timezone || null,
        p_status: payload.status || null,
        p_notes: payload.notes || null,
        p_new_password: payload.new_password || null
      });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminAssistants() {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_assistants', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminAssistantSave(payload) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_assistant_save', {
        p_token: session.token,
        p_assistant_id: payload.assistant_id,
        p_first_name: payload.first_name,
        p_full_name: payload.full_name,
        p_headline: payload.headline || null,
        p_phone: payload.phone || null,
        p_country: payload.country || null,
        p_timezone: payload.timezone || null,
        p_status: payload.status || null,
        p_notes: payload.notes || null,
        p_new_password: payload.new_password || null
      });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminJobs() {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_jobs', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminJobSave(payload) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_job_save', {
        p_token: session.token,
        p_job_id: payload.job_id || null,
        p_title: payload.title,
        p_client_id: payload.client_id || null,
        p_description: payload.description || null,
        p_schedule: payload.schedule || null,
        p_rate: payload.rate || 0,
        p_status: payload.status || 'draft'
      });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminJobStatus(jobId, status) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_job_status', { p_token: session.token, p_job_id: jobId, p_status: status });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminApplications() {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_applications', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminApplicationStatus(applicationId, status) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_application_status', { p_token: session.token, p_application_id: applicationId, p_status: status });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminSendCandidates(applicationIds, clientId) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_send_candidates', { p_token: session.token, p_application_ids: applicationIds, p_client_id: clientId });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminEngagements() {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_engagements', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminEngagementCreate(payload) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_engagement_create', {
        p_token: session.token,
        p_client_id: payload.client_id,
        p_assistant_id: payload.assistant_id,
        p_client_rate: payload.client_rate,
        p_assistant_rate: payload.assistant_rate,
        p_work_days: payload.work_days || [1,2,3,4,5],
        p_start_date: payload.start_date || null,
        p_end_date: payload.end_date || null,
        p_job_id: payload.job_id || null,
        p_application_id: payload.application_id || null
      });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminEngagementEnd(engagementId, endDate = null) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_engagement_end', { p_token: session.token, p_engagement_id: engagementId, p_end_date: endDate });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminTime(from = null, to = null, assistantId = null) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_time', { p_token: session.token, p_from: from, p_to: to, p_assistant_id: assistantId });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminTimeUpdate(payload) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_time_update', {
        p_token: session.token,
        p_entry_id: payload.entry_id,
        p_date: payload.date,
        p_start: payload.start,
        p_end: payload.end,
        p_reason: payload.reason
      });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminTimeDelete(entryId, reason) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_time_delete', { p_token: session.token, p_entry_id: entryId, p_reason: reason });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminBilling(from = null, to = null) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_billing', { p_token: session.token, p_from: from, p_to: to });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminSettings() {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_settings', { p_token: session.token });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminSettingsSave(fxRate, timezone = null) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_settings_save', { p_token: session.token, p_fx_rate: fxRate, p_timezone: timezone });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async adminChangePassword(currentPassword, newPassword) {
    const session = requireRole('admin', 'admin-login.html');
    try {
      return await rpc('portal_admin_change_password', { p_token: session.token, p_current_password: currentPassword, p_new_password: newPassword });
    } catch (error) {
      if (handleAuthFailure(error, 'admin-login.html')) throw error;
      throw new Error(friendlyError(error));
    }
  },

  async uploadAvatar(file) {
    const session = getSession();
    if (!session) throw authError();
    if (!file) throw new Error('Selecciona una imagen.');
    if (file.size > 2 * 1024 * 1024) throw new Error('La foto debe pesar 2 MB o menos.');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) throw new Error('Solo se permiten imágenes JPG, PNG o WebP.');
    const ext = file.type === 'image/png' ? 'png' : file.type === 'image/webp' ? 'webp' : 'jpg';
    const name = `${crypto.randomUUID()}.${ext}`;
    const path = `avatars/${name}`;
    const { error } = await supabase.storage.from('avatars').upload(path, file, { upsert: false, contentType: file.type });
    if (error) throw new Error(friendlyError(error));
    const { data } = supabase.storage.from('avatars').getPublicUrl(path);
    return data.publicUrl;
  }
};

export async function bootstrap() {
  hydrateIcons();
  try {
    await rpc('portal_health');
    return true;
  } catch {
    return false;
  }
}
