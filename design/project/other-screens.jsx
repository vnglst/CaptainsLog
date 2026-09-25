// Secondary screens: Settings, Mic + Personal Context, First-launch Onboarding

function SettingsWindow({ accent }) {
  const W = 720, H = 780;
  const ORANGE = accent?.orange || LCARS.rail;
  const WHEAT  = accent?.wheat  || LCARS.wheat;
  const RUSSET = accent?.russet || LCARS.russet;
  const PLUM   = accent?.plum   || LCARS.plum;
  const STEEL  = accent?.steel  || LCARS.steel;

  return (
    <AppFrame width={W} height={H}>
      {/* Top frame */}
      <div style={{ display: 'flex', gap: 6, paddingTop: 34, paddingLeft: 10, paddingRight: 14, alignItems: 'flex-start' }}>
        <div style={{ width: 110 }}>
          <Elbow color={ORANGE} width={110} height={74} radius={36} direction="tl" thickness={26} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <div style={{ flex: 1, height: 26, background: ORANGE, borderRadius: '0 13px 13px 0',
              display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
              paddingLeft: 18, paddingRight: 16, color: '#000',
              fontFamily: LCARS.display, fontWeight: 600, fontSize: 14, letterSpacing: '0.12em',
            }}>
              SETTINGS
            </div>
            <Pill color={WHEAT} height={26} pad={12}>SAVED</Pill>
            <Pill color={PLUM} height={26} pad={12}>⌘,</Pill>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
            <Cell color={RUSSET} height={16} width={64} pad={8}>041</Cell>
            <Cell color={LCARS.dusty} height={16} width={110} pad={8}>PREFERENCES</Cell>
            <div style={{ flex: 1, height: 16, background: '#1a1613', borderRadius: 8 }} />
          </div>
        </div>
      </div>

      {/* Body */}
      <div style={{ display: 'flex', gap: 6, paddingLeft: 10, paddingRight: 14, marginTop: 6, height: 620 }}>
        {/* Left rail — only the three areas that exist */}
        <div style={{ width: 110, display: 'flex', flexDirection: 'column', gap: 4 }}>
          <Cell color={ORANGE} height={48} pad={10} align="flex-end">SETTINGS</Cell>
          <Cell color={WHEAT} height={32} pad={10} align="flex-end">FOLDER</Cell>
          <Cell color={PLUM} height={32} pad={10} align="flex-end">CONTEXT</Cell>
          <Cell color={STEEL} height={32} pad={10} align="flex-end">CORRECTIONS</Cell>
          <div style={{ flex: 1 }} />
          <Cell color={LCARS.dim} height={22} pad={10} align="flex-end" textColor="#000">CLI · cl</Cell>
          <Cell color={LCARS.dusty} height={22} pad={10} align="flex-end">v2.4.1</Cell>
          <Elbow color={ORANGE} width={110} height={48} radius={36} direction="bl" thickness={26} />
        </div>

        {/* Content */}
        <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 18 }}>
          {/* Data folder */}
          <Section label="DATA FOLDER" color={WHEAT}>
            <div style={{
              background: '#0f0b08', padding: '14px 16px',
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{ fontFamily: LCARS.mono, fontSize: 20, color: ORANGE }}>▣</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: LCARS.mono, fontSize: 12, color: LCARS.ink,
                  overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                }}>
                  ~/Documents/Obsidian/Vault/Captains Log
                </div>
                <div style={{ fontFamily: LCARS.mono, fontSize: 9.5, color: LCARS.dim, marginTop: 3, letterSpacing: '0.05em' }}>
                  041 ENTRIES · 412 GB FREE · APFS
                </div>
              </div>
              <Pill color={ORANGE} height={28} pad={14}>CHOOSE…</Pill>
              <Pill color={LCARS.dim} height={28} pad={14} textColor="#000">REVEAL</Pill>
            </div>
          </Section>

          {/* Personal context */}
          <Section label="PERSONAL CONTEXT" color={PLUM}>
            <div style={{
              background: '#0f0b08', padding: '12px 14px',
              fontFamily: LCARS.body, fontSize: 12.5, color: LCARS.ink, lineHeight: 1.55,
              minHeight: 120,
            }}>
              I'm a Dutch software engineer who works on voice tooling and local ML. I speak
              English and Dutch interchangeably; I often switch mid-sentence. I frequently
              mention my partner Anouk, my team at Pioneer Trust, and projects CaptainsLog and
              Onboarding. Technical vocabulary: Whisper, Obsidian, Apple Silicon, MLX, Swift,
              stardate.
              <span style={{ display: 'inline-block', width: 2, height: 14, background: WHEAT, marginLeft: 1, verticalAlign: 'middle' }} />
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 6, alignItems: 'center' }}>
              <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim, flex: 1 }}>
                312 / 2000 CHARS · INJECTED INTO TRANSCRIPTION PROMPT
              </div>
            </div>
          </Section>

          {/* Corrections */}
          <Section label="NAME & TERM CORRECTIONS" color={STEEL}>
            <div style={{
              background: '#0f0b08', padding: '12px 14px',
              fontFamily: LCARS.mono, fontSize: 12, color: LCARS.ink, lineHeight: 1.65,
              minHeight: 130, whiteSpace: 'pre-wrap',
            }}>
              <span style={{ color: LCARS.russet }}>Rhabo</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>Pioneer Trust</span>{'\n'}
              <span style={{ color: LCARS.russet }}>Anuk, A-nook</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>Anouk</span>{'\n'}
              <span style={{ color: LCARS.russet }}>Cuen, Kwen</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>Qwen</span>{'\n'}
              <span style={{ color: LCARS.russet }}>captains log, captain's log</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>CaptainsLog</span>{'\n'}
              <span style={{ color: LCARS.russet }}>em-el-ex</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>MLX</span>
              <span style={{ display: 'inline-block', width: 2, height: 14, background: WHEAT, marginLeft: 1, verticalAlign: 'middle' }} />
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 6, alignItems: 'center' }}>
              <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim, flex: 1 }}>
                ONE RULE PER LINE · <span style={{ color: LCARS.russet }}>FROM</span> → <span style={{ color: ORANGE }}>TO</span> · APPLIED POST-TRANSCRIPTION
              </div>
            </div>
          </Section>
        </div>
      </div>
    </AppFrame>
  );
}

