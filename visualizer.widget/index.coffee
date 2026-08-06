# A recreation of the classic Winamp spectrum analyzer for Übersicht.
#
# Behaviour and palette are modelled on Webamp (MIT, github.com/captbaritone/webamp),
# a from-scratch reimplementation of Winamp 2.9, and on the documented VISCOLOR.TXT
# skin format. No Winamp source is used: that release is under the Winamp
# Collaborative License, which forbids distributing modified versions, and it was
# pulled from GitHub in 2024. See README.md.

options =
  # --- Location ---------------------------------------------------------------
  # Enable or disable the widget.
  widgetEnabled : true                 # true | false

  # How this widget gets positioned, if layout-controller.widget is installed.
  #
  #   "manual"  pin myself using the position options below, and tell the controller
  #             to leave me alone (it reads `data-layout-manual` off the root
  #             element). This is the default because the widget is a companion to
  #             music.widget, which pins itself bottom left: the two are meant to
  #             sit together, and packing this one into a column would separate them.
  #   "managed" join the grid. The controller then packs and drags this widget like
  #             any other, and the position options below only decide where it sits
  #             until the controller places it.
  #
  # With no controller installed the two behave identically.
  layoutMode : "manual"                # manual | managed

  # Where the widget sits on your screen.
  verticalPosition : "bottom"          # top | bottom | center
  horizontalPosition : "left"          # left | right | center

  # Distance from the chosen edges, in px. Ignored on an axis set to "center".
  #
  # Sits at the foot of column 2, beside music.widget (see LAYOUT.md):
  #   left  = EDGE + 1·(COL + GAP) = 10 + 330 = 340
  #   bottom = EDGE = 10, so its bottom edge lines up with music.widget's
  verticalOffset : 10                  # px
  horizontalOffset : 340               # px

  # Footprint. A number is px; the string "grid" reads the matching token published
  # by layout-controller.widget instead, so the widget follows the grid rather than
  # restating it:
  #
  #   width  "grid" -> var(--grid-col, 320px)    one column
  #   height "grid" -> var(--grid-unit, 80px)    one row, the base widget height
  #
  # The tokens carry the same values this widget would hardcode, so "grid" changes
  # nothing today; it matters on a screen where the controller computes a different
  # grid, and it keeps the two in step if LAYOUT.md's tokens are ever retuned.
  #
  # Height is deliberately 10px over UNIT: 16 quantised rows want a little more than
  # 80px to read as bars rather than a stack of dashes.
  width : "grid"                       # px | "grid"
  height : 90                          # px | "grid"

  # --- Connection -------------------------------------------------------------
  # Port the visualizerd daemon listens on. Übersicht itself owns 41416 and 41417,
  # so this deliberately sits clear of that pair.
  port : 41500

  # --- Analyzer ---------------------------------------------------------------
  # Palette.
  #
  #   "winamp"     the 16-colour VISCOLOR ramp below: red at the top through amber
  #                to green at the bottom, exactly as in Winamp. Ignores the theme.
  #   "theme"      follows theme-controller.widget. The ramp is built from the four
  #                data-series roles, which every colour scheme maps hot-to-cool in
  #                the same order (THEME.md), so it tracks whatever scheme is set.
  #   "monochrome" no hues at all. One ink colour at a stepped opacity, so intensity
  #                reads as brightness.
  #
  # "theme" and "monochrome" both follow the light/dark mode. Without the controller
  # installed both fall back gracefully: "theme" to the Winamp ramp, "monochrome" to
  # white ink.
  #
  # Orthogonal to colorStyle below: every palette runs through all three styles.
  colorScheme : "winamp"            # winamp | theme | monochrome

  # Opacity of the monochrome ramp, bottom of the ramp to top. The floor is what a
  # barely-there band looks like; below about .2 the quiet two thirds of the
  # display disappear into the panel. Only used by colorScheme "monochrome".
  monoRange : [0.3, 1]                 # [bottom, top]

  # Colour treatment, mirroring the classic analyzer's three modes:
  #
  #   "normal" the 16-colour ramp is anchored to the panel, so a pixel's colour
  #            depends on how high up the panel it sits. Short bars stay green,
  #            only tall ones reach orange and red.
  #   "fire"   the ramp is anchored to each bar's own top, so every bar runs the
  #            full ramp regardless of height and the whole display reads hot.
  #   "line"   the bar is filled in a single flat colour, sampled from the ramp at
  #            that bar's own height, so the whole column steps red -> amber ->
  #            green as it falls rather than holding a gradient.
  colorStyle : "line"                # normal | fire | line

  # Bar width. "thick" averages the incoming bands in groups of four, which turns
  # the daemon's 75 bands into the classic wide mode's 19 bars.
  bandWidth : "thick"                  # thin | thick

  # Show the falling peak markers above each bar.
  peaks : true                         # true | false

  # Falloff speeds, 1 (slowest) to 5 (fastest). The classic analyzer snaps a bar
  # up instantly and lets it fall at a fixed rate, rather than easing both ways;
  # peaks hold where they land, then accelerate downward like gravity.
  analyzerFalloff : 3                  # 1..5
  peakFalloff : 2                      # 1..5

  # --- Look -------------------------------------------------------------------
  # What sits behind the bars.
  #
  #   "panel"   this collection's translucent blurred panel.
  #   "classic" the opaque black pane, as in Winamp.
  #   "none"    nothing. The bars sit straight on the desktop with no pane behind
  #             them and no blur. The widget keeps its footprint and padding, so
  #             the bars do not move when you switch, and the fade still works
  #             (it is the whole panel's opacity either way).
  #
  # With "none" the "no audio daemon" message loses its backing, but keeps the
  # text-shadow, so it stays readable on most wallpapers.
  background : "panel"               # panel | classic | none

  # Draw the dotted backdrop behind the bars.
  grid : false                          # true | false

  # Round the corners of the analyzer area itself, in px. This is the canvas inside
  # the panel's 10px padding, not the panel, which has its own 10px radius.
  #
  # Clipped on the canvas rather than with CSS `border-radius` on the element: the
  # widget runs in WKWebView but is developed against Chrome in the browser preview,
  # and a clip path behaves identically in both. It rounds whatever reaches the
  # edges, so in practice that is the outer bottom corners of the end bars, plus
  # their top corners on a bar loud enough to fill the pane.
  #
  # 0 disables it. Note the geometrically "concentric" value here is 0 (outer radius
  # 10 minus 10 of padding), so any rounding is a deliberate look rather than an
  # attempt to follow the panel's curve.
  vizRadius : 3                         # px

  # Vertical resolution. The original is a 16px-tall pane, and quantising to 16
  # steps is a large part of why it reads as "that" analyzer rather than a smooth
  # modern meter. Raise for a finer display, at the cost of the chunky character.
  rows : 16

  # Gap between bars in px. The classic wide mode is a 3px bar with a 1px gap.
  barGap : 1                           # px

  # Display curve. The daemon emits a faithful dB mapping; a gamma above 1 pushes
  # the mids down for contrast, 1 is linear.
  #
  # Kept mild here on purpose. Quantising to 16 rows already supplies most of the
  # contrast, and a steep curve on top of it flattens every band above the bass
  # into the bottom row, leaving the right two thirds of the display dead.
  gamma : 1.35

  # --- Behaviour --------------------------------------------------------------
  # Frames are delivered in ~100ms bursts (an AVAudioEngine constraint, see the
  # README), so they are queued and played back on a clock. This caps how much
  # audio may sit in that queue.
  maxLatencyMs : 180

  # Fade the whole panel out when the music pauses or stops, rather than leaving an
  # empty pane sitting on the desktop, and fade it back in when audio returns.
  #
  # The fade waits for the display to actually come to rest, not for the audio to
  # stop: bars are still visibly falling for up to a second after a pause, and
  # fading over that reads as a glitch rather than a settle. The daemon going away
  # is deliberately not a fade: that is an error state, and the panel stays up so
  # its "no audio daemon" message can be read.
  fadeWhenSilent : true                # true | false
  fadeAfterMs : 800                    # rest before the fade-out starts
  fadeOutMs : 900                      # fade-out length
  fadeInMs : 180                       # fade-in length. Short, or the first beat of
                                       # a track is spent still fading up

  # Drop to a slow idle tick after this long without audio, instead of holding a
  # 60fps repaint loop open over a silent panel. Note that "without audio" is not
  # "without frames": a paused source still streams silence (see frameSignal below).
  idleAfterMs : 1500

