// Main window — single-column timeline with docked record bar
// Dimensions target ~720×780 (above the 620×660 minimum)

function MainWindow({ accent, recordStyle, recording = false }) {
  const W = 720, H = 780;
  const ORANGE = accent?.orange || LCARS.rail;
  const WHEAT  = accent?.wheat  || LCARS.wheat;
  const RUSSET = accent?.russet || LCARS.russet;
  const PLUM   = accent?.plum   || LCARS.plum;
  const STEEL  = accent?.steel  || LCARS.steel;

  // Fake entry data
  const entries = [
    {
      t: '14:32', date: 'STARDATE 79512.3',
      title: 'Rethinking the processing queue ordering',
      summary: 'Stages are sequential today, but transcription could fan out while cleanup runs on the previous entry. Worth a design sketch before touching the executor.',
      tags: ['architecture', 'voice-tooling'],
      people: ['Anouk'], proj: 'CaptainsLog',
      stages: ['done', 'done', 'done', 'active'], status: 'ENRICHING',
      statusColor: WHEAT,
    },
    {
      t: '11:08', date: 'STARDATE 79512.3',
      title: 'Morning walk — thoughts on Dutch/English switching',
      summary: 'The model keeps hallucinating English tokens inside Dutch phrases. I think the personal context prompt needs to name the two languages explicitly.',
      tags: ['language', 'research'], people: [], proj: 'CaptainsLog',
      stages: ['done', 'done', 'done', 'done'], status: 'READY',
      statusColor: ORANGE,
    },
    {
      t: '09:47', date: 'STARDATE 79512.3',
      title: 'Call with Pioneer Trust — onboarding rollout',
      summary: 'Confirmed Q2 launch. They want SSO before wider deployment; I pushed back on scope. Need to share the phased plan by Friday.',
      tags: ['clients', 'roadmap'], people: ['Elif', 'Johan'], proj: 'Onboarding',
      stages: ['done', 'done', 'done', 'done'], status: 'READY',
      statusColor: ORANGE,
    },
    {
      t: 'YESTERDAY · 17:21', date: 'STARDATE 79511.8',
      title: 'Debrief — why the model-load screen felt broken',
      summary: '',
      tags: [], people: [], proj: '',
      stages: ['done', 'active', 'queued', 'queued'], status: 'PAUSED',
      statusColor: RUSSET, paused: true,
    },
  ];

  return (
    <AppFrame width={W} height={H}>
      {/* ── Top elbow frame ──────────────────────────────────────────── */}
      <div style={{ display: 'flex', gap: 6, paddingTop: 34, paddingLeft: 10, paddingRight: 14, alignItems: 'flex-start' }}>
        {/* Left rail top-elbow — horizontal bar aligns with app title bar */}
        <div style={{ width: 110 }}>
          <Elbow color={ORANGE} width={110} height={74} radius={36} direction="tl" thickness={26} />
        </div>

        {/* Top bar region: horizontal strip with app title + status pills */}
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <div style={{ flex: 1, height: 26, background: ORANGE, borderRadius: '0 13px 13px 0',
              display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
              paddingLeft: 18, paddingRight: 16, color: '#000',
              fontFamily: LCARS.display, fontWeight: 600, fontSize: 14,
              letterSpacing: '0.12em',
            }}>
              CAPTAINSLOG · 041
            </div>
            <Pill color={WHEAT} height={26} pad={12}>LOCAL</Pill>
            <Pill color={PLUM} height={26} pad={12}>79512.3</Pill>
          </div>

          {/* Second row: secondary cells — status, not browsing */}
          <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
            <Cell color={RUSSET} height={16} width={64} pad={8}>041</Cell>
            <Cell color={LCARS.dusty} height={16} width={110} pad={8}>ON-DEVICE</Cell>
            <Cell color={STEEL} height={16} width={90} pad={8}>M3 · 16GB</Cell>
            <div style={{ flex: 1, height: 16, background: '#1a1613', borderRadius: 8 }} />
            <Cell color={ORANGE} height={16} width={80} pad={8}>412 GB</Cell>
          </div>
        </div>
      </div>

      {/* ── Body: left rail + entries column ─────────────────────────── */}
      <div style={{ display: 'flex', gap: 6, paddingLeft: 10, paddingRight: 14, marginTop: 6, height: 614 }}>
        {/* Left rail — focused on core actions: record, review entries, settings */}
        <div style={{ width: 110, display: 'flex', flexDirection: 'column', gap: 4 }}>
          <Cell color={ORANGE} height={48} pad={10} align="flex-end">LOG</Cell>
          <Cell color={WHEAT} height={28} pad={10} align="flex-end">ENTRIES</Cell>
          <Cell color={LCARS.dim} height={28} pad={10} align="flex-end" textColor="#000">SETTINGS</Cell>
          <div style={{ height: 24 }} />
          {/* Queue status — what's currently processing, not browsing UI */}
          <Cell color={LCARS.dusty} height={18} pad={10} align="flex-end" style={{ fontSize: 8 }}>QUEUE</Cell>
          <Cell color={WHEAT} height={36} pad={10} align="flex-end">2 CLEANING</Cell>
          <Cell color={RUSSET} height={22} pad={10} align="flex-end">1 HELD</Cell>
          <div style={{ flex: 1, minHeight: 8 }} />
          {/* Bottom-left elbow terminator */}
          <Elbow color={ORANGE} width={110} height={48} radius={36} direction="bl" thickness={26} />
        </div>

        {/* Entries column */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 10, overflow: 'hidden' }}>
          {/* Date header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 4 }}>
            <div style={{ fontFamily: LCARS.display, fontSize: 13, letterSpacing: '0.2em', color: WHEAT }}>
              FRIDAY · 24 APR 2026
            </div>
            <div style={{ flex: 1, height: 2, background: '#2a2520' }} />
            <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim, letterSpacing: '0.15em' }}>
              03 ENTRIES · 2H 47M
            </div>
          </div>

          {/* Entries */}
          {entries.slice(0, 3).map((e, i) => (
            <EntryRow key={i} e={e} orange={ORANGE} wheat={WHEAT} />
          ))}

          {/* Yesterday header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 2 }}>
            <div style={{ fontFamily: LCARS.display, fontSize: 13, letterSpacing: '0.2em', color: RUSSET }}>
              THURSDAY · 23 APR 2026
            </div>
            <div style={{ flex: 1, height: 2, background: '#2a2520' }} />
            <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim, letterSpacing: '0.15em' }}>
              01 ENTRY · PAUSED
            </div>
          </div>

          <EntryRow e={entries[3]} orange={ORANGE} wheat={WHEAT} />
        </div>
      </div>

      {/* ── Bottom dock: record strip ────────────────────────────────── */}
      <RecordDock style={recordStyle} accent={{ orange: ORANGE, wheat: WHEAT, russet: RUSSET }} recording={recording} />
    </AppFrame>
  );
}