function Section({ label, color, children }) {
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
        <Cell color={color} height={20} width={110} pad={10}>{label}</Cell>
        <div style={{ flex: 1, height: 2, background: '#2a2520' }} />
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, paddingLeft: 4 }}>
        {children}
      </div>
    </div>
  );
}

function FormRow({ label, color, children }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div style={{
        width: 180, fontFamily: LCARS.body, fontSize: 12, color: LCARS.ink,
      }}>{label}</div>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
        {children}
      </div>
    </div>
  );
}

function Segmented({ options, selected = 0, accent }) {
  return (
    <div style={{ display: 'flex', gap: 2, borderRadius: 14, overflow: 'hidden' }}>
      {options.map((o, i) => (
        <div key={i} style={{
          height: 28, padding: '0 14px',
          background: i === selected ? accent : '#1a1613',
          color: i === selected ? '#000' : LCARS.ink,
          fontFamily: LCARS.display, fontSize: 11, letterSpacing: '0.1em',
          display: 'flex', alignItems: 'center',
          borderRadius: i === 0 ? '14px 0 0 14px' : i === options.length - 1 ? '0 14px 14px 0' : 0,
        }}>{o}</div>
      ))}
    </div>
  );
}

function Toggle({ on = false, accent }) {
  return (
    <div style={{
      width: 44, height: 22, borderRadius: 11,
      background: on ? accent : '#1a1613',
      position: 'relative',
      transition: 'background 0.2s',
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 24 : 2,
        width: 18, height: 18, borderRadius: 9, background: '#000',
      }} />
    </div>
  );
}

