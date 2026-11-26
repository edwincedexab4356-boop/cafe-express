// Botón "Instalar app": en Android Chrome la instala como APK (WebAPK); en iPhone explica cómo agregarla al inicio.
(() => {
  if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) navigator.serviceWorker.register('sw.js').catch(() => { });
  const yaInstalada = matchMedia('(display-mode: standalone)').matches || navigator.standalone;
  if (yaInstalada) return;
  const clave = 'cx_no_instalar_' + location.pathname.split('/').pop();
  try { if (+localStorage.getItem(clave) > Date.now()) return; } catch (e) { }

  const css = document.createElement('style');
  css.textContent = `.cx-inst{position:fixed;left:12px;right:12px;bottom:max(12px,env(safe-area-inset-bottom));z-index:99;max-width:460px;margin:0 auto;
  background:#fff;color:#22140c;border-radius:18px;box-shadow:0 10px 30px rgba(0,0,0,.35);padding:12px;display:flex;gap:12px;align-items:center;font:15px/1.35 Archivo,system-ui,sans-serif}
  .cx-inst img{width:44px;height:44px;border-radius:10px;flex:none}.cx-inst div{flex:1}.cx-inst b{display:block}
  .cx-inst button{font:700 15px Archivo,sans-serif;border:0;border-radius:12px;min-height:44px;padding:0 14px;cursor:pointer}
  .cx-inst .si{background:#ff6a1a;color:#fff}.cx-inst .no{background:transparent;color:#6f5a4a;padding:0 8px;font-size:20px}`;
  document.head.appendChild(css);

  function mostrar(texto, boton, accion) {
    const el = document.createElement('div');
    el.className = 'cx-inst'; el.setAttribute('role', 'dialog'); el.setAttribute('aria-label', 'Instalar app');
    el.innerHTML = `<img src="iconos/icono-192.png" alt=""><div><b>Instala Cafe Express</b><span></span></div>${boton ? '<button class="si"></button>' : ''}<button class="no" aria-label="Cerrar">×</button>`;
    if (texto) el.querySelector('span').textContent = texto; else el.querySelector('span').remove();
    if (boton) { const b = el.querySelector('.si'); b.textContent = boton; b.onclick = () => { accion(); el.remove(); }; }
    el.querySelector('.no').onclick = () => { try { localStorage.setItem(clave, Date.now() + 7 * 864e5); } catch (e) { } el.remove(); document.body.style.paddingBottom = ''; };
    document.body.appendChild(el); document.body.style.paddingBottom = '96px';
  }

  let evento = null;
  addEventListener('beforeinstallprompt', e => {
    e.preventDefault(); evento = e;
    mostrar('', 'Instalar', async () => { evento.prompt(); await evento.userChoice; evento = null; });
  });
  addEventListener('appinstalled', () => document.querySelectorAll('.cx-inst').forEach(x => x.remove()));

  const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
  if (ios) setTimeout(() => mostrar('En Safari toca Compartir (el cuadrito con flecha) y luego «Agregar a inicio».'), 1500);
})();
