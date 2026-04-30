// QuickNote — cold-premium iOS note capture app
// All screens render inside a fixed phone-shaped frame (390×844 viewport).

const COLOR = {
  bg: '#F0F2F4',
  text: '#0A0A0B',
  sec: '#6B7280',
  ter: '#9CA3AF',
  divider: 'rgba(10,10,11,0.08)',
  glassWhite: 'rgba(255,255,255,0.55)',
  glassBorder: 'rgba(255,255,255,0.6)',
  glassTint: 'rgba(255,255,255,0.4)',
};

const FONT_HEAD = '"Helvetica Neue", Helvetica, Arial, sans-serif';
const FONT_BODY = '"Helvetica Neue", Helvetica, Arial, sans-serif';

// Subscribe to tweaks set on window from the host App. Returns the latest object
// (or {} before it's been initialized).
function useQnTweaks() {
  const [t, setT] = React.useState(() => (typeof window !== 'undefined' && window.__qnTweaks) || {});
  React.useEffect(() => {
    const handler = () => setT({ ...(window.__qnTweaks || {}) });
    window.addEventListener('qn-tweaks-changed', handler);
    handler(); // sync on mount
    return () => window.removeEventListener('qn-tweaks-changed', handler);
  }, []);
  return t;
}

// ── Glyph mark — rounded square + interior diagonal
function Mark({ size = 24, stroke = 1.5, color = COLOR.text }) {
  const r = 5;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <rect x="3.5" y="3.5" width="17" height="17" rx={r} stroke={color} strokeWidth={stroke} />
      <path d={`M3.5 ${20.5 - 7} L${20.5 - 7} 3.5`} stroke={color} strokeWidth={stroke} strokeLinecap="round" />
    </svg>
  );
}

// ── Hero mark — Mark with a soft pillowy halo and interior glow.
// One accent per screen; the only place color appears.
function HeroMark({ size = 64, stroke = 1.4, halo = '#7AA7FF', breathe = false }) {
  const ring = size * 1.7;
  return (
    <div style={{
      position: 'relative', width: ring, height: ring,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      animation: breathe ? 'qn-breathe 2.6s ease-in-out infinite' : 'none',
    }}>
      {/* outermost halo */}
      <div style={{
        position: 'absolute', inset: 0, borderRadius: '50%',
        background: `radial-gradient(closest-side, ${halo}55, ${halo}00 70%)`,
        filter: 'blur(8px)',
      }}/>
      {/* inner brighter glow */}
      <div style={{
        position: 'absolute', width: size * 1.15, height: size * 1.15, borderRadius: '50%',
        background: `radial-gradient(closest-side, ${halo}66, ${halo}00 75%)`,
        filter: 'blur(2px)',
      }}/>
      {/* pillow disc behind the mark — gives the glyph somewhere to sit */}
      <div style={{
        position: 'absolute', width: size * 0.95, height: size * 0.95, borderRadius: '50%',
        background: 'radial-gradient(at 35% 30%, #ffffff, #eef1f6 70%, #e4e8ee)',
        boxShadow: '0 1px 0 rgba(255,255,255,0.9) inset, 0 -8px 18px rgba(120,140,170,0.18) inset, 0 6px 18px rgba(60,80,110,0.12)',
      }}/>
      <div style={{ position: 'relative' }}>
        <Mark size={size * 0.55} stroke={stroke} />
      </div>
    </div>
  );
}

// ── Category icon — 14px line glyphs
function CatIcon({ kind, size = 14, color = COLOR.text, alpha = 1 }) {
  const s = { stroke: color, strokeWidth: 1.4, fill: 'none', strokeLinecap: 'round', strokeLinejoin: 'round', opacity: alpha };
  if (kind === 'task') return (
    <svg width={size} height={size} viewBox="0 0 14 14"><circle cx="7" cy="7" r="5.5" {...s} /><path d="M4.5 7.2 L6.2 8.8 L9.5 5.5" {...s} /></svg>
  );
  if (kind === 'idea') return (
    <svg width={size} height={size} viewBox="0 0 14 14"><path d="M7 1.5 a4 4 0 0 1 2.5 7.2 V10 H4.5 V8.7 A4 4 0 0 1 7 1.5 Z" {...s}/><path d="M5.5 11.8 H8.5" {...s}/></svg>
  );
  if (kind === 'note') return (
    <svg width={size} height={size} viewBox="0 0 14 14"><path d="M3 2 H8.5 L11 4.5 V12 H3 Z" {...s}/><path d="M8.5 2 V4.5 H11" {...s}/></svg>
  );
  if (kind === 'link') return (
    <svg width={size} height={size} viewBox="0 0 14 14"><path d="M5.5 8.5 a2.5 2.5 0 0 1 0 -3.5 L7 3.5 a2.5 2.5 0 0 1 3.5 3.5 L9.5 8" {...s}/><path d="M8.5 5.5 a2.5 2.5 0 0 1 0 3.5 L7 10.5 a2.5 2.5 0 0 1 -3.5 -3.5 L4.5 6" {...s}/></svg>
  );
  return null;
}

// ── Frosted card primitive — Liquid-Glass-ish stack:
//   1) backdrop blur + saturate (the refraction)
//   2) faint white tint (the body)
//   3) inset top-left highlight + bottom-right shade (the lensing)
//   4) hairline outer border (the rim)
// Children sit above all of it.
function Glass({ children, style, radius = 16, blur = 24, tone = 'light' }) {
  const dark = tone === 'dark';
  return (
    <div style={{
      position: 'relative',
      borderRadius: radius,
      isolation: 'isolate',
      ...style,
    }}>
      {/* refraction layer */}
      <div aria-hidden style={{
        position: 'absolute', inset: 0, borderRadius: radius,
        backdropFilter: `blur(${blur}px) saturate(180%)`,
        WebkitBackdropFilter: `blur(${blur}px) saturate(180%)`,
        background: dark
          ? 'linear-gradient(180deg, rgba(255,255,255,0.16), rgba(255,255,255,0.08))'
          : 'linear-gradient(180deg, rgba(255,255,255,0.62), rgba(255,255,255,0.44))',
        zIndex: 0,
      }}/>
      {/* lensing — top-left lit edge, bottom-right soft shade */}
      <div aria-hidden style={{
        position: 'absolute', inset: 0, borderRadius: radius,
        boxShadow: dark
          ? 'inset 1px 1px 0 rgba(255,255,255,0.22), inset -1px -1px 0 rgba(0,0,0,0.10)'
          : 'inset 1px 1px 0 rgba(255,255,255,0.85), inset -1px -1px 0 rgba(60,70,90,0.06)',
        zIndex: 1, pointerEvents: 'none',
      }}/>
      {/* hairline rim */}
      <div aria-hidden style={{
        position: 'absolute', inset: 0, borderRadius: radius,
        boxShadow: dark
          ? '0 0 0 0.5px rgba(255,255,255,0.18)'
          : '0 0 0 0.5px rgba(255,255,255,0.8), 0 0 0 1px rgba(10,10,11,0.04)',
        zIndex: 2, pointerEvents: 'none',
      }}/>
      <div style={{ position: 'relative', zIndex: 3 }}>{children}</div>
    </div>
  );
}