function Kbd({ children }) {
  return (
    <div style={{
      minWidth: 26, height: 26, padding: '0 8px',
      background: '#1a1613', borderRadius: 4,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: LCARS.mono, fontSize: 12, color: LCARS.ink,
    }}>{children}</div>
  );
}

function ModelRow({ name, size, state, accent }) {
  const stateColor = state === 'loaded' ? accent : (state === 'idle' ? LCARS.dim : LCARS.russet);
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      background: '#0f0b08', padding: '10px 14px',
    }}>
      <div style={{ width: 6, height: 6, borderRadius: 3, background: stateColor }} />
      <div style={{
        fontFamily: LCARS.mono, fontSize: 11.5, color: LCARS.ink, flex: 1,
      }}>{name}</div>
      <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim }}>{size}</div>
      <Cell color={state === 'loaded' ? accent : '#2a2520'} height={18} width={70} pad={8}
        textColor={state === 'loaded' ? '#000' : LCARS.ink}>
        {state.toUpperCase()}
      </Cell>
    </div>
  );
}

// ── Mic + personal context screen ─────────────────────────────────────────
function MicContextWindow({ accent }) {
  const W = 720, H = 780;
  const ORANGE = accent?.orange || LCARS.rail;
  const WHEAT  = accent?.wheat  || LCARS.wheat;
  const RUSSET = accent?.russet || LCARS.russet;
  const PLUM   = accent?.plum   || LCARS.plum;
  const STEEL  = accent?.steel  || LCARS.steel;

  return (
    <AppFrame width={W} height={H}>
      <div style={{ display: 'flex', gap: 6, paddingTop: 34, paddingLeft: 10, paddingRight: 14, alignItems: 'flex-start' }}>
        <div style={{ width: 110 }}>
          <Elbow color={ORANGE} width={110} height={74} radius={36} direction="tl" thickness={26} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <div style={{ flex: 1, height: 26, background: RUSSET, borderRadius: '0 13px 13px 0',
              display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
              paddingLeft: 18, paddingRight: 16, color: '#000',
              fontFamily: LCARS.display, fontWeight: 600, fontSize: 14, letterSpacing: '0.12em',
            }}>
              INPUT · PERSONAL CONTEXT
            </div>
            <Pill color={WHEAT} height={26} pad={12}>LIVE</Pill>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
            <Cell color={RUSSET} height={16} width={64} pad={8}>042</Cell>
            <Cell color={LCARS.dusty} height={16} width={110} pad={8}>VOICE PROFILE</Cell>
            <Cell color={STEEL} height={16} width={90} pad={8}>NL · EN</Cell>
            <div style={{ flex: 1, height: 16, background: '#1a1613', borderRadius: 8 }} />
          </div>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 6, paddingLeft: 10, paddingRight: 14, marginTop: 6, height: 686 }}>
        <div style={{ width: 110, display: 'flex', flexDirection: 'column', gap: 4 }}>
          <Cell color={ORANGE} height={28} pad={10} align="flex-end">GENERAL</Cell>
          <Cell color={WHEAT} height={28} pad={10} align="flex-end">STORAGE</Cell>
          <Cell color={RUSSET} height={48} pad={10} align="flex-end">MIC</Cell>
          <Cell color={PLUM} height={28} pad={10} align="flex-end">CONTEXT</Cell>
          <Cell color={STEEL} height={28} pad={10} align="flex-end">CORRECTIONS</Cell>
          <Cell color={LCARS.dusty} height={28} pad={10} align="flex-end">MODELS</Cell>
          <div style={{ flex: 1 }} />
          <Elbow color={ORANGE} width={110} height={48} radius={36} direction="bl" thickness={26} style={{ marginTop: 4 }} />
        </div>

        <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 16 }}>
          {/* Mic input */}
          <Section label="INPUT DEVICE" color={RUSSET}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              <MicOption name="MacBook Pro Microphone" channels="Built-in · 48kHz" level={0.62} selected accent={ORANGE} />
              <MicOption name="AirPods Pro" channels="Bluetooth · 16kHz" level={0.0} selected={false} accent={ORANGE} />
              <MicOption name="Shure MV7" channels="USB · 48kHz" level={0.0} selected={false} accent={ORANGE} />
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 10 }}>
              <div style={{ fontFamily: LCARS.display, fontSize: 11, color: WHEAT, letterSpacing: '0.12em', width: 80 }}>
                LIVE LEVEL
              </div>
              <div style={{ flex: 1 }}>
                <WaveformBars count={90} color={ORANGE} height={28} active />
              </div>
              <div style={{ fontFamily: LCARS.mono, fontSize: 11, color: LCARS.ink }}>-14 dB</div>
            </div>
          </Section>

          {/* Personal context */}
          <Section label="PERSONAL CONTEXT" color={PLUM}>
            <div style={{
              background: '#0f0b08', padding: '12px 14px',
              fontFamily: LCARS.body, fontSize: 12.5, color: LCARS.ink, lineHeight: 1.55,
              minHeight: 120,
            }}>
              I'm a Dutch software engineer who works on voice tooling and local ML. I speak
              English and Dutch interchangeably; I often switch mid-sentence. I frequently
              mention my partner Anouk, my team at Pioneer Trust, and projects CaptainsLog and
              Onboarding. Technical vocabulary: Whisper, Obsidian, Apple Silicon, MLX, Swift,
              stardate.
              <span style={{ display: 'inline-block', width: 2, height: 14, background: WHEAT, marginLeft: 1, verticalAlign: 'middle' }} />
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 6, alignItems: 'center' }}>
              <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim, flex: 1 }}>
                312 / 2000 CHARS · INJECTED INTO TRANSCRIPTION PROMPT
              </div>
              <Pill color={ORANGE} height={22} pad={12}>SAVE</Pill>
            </div>
          </Section>

          {/* Corrections — free-form text, like personal context */}
          <Section label="NAME & TERM CORRECTIONS" color={STEEL}>
            <div style={{
              background: '#0f0b08', padding: '12px 14px',
              fontFamily: LCARS.mono, fontSize: 12, color: LCARS.ink, lineHeight: 1.65,
              minHeight: 140, whiteSpace: 'pre-wrap',
            }}>
              <span style={{ color: LCARS.russet }}>Rhabo</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>Pioneer Trust</span>{'\n'}
              <span style={{ color: LCARS.russet }}>Anuk, A-nook</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>Anouk</span>{'\n'}
              <span style={{ color: LCARS.russet }}>Cuen, Kwen</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>Qwen</span>{'\n'}
              <span style={{ color: LCARS.russet }}>captains log, captain's log</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>CaptainsLog</span>{'\n'}
              <span style={{ color: LCARS.russet }}>em-el-ex</span> <span style={{ color: LCARS.dim }}>→</span> <span style={{ color: ORANGE }}>MLX</span>
              <span style={{ display: 'inline-block', width: 2, height: 14, background: WHEAT, marginLeft: 1, verticalAlign: 'middle' }} />
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 6, alignItems: 'center' }}>
              <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim, flex: 1 }}>
                ONE RULE PER LINE · <span style={{ color: LCARS.russet }}>FROM</span> → <span style={{ color: ORANGE }}>TO</span> · APPLIED POST-TRANSCRIPTION
              </div>
              <Pill color={ORANGE} height={22} pad={12}>SAVE</Pill>
            </div>
          </Section>
        </div>
      </div>
    </AppFrame>
  );
}

