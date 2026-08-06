# Visualizer

A real-time audio spectrum analyzer for [Übersicht](http://tracesof.net/uebersicht),
driven by whatever is actually playing. It recreates the classic Winamp visualizer:
a quantised 16-row bar display with the original VISCOLOR ramp, gravity-fed peak
markers, and the three classic colour modes, live on your desktop.

![Visualizer](screenshot.png)

Because it analyses real audio rather than reading track metadata, it responds to the
music itself. It also tells the difference between silence and a paused source, so it
fades away when the music stops and comes back when it starts.

```
Music.app ──▶ Loopback virtual device ──▶ visualizerd ──▶ ws://127.0.0.1:41500 ──▶ widget canvas
                                          (Swift, FFT)                              (jitter buffer)
```

> **Requires a virtual audio device** ([Loopback](https://rogueamoeba.com/loopback/),
> or the free [BlackHole](https://github.com/ExistentialAudio/BlackHole)) plus a small
> Swift daemon you build once, for the reasons in
> [Why there is a daemon](#why-there-is-a-daemon). See [Setup](#setup).

## A companion to the Music widget

This is built as a companion to
**[uebersicht-music](https://github.com/dionmunk/uebersicht-music)**, and the two are
designed to be run together: that widget shows you *what* is playing, this one shows
you the sound of it. They share the collection's panel treatment, and by default this
widget pins itself directly beside the Music widget, bottom-aligned with it, so the
pair reads as one unit (see [Placement](#placement)).

Neither depends on the other. The Music widget works on its own, and this one only
needs the audio daemon below, so you can run either alone. But the defaults here
assume both, and the visualizer taps the same Apple Music playback the Music widget
reports on.

## Why there is a daemon

The obvious approach, `getUserMedia` inside the widget, cannot work. Übersicht 1.6
ships no `NSMicrophoneUsageDescription` in its `Info.plist` (it declares Bluetooth,
Calendar, and HomeKit, but not the microphone), so macOS terminates the process on
first audio-device access. Separately, WKWebView on macOS 12+ only grants capture if
the host app implements the `requestMediaCapturePermissionFor` delegate, which
Übersicht does not. Both would have to be fixed by patching and re-signing the app.

A separate signed binary carries its own usage string and gets its own TCC grant, so
it sidesteps the problem entirely. The widget never touches audio; it only draws.

## Setup

### 1. Route audio into a virtual device

Create a virtual device in [Loopback](https://rogueamoeba.com/loopback/) (or
[BlackHole](https://github.com/ExistentialAudio/BlackHole), which is free) and add
**Music.app as a source**. Adding the app as a source is better than changing your
system output device, because only that app's audio is captured.

> **Important: add a monitor.** A Loopback device with no monitor swallows the audio,
> and you will stop hearing your music. In Loopback, add your real output (speakers,
> headphones, display) under **Monitors** for that device. This is a Loopback
> configuration step, not something the daemon controls.

### 2. Build the daemon

```sh
./lib/build.sh
```

This compiles `lib/visualizerd.swift`, links `lib/visualizerd-info.plist` into the
binary as a `__TEXT,__info_plist` section, and ad-hoc signs it with a stable
identifier so the microphone grant persists across runs.

The plist is deliberately not named `Info.plist`: codesign treats any directory
containing one as a bundle, and would sign all of `lib/` with a sealed resource
directory that goes invalid whenever anything else in there changes.

### 3. Check it can see the device

```sh
./lib/visualizerd --list
```

### 4. Run it

```sh
./lib/visualizerd --device "Music"
```

Approve the microphone prompt the first time. To start it automatically at login:

```sh
./lib/install-agent.sh "Music"      # remove with --uninstall
```

### 5. Point the widget at it

The widget defaults to port `41500` and connects on its own. If the daemon is not
running, the panel shows `no audio daemon` and retries with backoff.

## Placement

The widget sits at the foot of **column 2**, immediately right of
[the Music widget](https://github.com/dionmunk/uebersicht-music) and bottom-aligned
with it, one column wide:

| | left | bottom | width | height |
|---|---|---|---|---|
| `music.widget` | 10 | 10 | 320 (COL) | depends on its `layout` |
| `visualizer.widget` | 340 | 10 | 320 (COL) | 90 |

`left = EDGE + 1·(COL + GAP) = 340` and `bottom = EDGE = 10`, using this collection's
shared grid tokens (`EDGE` 10, `COL` 320, `GAP` 10, `UNIT` 80), so
the two share a bottom edge whichever `layout` the Music widget is set to. On a
2560×1440 screen with Music in its `horizontal` layout the pair occupies y 1338–1430;
its `square` layout is much taller and grows upward from the same bottom edge.

Column 2's stack (weather → news → stocks) ends at y=921 on a 1440px-tall screen,
leaving plenty of clearance above. On a shorter screen, check that stocks still
clears it.

The 90px height is deliberately 10px over `UNIT`: at 16 quantised rows an 80px panel
reads as a stack of dashes rather than bars. `gamma` is tuned to this height, so a
taller panel needs a lower value or the top sits permanently empty.

### Working with layout-controller.widget

`layoutMode` decides whether the widget joins the desktop grid:

| Value | Behaviour |
|---|---|
| `manual` (default) | Pins itself with the position options and sets `data-layout-manual` on its root element, the controller's documented opt-out |
| `managed` | Joins the grid. The controller packs and drags it like any other widget, and the position options only decide where it sits until then |

`manual` is the default precisely because of the companion relationship: the Music
widget pins itself bottom-left and is listed in the controller's own `offGrid` set,
so letting this one get packed into a column would separate the pair.

The widget also *reads* the grid rather than restating it. Setting `width: "grid"`
(the default) resolves to `var(--grid-col, 320px)`, and `height: "grid"` to
`var(--grid-unit, 80px)`, so the footprint follows whatever grid the controller
publishes. Every reference carries the hardcoded value as its fallback, so nothing
changes when the controller is not installed.

If the controller has already recorded a position from a drag, or from a load before
`data-layout-manual` was set, that saved entry keeps being replayed even after
switching back to `manual`. Clear it:

```sh
F="$HOME/.config/ubersicht/layout.json"
cp "$F" "$F.bak"
jq '.screens |= with_entries(.value.positions |= del(."visualizer-widget-index-coffee"))' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
```

then restart Übersicht, since the controller only re-reads that file on startup.

## The classic analyzer

The renderer recreates the Winamp 2.x spectrum analyzer: a quantised bar display
with the 16-colour VISCOLOR ramp, a dotted backdrop, gravity-fed peak markers, and
the three classic colour modes.

### Provenance

**No Winamp source is used here.** Winamp's code was published in September 2024
under the Winamp Collaborative License, which is not an open-source licence: v1.0
forbade forking outright, and v1.0.1 still banned distributing modified versions in
source or binary form. Llama Group then [deleted the repository](https://www.tomshardware.com/tech-industry/winamp-owner-deletes-open-source-repository-after-a-bumpy-month-on-github)
in October 2024, after third-party code (Intel and Microsoft codecs, Shoutcast
DNAS) was found in it. Community mirrors carry the same terms, so building on it
would leave this widget undistributable.

Instead the behaviour is modelled on **[Webamp](https://github.com/captbaritone/webamp)**
(MIT), a from-scratch reimplementation of Winamp 2.9 that renders to canvas — the
same medium as this widget — plus the publicly [documented VISCOLOR.TXT format](https://winampskins.neocities.org/config).

### Palette

Three schemes, set with `colorScheme`. They are orthogonal to the `colorStyle` modes
below: every palette runs through all three styles.

| `colorScheme` | Ramp |
|---|---|
| `winamp` | The 16-colour VISCOLOR ramp: red at the top through amber to green at the bottom. Ignores the theme |
| `theme` | Follows the theme controller, built from the active scheme's four data-series colours |
| `monochrome` | No hues. One ink colour at a stepped opacity, brightest at the top of the ramp |

**`winamp`.** `VISCOLOR.TXT` is a 24-line file every classic skin ships: line 0
background, line 1 backdrop dots, lines 2–17 the sixteen spectrum colours (top of
pane down to bottom), 18–22 oscilloscope, 23 peak marker. The defaults in
`index.coffee` are the stock ramp. Paste any other skin's values into the `VISCOLOR`
block to reskin it.

**`theme`** and **`monochrome`** both follow `theme-controller.widget`. See
[Theming](#theming) below.

### Theming

Optional, and driven by
[uebersicht-theme-controller](https://github.com/dionmunk/uebersicht-theme-controller).
Nothing here requires it: every token is read with the widget's own value as the
fallback, so the analyzer looks right on its own.

The panel, text and status message read the shared tokens (`--panel-bg`,
`--panel-blur`, `--text`, `--text-secondary`), so the widget's *chrome* follows the
theme under any `colorScheme`. `theme` and `monochrome` extend that to the bars.

**`theme`** builds its ramp from the four data-series roles the theme controller
publishes, `--series-primary` through `--series-quaternary`. Every colour scheme maps
those hot-to-cool in the same order (red / orange / yellow / green), which is the
same shape the VISCOLOR ramp has, so the four are read as stops and interpolated out
to all 16 steps. Switching scheme in the controller reskins the analyzer with no edit
here. Under `monochrome` the controller sets those same roles to ink at descending
opacity, so this scheme does the right thing there too.

**`monochrome`** ignores hues entirely and uses the mode's ink at a stepped opacity:
the 16 steps run from `monoRange[1]` at the top of the ramp down to `monoRange[0]` at
the bottom (default `.3` → `1`). Peak markers take the top step, and the backdrop
dots sit at `.05` to match `--dot-grid`.

Both resolve tokens with `getComputedStyle` on `:root` rather than through a
stylesheet, because a canvas cannot inherit custom properties the way a styled
element does. The resolved ramp is cached and invalidated from a `MutationObserver`
on `:root`, so a mode flip or scheme change repaints without a widget reload and
without costing a style recalc every frame. Theme colours arrive as whatever CSS
colour the theme file wrote, so they are normalised through a scratch canvas
(assign to `fillStyle`, read it back) rather than a hand-rolled hex parser.

Both degrade gracefully with no controller installed: `theme` falls back to the
Winamp ramp rather than inventing colours, and `monochrome` falls back to white ink.

One combination to avoid: `monochrome` with `background: "classic"` puts black ink on
an opaque black pane in dark mode, and the bars vanish. Use `panel` or `none`.

### Background

`background` picks what sits behind the bars:

| Value | Behaviour |
|---|---|
| `panel` | This collection's translucent blurred panel |
| `classic` | The opaque black pane, as in Winamp |
| `none` | Nothing. The bars sit straight on the desktop, with no pane and no blur |

`none` keeps the widget's footprint and padding, so the bars do not shift position
when you switch, and the silence fade still works, since that animates the whole
panel's opacity either way. Dropping the blur is part of the point: a
`backdrop-filter` under a fully transparent background still costs a blur pass over
the panel on every frame. The one thing that loses its backing is the
`no audio daemon` message, though it keeps its text-shadow and stays readable on most
wallpapers.

### Ballistics

The classic analyzer does not ease in both directions. A bar **snaps up instantly**
to a louder reading and only its descent is rate-limited, at a fixed rate rather
than an exponential decay. Peaks hold where the bar left them, then **accelerate**
downward. That asymmetry is most of why it reads as "that" analyzer instead of a
smooth modern meter.

Because of this, the daemon's own smoothing defaults to off (`attack`/`decay` = 1.0)
and all ballistics live in the widget. A second exponential decay upstream would
blunt exactly the snap the look depends on.

### Colour modes

Applies to every palette; the colour names below describe `winamp`.

| `colorStyle` | Behaviour |
|---|---|
| `normal` | Ramp anchored to the pane: a pixel's colour depends on its height, so a bar shows a gradient and only tall ones reach red |
| `fire` | Ramp anchored to each bar's own top, so every bar runs the full ramp regardless of height and the display reads hot |
| `line` | Each bar is filled in a single flat colour sampled from the ramp at that bar's height, so the whole column flickers red → amber → green as it falls |

`bandWidth: "thick"` averages the daemon's 75 bands in groups of four for the
classic wide mode's 19 bars; `"thin"` draws all 75.

## Options

Widget options live at the top of [`index.coffee`](index.coffee): `layoutMode`,
position and size, `colorScheme` (`winamp` / `theme` / `monochrome`) and `monoRange`,
`colorStyle` (`normal` / `fire` / `line`), `background`, `bandWidth`, `rows`,
`barGap`, `vizRadius`, `gamma`, peak markers, the falloff speeds, the fade options,
and the jitter-buffer latency cap.

`vizRadius` (3) rounds the analyzer area itself, which is the canvas inside the
panel's 10px padding rather than the panel. It is a canvas clip, not CSS
`border-radius` on the element, so it behaves identically in WKWebView (where the
widget runs) and in Chrome (where the browser preview renders it). Only what reaches
an edge is affected: in practice the outer bottom corners of the end bars, plus their
top corners once a bar is loud enough to fill the pane. The geometrically concentric
value would be 0 (the panel's 10px radius less its 10px padding), so any rounding
here is a deliberate look; 3 sits just inside the 6px used for `music.widget`'s
album art.

Daemon options:

```
--list                  list input-capable devices
--selftest              push a synthetic 1 kHz tone through the analyzer
--device <name>         device to tap (default: Music)
--port <n>              WebSocket port (default: 41500)
--fft <n>               FFT window, power of two (default: 2048)
--bands <n>             frequency bands (default: 75, the classic band count)
--floor / --ceil <dB>   normalization window (default: -72 / -12)
--tilt <dB>             high-frequency lift (default: 16)
--attack / --decay      smoothing coefficients (default: 1.0 / 1.0, i.e. off —
                        ballistics live in the widget, see above)
--verbose               log frame rates and raw dB ranges
```

## Design notes

**Frames arrive in ~100 ms bursts.** AVAudioEngine's input tap coalesces to 4800
frames at 48 kHz on macOS no matter what buffer size is requested. This was verified
against both the Loopback device and real hardware, and setting
`kAudioDevicePropertyBufferFrameSize` does not change it (it also disrupts playback
on a device other apps are using, so the daemon deliberately never touches it).

Emitting one frame per callback would mean analyzing a single 42 ms window out of
every 100 ms and discarding the rest, so transients falling in the gap would simply
never appear. Instead the analyzer steps each buffer at hop resolution and returns
every frame, giving ~86 fps of spectral data delivered in bursts of ~9. The widget
queues those and plays them back on a clock, interpolating between frames. The cost
is roughly 100 ms of latency, which is constant and not noticeable in practice.

**Normalization is measured, not guessed.** Against real playback, per-band peaks
span about -57..-17 dB, which is why the default window is -72..-12. Broadband RMS
sits ~40 dB higher and gets its own window (-60..-6), otherwise it pins at ~0.9 on
anything loud. The daemon emits a faithful dB mapping and leaves the display curve
to the widget's `gamma`, so the data stays honest and the look stays tunable.

**A paused source is not a silent stream.** Pausing the music does not stop the
frames. A virtual audio device keeps its clock running and hands the daemon buffers
of zeroes, which the daemon reports faithfully: measured against a paused Music.app,
the widget still receives ~94 frames/sec with every band and every `r` (RMS) value
at exactly 0. So "data is arriving" only means the pipeline is alive.

Anything that wants to know whether audio is *playing* therefore has to look inside
the frames, which `frameSignal` does off the daemon's `r` array. Two things depend on
it: the fade below, and the battery guard, which keys off the last frame that carried
signal rather than the last frame received.

**Fading.** When the music pauses or stops the whole panel fades out
(`fadeWhenSilent`), and fades back in when audio returns. The trigger is the display
coming to rest rather than the audio stopping, because the bars are still falling for
up to a second after a pause and fading over that reads as a glitch. So the full
sequence is: bars fall, `fadeAfterMs` (800) of stillness, then a `fadeOutMs` (900)
fade. Coming back is deliberately much quicker, `fadeInMs` (180), or the first beat of
a track is spent still fading up.

`visibility` flips to `hidden` only after the fade-out finishes, so the panel stops
being composited and blurred once it is gone rather than sitting there invisible at
`opacity: 0`. An unreachable daemon is deliberately exempt: that is an error state,
not a quiet one, so the panel stays up with its `no audio daemon` message legible.

**Battery.** The daemon only opens the audio device while a WebSocket client is
attached, and the widget drops from `requestAnimationFrame` to a 250 ms tick once
audio has been silent for `idleAfterMs`. A hidden or unloaded widget costs nothing.
Bursts of silence do not wake the 60 fps loop either; if they did it would wake and
sleep again ten times a second for a paused source.

## Troubleshooting

| Symptom | Check |
|---|---|
| Panel says `no audio daemon` | Is the daemon running? `lsof -nP -iTCP:41500 -sTCP:LISTEN` |
| Bars flat while music plays | `--verbose`; if `raw dB` sits near -100 the device is receiving silence, so the Loopback source is wrong |
| You cannot hear your music | Loopback has a per-source **"Mute when captured"** option; turn it off. Also confirm the device has a Monitor pointing at your real output (step 1) |
| Widget invisible but connected | `layout-controller.widget` is positioning it; see [Placement](#placement) |
| Suspect the DSP | `./lib/visualizerd --selftest` renders a 1 kHz tone and asserts it lands in the right band |
| Port conflict | Übersicht owns 41416 and 41417; pick another with `--port` and update the widget's `port` option |
| Panel never fades out | Only silence fades it, and silence is judged from the frame contents. Run `--verbose`: if the source is genuinely stopped but `raw dB` is not at the floor, the Loopback device is picking up something else |
| An option seems to have no effect on styling | Don't add Stylus `if` branches to the `style` block. `if #{option} == value` compares two bare Stylus identifiers and silently takes the else branch every time. Resolve the branch in CoffeeScript and interpolate the finished declaration, as `vertCss` / `panelBgCss` do |
| A declaration in `style` is silently missing | Check the indentation of any multi-line interpolated value. Stylus reads indentation as structure, so an under-indented continuation line dedents out of its rule and takes every property after it along; an over-indented one turns the line above into a selector. Both bugs were live here (no backdrop blur, and dead `center` position options). Use `INDENT_ROOT` / `INDENT_RULE`, and to see what Stylus actually produced, render the block with the copy of Stylus inside Übersicht: `Übersicht.app/Contents/Resources/node_modules/stylus` |
