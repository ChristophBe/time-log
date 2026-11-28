/* Palette and animated demos for the project site.
 *
 * Each demo is a small scripted timeline played against a miniature of the app's day
 * screen built from HTML. They are not recordings: they follow the real screen's rules
 * (SPEC §7 boundary editing, §8 composer and gaps, §6 actions) and cannot go stale as a
 * GIF would. With reduced motion they render their final frame once and stay there. */
(() => {
  'use strict';

  /* ---------- activity palette: a port of lib/src/app/palette.dart ---------- */

  const HUES = [214, 28, 134, 320, 46, 192, 278, 96, 6, 166, 68, 115];
  const lin = (v) => (v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
  const lum = ([r, g, b]) => 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);

  function hsl(h, s, l) {
    const k = (n) => (n + h / 30) % 12;
    const a = s * Math.min(l, 1 - l);
    const f = (n) => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
    return [f(0), f(8), f(4)];
  }

  // Solve for a target relative luminance, not a lightness: contrast is computed from it.
  function atLum(h, s, target) {
    let lo = 0, hi = 1, c = hsl(h, s, 0.5);
    for (let i = 0; i < 20; i++) {
      const mid = (lo + hi) / 2;
      c = hsl(h, s, mid);
      if (lum(c) < target) lo = mid; else hi = mid;
    }
    return '#' + c.map((v) => Math.round(v * 255).toString(16).padStart(2, '0')).join('');
  }

  function paletteCss(dark, tier, hue) {
    const fill = dark ? [0.045, 0.075][tier] : [0.8, 0.72][tier];
    return `--fill:${atLum(hue, dark ? 0.42 : 0.5, fill)};` +
      `--on:${atLum(hue, 0.65, dark ? 0.7 : 0.05)};` +
      `--edge:${atLum(hue, 0.75, dark ? 0.38 : 0.17)};` +
      `--tint:${atLum(hue, 0.35, dark ? 0.025 : 0.9)}`;
  }

  (function injectPalette() {
    let light = '', dark = '';
    HUES.forEach((h, i) => {
      light += `.a${i}{${paletteCss(false, i % 2, h)}}`;
      dark += `.a${i}{${paletteCss(true, i % 2, h)}}`;
    });
    const el = document.createElement('style');
    el.textContent = `${light}@media (prefers-color-scheme:dark){${dark}}`;
    document.head.appendChild(el);
  })();

  /* ---------- formats (SPEC §9.8: a colon means a clock time) ---------- */

  const pad = (n) => String(n).padStart(2, '0');
  const clock = (m) => `${pad(Math.floor(Math.round(m) / 60))}:${pad(Math.round(m) % 60)}`;
  const dur = (m) => {
    m = Math.round(m);
    const h = Math.floor(m / 60), r = m % 60;
    if (!h) return `${r} min`;
    return r ? `${h} h ${pad(r)} min` : `${h} h`;
  };
  const stopwatch = (s) => `${Math.floor(s / 3600)}:${pad(Math.floor(s / 60) % 60)}:${pad(s % 60)}`;
  const hm = (h, m = 0) => h * 60 + m;

  /* ---------- the mock screen ---------- */

  const CURSOR = '<svg width="22" height="22" viewBox="0 0 22 22"><path d="M4 2l13 8-6 1.6L8 18z" fill="#fff" stroke="#17171a" stroke-width="1.4" stroke-linejoin="round"/></svg>';

  function buildMock(root, cfg) {
    if (root._cleanup) root._cleanup();
    const { from, to, pph } = cfg;
    const dayH = (to - from) * pph / 60;
    const timers = [];
    root._cleanup = () => timers.forEach(clearInterval);

    let hours = '';
    for (let h = Math.ceil(from / 60); h <= to / 60; h++) {
      hours += `<div class="m-hr" style="top:${(h * 60 - from) * pph / 60}px"><span>${pad(h)}:00</span></div>`;
    }
    root.innerHTML = `
      <div class="m-head"><span class="m-date">Today</span><span class="m-total mono"></span></div>
      ${cfg.band ? '<div class="m-bandw"><div class="m-band"><div class="who"><span class="nm"></span><span class="since"></span></div><span class="rd mono"></span><span class="stop">Stop</span></div></div>' : '<div class="m-hsep"></div>'}
      <div class="m-dayw" style="height:${dayH}px"><div class="m-day" style="height:${dayH}px">
        ${hours}<div class="m-spine"></div><div class="m-items"></div>
        <div class="m-now"><span class="pill mono"></span></div>
        <div class="drag-chip"></div>
      </div></div>
      <div class="m-comp"><div class="m-field"><span class="ph">What now?</span><span class="txt"></span><span class="caret"></span></div><div class="m-btn idle">Start</div></div>
      <div class="m-scrim"></div><div class="m-panel"></div>
      <div class="m-toast"><span></span><b>Undo</b></div>
      <div class="m-sheet"></div>
      <div class="m-dialog"></div>
      <div class="m-cursor">${CURSOR}</div>`;

    const q = (s) => root.querySelector(s);
    const items = q('.m-items');
    const blocks = new Map();
    let nowMin = null;
    const y = (min) => (min - from) * pph / 60;

    const m = {
      root, q, y, items, blocks, timers,
      get now() { return nowMin; },

      setNow(min) {
        nowMin = min;
        const el = q('.m-now');
        el.classList.add('on');
        el.style.top = y(min) + 'px';
        el.querySelector('.pill').textContent = clock(min);
        blocks.forEach((_, id) => m.layout(id));
      },

      block(id, p) {
        let b = blocks.get(id);
        if (!b) {
          const el = document.createElement('div');
          el.innerHTML = '<span class="nm"></span><span class="tm mono"></span>';
          items.appendChild(el);
          b = { el, fresh: true };
          blocks.set(id, b);
        }
        Object.assign(b, p);
        m.layout(id);
        if (b.fresh) { b.el.classList.add('fresh'); b.fresh = false; }
        m.total();
        return b.el;
      },

      layout(id) {
        const b = blocks.get(id);
        const end = b.running ? nowMin : b.end;
        let h = (end - b.start) * pph / 60;
        let top = y(b.start);
        if (h < 18) { // the minimum is spent upwards for a running block, never past "now"
          if (b.running) top = y(end) - 18;
          h = 18;
        }
        const el = b.el;
        el.className = `blk a${b.slot}` + (b.running ? ' run' : '') + (b.sel ? ' sel' : '') +
          (h < 44 ? ' sm' : '') + (h < 26 ? ' xs' : '');
        el.style.top = top + 'px';
        el.style.height = h + 'px';
        el.querySelector('.nm').textContent = b.name;
        el.querySelector('.tm').textContent = dur(end - b.start);
      },

      remove(id) { const b = blocks.get(id); if (b) { b.el.remove(); blocks.delete(id); m.total(); } },

      total() {
        let t = 0;
        blocks.forEach((b) => { t += (b.running ? nowMin : b.end) - b.start; });
        q('.m-total').textContent = dur(t);
      },

      gap(id, start, end, label) {
        let g = m[`_gap${id}`];
        if (!g) { g = document.createElement('div'); g.className = 'm-gap'; items.appendChild(g); m[`_gap${id}`] = g; }
        g.style.top = y(start) + 'px';
        g.style.height = (end - start) * pph / 60 + 'px';
        g.textContent = label === undefined ? `${dur(end - start)} untracked` : label;
        return g;
      },
      removeGap(id) { const g = m[`_gap${id}`]; if (g) { g.remove(); m[`_gap${id}`] = null; } },

      band(p) {
        const el = q('.m-band');
        if (!p) { el.classList.remove('on'); clearInterval(m._tick); return; }
        el.className = `m-band a${p.slot} on`;
        el.querySelector('.nm').textContent = p.name;
        el.querySelector('.since').textContent = `since ${clock(nowMin - p.sec / 60)}`;
        let s = p.sec;
        const rd = el.querySelector('.rd');
        rd.textContent = stopwatch(s);
        clearInterval(m._tick);
        m._tick = setInterval(() => { s += 1; rd.textContent = stopwatch(s); }, 1000);
        timers.push(m._tick);
      },

      toast(text, show = true) {
        const t = q('.m-toast');
        t.firstElementChild.textContent = text;
        t.classList.toggle('on', show);
      },

      sheet(html, show = true) {
        const s = q('.m-sheet');
        if (html !== undefined) s.innerHTML = html;
        s.classList.toggle('on', show);
      },
      dialog(html, show = true) {
        const d = q('.m-dialog');
        if (html !== undefined) d.innerHTML = html;
        d.classList.toggle('on', show);
        q('.m-scrim').classList.toggle('on', show);
      },

      /* composer */
      focus(on) { q('.m-field').classList.toggle('focus', on); q('.m-scrim').classList.toggle('on', on); },
      typed(text) {
        q('.m-field .txt').textContent = text;
        q('.m-field .ph').style.display = text ? 'none' : '';
        q('.m-comp .m-btn').classList.toggle('idle', !text);
        m.renderPanel();
      },
      setRows(rows, cons) { m.rows = rows; m.cons = cons; m.panelOpen = true; m.renderPanel(); },
      renderPanel() {
        const p = q('.m-panel');
        if (!m.panelOpen) { p.classList.remove('on'); return; }
        const t = q('.m-field .txt').textContent.toLowerCase();
        const rows = m.rows.filter((r) => r[0].toLowerCase().includes(t));
        p.innerHTML = rows.map((r, i) =>
          `<div class="m-row a${r[1]}${i === 0 && t ? ' on' : ''}"><span class="d"></span><span class="nm">${r[0]}</span><span class="ag">${r[2]}</span></div>`).join('') +
          (m.cons ? `<div class="m-cons">${m.cons}</div>` : '');
        p.classList.add('on');
      },
      closePanel() { m.panelOpen = false; q('.m-panel').classList.remove('on'); },

      /* the pointer */
      async cursorTo(target, fx = 0.5, fy = 0.5, ms = 600) {
        const c = q('.m-cursor');
        const r = root.getBoundingClientRect();
        const t = typeof target === 'string' ? q(target) : target;
        const tr = t.getBoundingClientRect();
        const x = tr.left - r.left + tr.width * fx, yy = tr.top - r.top + tr.height * fy;
        if (!c._placed) {
          c.style.transition = 'none';
          c.style.transform = `translate(${r.width * 0.78}px, ${r.height * 0.7}px)`;
          c.offsetWidth; // flush
          c.style.transition = '';
          c._placed = true;
        }
        c.style.opacity = 1;
        c.style.transitionDuration = ms + 'ms, .2s';
        c.style.transform = `translate(${x}px, ${yy}px)`;
      },
      async click(el) {
        const c = q('.m-cursor');
        c.classList.remove('down'); c.offsetWidth; c.classList.add('down');
        if (el) { el.classList.add('press'); setTimeout(() => el.classList.remove('press'), 220); }
      },
    };
    return m;
  }

  /* ---------- the runner ---------- */

  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const CANCEL = Symbol('cancel');

  class Demo {
    constructor(root, cfg, script) {
      this.root = root; this.cfg = cfg; this.script = script;
      this.gen = 0; this.playing = false; this.btn = null;
      if (reduced) root.classList.add('reduced');
    }
    sleep(ms, gen) {
      return new Promise((res, rej) => setTimeout(() => (gen === this.gen ? res() : rej(CANCEL)), reduced ? 0 : ms));
    }
    async play() {
      const gen = ++this.gen;
      this.setPlaying(true);
      try {
        do {
          const m = buildMock(this.root, this.cfg);
          const sleep = (ms) => this.sleep(ms, gen);
          await sleep(300);
          await this.script(m, sleep);
          if (reduced) break;
          await sleep(2600);
        } while (true);
      } catch (e) {
        if (e !== CANCEL) throw e;
      }
      if (gen === this.gen) this.setPlaying(false);
    }
    pause() { this.gen++; this.setPlaying(false); }
    setPlaying(on) {
      this.playing = on;
      if (this.btn) this.btn.textContent = on ? 'Pause' : 'Replay';
    }
  }

  /* ---------- the scripts ---------- */

  const SUGGEST = [['Review PRs', 1, '2 h ago'], ['Email', 4, '3 h ago'], ['Standup', 5, '3 h ago']];

  const demos = {
    // §8.3 — the composer: type, pick, the running entry stops where the new one starts.
    start: {
      cfg: { from: hm(11), to: hm(15), pph: 68, band: true },
      async script(m, sleep) {
        const now = hm(14, 32);
        m.setNow(now);
        m.block('a', { slot: 5, name: 'Standup', start: hm(11), end: hm(11, 30) });
        m.block('b', { slot: 0, name: 'Writing specs', start: hm(11, 30), end: now, running: true });
        m.band({ slot: 0, name: 'Writing specs', sec: (now - hm(11, 30)) * 60 });
        await sleep(1100);
        await m.cursorTo('.m-field', 0.4); await sleep(700);
        await m.click(); m.focus(true);
        m.setRows(SUGGEST, 'Stops <b>Writing specs</b> at 14:32.');
        await sleep(900);
        let s = '';
        for (const ch of 'Rev') { s += ch; m.typed(s); await sleep(200); }
        await sleep(600);
        await m.cursorTo('.m-panel .m-row', 0.5, 0.5, 500); await sleep(600);
        await m.click(); await sleep(150);
        m.closePanel(); m.typed(''); m.focus(false);
        m.block('b', { running: false, end: now });
        m.block('c', { slot: 1, name: 'Review PRs', start: now, running: true });
        m.band({ slot: 1, name: 'Review PRs', sec: 0 });
        m.toast('Started Review PRs');
        await sleep(300);
        m.q('.blk.run').classList.remove('fresh'); m.q('.blk.run').offsetWidth; m.q('.blk.run').classList.add('fresh');
        await sleep(2500);
      },
    },

    // §7 — drag a shared boundary away from its neighbour and get asked, never assumed.
    boundary: {
      cfg: { from: hm(11), to: hm(14), pph: 92 },
      async script(m, sleep) {
        m.setNow(hm(13, 40));
        m.block('a', { slot: 0, name: 'Writing specs', start: hm(11), end: hm(12, 30) });
        m.block('b', { slot: 4, name: 'Email', start: hm(12, 30), end: hm(13, 30) });
        const chip = m.q('.drag-chip');
        await sleep(1000);
        const edgeY = m.y(hm(12, 30));
        const dayEl = m.q('.m-day');
        await m.cursorTo(dayEl, 0.7, edgeY / dayEl.getBoundingClientRect().height); await sleep(900);
        await m.click(); m.block('a', { sel: true });
        chip.classList.add('on');
        // Drag the edge up in snapped 5-minute steps. The neighbour stays put until asked.
        for (let t = hm(12, 30); t >= hm(12, 15); t -= 5) {
          m.block('a', { end: t });
          chip.textContent = clock(t);
          chip.style.top = m.y(t) - 26 + 'px';
          if (t < hm(12, 30)) m.gap('d', t, hm(12, 30), '');
          m.q('.m-cursor').style.transitionDuration = '200ms, .2s';
          m.q('.m-cursor').style.transform =
            `translate(${m.root.getBoundingClientRect().width * 0.7}px, ${dayEl.getBoundingClientRect().top - m.root.getBoundingClientRect().top + m.y(t)}px)`;
          await sleep(300);
        }
        await sleep(500);
        chip.classList.remove('on');
        m.dialog(`<h4 style="margin:0;font-size:16px">Move Email along?</h4>
          <p>That leaves a gap before <b>Email</b>.</p>
          <div class="btns" style="display:flex;gap:8px;flex-wrap:wrap"><span class="m-btn" id="adj">Adjust Email</span><span class="m-btn ghost">Leave gap</span></div>`);
        await sleep(1400);
        await m.cursorTo(m.q('#adj'), 0.5, 0.5, 500); await sleep(600);
        await m.click(m.q('#adj')); await sleep(200);
        m.dialog(undefined, false);
        m.removeGap('d');
        m.block('b', { start: hm(12, 15) });
        m.block('a', { sel: false });
        m.toast('Moved Email to 12:15');
        await sleep(2800);
      },
    },

    // §8.2 — a gap is a shape you can tap; the new entry fills exactly its length.
    gap: {
      cfg: { from: hm(11), to: hm(14), pph: 92 },
      async script(m, sleep) {
        m.setNow(hm(13, 50));
        m.block('a', { slot: 5, name: 'Standup', start: hm(11), end: hm(11, 30) });
        const g = m.gap('g', hm(11, 30), hm(12, 15));
        m.block('d', { slot: 2, name: 'Deep work', start: hm(12, 15), end: hm(13, 45) });
        await sleep(1100);
        await m.cursorTo(g, 0.5, 0.5); await sleep(800);
        g.classList.add('hl'); await m.click(); await sleep(250);
        m.sheet(`<h4>Fill gap</h4>
          <div class="fld focus"><span id="nm"></span></div>
          <div class="btns"><span class="m-btn" id="add">Add</span></div>`);
        await sleep(700);
        let s = '';
        for (const ch of 'Email') { s += ch; m.q('#nm').textContent = s; await sleep(150); }
        await sleep(500);
        await m.cursorTo(m.q('#add'), 0.5, 0.5, 450); await sleep(500);
        await m.click(m.q('#add')); await sleep(200);
        m.sheet(undefined, false);
        m.removeGap('g');
        m.block('e', { slot: 4, name: 'Email', start: hm(11, 30), end: hm(12, 15) });
        await sleep(2800);
      },
    },

  };

  /* ---------- wire up ---------- */

  const live = [];
  document.querySelectorAll('[data-demo]').forEach((root) => {
    const def = demos[root.dataset.demo];
    if (!def) return;
    const demo = new Demo(root, def.cfg, def.script);
    const ctl = root.parentElement.querySelector('.ctl');
    if (ctl) {
      demo.btn = ctl;
      ctl.addEventListener('click', () => {
        demo.userPaused = demo.playing;
        if (demo.playing) demo.pause(); else demo.play();
      });
    }
    if (reduced && ctl) ctl.hidden = true;
    live.push({ demo, root });
    buildMock(root, def.cfg); // a poster frame before it scrolls into view
  });

  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      const l = live.find((x) => x.root === e.target);
      if (!l) return;
      if (e.isIntersecting) { if (!l.demo.playing && !l.demo.userPaused) l.demo.play(); }
      else if (l.demo.playing) l.demo.pause();
    });
  }, { threshold: 0.4 });
  live.forEach((l) => io.observe(l.root));

  /* ---------- the call to action ---------- */

  document.documentElement.classList.add('js');

  const ua = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '';
  const agent = navigator.userAgent;
  const os = /android/i.test(agent) ? 'Android'
    : /iphone|ipad|ios/i.test(agent) ? null
    : /mac/i.test(ua + agent) ? 'macOS'
    : /win/i.test(ua + agent) ? 'Windows'
    : /linux|x11/i.test(ua + agent) ? 'Linux' : null;
  if (os) document.querySelectorAll('[data-dl]').forEach((a) => { a.textContent = `Download for ${os}`; });

  const hero = document.querySelector('.hero');
  const sticky = document.getElementById('sticky');
  if (hero && sticky) {
    new IntersectionObserver(([e]) => {
      const on = !e.isIntersecting && e.boundingClientRect.top < 0;
      sticky.classList.toggle('on', on);
      sticky.setAttribute('aria-hidden', String(!on));
      sticky.querySelector('a').tabIndex = on ? 0 : -1;
    }).observe(hero);
  }

  const reveal = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); reveal.unobserve(e.target); } });
  }, { threshold: 0.15 });
  document.querySelectorAll('.demo .text, .grid > div, .cta-band .wrap').forEach((el) => {
    el.classList.add('reveal'); reveal.observe(el);
  });
})();