// ── Glossy primary button — black with a subtle lit top edge + bottom shade.
// Pressing dims the gloss for tactile feedback.
function GlossButton({ children, onClick, style, height = 52, radius = 14 }) {
  const [pressed, setPressed] = React.useState(false);
  return (
    <button
      onClick={onClick}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
      style={{
        position: 'relative', width: '100%', height, borderRadius: radius,
        border: 'none', cursor: 'pointer',
        background: 'linear-gradient(180deg, #1a1a1d 0%, #0a0a0b 60%, #000 100%)',
        color: '#fff',
        fontFamily: FONT_HEAD, fontSize: 16, fontWeight: 500, letterSpacing: -0.1,
        boxShadow: pressed
          ? '0 1px 2px rgba(0,0,0,0.2), inset 0 1px 0 rgba(255,255,255,0.04)'
          : '0 1px 0 rgba(255,255,255,0.6), 0 8px 22px rgba(10,10,30,0.22), inset 0 1px 0 rgba(255,255,255,0.18), inset 0 -1px 0 rgba(0,0,0,0.5)',
        transform: pressed ? 'translateY(0.5px)' : 'translateY(0)',
        transition: 'transform 120ms, box-shadow 160ms',
        overflow: 'hidden',
        ...style,
      }}>
      {/* top sheen */}
      <span aria-hidden style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: '50%',
        borderTopLeftRadius: radius, borderTopRightRadius: radius,
        background: 'linear-gradient(180deg, rgba(255,255,255,0.10), rgba(255,255,255,0))',
        pointerEvents: 'none',
        opacity: pressed ? 0.4 : 1,
        transition: 'opacity 160ms',
      }}/>
      <span style={{ position: 'relative', zIndex: 1 }}>{children}</span>
    </button>
  );
}

// ── Status bar (iOS-style, monochrome)
function StatusBar({ time = '9:41' }) {
  return (
    <div style={{
      height: 54, padding: '20px 28px 0', display: 'flex',
      alignItems: 'center', justifyContent: 'space-between',
      fontFamily: FONT_HEAD, fontSize: 16, fontWeight: 600, color: COLOR.text,
      letterSpacing: -0.2,
    }}>
      <span style={{ fontVariantNumeric: 'tabular-nums' }}>{time}</span>
      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <svg width="17" height="11" viewBox="0 0 17 11"><rect x="0" y="7" width="3" height="4" rx="0.6" fill={COLOR.text}/><rect x="4.5" y="5" width="3" height="6" rx="0.6" fill={COLOR.text}/><rect x="9" y="2.5" width="3" height="8.5" rx="0.6" fill={COLOR.text}/><rect x="13.5" y="0" width="3" height="11" rx="0.6" fill={COLOR.text}/></svg>
        <svg width="15" height="11" viewBox="0 0 15 11"><path d="M7.5 2.5 C9.5 2.5 11.3 3.3 12.5 4.5 L13.5 3.5 C12 2 9.9 1 7.5 1 C5.1 1 3 2 1.5 3.5 L2.5 4.5 C3.7 3.3 5.5 2.5 7.5 2.5 Z" fill={COLOR.text}/><circle cx="7.5" cy="9" r="1.3" fill={COLOR.text}/></svg>
        <svg width="24" height="11" viewBox="0 0 24 11"><rect x="0.5" y="0.5" width="20" height="10" rx="2.5" stroke={COLOR.text} strokeOpacity="0.4" fill="none"/><rect x="2" y="2" width="17" height="7" rx="1.5" fill={COLOR.text}/><rect x="21.5" y="3.5" width="1.5" height="4" rx="0.5" fill={COLOR.text} fillOpacity="0.4"/></svg>
      </div>
    </div>
  );
}

function HomeIndicator({ dark }) {
  return (
    <div style={{ position: 'absolute', bottom: 6, left: 0, right: 0, height: 28, display: 'flex', justifyContent: 'center', alignItems: 'flex-end', paddingBottom: 7, pointerEvents: 'none' }}>
      <div style={{ width: 134, height: 5, borderRadius: 100, background: dark ? 'rgba(255,255,255,0.85)' : 'rgba(10,10,11,0.85)' }}/>
    </div>
  );
}

// ── Phone Frame (used inside artboards)
function Phone({ children, width = 390, height = 844, bg = COLOR.bg, dark = false, scrollY = 0 }) {
  return (
    <div style={{
      width, height, position: 'relative', overflow: 'hidden',
      background: bg,
      fontFamily: FONT_BODY,
      WebkitFontSmoothing: 'antialiased',
      color: COLOR.text,
    }}>
      {children}
      <HomeIndicator dark={dark} />
    </div>
  );
}

// ── Wallpaper for screens that need a soft tonal field behind glass
function Wallpaper() {
  const t = useQnTweaks();
  const w = t.wallpaperWarmth || 0;
  // shift base hue subtly toward amber (positive) or cyan (negative) by warping the rgb stops
  const warm = (a, b) => `rgba(${214 + w * 1.5}, ${222 - w * 0.4}, ${232 - w * 1.4}, ${a})`;
  return (
    <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none',
      background: `radial-gradient(120% 60% at 30% 0%, ${warm(0.7)}, transparent 60%), radial-gradient(80% 50% at 80% 100%, rgba(225,228,232,0.6), transparent 60%), hsl(${210 - w * 1.2}, 13%, ${95 + w * 0.05}%)`,
    }} />
  );
}

