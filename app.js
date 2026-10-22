import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

export const SUPABASE_URL = 'https://qcqhxtoffjnhvbqltrnu.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjcWh4dG9mZmpuaHZicWx0cm51Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NDkzMzcsImV4cCI6MjEwODIyNTMzN30.0uyZM_wUrIktt0JlqbO9lXipes6yHrj6sSAA3a6pvBM';

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const LEGACY_ADMIN_USER = 'Admin';
const LEGACY_ADMIN_PASS = 'Admin2026';
const SESSION_KEY = 'usuario';

export class AuthError extends Error {
  constructor(message = 'Tu sesión expiró. Vuelve a entrar.') {
    super(message);
    this.name = 'AuthError';
  }
}

export function authError(message) {
  return new AuthError(message);
}

function rpcError(data) {
  if (data?.code === 'auth') return authError(data.error);
  return new Error(data?.error || 'No se pudo completar la operación.');
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

export function hours(value) {
  return (Number(value) || 0).toFixed(2) + ' h';
}

export function fmtDate(value) {
  if (!value) return '—';
  const raw = String(value);
  const datePart = raw.length >= 10 ? raw.slice(0, 10) : raw;
  const [y, m, d] = datePart.split('-');
  if (!y || !m || !d) return raw;
  return `${d}/${m}/${y}`;
}

export function fmtTime(value) {
  if (!value) return '—';
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

export function calcularHoras(entrada, salida, lunch) {
  if (!entrada || !salida) return 0;
  const [eh, em] = entrada.split(':').map(Number);
  const [sh, sm] = salida.split(':').map(Number);
  if ([eh, em, sh, sm].some(n => Number.isNaN(n))) return 0;
  let total = (sh * 60 + sm) - (eh * 60 + em);
  if (total < 0) total += 24 * 60;
  const effective = total - (Number(lunch) || 0);
  return Math.max(0, effective / 60);
}

export function sumHours(jornadas) {
  return (jornadas || []).reduce((sum, j) => sum + (Number(j.horas_calculadas) || 0), 0);
}

export function totalPago(jornadas, tarifa) {
  return sumHours(jornadas) * (Number(tarifa) || 0);
}

function sanitizeSession(session) {
  if (!session || !session.usuario) return session;
  const { password, ...usuario } = session.usuario;
  return { ...session, usuario };
}

export function getSession() {
  try {
    return sanitizeSession(JSON.parse(localStorage.getItem(SESSION_KEY) || 'null'));
  } catch {
    return null;
  }
}

export function setSession(session) {
  localStorage.setItem(SESSION_KEY, JSON.stringify(sanitizeSession(session)));
}

export function clearSession() {
  localStorage.removeItem(SESSION_KEY);
}

export function requireRole(role, redirect, requireToken = false) {
  const session = getSession();
  if (!session || session.rol !== role || (requireToken && !session.token)) {
    clearSession();
    location.replace(redirect);
    return null;
  }
  return session;
}

export function handleAuthFailure(error, redirect) {
  if (error?.name === 'AuthError') {
    clearSession();
    location.replace(redirect);
    return true;
  }
  return false;
}

export function friendlyError(error) {
  const message = String(error?.message || error || '');
  if (/invalid api key/i.test(message)) return 'La conexión con Supabase falló (clave inválida).';
  if (/failed to fetch|network|load failed/i.test(message)) return 'No se pudo conectar. Revisa tu conexión a internet.';
  if (/duplicate key|23505|ya está registrado/i.test(message)) return 'Ese email ya está registrado.';
  if (/violates row-level security|permission denied|401|403/i.test(message)) return 'No tienes permisos para esta acción.';
  return message || 'Ocurrió un error inesperado.';
}

const ICONS = {
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  user: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  wallet: '<path d="M21 12V7a2 2 0 0 0-2-2H5a2 2 0 0 0 0 4h16v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7"/><circle cx="17" cy="12" r="1"/>',
  calendar: '<rect x="3" y="4" width="18" height="18" rx="3"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  chart: '<path d="M3 3v18h18"/><path d="M7 15l4-5 3 3 5-7"/>',
  home: '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/>',
  building: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M9 15h2M13 15h2"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="M16 17l5-5-5-5"/><path d="M21 12H9"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  trash: '<path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/>',
  check: '<path d="M20 6 9 17l-5-5"/>',
  alert: '<path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
  eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
  eyeOff: '<path d="M3 3l18 18"/><path d="M10.6 10.6a2 2 0 0 0 2.8 2.8"/><path d="M9.9 5.2A10.8 10.8 0 0 1 12 5c6.5 0 10 7 10 7a17.6 17.6 0 0 1-3.2 4.2"/><path d="M6.2 6.2A17.4 17.4 0 0 0 2 12s3.5 7 10 7a10.7 10.7 0 0 0 4.1-.8"/>',
  menu: '<path d="M3 6h18M3 12h18M3 18h18"/>',
  refresh: '<path d="M21 12a9 9 0 1 1-2.6-6.4"/><path d="M21 3v6h-6"/>',
  shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/>',
  sparkles: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4"/><path d="M6.3 6.3l2.4 2.4M15.3 15.3l2.4 2.4M17.7 6.3l-2.4 2.4M8.7 15.3l-2.4 2.4"/>',
  x: '<path d="M18 6 6 18M6 6l12 12"/>',
  arrowRight: '<path d="M5 12h14M13 6l6 6-6 6"/>'
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

function sanitizeUser(row) {
  if (!row) return null;
  const { password, ...rest } = row;
  return rest;
}

function normalizeTrabajadores(rows = []) {
  return rows.map(row => {
    const { password, clientes, ...trabajador } = row;
    return {
      ...trabajador,
      tarifa_hora: Number(trabajador.tarifa_hora) || 0,
      cliente_nombre: row.cliente_nombre ?? clientes?.empresa ?? '—'
    };
  });
}

function normalizeJornadas(rows = []) {
  return rows.map(row => {
    const nested = row.trabajadores || {};
    return {
      id: row.id,
      trabajador_id: row.trabajador_id,
      fecha: row.fecha,
      hora_entrada: row.hora_entrada,
      hora_salida: row.hora_salida,
      minutos_lunch: row.minutos_lunch,
      horas_calculadas: Number(row.horas_calculadas) || 0,
      notas: row.notas,
      creado_en: row.creado_en,
      trabajador_nombre: row.trabajador_nombre ?? nested.nombre ?? '—',
      tarifa_hora: Number(row.tarifa_hora ?? nested.tarifa_hora) || 0,
      cliente_id: row.cliente_id ?? nested.cliente_id ?? null,
      cliente_nombre: row.cliente_nombre ?? nested.clientes?.empresa ?? '—'
    };
  });
}

function normalizeClientes(rows = []) {
  return rows.map(row => {
    const { password, ...cliente } = row;
    return cliente;
  });
}

async function assertUniqueEmail(email, exceptTable, exceptId) {
  const normalized = String(email || '').trim().toLowerCase();
  const queries = [];
  if (exceptTable !== 'clientes') {
    queries.push(supabase.from('clientes').select('id').ilike('email', normalized).limit(1));
  }
  if (exceptTable !== 'trabajadores') {
    queries.push(supabase.from('trabajadores').select('id').ilike('email', normalized).limit(1));
  }
  const results = await Promise.all(queries);
  const duplicate = results.some(result => (result.data || []).some(row => row.id !== exceptId));
  if (duplicate) throw new Error('Ese email ya está registrado.');
}

export const api = {
  secure: false,

  async init() {
    try {
      const { error } = await supabase.rpc('portal_ping');
      if (!error) {
        this.secure = true;
      } else {
        const missing = error.code === 'PGRST202'
          || /could not find|does not exist|schema cache/i.test(error.message || '');
        this.secure = !missing;
      }
    } catch {
      this.secure = false;
    }
    return this.secure;
  },

  async login(email, password) {
    const cleanEmail = String(email || '').trim();
    if (!cleanEmail || !password) {
      return { ok: false, error: 'Escribe tu email y contraseña.' };
    }

    if (this.secure) {
      const { data, error } = await supabase.rpc('portal_login', {
        p_email: cleanEmail,
        p_password: password
      });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) return { ok: false, error: data?.error || 'Credenciales incorrectas.' };
      const session = { rol: data.rol, usuario: data.usuario, token: data.token };
      setSession(session);
      return { ok: true, session };
    }

    const trabajadores = await supabase
      .from('trabajadores')
      .select('*')
      .ilike('email', cleanEmail)
      .eq('password', password)
      .limit(1);
    if (trabajadores.error) throw new Error(friendlyError(trabajadores.error));
    const trabajador = trabajadores.data?.[0];
    if (trabajador) {
      if (trabajador.activo === false) {
        return { ok: false, error: 'Tu cuenta está desactivada. Contacta al administrador.' };
      }
      const session = { rol: 'trabajador', usuario: sanitizeUser(trabajador) };
      setSession(session);
      return { ok: true, session };
    }

    const clientes = await supabase
      .from('clientes')
      .select('*')
      .ilike('email', cleanEmail)
      .eq('password', password)
      .limit(1);
    if (clientes.error) throw new Error(friendlyError(clientes.error));
    const cliente = clientes.data?.[0];
    if (cliente) {
      const session = { rol: 'cliente', usuario: sanitizeUser(cliente) };
      setSession(session);
      return { ok: true, session };
    }

    return { ok: false, error: 'Credenciales incorrectas.' };
  },

  async adminLogin(usuario, password) {
    const cleanUser = String(usuario || '').trim();
    if (!cleanUser || !password) {
      return { ok: false, error: 'Escribe usuario y contraseña.' };
    }

    if (this.secure) {
      const { data, error } = await supabase.rpc('portal_admin_login', {
        p_usuario: cleanUser,
        p_password: password
      });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) return { ok: false, error: data?.error || 'Credenciales incorrectas.' };
      const session = { rol: 'admin', usuario: data.usuario, token: data.token };
      setSession(session);
      return { ok: true, session };
    }

    if (cleanUser === LEGACY_ADMIN_USER && password === LEGACY_ADMIN_PASS) {
      const session = { rol: 'admin', usuario: { nombre: 'Admin', usuario: cleanUser } };
      setSession(session);
      return { ok: true, session };
    }
    return { ok: false, error: 'Credenciales incorrectas.' };
  },

  async logout() {
    const session = getSession();
    if (this.secure && session?.token) {
      try {
        await supabase.rpc('portal_logout', { p_token: session.token });
      } catch {
        /* noop */
      }
    }
    clearSession();
  },

  async adminData(session) {
    if (this.secure) {
      const { data, error } = await supabase.rpc('portal_admin_resumen', { p_token: session.token });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) throw rpcError(data);
      return {
        clientes: normalizeClientes(data.clientes || []),
        trabajadores: normalizeTrabajadores(data.trabajadores || []),
        jornadas: normalizeJornadas(data.jornadas || [])
      };
    }

    const [clientes, trabajadores, jornadas] = await Promise.all([
      supabase.from('clientes').select('*').order('creado_en'),
      supabase.from('trabajadores').select('*, clientes(empresa)').order('creado_en'),
      supabase.from('jornadas')
        .select('*, trabajadores(nombre, tarifa_hora, cliente_id, clientes(empresa))')
        .order('fecha', { ascending: false })
    ]);
    const failure = clientes.error || trabajadores.error || jornadas.error;
    if (failure) throw new Error(friendlyError(failure));

    return {
      clientes: normalizeClientes(clientes.data || []),
      trabajadores: normalizeTrabajadores(trabajadores.data || []),
      jornadas: normalizeJornadas(jornadas.data || [])
    };
  },

  async workerData(session) {
    if (this.secure) {
      const { data, error } = await supabase.rpc('portal_trabajador_datos', { p_token: session.token });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) throw rpcError(data);
      return {
        usuario: sanitizeUser(data.usuario),
        jornadas: normalizeJornadas(data.jornadas || [])
      };
    }

    const trabajador = await supabase
      .from('trabajadores')
      .select('*')
      .eq('id', session.usuario.id)
      .maybeSingle();
    if (trabajador.error) throw new Error(friendlyError(trabajador.error));
    if (!trabajador.data) throw authError('Tu cuenta ya no existe.');
    if (trabajador.data.activo === false) throw authError('Tu cuenta está desactivada.');

    const jornadas = await supabase
      .from('jornadas')
      .select('*')
      .eq('trabajador_id', session.usuario.id)
      .order('fecha', { ascending: false })
      .order('creado_en', { ascending: false });
    if (jornadas.error) throw new Error(friendlyError(jornadas.error));

    return {
      usuario: sanitizeUser(trabajador.data),
      jornadas: normalizeJornadas(jornadas.data || [])
    };
  },

  async clientData(session) {
    if (this.secure) {
      const { data, error } = await supabase.rpc('portal_cliente_resumen', { p_token: session.token });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) throw rpcError(data);
      return {
        usuario: sanitizeUser(data.usuario),
        trabajadores: normalizeTrabajadores(data.trabajadores || []),
        jornadas: normalizeJornadas(data.jornadas || [])
      };
    }

    const cliente = await supabase
      .from('clientes')
      .select('*')
      .eq('id', session.usuario.id)
      .maybeSingle();
    if (cliente.error) throw new Error(friendlyError(cliente.error));
    if (!cliente.data) throw authError('Tu cuenta ya no existe.');

    const trabajadores = await supabase
      .from('trabajadores')
      .select('*, clientes(empresa)')
      .eq('cliente_id', session.usuario.id)
      .order('nombre');
    if (trabajadores.error) throw new Error(friendlyError(trabajadores.error));

    const ids = (trabajadores.data || []).map(t => t.id);
    let jornadasData = [];
    if (ids.length) {
      const jornadas = await supabase
        .from('jornadas')
        .select('*')
        .in('trabajador_id', ids)
        .order('fecha', { ascending: false });
      if (jornadas.error) throw new Error(friendlyError(jornadas.error));
      jornadasData = jornadas.data || [];
    }

    return {
      usuario: sanitizeUser(cliente.data),
      trabajadores: normalizeTrabajadores(trabajadores.data || []),
      jornadas: normalizeJornadas(jornadasData)
    };
  },

  async createCliente(payload, session) {
    if (this.secure) {
      const { data, error } = await supabase.rpc('portal_admin_crear_cliente', {
        p_token: session.token,
        p_nombre: payload.nombre,
        p_empresa: payload.empresa,
        p_email: payload.email,
        p_password: payload.password
      });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) throw rpcError(data);
      return data.cliente;
    }

    await assertUniqueEmail(payload.email);
    const { data, error } = await supabase
      .from('clientes')
      .insert([{
        nombre: payload.nombre,
        empresa: payload.empresa,
        email: String(payload.email).trim().toLowerCase(),
        password: payload.password
      }])
      .select()
      .single();
    if (error) throw new Error(friendlyError(error));
    return normalizeClientes([data])[0];
  },

  async createTrabajador(payload, session) {
    if (this.secure) {
      const { data, error } = await supabase.rpc('portal_admin_crear_trabajador', {
        p_token: session.token,
        p_nombre: payload.nombre,
        p_email: payload.email,
        p_password: payload.password,
        p_tarifa: payload.tarifa_hora,
        p_cliente_id: payload.cliente_id
      });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) throw rpcError(data);
      return data.trabajador;
    }

    await assertUniqueEmail(payload.email);
    const { data, error } = await supabase
      .from('trabajadores')
      .insert([{
        nombre: payload.nombre,
        email: String(payload.email).trim().toLowerCase(),
        password: payload.password,
        tarifa_hora: payload.tarifa_hora,
        cliente_id: payload.cliente_id,
        activo: true
      }])
      .select('*, clientes(empresa)')
      .single();
    if (error) throw new Error(friendlyError(error));
    return normalizeTrabajadores([data])[0];
  },

  async setTrabajadorActivo(id, activo, session) {
    if (this.secure) {
      const { data, error } = await supabase.rpc('portal_admin_set_activo', {
        p_token: session.token,
        p_trabajador_id: id,
        p_activo: activo
      });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) throw rpcError(data);
      return;
    }
    const { error } = await supabase.from('trabajadores').update({ activo }).eq('id', id);
    if (error) throw new Error(friendlyError(error));
  },

  async createJornada(payload, session) {
    if (this.secure) {
      const { data, error } = await supabase.rpc('portal_trabajador_crear_jornada', {
        p_token: session.token,
        p_fecha: payload.fecha,
        p_entrada: payload.hora_entrada,
        p_salida: payload.hora_salida,
        p_lunch: payload.minutos_lunch,
        p_notas: payload.notas
      });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) throw rpcError(data);
      return data.jornada;
    }

    const horasCalculadas = calcularHoras(payload.hora_entrada, payload.hora_salida, payload.minutos_lunch);
    const { data, error } = await supabase
      .from('jornadas')
      .insert([{
        trabajador_id: session.usuario.id,
        fecha: payload.fecha,
        hora_entrada: payload.hora_entrada,
        hora_salida: payload.hora_salida,
        minutos_lunch: payload.minutos_lunch,
        horas_calculadas: horasCalculadas,
        notas: payload.notas || null
      }])
      .select()
      .single();
    if (error) throw new Error(friendlyError(error));
    return normalizeJornadas([data])[0];
  },

  async deleteJornada(id, session, asAdmin = false) {
    if (this.secure) {
      const fn = asAdmin ? 'portal_admin_borrar_jornada' : 'portal_trabajador_borrar_jornada';
      const { data, error } = await supabase.rpc(fn, { p_token: session.token, p_jornada_id: id });
      if (error) throw new Error(friendlyError(error));
      if (!data?.ok) throw rpcError(data);
      return;
    }
    let query = supabase.from('jornadas').delete().eq('id', id);
    if (!asAdmin) query = query.eq('trabajador_id', session.usuario.id);
    const { error } = await query;
    if (error) throw new Error(friendlyError(error));
  }
};

export async function bootstrap() {
  hydrateIcons();
  await api.init();
  return api.secure;
}