function MicOption({ name, channels, level, selected, accent }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      background: selected ? '#1a1208' : '#0f0b08',
      padding: '10px 14px',
      borderLeft: selected ? `3px solid ${accent}` : '3px solid transparent',
    }}>
      <div style={{
        width: 12, height: 12, borderRadius: 6,
        border: `2px solid ${selected ? accent : LCARS.dim}`,
        background: selected ? accent : 'transparent',
      }} />
      <div style={{ flex: 1 }}>
        <div style={{ fontFamily: LCARS.body, fontSize: 12.5, color: LCARS.ink, fontWeight: 500 }}>{name}</div>
        <div style={{ fontFamily: LCARS.mono, fontSize: 9.5, color: LCARS.dim, marginTop: 2, letterSpacing: '0.05em' }}>
          {channels}
        </div>
      </div>
      {level > 0 && (
        <div style={{ width: 80, height: 4, background: '#1a1613', borderRadius: 2, overflow: 'hidden' }}>
          <div style={{ width: `${level * 100}%`, height: '100%', background: accent }} />
        </div>
      )}
    </div>
  );
}

function Correction({ from, to, count, accent }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      background: '#0f0b08', padding: '8px 14px',
    }}>
      <div style={{ fontFamily: LCARS.mono, fontSize: 11, color: LCARS.ink, flex: 1 }}>
        <span style={{ color: LCARS.russet }}>{from}</span>
        <span style={{ color: LCARS.dim, margin: '0 10px' }}>→</span>
        <span style={{ color: accent }}>{to}</span>
      </div>
      <div style={{ fontFamily: LCARS.mono, fontSize: 9, color: LCARS.dim, letterSpacing: '0.08em' }}>
        {count} APPLIED
      </div>
    </div>
  );
}