// ─────────────────────────────────────────────────────────────
// SCREEN 1 — Splash / Onboarding
// ─────────────────────────────────────────────────────────────
function SplashScreen() {
  return (
    <Phone>
      <Wallpaper />
      <StatusBar />
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 32px' }}>
        <div style={{ marginBottom: 24 }}>
          <HeroMark size={72} halo="#7AA7FF" breathe />
        </div>
        <div style={{ fontFamily: FONT_HEAD, fontSize: 30, fontWeight: 800, letterSpacing: -0.7, color: COLOR.text }}>quicknote</div>
        <div style={{ marginTop: 10, fontSize: 15, fontWeight: 300, color: COLOR.sec, letterSpacing: -0.1, textAlign: 'center', maxWidth: 280, lineHeight: 1.45 }}>
          capture anything. forget nothing.
        </div>
      </div>
      <div style={{ position: 'absolute', left: 20, right: 20, bottom: 56 }}>
        <GlossButton>get started</GlossButton>
        <div style={{ textAlign: 'center', marginTop: 18, fontSize: 12, color: COLOR.ter, fontWeight: 300 }}>
          private by default · no account required
        </div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// Shared: Note data + card
// ─────────────────────────────────────────────────────────────
// Mind only contains thoughts — links live in the Library (separate shelf, Strategy 3)
const SAMPLE_NOTES = [
  { id: 1, kind: 'task', time: 'now',     text: 'plan the q2 offsite — book venue, send invite, finalize agenda by friday', sub: '3 action items extracted' },
  { id: 2, kind: 'idea', time: '12m',     text: 'what if onboarding skipped the tour entirely and just dropped you into a populated empty state', sub: 'tagged · product, onboarding' },
  { id: 4, kind: 'note', time: '3h',      text: 'mom\'s birthday is the 24th. flowers + the small ceramic from the shop on rue saint-paul.', sub: 'reminder set for the 22nd' },
  { id: 5, kind: 'task', time: 'yesterday', text: 'draft the response to the partnership email — keep it short, no commitment yet', sub: '1 action item · 1 contact' },
  { id: 6, kind: 'idea', time: 'tue',     text: 'a notes app that doesn\'t feel like a notes app. less ceremony. more residue.', sub: 'tagged · meta' },
];

function Badge({ kind }) {
  const label = { task: 'task', idea: 'idea', note: 'note', link: 'link' }[kind];
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      height: 22, padding: '0 9px',
      background: 'rgba(10,10,11,0.04)',
      boxShadow: 'inset 0 0 0 0.5px rgba(10,10,11,0.07)',
      borderRadius: 999,
      fontFamily: FONT_HEAD, fontSize: 10.5, fontWeight: 500, letterSpacing: 0.8,
      color: COLOR.text, textTransform: 'uppercase',
    }}>
      <CatIcon kind={kind} size={11} />
      <span>{label}</span>
    </div>
  );
}

function NoteCard({ note, onTap, swiped = false, onSwipe }) {
  return (
    <div style={{ position: 'relative' }}>
      {/* delete revealed underneath — only rendered while swiped */}
      {swiped && (
        <div style={{
          position: 'absolute', inset: 0, borderRadius: 16, background: '#C8362F',
          display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
          paddingRight: 22, fontFamily: FONT_HEAD, fontSize: 14, fontWeight: 500, color: '#fff',
          letterSpacing: -0.1,
        }}>delete</div>
      )}
      <Glass style={{
        padding: '14px 16px 14px',
        transform: swiped ? 'translateX(-90px)' : 'translateX(0)',
        transition: 'transform 280ms cubic-bezier(.2,.7,.2,1)',
        cursor: 'pointer',
      }} onClick={onTap}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
          <Badge kind={note.kind} />
          <span style={{ fontSize: 12, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.1 }}>{note.time}</span>
        </div>
        <div style={{ fontFamily: FONT_BODY, fontSize: 15, fontWeight: 300, lineHeight: 1.45, color: COLOR.text, letterSpacing: -0.15, textWrap: 'pretty' }}>
          {note.text}
        </div>
        <div style={{ marginTop: 8, fontSize: 12.5, fontWeight: 300, color: COLOR.sec, letterSpacing: -0.1 }}>
          {note.sub}
        </div>
      </Glass>
    </div>
  );
}