# The 16 spectrum colours of the stock VISCOLOR.TXT, ordered top of the pane down
# to the bottom, followed by the peak-marker and backdrop-dot colours. Any classic
# skin ships its own VISCOLOR.TXT in this format (24 lines: background, dots, 16
# spectrum colours, 5 oscilloscope colours, peak); drop another skin's values in
# here to reskin the analyzer.
VISCOLOR =
  spectrum: [
    '239,49,16'   # 0 — top
    '206,41,16'
    '214,90,0'
    '214,102,0'
    '214,115,0'
    '198,123,8'
    '222,165,24'
    '214,181,33'
    '189,222,41'
    '148,222,33'
    '41,206,16'
    '50,190,16'
    '57,181,16'
    '49,156,8'
    '41,148,0'
    '24,132,8'    # 15 — bottom
  ]
  peak: '150,150,150'
  dots: '24,33,41'
  background: '0,0,0'

# Falloff rates in fractions of full scale per second, indexed by the 1..5 option.
# The original works in whole pixels per frame on a 16px pane; these are the same
# rates expressed per second so the display is frame-rate independent.
BAR_FALLOFF  = [0.45, 0.75, 1.20, 1.90, 3.20]
# Peak markers accelerate rather than fall linearly, in full scale per second².
PEAK_GRAVITY = [0.50, 0.90, 1.60, 2.80, 4.80]