// ── Onboarding ────────────────────────────────────────────────────────────
function OnboardingWindow({ accent }) {
  const W = 720, H = 780;
  const ORANGE = accent?.orange || LCARS.rail;
  const WHEAT  = accent?.wheat  || LCARS.wheat;
  const RUSSET = accent?.russet || LCARS.russet;
  const PLUM   = accent?.plum   || LCARS.plum;
  const STEEL  = accent?.steel  || LCARS.steel;

  return (
    <AppFrame width={W} height={H}>
      {/* Top */}
      <div style={{ display: 'flex', gap: 6, paddingTop: 38, paddingLeft: 10, paddingRight: 14, alignItems: 'flex-start' }}>
        <div style={{ width: 150 }}>
          <Elbow color={ORANGE} width={150} height={94} radius={44} direction="tl" thickness={34} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <div style={{ flex: 1, height: 34, background: ORANGE, borderRadius: '0 17px 17px 0',
              display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
              paddingLeft: 22, paddingRight: 20, color: '#000',
              fontFamily: LCARS.display, fontWeight: 600, fontSize: 18, letterSpacing: '0.14em',
            }}>
              WELCOME ABOARD
            </div>
            <Pill color={WHEAT} height={34} pad={14}>FIRST LAUNCH</Pill>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
            <Cell color={RUSSET} height={18} width={80} pad={8}>STEP 1</Cell>
            <Cell color={LCARS.dusty} height={18} width={140} pad={8}>CHOOSE DATA FOLDER</Cell>
            <div style={{ flex: 1, height: 18, background: '#1a1613', borderRadius: 9 }} />
          </div>
        </div>
      </div>

      {/* Body */}
      <div style={{ display: 'flex', gap: 6, paddingLeft: 10, paddingRight: 14, marginTop: 6, height: 600 }}>
        <div style={{ width: 150, display: 'flex', flexDirection: 'column', gap: 4 }}>
          <Cell color={ORANGE} height={60} pad={10} align="flex-end">● WELCOME</Cell>
          <Cell color={LCARS.dim} height={36} pad={10} align="flex-end" textColor="#000">○ READY</Cell>
          <div style={{ height: 14 }} />
          <Cell color={RUSSET} height={22} pad={10} align="flex-end">OFFLINE</Cell>
          <Cell color={PLUM} height={22} pad={10} align="flex-end">PRIVATE</Cell>
          <Cell color={STEEL} height={22} pad={10} align="flex-end">ON-DEVICE</Cell>
          <div style={{ flex: 1, minHeight: 20 }} />
          <Elbow color={ORANGE} width={150} height={60} radius={44} direction="bl" thickness={34} />
        </div>

        <div style={{ flex: 1, paddingTop: 4, display: 'flex', flexDirection: 'column', gap: 22 }}>
          {/* Heading */}
          <div>
            <div style={{ fontFamily: LCARS.display, fontSize: 34, fontWeight: 500,
              letterSpacing: '0.04em', color: LCARS.ink, lineHeight: 1.05,
              textTransform: 'uppercase',
            }}>
              Your voice.<br />
              Structured.<br />
              <span style={{ color: ORANGE }}>On this Mac. Only.</span>
            </div>
            <div style={{ fontFamily: LCARS.body, fontSize: 13.5, color: '#a9a090',
              lineHeight: 1.6, marginTop: 16, maxWidth: 480,
            }}>
              CaptainsLog transcribes, cleans, names and enriches your recordings entirely on
              this machine. Nothing leaves your Mac. Choose where your logs will live — any
              folder, including an Obsidian vault or synced drive.
            </div>
          </div>

          {/* Data folder block */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
              <Cell color={WHEAT} height={24} width={150} pad={10}>DATA FOLDER</Cell>
              <div style={{ flex: 1, height: 2, background: '#2a2520' }} />
            </div>
            <div style={{
              background: '#0f0b08', padding: '16px 18px',
              display: 'flex', alignItems: 'center', gap: 14,
            }}>
              <div style={{ fontFamily: LCARS.mono, fontSize: 24, color: ORANGE }}>▣</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: LCARS.mono, fontSize: 12, color: LCARS.ink,
                  overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                }}>
                  ~/Documents/Obsidian/Vault/Captains Log
                </div>
                <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim, marginTop: 4, letterSpacing: '0.05em' }}>
                  EMPTY FOLDER · 412 GB FREE · APFS
                </div>
              </div>
              <Pill color={ORANGE} height={30} pad={16}>CHOOSE…</Pill>
            </div>
            <div style={{
              fontFamily: LCARS.body, fontSize: 12, color: LCARS.dim,
              lineHeight: 1.55, marginTop: 10, maxWidth: 520,
            }}>
              Each recording becomes a Markdown file with its audio alongside. Change this
              anytime in Settings.
            </div>
          </div>

          <div style={{ flex: 1 }} />

          {/* Nav */}
          <div style={{ display: 'flex', gap: 8 }}>
            <Pill color={LCARS.dim} height={40} pad={20} textColor="#000">QUIT</Pill>
            <div style={{ flex: 1 }} />
            <Pill color={ORANGE} height={40} pad={22}>BEGIN →</Pill>
          </div>
        </div>
      </div>
    </AppFrame>
  );
}