// ── Capture bar — frosted, anchored above home indicator.
// Rotates placeholder lines so the surface has voice without having a face.
const CAPTURE_PLACEHOLDERS = [
  'anything on your mind…',
  'say it out loud.',
  'what\'s the residue?',
  'leave it here. come back later.',
];
function CaptureBar({ value = '', onChange, focused = false, dark = false }) {
  const showSend = value.length > 0;
  const [phIdx, setPhIdx] = React.useState(0);
  React.useEffect(() => {
    if (value.length > 0) return;
    const t = setInterval(() => setPhIdx(i => (i + 1) % CAPTURE_PLACEHOLDERS.length), 4200);
    return () => clearInterval(t);
  }, [value.length]);
  return (
    <Glass radius={18} blur={28} style={{ padding: '10px 10px 10px 16px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 52 }}>
      <div style={{ flex: 1, position: 'relative', minHeight: 28, display: 'flex', alignItems: 'center', overflow: 'hidden' }}>
        {value.length === 0 ? (
          <span key={phIdx} style={{
            color: COLOR.ter, fontSize: 15, fontWeight: 300, letterSpacing: -0.15,
            animation: 'qn-fade-in 360ms ease both',
          }}>{CAPTURE_PLACEHOLDERS[phIdx]}</span>
        ) : (
          <span style={{ color: COLOR.text, fontSize: 15, fontWeight: 300, letterSpacing: -0.15, lineHeight: 1.4 }}>{value}<span style={{ display: focused ? 'inline-block' : 'none', width: 1.5, height: 16, background: COLOR.text, marginLeft: 1, verticalAlign: 'middle' }}/></span>
        )}
      </div>
      <button style={{
        position: 'relative', width: 32, height: 32, borderRadius: 999, border: 'none', cursor: 'pointer',
        background: 'linear-gradient(180deg, #1a1a1d, #000)',
        opacity: showSend ? 1 : 0,
        transform: showSend ? 'scale(1)' : 'scale(0.6)',
        transition: 'opacity 180ms ease, transform 220ms cubic-bezier(.2,.7,.2,1)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.22), inset 0 -1px 0 rgba(0,0,0,0.5), 0 4px 10px rgba(0,0,0,0.18)',
      }}>
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M7 11.5 V2.5 M3 6.5 L7 2.5 L11 6.5" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>
      </button>
    </Glass>
  );
}

function FilterChips({ active = 'all', onChange }) {
  const t = useQnTweaks();
  const items = ['all', 'tasks', 'ideas', 'notes'];
  const useBackdrop = t.chipBackdrop !== false;
  return (
    <div style={{
      display: 'flex', gap: 6, padding: '6px 20px 10px', overflowX: 'auto',
      // frosted backdrop so scrolled notes don't read through the chips
      background: useBackdrop ? 'linear-gradient(180deg, rgba(240,242,244,0.92) 0%, rgba(240,242,244,0.78) 70%, rgba(240,242,244,0) 100%)' : 'transparent',
      backdropFilter: useBackdrop ? 'blur(12px) saturate(160%)' : 'none',
      WebkitBackdropFilter: useBackdrop ? 'blur(12px) saturate(160%)' : 'none',
      position: 'relative', zIndex: 2,
    }}>
      {items.map(k => {
        const isActive = k === active;
        return (
          <button key={k} onClick={() => onChange && onChange(k)} style={{
            position: 'relative',
            height: 28, padding: '0 10px',
            border: 'none', cursor: 'pointer',
            borderRadius: 999,
            background: isActive
              ? 'linear-gradient(180deg, #1a1a1d, #000)'
              : 'rgba(10,10,11,0.06)',
            color: isActive ? '#fff' : COLOR.sec,
            backdropFilter: isActive ? 'none' : 'blur(20px) saturate(180%)',
            WebkitBackdropFilter: isActive ? 'none' : 'blur(20px) saturate(180%)',
            boxShadow: isActive
              ? 'inset 0 1px 0 rgba(255,255,255,0.18), inset 0 -1px 0 rgba(0,0,0,0.4), 0 2px 6px rgba(0,0,0,0.12)'
              : 'inset 0 0 0 0.5px rgba(10,10,11,0.04)',
            fontFamily: FONT_HEAD, fontSize: 11, fontWeight: 500, letterSpacing: 0.3,
            textTransform: 'uppercase',
            transition: 'background 180ms, box-shadow 180ms',
          }}>{k}</button>
        );
      })}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SCREEN 2 — Inbox
// ─────────────────────────────────────────────────────────────
function InboxScreen({ filter = 'all', notes = SAMPLE_NOTES, swipedId = null, captureValue = '', onTapCard, onSetFilter, fadingNew }) {
  const filtered = filter === 'all' ? notes : notes.filter(n => n.kind + 's' === filter);
  return (
    <Phone>
      <Wallpaper />
      <StatusBar />
      {/* Nav row: mark + library button (matches the live prototype) */}
      <div style={{ height: 44, padding: '0 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Mark size={22} stroke={1.4} />
        <span style={{
          background: 'rgba(10,10,11,0.06)',
          padding: '0 12px 0 10px',
          height: 32, borderRadius: 999,
          display: 'flex', alignItems: 'center', gap: 8,
          color: COLOR.text, fontSize: 13, fontWeight: 400, letterSpacing: -0.1,
          boxShadow: 'inset 0 0 0 0.5px rgba(10,10,11,0.06)',
        }}>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <rect x="2" y="2.5" width="10" height="2.2" rx="0.6" stroke={COLOR.text} strokeWidth="1.1"/>
            <rect x="2" y="6" width="10" height="2.2" rx="0.6" stroke={COLOR.text} strokeWidth="1.1"/>
            <rect x="2" y="9.5" width="10" height="2.2" rx="0.6" stroke={COLOR.text} strokeWidth="1.1"/>
          </svg>
          <span>library</span>
          <span style={{
            minWidth: 18, height: 18, padding: '0 5px',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            borderRadius: 999,
            background: '#7AA7FF', color: '#0A0A0B',
            fontFamily: FONT_HEAD, fontSize: 10.5, fontWeight: 600,
            boxShadow: 'inset 0 0 0 0.5px rgba(10,10,11,0.08), 0 1px 2px rgba(0,0,0,0.08)',
            fontVariantNumeric: 'tabular-nums',
          }}>8</span>
        </span>
      </div>
      {/* Title */}
      <div style={{ padding: '4px 20px 18px' }}>
        <div style={{ fontSize: 12, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.05, marginBottom: 4 }}>good morning, alex.</div>
        <div style={{ fontFamily: FONT_HEAD, fontSize: 34, fontWeight: 800, letterSpacing: -1, color: COLOR.text, lineHeight: 1 }}>
          mind
          <span style={{ fontSize: 12, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.1, marginLeft: 10, verticalAlign: 'middle' }}>· {filtered.length} thought{filtered.length === 1 ? '' : 's'}</span>
        </div>
      </div>
      {/* Filter row */}
      <FilterChips active={filter} onChange={onSetFilter} />
      {/* Note list */}
      <div style={{
        position: 'absolute', top: 230, left: 0, right: 0, bottom: 0,
        overflowY: 'hidden',
        padding: '14px 20px 140px',
        maskImage: 'linear-gradient(to bottom, transparent 0, #000 18px, #000 calc(100% - 120px), transparent calc(100% - 24px))',
        WebkitMaskImage: 'linear-gradient(to bottom, transparent 0, #000 18px, #000 calc(100% - 120px), transparent calc(100% - 24px))',
      }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {filtered.map((n, i) => (
            <div key={n.id} style={{
              opacity: fadingNew && i === 0 ? 0 : 1,
              transform: fadingNew && i === 0 ? 'translateY(-6px)' : 'translateY(0)',
              animation: 'qn-card-in 320ms cubic-bezier(.2,.7,.2,1) both',
              animationDelay: `${i * 40}ms`,
            }}>
              <NoteCard note={n} swiped={swipedId === n.id} onTap={() => onTapCard && onTapCard(n)} />
            </div>
          ))}
        </div>
      </div>
      {/* Capture bar */}
      <div style={{ position: 'absolute', left: 16, right: 16, bottom: 36 }}>
        <CaptureBar value={captureValue} />
      </div>
      {/* Page dots — teaches the two-surface model */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 102, display: 'flex', justifyContent: 'center', gap: 6, pointerEvents: 'none' }}>
        <span style={{ width: 6, height: 6, borderRadius: 999, background: COLOR.text, opacity: 0.85 }}/>
        <span style={{ width: 6, height: 6, borderRadius: 999, background: COLOR.text, opacity: 0.18 }}/>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// SCREEN 3 — AI Processing
// ─────────────────────────────────────────────────────────────
function ProcessingScreen() {
  return (
    <Phone>
      <Wallpaper />
      <StatusBar />
      {/* Blurred inbox preview behind */}
      <div style={{ position: 'absolute', inset: 0, filter: 'blur(14px)', opacity: 0.65, pointerEvents: 'none' }}>
        <div style={{ padding: '90px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
          {SAMPLE_NOTES.slice(0, 5).map(n => (
            <Glass key={n.id} style={{ height: 96 }} />
          ))}
        </div>
      </div>
      {/* Soft veil */}
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(240,242,244,0.55)' }} />
      {/* Centered breathing mark with halo */}
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
        <HeroMark size={64} halo="#7AA7FF" breathe />
        <div style={{ fontSize: 15, fontWeight: 300, color: COLOR.sec, letterSpacing: -0.1, fontStyle: 'italic' }}>thinking…</div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// SCREEN 4 — Note Detail (sheet)
// ─────────────────────────────────────────────────────────────
function DetailSheet({ note, checks, onToggle, onClose }) {
  const isTask = note.kind === 'task';
  const tasks = isTask ? [
    'book venue (proposal received from two)',
    'send calendar invite to the team',
    'finalize agenda — circulate by friday',
  ] : [];
  return (
    <div style={{ position: 'absolute', inset: 0, pointerEvents: 'auto' }}>
      {/* Backdrop — inbox darkened */}
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(10,10,11,0.18)', backdropFilter: 'blur(2px)', WebkitBackdropFilter: 'blur(2px)' }}/>
      {/* Sheet */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: '#F4F6F8',
        borderTopLeftRadius: 28, borderTopRightRadius: 28,
        padding: '10px 24px 34px',
        boxShadow: '0 -1px 0 rgba(255,255,255,0.6) inset',
        animation: 'qn-sheet-in 360ms cubic-bezier(.2,.7,.2,1) both',
        maxHeight: '78%', overflow: 'hidden', display: 'flex', flexDirection: 'column',
      }}>
        {/* Grabber */}
        <div style={{ display: 'flex', justifyContent: 'center', padding: '6px 0 14px' }}>
          <div style={{ width: 36, height: 5, borderRadius: 999, background: 'rgba(10,10,11,0.18)' }}/>
        </div>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <Badge kind={note.kind} />
          <span style={{ fontSize: 12, color: COLOR.ter, fontWeight: 300 }}>captured · {note.time}</span>
        </div>
        <div style={{ fontSize: 12, fontStyle: 'italic', fontWeight: 300, color: COLOR.ter, letterSpacing: -0.05, marginBottom: 8 }}>from a tuesday afternoon.</div>
        {/* Raw text */}
        <div style={{ fontFamily: FONT_HEAD, fontSize: 22, fontWeight: 700, lineHeight: 1.25, letterSpacing: -0.5, color: COLOR.text, textWrap: 'pretty' }}>
          {note.text}
        </div>
        <div style={{ height: 0.5, background: COLOR.divider, margin: '22px 0 16px' }}/>
        {/* Action items (task) */}
        {isTask && (
          <>
            <div style={{ fontSize: 11, fontWeight: 500, letterSpacing: 1.4, textTransform: 'uppercase', color: COLOR.ter, marginBottom: 10 }}>action items</div>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              {tasks.map((t, i) => {
                const checked = (checks || {})[i];
                return (
                  <div key={i} onClick={() => onToggle && onToggle(i)} style={{
                    minHeight: 36, display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer',
                  }}>
                    <div style={{
                      width: 18, height: 18, borderRadius: 999,
                      background: checked ? COLOR.text : 'transparent',
                      boxShadow: checked ? 'none' : `inset 0 0 0 1.4px ${COLOR.ter}`,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      transition: 'all 200ms',
                    }}>
                      {checked && <svg width="10" height="10" viewBox="0 0 10 10" fill="none"><path d="M2 5.2 L4.2 7.2 L8 3" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>}
                    </div>
                    <div style={{
                      fontSize: 15, fontWeight: 300, letterSpacing: -0.1,
                      color: checked ? COLOR.sec : COLOR.text,
                      textDecoration: checked ? 'line-through' : 'none',
                      transition: 'all 200ms',
                    }}>{t}</div>
                  </div>
                );
              })}
            </div>
            <div style={{ height: 0.5, background: COLOR.divider, margin: '20px 0 16px' }}/>
          </>
        )}
        {/* Tags */}
        <div style={{ fontSize: 11, fontWeight: 500, letterSpacing: 1.4, textTransform: 'uppercase', color: COLOR.ter, marginBottom: 10 }}>tags</div>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 18 }}>
          {(isTask ? ['offsite', 'q2', 'planning'] : ['product', 'onboarding']).map(t => (
            <span key={t} style={{
              height: 26, padding: '0 10px',
              display: 'inline-flex', alignItems: 'center',
              background: COLOR.glassWhite, backdropFilter: 'blur(10px)',
              boxShadow: `inset 0 0 0 0.5px ${COLOR.glassBorder}`,
              borderRadius: 999, fontSize: 12, color: COLOR.sec, fontWeight: 400, letterSpacing: -0.1,
            }}>{t}</span>
          ))}
        </div>
        {/* Summary */}
        <div style={{ fontSize: 11, fontWeight: 500, letterSpacing: 1.4, textTransform: 'uppercase', color: COLOR.ter, marginBottom: 8 }}>summary</div>
        <div style={{ fontSize: 15, fontStyle: 'italic', fontWeight: 300, color: COLOR.sec, letterSpacing: -0.1, lineHeight: 1.45 }}>
          {isTask
            ? 'three concrete steps to land q2 offsite by friday — venue, invite, agenda.'
            : 'a hypothesis about removing onboarding ceremony in favor of pre-populated state.'}
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{ marginTop: 22, display: 'flex', justifyContent: 'flex-end' }}>
          <button style={{ background: 'none', border: 'none', padding: '8px 4px', cursor: 'pointer', fontSize: 13, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.1 }}>delete note</button>
        </div>
      </div>
    </div>
  );
}

function DetailScreen() {
  const [checks, setChecks] = React.useState({ 0: true });
  return (
    <Phone>
      <Wallpaper />
      <StatusBar />
      {/* Inbox preview, slightly dimmed under sheet */}
      <div style={{ position: 'absolute', inset: 0, opacity: 0.55, pointerEvents: 'none' }}>
        <div style={{ padding: '90px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
          {SAMPLE_NOTES.slice(0, 4).map(n => <Glass key={n.id} style={{ height: 96 }} />)}
        </div>
      </div>
      <DetailSheet note={SAMPLE_NOTES[0]} checks={checks} onToggle={(i) => setChecks(c => ({ ...c, [i]: !c[i] }))} />
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// SCREEN 5 — Lock Screen Widgets (small + medium, dark context)
// ─────────────────────────────────────────────────────────────
function LockScreen() {
  return (
    <Phone dark>
      <div style={{ position: 'absolute', inset: 0, background:
        'radial-gradient(120% 80% at 30% 10%, #2b3340 0%, #1a1f28 50%, #0d1218 100%)' }} />
      <div style={{ position: 'absolute', inset: 0, background:
        'radial-gradient(40% 30% at 80% 80%, rgba(120,140,170,0.22), transparent 70%)' }} />
      <StatusBarLight />
      {/* Time */}
      <div style={{ position: 'absolute', top: 64, left: 0, right: 0, textAlign: 'center', color: '#fff' }}>
        <div style={{ fontFamily: FONT_HEAD, fontSize: 14, fontWeight: 400, opacity: 0.85, letterSpacing: 0.5 }}>Friday, April 25</div>
        <div style={{ fontFamily: FONT_HEAD, fontSize: 88, fontWeight: 200, lineHeight: 1, letterSpacing: -3, marginTop: 2 }}>9:41</div>
      </div>
      {/* Widgets — small (left) + small (right) on top row, medium (full) below */}
      <div style={{ position: 'absolute', top: 270, left: 20, right: 20, display: 'flex', flexDirection: 'column', gap: 10 }}>
        {/* Small pair */}
        <div style={{ display: 'flex', gap: 10 }}>
          {/* Small — last note */}
          <LockGlass style={{ width: 162, height: 162, padding: '14px 16px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Mark size={16} stroke={1.4} color="#fff" />
              <span style={{ fontSize: 10, fontWeight: 500, letterSpacing: 1.2, textTransform: 'uppercase', color: 'rgba(255,255,255,0.55)' }}>now</span>
            </div>
            <div>
              <div style={{ fontSize: 13, fontWeight: 300, color: '#fff', lineHeight: 1.35, letterSpacing: -0.1, display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>plan the q2 offsite — book venue, send invite, finalize agenda…</div>
              <div style={{ marginTop: 8, display: 'inline-flex', alignItems: 'center', gap: 4, padding: '2px 8px', borderRadius: 999, background: 'rgba(255,255,255,0.14)', fontSize: 10, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase', color: '#fff' }}>
                <CatIcon kind="task" size={10} color="#fff" /> task
              </div>
            </div>
          </LockGlass>
          {/* Small — quick capture shortcut */}
          <LockGlass style={{ flex: 1, height: 162, padding: '14px 16px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Mark size={16} stroke={1.4} color="#fff" />
              <span style={{ fontSize: 10, fontWeight: 500, letterSpacing: 1.2, textTransform: 'uppercase', color: 'rgba(255,255,255,0.55)' }}>capture</span>
            </div>
            <div style={{ fontSize: 14, fontWeight: 300, color: 'rgba(255,255,255,0.7)', letterSpacing: -0.1, lineHeight: 1.35 }}>tap to leave it here.</div>
            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <div style={{ width: 38, height: 38, borderRadius: 999, background: 'rgba(255,255,255,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.25)' }}>
                <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M7 11 V3 M3 7 L7 3 L11 7" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
              </div>
            </div>
          </LockGlass>
        </div>
        {/* Medium 4x2 */}
        <LockGlass style={{ height: 162, padding: '14px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <Mark size={14} stroke={1.4} color="#fff" />
              <span style={{ fontSize: 11, fontWeight: 500, letterSpacing: 1.4, textTransform: 'uppercase', color: 'rgba(255,255,255,0.7)' }}>quick capture</span>
            </div>
            <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.55)', fontWeight: 300 }}>3 today</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <LockRow kind="task" text="plan the q2 offsite — book venue…" time="now" />
            <div style={{ height: 0.5, background: 'rgba(255,255,255,0.18)', margin: '8px 0' }}/>
            <LockRow kind="idea" text="onboarding without a tour" time="12m" />
            <div style={{ height: 0.5, background: 'rgba(255,255,255,0.18)', margin: '8px 0' }}/>
            <LockRow kind="link" text="arxiv.org/2401.04088" time="1h" />
          </div>
        </LockGlass>
      </div>
    </Phone>
  );
}

function LockRow({ kind, text, time }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <CatIcon kind={kind} size={12} color="#fff" />
      <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', opacity: 0.92 }}>{text}</span>
      <span style={{ opacity: 0.55, fontVariantNumeric: 'tabular-nums' }}>{time}</span>
    </div>
  );
}

function LockGlass({ children, style }) {
  return (
    <div style={{
      borderRadius: 22,
      background: 'rgba(255,255,255,0.12)',
      backdropFilter: 'blur(28px) saturate(160%)',
      WebkitBackdropFilter: 'blur(28px) saturate(160%)',
      boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.18)',
      ...style,
    }}>{children}</div>
  );
}

function StatusBarLight() {
  return (
    <div style={{
      height: 54, padding: '20px 28px 0', display: 'flex',
      alignItems: 'center', justifyContent: 'space-between',
      fontFamily: FONT_HEAD, fontSize: 16, fontWeight: 600, color: '#fff',
      letterSpacing: -0.2,
    }}>
      <span>9:41</span>
      <div style={{ display: 'flex', gap: 6, alignItems: 'center', opacity: 0.95 }}>
        <svg width="17" height="11" viewBox="0 0 17 11"><rect x="0" y="7" width="3" height="4" rx="0.6" fill="#fff"/><rect x="4.5" y="5" width="3" height="6" rx="0.6" fill="#fff"/><rect x="9" y="2.5" width="3" height="8.5" rx="0.6" fill="#fff"/><rect x="13.5" y="0" width="3" height="11" rx="0.6" fill="#fff"/></svg>
        <svg width="24" height="11" viewBox="0 0 24 11"><rect x="0.5" y="0.5" width="20" height="10" rx="2.5" stroke="#fff" strokeOpacity="0.4" fill="none"/><rect x="2" y="2" width="17" height="7" rx="1.5" fill="#fff"/></svg>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SCREEN 6 — Empty States
// ─────────────────────────────────────────────────────────────
function EmptyScreen({ variant = 'inbox' }) {
  const map = {
    inbox:  { hero: <HeroMark size={68} halo="#7AA7FF" />,                     head: 'your brain\'s offsite.', sub: 'fill it back up.', pulse: false },
    filter: { hero: <HeroMark size={56} halo="#7AA7FF" />,                     head: 'no tasks yet.',          sub: 'they\'ll surface here once you mention them.', pulse: false },
    first:  { hero: <HeroMark size={68} halo="#7AA7FF" breathe />,             head: 'nothing here yet.',      sub: 'capture your first thought.', pulse: true },
  };
  const cfg = map[variant];
  return (
    <Phone>
      <Wallpaper />
      <StatusBar />
      {/* Header (so this looks like inbox in empty state) */}
      <div style={{ height: 44, padding: '0 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Mark size={22} stroke={1.4} />
        <div style={{ width: 20, height: 20 }}/>
      </div>
      <div style={{ padding: '4px 20px 18px' }}>
        <div style={{ fontSize: 12, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.05, marginBottom: 4 }}>
          {variant === 'first' ? 'welcome.' : 'good morning, alex.'}
        </div>
        <div style={{ fontFamily: FONT_HEAD, fontSize: 34, fontWeight: 800, letterSpacing: -1, color: COLOR.text, lineHeight: 1 }}>
          mind
        </div>
      </div>
      {variant === 'filter' && <FilterChips active="tasks" />}
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 32px', pointerEvents: 'none' }}>
        <div>{cfg.hero}</div>
        <div style={{ marginTop: 14, fontFamily: FONT_HEAD, fontSize: 19, fontWeight: 700, letterSpacing: -0.4, color: COLOR.text }}>{cfg.head}</div>
        <div style={{ marginTop: 6, fontSize: 13, fontWeight: 300, color: COLOR.sec, letterSpacing: -0.1, textAlign: 'center', maxWidth: 240 }}>{cfg.sub}</div>
      </div>
      <div style={{ position: 'absolute', left: 16, right: 16, bottom: 36, animation: cfg.pulse ? 'qn-pulse 2s ease-in-out infinite' : 'none', borderRadius: 18 }}>
        <CaptureBar value="" />
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// INTERACTIVE — full prototype with state machine
// ─────────────────────────────────────────────────────────────
function Prototype() {
  const t = useQnTweaks();
  const halo = t.haloColor || '#7AA7FF';
  const greeting = t.headerGreeting ?? 'good morning, alex.';
  const titleWord = t.headerTitle ?? 'mind';
  const placeholder = t.captureCopy ?? 'anything on your mind…';
  const showLib = t.showLibraryPill !== false;
  const noteListTop = t.noteListTop || 230;

  // ── Swipe between Mind <-> Library. Only fires when the gesture starts in the
  //    outer 24px gutters, so it doesn't fight the input, the chip row, or
  //    horizontal scrolling inside cards.
  const swipeRef = React.useRef({ x: 0, y: 0, active: false, dir: 0 });
  const onPointerDown = (e) => {
    const x = e.clientX ?? (e.touches && e.touches[0]?.clientX) ?? 0;
    const y = e.clientY ?? (e.touches && e.touches[0]?.clientY) ?? 0;
    const rect = e.currentTarget.getBoundingClientRect();
    const localX = x - rect.left;
    const fromLeftEdge = localX < 28;
    const fromRightEdge = localX > rect.width - 28;
    if (!fromLeftEdge && !fromRightEdge) return;
    swipeRef.current = { x, y, active: true, dir: fromLeftEdge ? 1 : -1 };
  };
  const onPointerMove = (e) => {
    if (!swipeRef.current.active) return;
    const x = e.clientX ?? (e.touches && e.touches[0]?.clientX) ?? 0;
    const y = e.clientY ?? (e.touches && e.touches[0]?.clientY) ?? 0;
    const dx = x - swipeRef.current.x;
    const dy = y - swipeRef.current.y;
    if (Math.abs(dy) > 40) { swipeRef.current.active = false; return; }
    if (Math.abs(dx) > 50) {
      // dir = +1 means started at left edge (swipe-right gesture, but here we want
      // a swipe-LEFT to go to library and swipe-RIGHT to come back from library).
      // From Mind: swipe LEFT (dx<0) → library. From Library: swipe RIGHT (dx>0) → mind.
      if (stage !== 'library' && dx < -50 && swipeRef.current.dir === -1) {
        setStage('library');
      } else if (stage === 'library' && dx > 50 && swipeRef.current.dir === 1) {
        setStage('inbox');
      }
      swipeRef.current.active = false;
    }
  };
  const onPointerUp = () => { swipeRef.current.active = false; };

  const [stage, setStage] = React.useState('splash'); // splash | inbox | processing | detail | library
  const [filter, setFilter] = React.useState('all');
  const [notes, setNotes] = React.useState(SAMPLE_NOTES);
  const [capture, setCapture] = React.useState('');
  const [active, setActive] = React.useState(null);
  const [checks, setChecks] = React.useState({ 0: true });
  const [swipedId, setSwipedId] = React.useState(null);
  const [toast, setToast] = React.useState(false);
  const filtered = filter === 'all' ? notes : notes.filter(n => n.kind + 's' === filter);

  const URL_RE = /(https?:\/\/|www\.|\.com|\.org|\.io|\.net|youtu\.be|tiktok|instagram)/i;

  const submit = () => {
    if (!capture.trim()) return;
    const text = capture.trim();
    setCapture('');
    // URL → goes to Library, never enters Mind
    if (URL_RE.test(text)) {
      setToast(true);
      setTimeout(() => setToast(false), 2400);
      return;
    }
    setStage('processing');
    setTimeout(() => {
      const k = /^(call|email|book|finish|send|finalize|plan|buy|fix|ship|prep)\b/i.test(text) ? 'task'
        : /\?|what if|maybe|idea/i.test(text) ? 'idea' : 'note';
      const note = { id: Date.now(), kind: k, time: 'now', text, sub: k === 'task' ? '1 action item extracted' : 'tagged · captured' };
      setNotes(n => [note, ...n]);
      setStage('inbox');
    }, 1400);
  };

  return (
    <div
      style={{ position: 'relative', width: 390, height: 844, fontFamily: FONT_BODY, color: COLOR.text, touchAction: 'pan-y' }}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
    >
      {/* INBOX layer (always rendered as base) */}
      <Phone>
        <Wallpaper />
        <StatusBar />
        <div style={{ height: 44, padding: '0 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Mark size={22} stroke={1.4} />
          {showLib ? (
            <button onClick={() => setStage('library')} aria-label="open library" style={{
              background: 'rgba(10,10,11,0.06)',
              border: 'none', padding: '0 12px 0 10px', cursor: 'pointer',
              height: 32, borderRadius: 999,
              display: 'flex', alignItems: 'center', gap: 8,
              color: COLOR.text, fontSize: 13, fontWeight: 400, letterSpacing: -0.1,
              boxShadow: 'inset 0 0 0 0.5px rgba(10,10,11,0.06)',
              backdropFilter: 'blur(20px) saturate(160%)',
              WebkitBackdropFilter: 'blur(20px) saturate(160%)',
            }}>
              {/* Stack glyph — three stacked rectangles */}
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                <rect x="2" y="2.5" width="10" height="2.2" rx="0.6" stroke={COLOR.text} strokeWidth="1.1"/>
                <rect x="2" y="6" width="10" height="2.2" rx="0.6" stroke={COLOR.text} strokeWidth="1.1"/>
                <rect x="2" y="9.5" width="10" height="2.2" rx="0.6" stroke={COLOR.text} strokeWidth="1.1"/>
              </svg>
              <span>library</span>
              <span style={{
                minWidth: 18, height: 18, padding: '0 5px',
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                borderRadius: 999,
                background: halo, color: '#0A0A0B',
                fontFamily: FONT_HEAD, fontSize: 10.5, fontWeight: 600, letterSpacing: 0,
                boxShadow: 'inset 0 0 0 0.5px rgba(10,10,11,0.08), 0 1px 2px rgba(0,0,0,0.08)',
                fontVariantNumeric: 'tabular-nums',
              }}>{SAMPLE_LINKS ? SAMPLE_LINKS.length : 8}</span>
            </button>
          ) : <div style={{ width: 20, height: 20 }}/>}
        </div>
        <div style={{ padding: '4px 20px 18px' }}>
          <div style={{ fontSize: 12, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.05, marginBottom: 4 }}>{greeting}</div>
          <div style={{ fontFamily: FONT_HEAD, fontSize: 34, fontWeight: 800, letterSpacing: -1, lineHeight: 1 }}>
            {titleWord}
            <span style={{ fontSize: 12, fontWeight: 300, color: COLOR.ter, letterSpacing: -0.1, marginLeft: 10, verticalAlign: 'middle' }}>· {filtered.length} thought{filtered.length === 1 ? '' : 's'}</span>
          </div>
        </div>
        <FilterChips active={filter} onChange={setFilter} />
        <div style={{
          position: 'absolute', top: noteListTop, left: 0, right: 0, bottom: 0,
          padding: '14px 20px 140px', overflowY: 'auto',
          maskImage: 'linear-gradient(to bottom, transparent 0, #000 18px, #000 calc(100% - 120px), transparent calc(100% - 24px))',
          WebkitMaskImage: 'linear-gradient(to bottom, transparent 0, #000 18px, #000 calc(100% - 120px), transparent calc(100% - 24px))',
        }}>
          {filtered.length === 0 ? (
            <div style={{ height: 380, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
              <CatIcon kind={filter === 'tasks' ? 'task' : filter === 'ideas' ? 'idea' : filter === 'links' ? 'link' : 'note'} size={32} color={COLOR.text} />
              <div style={{ marginTop: 16, fontFamily: FONT_HEAD, fontSize: 17, fontWeight: 700, letterSpacing: -0.3 }}>no {filter} yet</div>
              <div style={{ marginTop: 4, fontSize: 13, fontWeight: 300, color: COLOR.sec }}>they'll show up here.</div>
            </div>
          ) : (
            <div key={filter} style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {filtered.map((n, i) => (
                <div key={n.id} style={{
                  animation: 'qn-card-in 320ms cubic-bezier(.2,.7,.2,1) both',
                  animationDelay: `${i * 40}ms`,
                }}>
                  <NoteCard
                    note={n}
                    swiped={swipedId === n.id}
                    onTap={() => {
                      if (swipedId === n.id) { setSwipedId(null); return; }
                      if (swipedId) { setSwipedId(null); return; }
                      setActive(n); setStage('detail');
                    }}
                  />
                  {/* Long-press / right-click area to swipe */}
                  <div onContextMenu={(e) => { e.preventDefault(); setSwipedId(swipedId === n.id ? null : n.id); }} style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}/>
                </div>
              ))}
            </div>
          )}
        </div>
        {/* Page dots — above capture bar; teaches the two-surface model */}
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: 102, display: 'flex', justifyContent: 'center', gap: 6, pointerEvents: 'none' }}>
          <span aria-label="mind page" style={{ width: 6, height: 6, borderRadius: 999, background: COLOR.text, opacity: 0.85 }}/>
          <span aria-label="library page" style={{ width: 6, height: 6, borderRadius: 999, background: COLOR.text, opacity: 0.18 }}/>
        </div>
        {/* Capture bar (interactive) */}
        <div style={{ position: 'absolute', left: 16, right: 16, bottom: 36 }}>
          <Glass radius={18} blur={28} style={{ padding: '10px 10px 10px 16px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 52 }}>
            <input
              value={capture}
              onChange={(e) => setCapture(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') submit(); }}
              placeholder={placeholder}
              style={{
                flex: 1, border: 'none', outline: 'none', background: 'transparent',
                fontFamily: FONT_BODY, fontSize: 15, fontWeight: 300, color: COLOR.text, letterSpacing: -0.15,
                padding: '4px 0',
              }}
            />
            <button onClick={submit} style={{
              position: 'relative',
              width: 32, height: 32, borderRadius: 999, border: 'none', cursor: 'pointer',
              background: 'linear-gradient(180deg, #1a1a1d, #000)',
              opacity: capture.length > 0 ? 1 : 0,
              transform: capture.length > 0 ? 'scale(1)' : 'scale(0.6)',
              transition: 'opacity 180ms, transform 220ms cubic-bezier(.2,.7,.2,1)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.22), inset 0 -1px 0 rgba(0,0,0,0.5), 0 4px 10px rgba(0,0,0,0.18)',
            }}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M7 11.5 V2.5 M3 6.5 L7 2.5 L11 6.5" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </button>
          </Glass>
        </div>
        <LibraryToast visible={toast} onPeek={() => { setToast(false); setStage('library'); }} />
      </Phone>

      {/* LIBRARY overlay */}
      {stage === 'library' && (
        <div style={{ position: 'absolute', inset: 0, animation: 'qn-slide-in-right 360ms cubic-bezier(.2,.7,.2,1) both' }}>
          <LibraryScreen onBack={() => setStage('inbox')} />
        </div>
      )}

      {/* SPLASH overlay */}
      {stage === 'splash' && (
        <div style={{ position: 'absolute', inset: 0, animation: 'qn-fade-in 240ms ease both' }}>
          <Phone>
            <Wallpaper />
            <StatusBar />
            <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 32px' }}>
              <div style={{ marginBottom: 24 }}><HeroMark size={72} halo={halo} breathe /></div>
              <div style={{ fontFamily: FONT_HEAD, fontSize: 30, fontWeight: 800, letterSpacing: -0.7 }}>quicknote</div>
              <div style={{ marginTop: 10, fontSize: 15, fontWeight: 300, color: COLOR.sec, letterSpacing: -0.1, textAlign: 'center', maxWidth: 260, lineHeight: 1.45 }}>a quieter place<br/>than your own messages.</div>
            </div>
            <div style={{ position: 'absolute', left: 20, right: 20, bottom: 56 }}>
              <GlossButton onClick={() => setStage('inbox')}>get started</GlossButton>
              <div style={{ textAlign: 'center', marginTop: 18, fontSize: 12, color: COLOR.ter, fontWeight: 300 }}>private by default · no account required</div>
            </div>
          </Phone>
        </div>
      )}

      {/* PROCESSING overlay */}
      {stage === 'processing' && (
        <div style={{ position: 'absolute', inset: 0, animation: 'qn-fade-in 200ms ease both' }}>
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(240,242,244,0.55)', backdropFilter: 'blur(14px)', WebkitBackdropFilter: 'blur(14px)' }}/>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
            <HeroMark size={64} halo={halo} breathe />
            <div style={{ fontSize: 15, fontWeight: 300, color: COLOR.sec, fontStyle: 'italic' }}>thinking…</div>
          </div>
        </div>
      )}

      {/* DETAIL overlay */}
      {stage === 'detail' && active && (
        <DetailSheet
          note={active}
          checks={checks}
          onToggle={(i) => setChecks(c => ({ ...c, [i]: !c[i] }))}
          onClose={() => { setStage('inbox'); setActive(null); }}
        />
      )}
    </div>
  );
}

Object.assign(window, {
  Mark, HeroMark, CatIcon, Glass, GlossButton, StatusBar, Phone, Wallpaper,
  SplashScreen, InboxScreen, ProcessingScreen, DetailScreen, LockScreen, EmptyScreen,
  Prototype, NoteCard, CaptureBar, FilterChips, Badge, DetailSheet,
  SAMPLE_NOTES, COLOR,
});
