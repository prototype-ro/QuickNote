// Library — the quieter shelf. Image-first, 2-column masonry.
// Strategy 3: adjacent to Mind, not nested under it. Reached by swipe-left or icon.

const SAMPLE_LINKS = [
  {
    id: 'l1', kind: 'youtube', host: 'youtube.com', author: '@cleartype',
    title: 'How Wabi designed for emotional restraint',
    aspect: 1.0, // square thumbnail (we mock)
    accent: '#FF3D3D', // red, but only as a tiny corner mark
    duration: '14:22',
  },
  {
    id: 'l2', kind: 'tiktok', host: 'tiktok.com', author: '@frankochieng',
    title: 'one-take kitchen lighting test',
    aspect: 1.6, // tall vertical
    accent: '#25F4EE',
  },
  {
    id: 'l3', kind: 'article', host: 'newyorker.com',
    title: 'In praise of the boring interface',
    readTime: '9 min',
    aspect: 0.7, // wide-ish landscape
  },
  {
    id: 'l4', kind: 'instagram', host: 'instagram.com', author: '@studiokoma',
    title: 'kintsugi vase, ash glaze',
    aspect: 1.25,
    accent: '#E1306C',
  },
  {
    id: 'l5', kind: 'spotify', host: 'open.spotify.com', author: 'nils frahm',
    title: 'all melody — late edition',
    aspect: 0.9,
    accent: '#1DB954',
  },
  {
    id: 'l6', kind: 'article', host: 'arxiv.org',
    title: 'Mixture-of-experts for sparse activation',
    readTime: '12 min',
    aspect: 0.85,
  },
  {
    id: 'l7', kind: 'bare', host: 'mghof.fi',
    title: 'mghof — slow studio. helsinki.',
    aspect: 1.1,
  },
  {
    id: 'l8', kind: 'youtube', host: 'youtube.com', author: '@dieterrams',
    title: 'less, but better — 1979 lecture',
    aspect: 0.9,
    accent: '#FF3D3D',
    duration: '38:04',
  },
];

// ── Mock thumbnails — abstract gradient blocks per kind, not photos.
//    Real app: fetched og:image / oembed thumbnail.
function MockThumb({ kind, aspect, accent }) {
  const palettes = {
    youtube: ['#1a1a1d', '#2a2a30', '#16161a'],
    tiktok: ['#0a0a0b', '#1a1a22', '#0a0a14'],
    instagram: ['#3a2a3a', '#5a3a5a', '#2a1a2a'],
    article: ['#e8e6e1', '#d8d4cc', '#cdc8be'],
    spotify: ['#0e1a14', '#1a2a20', '#0a140e'],
    bare: ['#dcdfe3', '#cdd2d8', '#bec4cc'],
  };
  const p = palettes[kind] || palettes.bare;
  return (
    <div style={{
      position: 'relative', width: '100%', aspectRatio: aspect,
      borderRadius: 14, overflow: 'hidden',
      background: `linear-gradient(135deg, ${p[0]} 0%, ${p[1]} 55%, ${p[2]} 100%)`,
      boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.06), 0 0 0 0.5px rgba(10,10,11,0.08)',
    }}>
      {/* faint diagonal sheen for depth */}
      <div style={{ position: 'absolute', inset: 0, background:
        'radial-gradient(120% 80% at 20% 10%, rgba(255,255,255,0.08), transparent 50%), radial-gradient(60% 40% at 90% 90%, rgba(0,0,0,0.18), transparent 60%)' }}/>
      {/* article gets a faint serif "A" mark, others get the platform glyph */}
      {kind === 'article' && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: 'Georgia, serif', fontSize: 64, fontStyle: 'italic', fontWeight: 400, color: 'rgba(10,10,11,0.18)' }}>A</div>
      )}
      {kind === 'youtube' && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ width: 44, height: 44, borderRadius: 999, background: 'rgba(255,255,255,0.18)', backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.25)' }}>
            <svg width="14" height="14" viewBox="0 0 14 14"><path d="M3.5 2.5 L11 7 L3.5 11.5 Z" fill="#fff"/></svg>
          </div>
        </div>
      )}
      {kind === 'tiktok' && (
        <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(50% 30% at 50% 50%, rgba(37,244,238,0.15), transparent 70%), radial-gradient(50% 30% at 50% 50%, rgba(254,44,85,0.12), transparent 70%)' }}/>
      )}
      {kind === 'spotify' && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'flex-end', padding: 14 }}>
          <svg width="60" height="60" viewBox="0 0 60 60" style={{ opacity: 0.18 }}>
            {[0, 1, 2, 3, 4, 5, 6, 7].map(i => (
              <rect key={i} x={i * 7} y={60 - (8 + (i % 3) * 12)} width="4" height={8 + (i % 3) * 12} rx="1" fill="#fff"/>
            ))}
          </svg>
        </div>
      )}
    </div>
  );
}