# Option-driven CSS is resolved here rather than with Stylus `if` blocks.
# `if #{someOption} == classic` interpolates to a comparison of two bare Stylus
# identifiers, which does not evaluate the way it reads: it silently takes the
# else branch every time. That went unnoticed for the position options (whose
# defaults want the else branch anyway) but meant background:"classic" never
# applied. Building the finished declarations in CoffeeScript removes the guesswork.
#
# Second trap, for any value spanning more than one line: it has to carry the exact
# indentation of the site it is interpolated into, because Stylus reads indentation
# as structure. Get it wrong and there is no error: an under-indented line dedents
# out of the rule it belongs to (taking every property after it along), and an
# over-indented one turns the line above it into a selector. Both failures were live
# here: the `center` branches below emitted `#widget top 50% { transform: … }`, so
# neither centering option did anything, and the panel's two blur lines fell out of
# `.panel` entirely, which is why this widget alone had no backdrop blur.
#
# Hence these two constants. The style block is a CoffeeScript heredoc, so its own
# two-space indentation is stripped before Stylus sees it: the widget's top level
# lands at column 0 and a rule's properties at column 2.
INDENT_ROOT = "\n"     # interpolated at the widget's top level
INDENT_RULE = "\n  "   # interpolated among a rule's properties (.panel)

# Footprint values: a number is px, "grid" defers to the layout controller's token.
# Every reference carries the same fallback the widget would have hardcoded, so it
# renders identically with no controller installed.
GRID_COL  = 'var(--grid-col, 320px)'
GRID_UNIT = 'var(--grid-unit, 80px)'

widthCss  = if options.width  is 'grid' then GRID_COL  else "#{options.width}px"
heightCss = if options.height is 'grid' then GRID_UNIT else "#{options.height}px"
# Centring needs half the width, which has to stay symbolic when it is a token.
halfWidthCss =
  if options.width is 'grid' then "calc(#{GRID_COL} / -2)" else "-#{options.width / 2}px"

vertCss =
  if options.verticalPosition is 'center'
    "top 50%#{INDENT_ROOT}transform translateY(-50%)"
  else
    "#{options.verticalPosition} #{options.verticalOffset}px"

horizCss =
  if options.horizontalPosition is 'center'
    "left 50%#{INDENT_ROOT}margin-left #{halfWidthCss}"
  else
    "#{options.horizontalPosition} #{options.horizontalOffset}px"

panelBgCss =
  switch options.background
    when 'classic'
      "background rgba(#{VISCOLOR.background}, .82)"
    when 'none'
      # No pane: the bars sit directly on the desktop. Written out as an explicit
      # `transparent` rather than an empty string, both so the rule never ends up
      # with a dangling blank line and so the intent is visible in the compiled CSS.
      # Note this drops the blur too, which is the point: a backdrop-filter with
      # nothing painted over it still costs a full-panel blur pass every frame.
      "background transparent"
    else
      [ "background var(--panel-bg, rgba(0, 0, 0, .15))"
        "-webkit-backdrop-filter blur(var(--panel-blur, 48px))"
        "backdrop-filter blur(var(--panel-blur, 48px))"
      ].join(INDENT_RULE)