// ── EntryRow ────────────────────────────────────────────────────────────────
function EntryRow({ e, orange, wheat }) {
  const active = e.stages.includes('active');
  return (
    <div style={{
      display: 'flex', gap: 8, alignItems: 'stretch',
      paddingBottom: 10,
      borderBottom: '1px solid #15110e',
    }}>
      {/* Time gutter */}
      <div style={{ width: 60, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', paddingTop: 2 }}>
        <div style={{ fontFamily: LCARS.mono, fontSize: 11, color: wheat, letterSpacing: '0.05em' }}>
          {e.t.includes('YESTERDAY') ? '17:21' : e.t}
        </div>
        <div style={{ fontFamily: LCARS.mono, fontSize: 8, color: LCARS.dim, marginTop: 2 }}>
          {e.paused ? 'HELD' : (active ? 'LIVE' : '')}
        </div>
      </div>

      {/* Content */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
          <div style={{
            fontFamily: LCARS.body, fontSize: 13, fontWeight: 600,
            color: LCARS.ink, flex: 1, minWidth: 0,
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>
            {e.title}
          </div>
          <div style={{ flexShrink: 0 }}>
            <Pill color={e.statusColor} height={16} pad={8}>{e.status}</Pill>
          </div>
        </div>

        {e.summary && (
          <div style={{
            fontFamily: LCARS.body, fontSize: 11.5, color: '#a9a090',
            lineHeight: 1.45, marginBottom: 6,
            overflow: 'hidden', display: '-webkit-box',
            WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
          }}>
            {e.summary}
          </div>
        )}

        {/* Meta row: stages + tags + people */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'nowrap', minWidth: 0, overflow: 'hidden' }}>
          <div style={{ flexShrink: 0 }}>
            <StageDots stages={e.stages} compact />
          </div>
          {e.tags.length > 0 && (
            <>
              <div style={{ width: 1, height: 12, background: '#2a2520', flexShrink: 0 }} />
              <div style={{ display: 'flex', gap: 8, minWidth: 0, overflow: 'hidden' }}>
                {e.tags.map((t, i) => (
                  <div key={i} style={{
                    fontFamily: LCARS.mono, fontSize: 9, color: LCARS.dim,
                    letterSpacing: '0.05em', whiteSpace: 'nowrap',
                  }}>#{t}</div>
                ))}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

// ── RecordDock ─────────────────────────────────────────────────────────────
function RecordDock({ style = 'pill', accent, recording = false }) {
  const { orange, wheat, russet } = accent;

  if (style === 'hero') {
    return (
      <div style={{
        position: 'absolute', bottom: 14, left: 14, right: 14,
        background: '#0f0b08', borderRadius: 24,
        padding: 14, display: 'flex', alignItems: 'center', gap: 14,
      }}>
        <div style={{
          width: 56, height: 56, borderRadius: 28,
          background: recording ? russet : orange,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{
            width: recording ? 18 : 22, height: recording ? 18 : 22,
            borderRadius: recording ? 4 : 11,
            background: '#000',
          }} />
        </div>
        {recording && (
          <div style={{
            width: 44, height: 44, borderRadius: 22,
            background: wheat,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            gap: 3, cursor: 'pointer', flexShrink: 0,
          }} title="Pause (⌘⇧P)">
            <div style={{ width: 4, height: 16, background: '#000' }} />
            <div style={{ width: 4, height: 16, background: '#000' }} />
          </div>
        )}
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: LCARS.display, fontSize: 11, letterSpacing: '0.2em', color: wheat, marginBottom: 4 }}>
            {recording ? 'RECORDING · 00:14' : 'READY TO RECORD'}
          </div>
          <WaveformBars count={56} color={recording ? orange : '#3a3128'} height={28} active={recording} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-end' }}>
          <MicSelector accent={orange} height={28} />
          <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim, letterSpacing: '0.08em' }}>
            {recording ? '⌘R STOP · ⌘⇧P PAUSE' : '⌘R · TOGGLE'}
          </div>
        </div>
      </div>
    );
  }

  if (style === 'command') {
    return (
      <div style={{
        position: 'absolute', bottom: 10, left: 10, right: 14,
        display: 'flex', gap: 6, alignItems: 'center',
      }}>
        <Cell color={orange} height={40} width={110} align="flex-end" pad={14}>
          {recording ? '■ STOP' : '● RECORD'}
        </Cell>
        {recording && (
          <Cell color={wheat} height={40} width={70} align="flex-end" pad={12}>
            ▌▌ PAUSE
          </Cell>
        )}
        <div style={{
          flex: 1, height: 40, background: '#0f0b08', borderRadius: 0,
          display: 'flex', alignItems: 'center', paddingLeft: 14, paddingRight: 14, gap: 12,
        }}>
          <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: wheat, letterSpacing: '0.12em', minWidth: 50 }}>
            {recording ? '00:14' : '00:00'}
          </div>
          <WaveformBars count={60} color={recording ? orange : '#3a3128'} height={24} active={recording} />
          <MicSelector accent={orange} height={28} compact />
        </div>
        <Pill color={wheat} height={40} pad={14}>⌘R</Pill>
      </div>
    );
  }

  // default 'pill' — compact docked button + live waveform
  return (
    <div style={{
      position: 'absolute', bottom: 14, left: 124, right: 14,
      display: 'flex', gap: 8, alignItems: 'center',
      background: '#0f0b08', borderRadius: 24, paddingLeft: 6, paddingRight: 14, height: 48,
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: 18,
        background: recording ? russet : orange,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0,
      }}>
        <div style={{
          width: recording ? 12 : 14, height: recording ? 12 : 14,
          borderRadius: recording ? 2 : 7,
          background: '#000',
        }} />
      </div>
      <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: wheat, letterSpacing: '0.12em', minWidth: 48 }}>
        {recording ? '00:14' : 'READY'}
      </div>
      <div style={{ flex: 1, minWidth: 40 }}>
        <WaveformBars count={36} color={recording ? orange : '#3a3128'} height={22} active={recording} />
      </div>
      {recording && (
        <div style={{
          height: 30, display: 'flex', alignItems: 'center', gap: 3,
          paddingLeft: 10, paddingRight: 12,
          background: wheat, borderRadius: 15, cursor: 'pointer',
          fontFamily: LCARS.display, fontSize: 10, letterSpacing: '0.14em', color: '#000',
        }} title="Pause (⌘⇧P)">
          <div style={{ display: 'flex', gap: 2, marginRight: 4 }}>
            <div style={{ width: 3, height: 11, background: '#000' }} />
            <div style={{ width: 3, height: 11, background: '#000' }} />
          </div>
          PAUSE
        </div>
      )}
      <MicSelector accent={orange} height={30} compact />
      <div style={{ width: 1, height: 18, background: '#2a2520' }} />
      <div style={{ fontFamily: LCARS.mono, fontSize: 9, color: LCARS.dim }}>⌘R</div>
    </div>
  );
}

// ── MicSelector — obvious clickable device switcher ───────────────────────
function MicSelector({ accent, height = 28, compact = false }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'stretch', gap: 2,
      height, flexShrink: 0, cursor: 'pointer',
    }}>
      {/* Label cell */}
      <div style={{
        background: accent, color: '#000',
        padding: '0 10px',
        display: 'flex', alignItems: 'center', gap: 6,
        borderRadius: `${height / 2}px 0 0 ${height / 2}px`,
        fontFamily: LCARS.display, fontSize: Math.round(height * 0.42),
        letterSpacing: '0.1em',
      }}>
        <div style={{
          width: 8, height: 8, borderRadius: '50% 50% 50% 50% / 60% 60% 40% 40%',
          background: '#000',
        }} />
        INPUT
      </div>
      {/* Value — device name + chevron */}
      <div style={{
        background: '#1a1208',
        padding: compact ? '0 10px' : '0 12px 0 12px',
        display: 'flex', alignItems: 'center', gap: 8,
        borderRadius: `0 ${height / 2}px ${height / 2}px 0`,
        border: `1px solid ${accent}`, borderLeft: 'none',
      }}>
        <div style={{
          fontFamily: LCARS.body, fontSize: compact ? 11 : 12, fontWeight: 500,
          color: LCARS.ink,
        }}>
          MacBook Pro Mic
        </div>
        <div style={{
          fontFamily: LCARS.mono, fontSize: 9, color: accent,
          letterSpacing: '0.08em',
        }}>▾</div>
      </div>
    </div>
  );
}

Object.assign(window, { MicSelector });
