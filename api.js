(() => {
  const CFG = window.CX_CONFIG;
  const DEMO = !CFG.supabaseUrl || !CFG.anonKey;
  const dia = t => new Date(t).toLocaleDateString('en-CA', { timeZone: 'America/Panama' });

  async function rpc(fn, args) {
    const url = DEMO ? new URL('api/' + fn, location.href).href : CFG.supabaseUrl.replace(/\/$/, '') + '/rest/v1/rpc/' + fn;
    const headers = { 'Content-Type': 'application/json' };
    if (!DEMO) { headers.apikey = CFG.anonKey; headers.Authorization = 'Bearer ' + CFG.anonKey; }
    let r;
    try { r = await fetch(url, { method: 'POST', headers, body: JSON.stringify(args || {}) }); }
    catch (e) { throw new Error(DEMO ? 'No hay conexión con la computadora del demo. ¿Está abierto iniciar_demo.bat y estás en el mismo WiFi?' : 'Sin conexión a internet. Intenta de nuevo.'); }
    const j = await r.json().catch(() => null);
    if (!r.ok) throw new Error((j && j.message) || (DEMO && r.status === 404 ? 'Abre el demo con iniciar_demo.bat' : 'Error del servidor'));
    return j;
  }

  // En el demo, el QR debe llevar la dirección de la PC en la red (no "localhost")
  async function base() {
    if (/^(localhost|127\.)/.test(location.hostname)) {
      try { const j = await (await fetch('api/base')).json(); if (j.base) return j.base; } catch (e) { }
    }
    return new URL('./', location.href).href;
  }

  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const store = {
    get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { } },
    del(k) { try { localStorage.removeItem(k); } catch (e) { } }
  };

  window.CX = { CFG, DEMO, rpc, base, esc, store, hoy: () => dia(Date.now()) };
})();