command: ""

refreshFrequency: false

style: """
  // grid: foot of column 2, beside music.widget (see LAYOUT.md)
  font-family -apple-system, BlinkMacSystemFont, system-ui, sans-serif
  color var(--text, #fff)
  position absolute

  #{vertCss}
  #{horizCss}

  display #{if options.widgetEnabled then 'block' else 'none'}

  .panel
    border-radius 10px
    box-sizing border-box
    width #{widthCss}
    height #{heightCss}
    min-height #{GRID_UNIT}
    padding 10px
    position relative
    overflow hidden
    // Leaving .is-silent applies the rule below in reverse, so this duration is
    // the fade back IN when audio returns.
    transition opacity #{options.fadeInMs}ms ease, visibility 0s
    // Kept last in the block on purpose: it is the one multi-line interpolation
    // here, so if its indentation is ever wrong again it can only dedent past the
    // end of the rule rather than swallowing the declarations below it.
    #{panelBgCss}

  // visibility flips only once the fade has finished, so the panel keeps painting
  // (and blurring) while it is still on screen but stops entirely once it is not.
  // An opacity-0 element is still composited; a hidden one is skipped.
  .panel.is-silent
    opacity 0
    visibility hidden
    transition opacity #{options.fadeOutMs}ms ease, visibility 0s linear #{options.fadeOutMs}ms

  .viz
    display block
    width 100%
    height 100%

  .viz-status
    position absolute
    top 50%
    left 0
    right 0
    transform translateY(-50%)
    text-align center
    font-size 10px
    line-height 1.4          // room for descenders (see LAYOUT.md notes)
    text-transform uppercase
    letter-spacing .08em
    font-weight bold
    color var(--text-secondary, rgba(#fff, .45))
    text-shadow 0 1px 1px rgba(20, 1, 1, .2)
    opacity 0
    transition opacity .4s ease
    pointer-events none

  .panel.is-offline .viz-status
    opacity 1
"""

options : options

render: () -> """
<div class="panel">
    <canvas class="viz"></canvas>
    <div class="viz-status">no audio daemon</div>
</div>
"""