function PlatformPill({ kind }) {
  if (kind === 'bare' || kind === 'article') return null;
  const map = {
    youtube:   { label: 'youtube',   color: '#fff', bg: 'rgba(255,61,61,0.92)' },
    tiktok:    { label: 'tiktok',    color: '#fff', bg: 'rgba(10,10,11,0.85)' },
    instagram: { label: 'instagram', color: '#fff', bg: 'rgba(225,48,108,0.9)' },
    spotify:   { label: 'spotify',   color: '#fff', bg: 'rgba(29,185,84,0.9)' },
  };
  const cfg = map[kind];
  if (!cfg) return null;
  return (
    <div style={{
      position: 'absolute', top: 8, left: 8,
      height: 18, padding: '0 7px',
      display: 'inline-flex', alignItems: 'center',
      background: cfg.bg, color: cfg.color,
      borderRadius: 999,
      fontFamily: FONT_HEAD, fontSize: 9, fontWeight: 500, letterSpacing: 0.5,
      textTransform: 'uppercase',
      boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.18)',
    }}>{cfg.label}</div>
  );
}

function LinkCard({ link, onTap }) {
  return (
    <div onClick={onTap} style={{ cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div style={{ position: 'relative' }}>
        <MockThumb kind={link.kind} aspect={link.aspect} accent={link.accent} />
        <PlatformPill kind={link.kind} />
        {link.duration && (
          <div style={{
            position: 'absolute', bottom: 6, right: 6,
            height: 16, padding: '0 5px',
            background: 'rgba(10,10,11,0.78)', color: '#fff',
            borderRadius: 4, fontFamily: FONT_HEAD, fontSize: 9.5, fontWeight: 500,
            display: 'flex', alignItems: 'center', fontVariantNumeric: 'tabular-nums', letterSpacing: 0.2,
          }}>{link.duration}</div>
        )}
      </div>
      <div style={{ padding: '0 2px' }}>
        <div style={{
          fontFamily: FONT_HEAD, fontSize: 12, fontWeight: 500, lineHeight: 1.3,
          color: COLOR.text, letterSpacing: -0.15,
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
          textWrap: 'pretty',
        }}>{link.title}</div>
        <div style={{ marginTop: 3, display: 'flex', alignItems: 'center', gap: 5, fontSize: 10.5, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.05 }}>
          <span>{link.author || link.host}</span>
          {link.readTime && <><span>·</span><span>{link.readTime}</span></>}
        </div>
      </div>
    </div>
  );
}

// ── Two-column masonry layout — pieces hand-distributed to keep heights balanced
function LibraryGrid({ links = SAMPLE_LINKS, onTap }) {
  const colA = []; const colB = [];
  links.forEach((l, i) => (i % 2 === 0 ? colA : colB).push(l));
  return (
    <div style={{ display: 'flex', gap: 10, padding: '0 16px' }}>
      {[colA, colB].map((col, ci) => (
        <div key={ci} style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 14 }}>
          {col.map((l, i) => (
            <div key={l.id} style={{
              animation: 'qn-card-in 360ms cubic-bezier(.2,.7,.2,1) both',
              animationDelay: `${(ci * 40) + i * 60}ms`,
            }}>
              <LinkCard link={l} onTap={() => onTap && onTap(l)} />
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}

// ── Library Screen — full screen, dark-on-cool field, Mind icon top-right to return
function LibraryScreen({ onBack }) {
  return (
    <Phone>
      <Wallpaper />
      <StatusBar />
      <div style={{ height: 44, padding: '0 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        {/* Back to Mind */}
        <button onClick={onBack} style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6, color: COLOR.sec, fontSize: 13, fontWeight: 300, letterSpacing: -0.1 }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M9.5 3.5 L5 8 L9.5 12.5" stroke={COLOR.sec} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/></svg>
          mind
        </button>
        <div style={{ width: 20, height: 20 }}/>
      </div>
      <div style={{ padding: '4px 20px 16px' }}>
        <div style={{ fontSize: 12, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.05, marginBottom: 4 }}>quieter shelf.</div>
        <div style={{ fontFamily: FONT_HEAD, fontSize: 34, fontWeight: 800, letterSpacing: -1, color: COLOR.text, lineHeight: 1 }}>
          library
          <span style={{ fontSize: 12, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.1, marginLeft: 10, verticalAlign: 'middle' }}>· {SAMPLE_LINKS.length} saved</span>
        </div>
      </div>
      {/* Library filter row — host-based */}
      <div style={{ display: 'flex', gap: 6, padding: '0 20px 14px', overflowX: 'auto' }}>
        {['all', 'video', 'reading', 'audio', 'social'].map((k, i) => (
          <button key={k} style={{
            height: 26, padding: '0 10px', border: 'none', cursor: 'pointer', borderRadius: 999,
            background: i === 0 ? 'linear-gradient(180deg,#1a1a1d,#000)' : 'rgba(10,10,11,0.06)',
            color: i === 0 ? '#fff' : COLOR.sec,
            fontFamily: FONT_HEAD, fontSize: 10.5, fontWeight: 500, letterSpacing: 0.3, textTransform: 'uppercase',
            boxShadow: i === 0 ? 'inset 0 1px 0 rgba(255,255,255,0.18), inset 0 -1px 0 rgba(0,0,0,0.4)' : 'inset 0 0 0 0.5px rgba(10,10,11,0.04)',
          }}>{k}</button>
        ))}
      </div>
      <div style={{
        position: 'absolute', top: 198, left: 0, right: 0, bottom: 0,
        overflowY: 'auto', paddingBottom: 120,
        maskImage: 'linear-gradient(to bottom, transparent 0, #000 18px, #000 calc(100% - 80px), transparent calc(100% - 16px))',
        WebkitMaskImage: 'linear-gradient(to bottom, transparent 0, #000 18px, #000 calc(100% - 80px), transparent calc(100% - 16px))',
      }}>
        <LibraryGrid />
      </div>
      {/* Page dots — mirrors Mind's, with the second dot active */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 36, display: 'flex', justifyContent: 'center', gap: 6, pointerEvents: 'none' }}>
        <span aria-label="mind page" style={{ width: 6, height: 6, borderRadius: 999, background: COLOR.text, opacity: 0.18 }}/>
        <span aria-label="library page" style={{ width: 6, height: 6, borderRadius: 999, background: COLOR.text, opacity: 0.85 }}/>
      </div>
    </Phone>
  );
}

// ── Toast — "saved to library →" — appears above capture bar after URL paste
function LibraryToast({ visible, onPeek }) {
  return (
    <div style={{
      position: 'absolute', left: 16, right: 16, bottom: 100,
      pointerEvents: visible ? 'auto' : 'none',
      opacity: visible ? 1 : 0,
      transform: visible ? 'translateY(0)' : 'translateY(8px)',
      transition: 'opacity 240ms ease, transform 280ms cubic-bezier(.2,.7,.2,1)',
    }}>
      <Glass radius={14} blur={28} style={{ padding: '10px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 22, height: 22, borderRadius: 999, background: 'radial-gradient(closest-side, #7AA7FF55, transparent 70%)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="11" height="11" viewBox="0 0 11 11"><path d="M2 5.5 L4.5 8 L9 3" stroke={COLOR.text} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" fill="none"/></svg>
          </div>
          <span style={{ fontSize: 13, fontWeight: 400, color: COLOR.text, letterSpacing: -0.1 }}>saved to library</span>
        </div>
        <button onClick={onPeek} style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', fontSize: 12, fontWeight: 500, color: COLOR.text, letterSpacing: -0.05, display: 'flex', alignItems: 'center', gap: 4 }}>
          peek
          <svg width="11" height="11" viewBox="0 0 11 11"><path d="M3 5.5 H8 M6 3 L8.5 5.5 L6 8" stroke={COLOR.text} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" fill="none"/></svg>
        </button>
      </Glass>
    </div>
  );
}

Object.assign(window, {
  LibraryScreen, LibraryGrid, LinkCard, LibraryToast, MockThumb, PlatformPill, SAMPLE_LINKS,
});
