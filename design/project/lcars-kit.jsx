// LCARS-inspired primitives for CaptainsLog
// — asymmetric elbow frames, pill controls, color cells, horizontal bars
// Strictly an aesthetic influence; not a copy of any branded UI.

const LCARS = {
  // Warm saturated palette on near-black
  bg:       '#07070a',
  panel:    '#0b0b0f',
  ink:      '#f3e9d8',   // warm off-white
  dim:      '#8a8173',   // muted warm grey
  rail:     '#FF9933',   // primary orange
  wheat:    '#FFCC66',
  russet:   '#CC6666',
  plum:     '#9966CC',
  steel:    '#6688CC',
  dusty:    '#C8A97E',
  // Type
  display:  "'Antonio', 'Oswald', 'Barlow Condensed', sans-serif",
  body:     "'Inter', -apple-system, sans-serif",
  mono:     "'JetBrains Mono', 'SF Mono', 'Menlo', monospace",
};

// ── Pill — LCARS-style capsule button/label ────────────────────────────────
function Pill({ children, color = LCARS.rail, textColor = '#000', width, height = 26, style = {}, align = 'flex-end', pad = 14 }) {
  return (
    <div style={{
      height, minWidth: height, width,
      background: color, color: textColor,
      borderRadius: height / 2,
      display: 'flex', alignItems: 'center', justifyContent: align,
      paddingLeft: pad, paddingRight: pad,
      fontFamily: LCARS.display, fontWeight: 500,
      fontSize: Math.round(height * 0.5),
      letterSpacing: '0.06em',
      textTransform: 'uppercase',
      lineHeight: 1,
      whiteSpace: 'nowrap',
      ...style,
    }}>{children}</div>
  );
}

// ── Cell — rectangular color block used as a label strip ───────────────────
function Cell({ children, color = LCARS.wheat, textColor = '#000', width, height = 26, style = {}, align = 'flex-end', pad = 12 }) {
  return (
    <div style={{
      height, width, background: color, color: textColor,
      display: 'flex', alignItems: 'center', justifyContent: align,
      paddingLeft: pad, paddingRight: pad,
      fontFamily: LCARS.display, fontWeight: 500,
      fontSize: Math.round(height * 0.5),
      letterSpacing: '0.06em', textTransform: 'uppercase',
      lineHeight: 1, whiteSpace: 'nowrap',
      ...style,
    }}>{children}</div>
  );
}

// ── Elbow — the signature LCARS "L" corner piece ───────────────────────────
// direction: 'tl' | 'tr' | 'bl' | 'br'
// The elbow is a block with a rounded inner corner cut out.
function Elbow({ color = LCARS.rail, width = 160, height = 90, radius = 40, direction = 'tl', thickness = 28, style = {} }) {
  // We draw via two divs: a horizontal bar and a vertical bar that overlap,
  // then apply a single large border-radius on the outside corner.
  const isTop = direction.includes('t');
  const isLeft = direction.includes('l');
  const br = {
    tl: `${radius}px 0 0 0`,
    tr: `0 ${radius}px 0 0`,
    bl: `0 0 0 ${radius}px`,
    br: `0 0 ${radius}px 0`,
  }[direction];
  return (
    <div style={{ position: 'relative', width, height, ...style }}>
      {/* horizontal bar */}
      <div style={{
        position: 'absolute', left: 0, right: 0, height: thickness,
        top: isTop ? 0 : 'auto', bottom: isTop ? 'auto' : 0,
        background: color,
        borderRadius: br,
      }} />
      {/* vertical bar */}
      <div style={{
        position: 'absolute', top: 0, bottom: 0, width: thickness,
        left: isLeft ? 0 : 'auto', right: isLeft ? 'auto' : 0,
        background: color,
        borderRadius: br,
      }} />
    </div>
  );
}

// ── HBar — horizontal divider with a gap and terminating pill ──────────────
function HBar({ color = LCARS.rail, height = 8, style = {}, children }) {
  return (
    <div style={{
      height, background: color, borderRadius: height / 2,
      ...style,
    }}>{children}</div>
  );
}