afterRender: (domEl) ->
  # Übersicht builds a fresh element when the widget reloads, so a cleanup hook
  # stored on the element is unreachable by the time the replacement runs and the
  # old socket + rAF loop leak. Keeping the handle on `window` (per screen, one
  # page each) means every reload tears the previous instance down.
  window.__visualizerWidgetCleanup?()
  window.__visualizerWidgetCleanup = null

  # layout-controller.widget reads this attribute off the root element to mean "never
  # manage me". Set it in "manual" mode, where the widget pins itself via the offset
  # options and expects to stay put beside music.widget; without it the controller
  # assigns a grid slot and publishes an `!important` inset rule that beats our CSS.
  #
  # Removed rather than skipped in "managed" mode, because Übersicht reuses the
  # element across reloads: leaving a stale attribute behind would silently keep the
  # widget off the grid after the option was changed.
  if options.layoutMode is 'managed'
    domEl.removeAttribute?('data-layout-manual')
  else
    domEl.setAttribute?('data-layout-manual', '')

  panel = domEl.querySelector('.panel')
  canvas = domEl.querySelector('.viz')
  return unless panel and canvas
  ctx = canvas.getContext('2d')
  return unless ctx

  ROWS = Math.max(4, options.rows)
  GROUP = if options.bandWidth is 'thick' then 4 else 1
  falloffRate = BAR_FALLOFF[Math.min(4, Math.max(0, options.analyzerFalloff - 1))]
  peakGravity = PEAK_GRAVITY[Math.min(4, Math.max(0, options.peakFalloff - 1))]

  fill = (rgb, alpha = 1) -> "rgba(#{rgb}, #{alpha})"

  state =
    queue: []            # frames awaiting playback
    dt: 10.67            # ms between frames, replaced by the daemon's own value
    cursor: 0            # fractional position between queue[0] and queue[1]
    bands: 0             # band count the daemon is sending
    bars: 0              # bars actually drawn, after thin/thick grouping
    cur: null            # ballistic bar values, 0..1
    peak: null           # peak marker positions, 0..1
    peakVel: null        # peak fall velocity, full scale per second
    lastT: performance.now()
    lastDataT: 0         # last frame received, silent or not
    lastSignalT: 0       # last frame that actually carried audio
    restSince: 0         # when the display last came to a standstill
    idle: true
    stopped: false
    ws: null
    raf: null
    timer: null
    retryTimer: null
    retries: 0
    dotPattern: null
    palette: null

  # --- palette --------------------------------------------------------------
  # Every scheme resolves to the same shape (a 16-entry ramp, index 0 = top of the
  # ramp, plus the peak-marker and backdrop-dot colours), so the drawing code below
  # never asks which scheme is active. Entries are finished CSS colours rather than
  # bare triplets, because monochrome carries its intensity in the alpha channel.
  #
  # A canvas cannot inherit custom properties the way a styled element does, so the
  # two themed schemes resolve the tokens here with getComputedStyle. That is also
  # why the ramp is cached and invalidated from a MutationObserver further down,
  # rather than re-read per frame.
  ROOT = -> document.documentElement

  readToken = (name) ->
    try
      getComputedStyle(ROOT()).getPropertyValue(name).trim()
    catch e
      ''

  # theme-controller.widget publishes --ink as a bare "r, g, b" triplet, ready to
  # drop into rgba(). Falls back to white so the widget still looks right with no
  # controller installed.
  readInk = ->
    v = readToken('--ink')
    if /^\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}$/.test(v) then v else '255, 255, 255'

  # Any CSS colour -> "r, g, b", by letting the canvas parse it: assigning to
  # fillStyle and reading it back returns a canonical form the regexes below can
  # take apart. That covers hex, rgb(), colour keywords and anything else the engine
  # accepts, so a theme file is free to write its palette however it likes.
  probeCtx = null
  toChannels = (value) ->
    return null unless value
    probeCtx ?= document.createElement('canvas').getContext('2d')
    return null unless probeCtx
    probeCtx.fillStyle = '#000'
    probeCtx.fillStyle = value
    out = probeCtx.fillStyle
    if m = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(out)
      return "#{parseInt(m[1], 16)}, #{parseInt(m[2], 16)}, #{parseInt(m[3], 16)}"
    if m = /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i.exec(out)
      return "#{Math.round(+m[1])}, #{Math.round(+m[2])}, #{Math.round(+m[3])}"
    null

  # Spread a handful of colour stops (top of the ramp first) over all 16 steps.
  rampFrom = (stops, steps) ->
    nums = for s in stops
      s.split(',').map((n) -> parseFloat(n))
    last = nums.length - 1
    for i in [0...steps]
      p = (i / (steps - 1)) * last
      a = Math.min(last, Math.floor(p))
      b = Math.min(last, a + 1)
      t = p - a
      fill(((Math.round(nums[a][c] + (nums[b][c] - nums[a][c]) * t)) for c in [0..2]).join(', '))

  buildPalette = ->
    steps = VISCOLOR.spectrum.length
    round = (n) -> Math.round(n * 1000) / 1000

    if options.colorScheme is 'monochrome'
      ink = readInk()
      lo = Math.min(options.monoRange...)
      hi = Math.max(options.monoRange...)
      spectrum =
        for i in [0...steps]
          # Index 0 is the top of the ramp, so alpha runs hi -> lo down the list,
          # mirroring the Winamp ramp's hot-to-cool ordering.
          fill(ink, round(hi + (lo - hi) * (i / (steps - 1))))
      # Peak markers sit above the bar tops, so they take the brightest step and
      # stay the most solid thing on the panel. Dots match the --dot-grid neutral.
      return { spectrum: spectrum, peak: fill(ink, round(hi)), dots: fill(ink, .05) }

    if options.colorScheme is 'theme'
      # The four data-series roles are the theme system's own hot-to-cool ramp
      # (primary -> quaternary maps to red/orange/yellow/green in every colour
      # scheme, see THEME.md), which is the same shape the Winamp ramp has. Under
      # monochrome the controller sets them to ink at descending opacity instead, so
      # this scheme quietly does the right thing there too.
      stops = (toChannels(readToken(n)) for n in [
        '--series-primary', '--series-secondary', '--series-tertiary', '--series-quaternary'
      ])
      stops = (s for s in stops when s)
      if stops.length >= 2
        ink = readInk()
        return
          spectrum: rampFrom(stops, steps)
          peak: fill(ink, .8)
          dots: fill(ink, .05)
      # No controller, or a theme that publishes no series roles: fall through to
      # the Winamp ramp rather than inventing colours.

    spectrum: (fill(c) for c in VISCOLOR.spectrum)
    peak: fill(VISCOLOR.peak)
    dots: fill(VISCOLOR.dots)

  palette = ->
    state.palette ?= buildPalette()

  # Sized on the first frame, and again if the daemon's band count changes.
  allocate = (bandCount) ->
    state.bands = bandCount
    state.bars = Math.max(1, Math.ceil(bandCount / GROUP))
    state.cur = new Float32Array(state.bars)
    state.peak = new Float32Array(state.bars)
    state.peakVel = new Float32Array(state.bars)
    return

  # --- canvas sizing --------------------------------------------------------
  sizeCanvas = ->
    dpr = window.devicePixelRatio or 1
    w = canvas.clientWidth
    h = canvas.clientHeight
    return false unless w > 0 and h > 0
    want = [Math.round(w * dpr), Math.round(h * dpr)]
    if canvas.width isnt want[0] or canvas.height isnt want[1]
      canvas.width = want[0]
      canvas.height = want[1]
      state.dotPattern = null
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    true

  # The backdrop is a dot per 2×2 block. Building it once as a pattern keeps this
  # off the hot path; drawn per pixel it would be thousands of fills a frame.
  dotPattern = ->
    return state.dotPattern if state.dotPattern
    tile = document.createElement('canvas')
    tile.width = 2
    tile.height = 2
    tctx = tile.getContext('2d')
    tctx.fillStyle = palette().dots
    tctx.fillRect(0, 0, 1, 1)
    state.dotPattern = ctx.createPattern(tile, 'repeat')
    state.dotPattern

  ro = null
  if window.ResizeObserver
    ro = new ResizeObserver(-> sizeCanvas())
    ro.observe(panel)

  # The theme controller rewrites :root when the wallpaper (and so the mode) flips.
  # Watching for that drops the cached ramp instead of re-reading --ink every frame,
  # which would force a style recalc 60 times a second for a value that changes
  # about as often as the wallpaper does.
  themeObserver = null
  if options.colorScheme isnt 'winamp' and window.MutationObserver
    themeObserver = new MutationObserver ->
      state.palette = null
      state.dotPattern = null
    themeObserver.observe(document.documentElement, {
      attributes: true
      attributeFilter: ['style', 'data-mode', 'data-scheme']
    })

  # --- socket ---------------------------------------------------------------
  # Does this burst carry audio, or is it silence?
  #
  # It has to be asked, because a paused source does not stop the stream: a virtual
  # audio device keeps its clock running and hands the daemon buffers of zeroes,
  # which the daemon faithfully reports at the full ~94 frames/sec. So "frames are
  # arriving" says only that the pipeline is alive, not that anything is playing.
  #
  # The daemon's `r` (broadband RMS per frame, 0-255) settles it in a handful of
  # comparisons. Scanning the bands is the fallback for a daemon binary built before
  # `r` was added to the wire format.
  frameSignal = (msg) ->
    if msg.r and msg.r.length
      for v in msg.r
        return true if v > 0
    else if msg.f
      for f in msg.f
        for v in f
          return true if v > 0
    false

  # The daemon only captures audio while a client is attached, so this socket
  # staying open is what keeps the whole pipeline alive.
  scheduleRetry = ->
    return if state.stopped
    state.retries += 1
    delay = Math.min(10000, 500 * Math.pow(2, Math.min(4, state.retries)))
    state.retryTimer = setTimeout(connect, delay)

  connect = ->
    return if state.stopped
    try
      ws = new WebSocket("ws://127.0.0.1:#{options.port}/")
    catch e
      scheduleRetry()
      return
    state.ws = ws

    ws.onopen = ->
      state.retries = 0
      panel.classList.remove('is-offline')

    ws.onmessage = (ev) ->
      msg = null
      try
        msg = JSON.parse(ev.data)
      catch e
        return
      return unless msg
      state.dt = msg.dt if msg.dt > 0
      return unless msg.f and msg.f.length

      allocate(msg.f[0].length) unless state.bands is msg.f[0].length
      state.queue.push(f) for f in msg.f
      state.lastDataT = performance.now()
      state.lastSignalT = state.lastDataT if frameSignal(msg)

      # Latency guard: if playback has fallen behind the source, drop the backlog
      # rather than letting the display drift permanently behind the music.
      maxQ = Math.max(2, Math.ceil(options.maxLatencyMs / state.dt))
      if state.queue.length > maxQ
        state.queue.splice(0, state.queue.length - maxQ)

      # Wake the 60fps loop for audio only. Waking it for silence would thrash:
      # bursts keep arriving ~10 times a second while paused, so it would wake and
      # immediately put itself back to sleep on every one of them.
      if state.idle and state.lastSignalT is state.lastDataT
        state.idle = false
        clearTimeout(state.timer) if state.timer
        state.timer = null
        state.lastT = performance.now()
        state.raf = requestAnimationFrame(draw)

    ws.onerror = ->
      try ws.close() catch e then null

    ws.onclose = ->
      panel.classList.add('is-offline')
      state.queue.length = 0
      scheduleRetry()

  # --- playback -------------------------------------------------------------
  # Mean of the bands feeding one bar. In thick mode that is the group of four the
  # classic wide display averages together.
  bandValue = (frame, bar) ->
    return 0 unless frame
    lo = bar * GROUP
    hi = Math.min(frame.length, lo + GROUP)
    return 0 if hi <= lo
    sum = 0
    sum += frame[i] for i in [lo...hi]
    sum / (hi - lo) / 255

  advance = (elapsed) ->
    return unless state.cur
    secs = elapsed / 1000

    # Interpolate between the two frames straddling the playback cursor.
    target = null
    if state.queue.length
      state.cursor += elapsed / state.dt
      while state.cursor >= 1 and state.queue.length > 1
        state.queue.shift()
        state.cursor -= 1
      state.cursor = 0 if state.queue.length is 1
      target = [state.queue[0], state.queue[1] or state.queue[0], Math.min(1, Math.max(0, state.cursor))]

    for i in [0...state.bars]
      v = 0
      if target
        a = bandValue(target[0], i)
        b = bandValue(target[1], i)
        v = a + (b - a) * target[2]
        v = Math.pow(v, options.gamma)

      # Instant attack, linear falloff: the bar jumps straight to a louder value
      # and only the descent is rate-limited. Easing the rise as well is what makes
      # a modern meter look soft next to this one.
      if v >= state.cur[i]
        state.cur[i] = v
      else
        state.cur[i] = Math.max(v, state.cur[i] - falloffRate * secs)

      # Peaks hold where the bar left them, then accelerate downward.
      if state.cur[i] >= state.peak[i]
        state.peak[i] = state.cur[i]
        state.peakVel[i] = 0
      else
        state.peakVel[i] += peakGravity * secs
        state.peak[i] = Math.max(0, state.peak[i] - state.peakVel[i] * secs)
    return

  quiet = ->
    return true unless state.cur
    for i in [0...state.bars]
      return false if state.cur[i] > 0.004 or state.peak[i] > 0.004
    true

  # --- drawing --------------------------------------------------------------
  LAST_COLOR = VISCOLOR.spectrum.length - 1

  # Sample the ramp by height in the pane: the bottom row is the last entry
  # (green, or the faintest ink), the top row the first (red, or solid ink).
  colorAtRow = (row) ->
    idx = Math.round((1 - row / (ROWS - 1)) * LAST_COLOR)
    palette().spectrum[Math.min(LAST_COLOR, Math.max(0, idx))]

  # Colour of one row of one bar, for the styles that fill a bar row by row.
  #   normal: by absolute height in the pane, so the ramp is fixed to the panel
  #   fire:   by distance below that bar's own top, so every bar runs the full ramp
  rowColor = (row, level) ->
    if options.colorStyle is 'fire'
      idx = Math.min(LAST_COLOR, (level - 1) - row)
      return palette().spectrum[Math.max(0, idx)]
    colorAtRow(row)

  # Clip everything drawn below to a rounded rectangle covering the whole canvas.
  #
  # The path is built with arcTo rather than the tidier roundRect so it does not
  # depend on the WebKit version Übersicht happens to ship. Caller owns save/restore:
  # a clip is part of the canvas state and survives setTransform, so leaving one in
  # place would compound it against a stale size after a resize.
  clipRounded = (w, h) ->
    r = Math.min(options.vizRadius, w / 2, h / 2)
    return unless r > 0
    ctx.beginPath()
    ctx.moveTo(r, 0)
    ctx.arcTo(w, 0, w, h, r)
    ctx.arcTo(w, h, 0, h, r)
    ctx.arcTo(0, h, 0, 0, r)
    ctx.arcTo(0, 0, w, 0, r)
    ctx.closePath()
    ctx.clip()
    return

  draw = ->
    return if state.stopped
    now = performance.now()
    # Clamp so a backgrounded desktop (or a wake from sleep) does not fast-forward
    # the whole queue in one frame.
    elapsed = Math.min(250, now - state.lastT)
    state.lastT = now

    advance(elapsed)

    if sizeCanvas() and state.cur
      w = canvas.clientWidth
      h = canvas.clientHeight
      # Clear the full rect, then round off everything painted after it.
      ctx.clearRect(0, 0, w, h)
      ctx.save()
      clipRounded(w, h)

      if options.grid
        ctx.fillStyle = dotPattern()
        ctx.fillRect(0, 0, w, h)

      rowH = h / ROWS
      gap = options.barGap
      barW = Math.max(1, (w - gap * (state.bars - 1)) / state.bars)

      for i in [0...state.bars]
        x = i * (barW + gap)
        level = Math.round(state.cur[i] * ROWS)
        level = Math.min(ROWS, level)

        if level > 0
          if options.colorStyle is 'line'
            # A filled bar in one flat colour, taken from the ramp at the bar's own
            # height. As the bar falls it steps down through the ramp, so the whole
            # column flickers red -> amber -> green rather than holding a gradient.
            ctx.fillStyle = colorAtRow(level - 1)
            ctx.fillRect(x, h - level * rowH, barW, level * rowH)
          else
            for row in [0...level]
              ctx.fillStyle = rowColor(row, level)
              ctx.fillRect(x, h - (row + 1) * rowH, barW, rowH)

        if options.peaks
          p = Math.min(ROWS - 1, Math.round(state.peak[i] * ROWS))
          if p > 0
            ctx.fillStyle = palette().peak
            ctx.fillRect(x, h - (p + 1) * rowH, barW, Math.max(1, rowH * 0.5))

      ctx.restore()

    # --- fade -----------------------------------------------------------------
    # Rest is measured off the display, not the audio: the bars are still falling
    # for up to a second after a pause, and starting the fade under them looks like
    # a glitch instead of a settle.
    atRest = quiet()
    if atRest then state.restSince or= now else state.restSince = 0

    if options.fadeWhenSilent
      # An unreachable daemon is an error, not a quiet passage, so it keeps the
      # panel up rather than fading it away with its own message still inside.
      settled = state.restSince > 0 and now - state.restSince > options.fadeAfterMs
      panel.classList.toggle('is-silent', settled and not panel.classList.contains('is-offline'))

    # Battery guard: once the music stops there is nothing to animate, so fall back
    # to a slow tick. Keyed off the last frame carrying signal rather than the last
    # frame received: a paused source streams silence indefinitely, so waiting for
    # the frames themselves to stop would hold the 60fps loop open forever.
    stale = now - state.lastSignalT > options.idleAfterMs
    if stale and atRest
      state.idle = true
      state.raf = null
      state.timer = setTimeout(draw, 250)
    else
      state.idle = false
      state.raf = requestAnimationFrame(draw)
    return

  # --- lifecycle ------------------------------------------------------------
  window.__visualizerWidgetCleanup = ->
    state.stopped = true
    cancelAnimationFrame(state.raf) if state.raf
    clearTimeout(state.timer) if state.timer
    clearTimeout(state.retryTimer) if state.retryTimer
    ro?.disconnect()
    themeObserver?.disconnect()
    if state.ws
      state.ws.onclose = null
      try state.ws.close() catch e then null
    return

  panel.classList.add('is-offline')
  sizeCanvas()
  connect()
  state.timer = setTimeout(draw, 250)
  return