function ModelProgress({ name, size, pct, accent, state }) {
  const color = state === 'done' ? accent : state === 'active' ? accent : LCARS.dim;
  return (
    <div style={{
      background: '#0f0b08', padding: '10px 14px',
      display: 'flex', alignItems: 'center', gap: 12,
    }}>
      <div style={{ width: 6, height: 6, borderRadius: 3, background: color }} />
      <div style={{ width: 200, fontFamily: LCARS.mono, fontSize: 11.5, color: LCARS.ink }}>{name}</div>
      <div style={{ flex: 1, height: 4, background: '#1a1613', borderRadius: 2, overflow: 'hidden' }}>
        <div style={{ width: `${pct}%`, height: '100%', background: accent }} />
      </div>
      <div style={{ fontFamily: LCARS.mono, fontSize: 10, color: LCARS.dim, width: 54, textAlign: 'right' }}>
        {size}
      </div>
      <div style={{
        fontFamily: LCARS.display, fontSize: 10, letterSpacing: '0.12em',
        color: state === 'done' ? accent : state === 'active' ? LCARS.wheat : LCARS.dim,
        width: 52, textAlign: 'right',
      }}>
        {state === 'done' ? '✓ DONE' : state === 'active' ? `${pct}%` : 'QUEUED'}
      </div>
    </div>
  );
}

Object.assign(window, { SettingsWindow, MicContextWindow, OnboardingWindow });