// ── Row — common LCARS layout: colored cell label + content ────────────────
function LabelRow({ label, color = LCARS.wheat, textColor = '#000', children, cellWidth = 96, gap = 8, style = {} }) {
  return (
    <div style={{ display: 'flex', gap, alignItems: 'stretch', ...style }}>
      <Cell color={color} textColor={textColor} width={cellWidth} height={22} align="flex-end" pad={10}>{label}</Cell>
      <div style={{ flex: 1, color: LCARS.ink, fontFamily: LCARS.body, fontSize: 13, display: 'flex', alignItems: 'center' }}>
        {children}
      </div>
    </div>
  );
}

// ── Left rail — stack of pills/cells forming the sidebar column ────────────
function LeftRail({ width = 120, children, style = {} }) {
  return (
    <div style={{
      width, display: 'flex', flexDirection: 'column', gap: 4,
      ...style,
    }}>{children}</div>
  );
}

// ── WaveformBars — fake live audio waveform ────────────────────────────────
function WaveformBars({ count = 48, color = LCARS.rail, height = 32, active = true, seed = 1 }) {
  // Deterministic pseudo-random so layout is stable
  const bars = [];
  let s = seed;
  for (let i = 0; i < count; i++) {
    s = (s * 9301 + 49297) % 233280;
    const r = s / 233280;
    const centerDist = Math.abs(i - count / 2) / (count / 2);
    const env = 1 - centerDist * 0.6;
    const h = Math.max(2, Math.round((0.25 + r * 0.75) * height * env));
    bars.push(h);
  }
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 2, height }}>
      {bars.map((h, i) => (
        <div key={i} style={{
          width: 2, height: h, background: color,
          opacity: active ? (0.5 + (h / height) * 0.5) : 0.25,
          borderRadius: 1,
        }} />
      ))}
    </div>
  );
}

// ── StageDots — 4 stage indicators for processing ──────────────────────────
// stages: ['transcribe', 'cleanup', 'name', 'enrich']
// state per stage: 'done' | 'active' | 'queued' | 'idle' | 'paused'
function StageDots({ stages, compact = false }) {
  const COLORS = {
    done:   LCARS.rail,
    active: LCARS.wheat,
    queued: LCARS.dusty,
    idle:   '#2a2520',
    paused: LCARS.russet,
  };
  const LABELS = ['TRN', 'CLN', 'NAM', 'ENR'];
  return (
    <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
      {stages.map((st, i) => (
        <div key={i} style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
        }}>
          <div style={{
            width: compact ? 18 : 26, height: 4,
            background: COLORS[st],
            borderRadius: 2,
            opacity: st === 'idle' ? 0.6 : 1,
          }} />
          {!compact && (
            <div style={{
              fontFamily: LCARS.mono, fontSize: 8, letterSpacing: '0.12em',
              color: st === 'idle' ? LCARS.dim : LCARS.ink,
              opacity: st === 'idle' ? 0.5 : 0.9,
            }}>{LABELS[i]}</div>
          )}
        </div>
      ))}
    </div>
  );
}

// ── AppFrame — the actual macOS window wrapper, titleless, dark ────────────
function AppFrame({ width, height, children, style = {} }) {
  return (
    <div style={{
      width, height, background: LCARS.bg,
      borderRadius: 12,
      overflow: 'hidden',
      position: 'relative',
      boxShadow: '0 20px 60px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,153,51,0.08)',
      fontFamily: LCARS.body,
      color: LCARS.ink,
      ...style,
    }}>
      {/* Titleless draggable strip with traffic lights only */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 28,
        display: 'flex', alignItems: 'center', gap: 8,
        paddingLeft: 14, zIndex: 10,
        pointerEvents: 'none',
      }}>
        <div style={{ width: 12, height: 12, borderRadius: 6, background: '#FF5F57' }} />
        <div style={{ width: 12, height: 12, borderRadius: 6, background: '#FEBC2E' }} />
        <div style={{ width: 12, height: 12, borderRadius: 6, background: '#28C840' }} />
      </div>
      {children}
    </div>
  );
}

Object.assign(window, {
  LCARS, Pill, Cell, Elbow, HBar, LabelRow, LeftRail,
  WaveformBars, StageDots, AppFrame,
});
