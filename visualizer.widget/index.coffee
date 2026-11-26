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
  #             to leave me alone (it reads `data-layout-manual` off the root element).
  #   "managed" join the grid. The controller then packs and drags this widget like
  #             any other, and the position options below only decide where it sits
  #             until the controller places it.
  #
  # "managed" is the default. It used to be "manual", because this widget is a
  # companion to music.widget and both belong at the foot of the screen, while the
  # controller only ever grew columns downward from the top: being managed meant being
  # dragged up to join a stack, away from the widget it pairs with. The controller now
  # anchors each widget to the screen edge it belongs to, and this one publishes
  # `data-layout-anchor` from verticalPosition below, so it can be packed and dragged
  # like anything else and still sit where it was written to sit.
  #
  # With no controller installed the two behave identically.
  layoutMode : "managed"               # manual | managed

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

  # How many grid columns wide the widget is.
  #
  #   1  one column (320px), matching every other single-column widget.
  #   2  two columns (650px), the footprint github-contributions takes in its `year`
  #      span: n·COL + (n-1)·GAP, per LAYOUT.md's horizontal formula.
  #
  # Two columns also **doubles the number of bars**, so the extra room buys more of
  # them rather than wider ones: the bands are grouped half as coarsely, turning thick
  # mode's 19 bars into 38 at very nearly the same bar width (15.6px against 14.8px).
  # That is the whole point of tying the two together, since a display that just
  # stretches its bars stops looking like the original. See bandWidth below for the
  # one case that cannot double.
  #
  # This only decides the footprint while `width` is "grid". An explicit px width wins
  # over it, and this option then sets nothing but the bar density.
  #
  # Nothing else needs saying when layout-controller.widget is installed: it derives a
  # widget's column span from its measured width (its `spanOf`), so a two-column
  # widget is packed as two columns with no `data-layout-span` declared here.
  columns : 1                          # 1 | 2

  # Footprint. A number is px; the string "grid" reads the matching token published
  # by layout-controller.widget instead, so the widget follows the grid rather than
  # restating it:
  #
  #   width  "grid" -> one column, or the `columns` span above
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

  # --- Visualization ----------------------------------------------------------
  # Which of the two classic visualizations to draw. Winamp cycles these by clicking
  # its vis pane; here it is an option.
  #
  #   "analyzer" the spectrum analyzer: a bar per band, instant attack and a stepped
  #              falloff, with falling peak markers above.
  #   "scope"    the oscilloscope: the waveform itself, one sample per column,
  #              coloured by its distance from the centre line.
  #
  # The two share the palette below, and the panel, backdrop dots, rounding and fade
  # under "Look". Everything else under "Analyzer" is analyzer-only, and everything
  # under "Oscilloscope" is scope-only.
  #
  # The scope needs a waveform on the wire, which the daemon has only carried since it
  # gained its `--scope` flag. Against an older binary the widget says so on the panel
  # rather than drawing a flat line and leaving you to wonder which end is broken.
  visualization : "analyzer"              # analyzer | scope

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
  #
  # At `columns: 2` the grouping halves and the bar count doubles: thick goes to 38
  # bars. "thin" is the exception, and cannot double. It is already one bar per band,
  # so there is nothing left to divide and a two-column widget simply draws its 75
  # bars wider. Detail there has to come from the daemon instead, which takes a
  # `--bands` flag (capped at 128, so 150 is not available even by hand).
  bandWidth : "thick"                  # thin | thick

  # Show the falling peak markers above each bar.
  peaks : true                         # true | false

  # Falloff speeds, 1 (slowest) to 5 (fastest), matching the five positions of the
  # original's own two sliders. The classic analyzer snaps a bar up instantly and
  # lets it fall at a fixed rate, rather than easing both ways; peaks hold where they
  # land, then accelerate downward.
  #
  # These are 3 and 2, a fresh Winamp's own pair, but they do not mean here what they
  # mean there: the ladder is in pixels per *frame*, so what a setting works out to in
  # wall-clock terms depends on `visRefresh` below, which this widget runs at half the
  # original's rate. The pair is therefore a notch slower than Winamp in practice.
  #
  # Measured, at the 30 Hz set below: a full-scale bar takes 700 ms to reach the floor
  # and its peak marker 1733 ms. At 60 Hz the same pair halves both. So if you raise
  # `visRefresh`, drop these to keep the cadence, and vice versa.
  analyzerFalloff : 3                  # 1..5
  peakFalloff : 2                      # 1..5

  # The vis clock, in Hz. Winamp's falloff ladder is in whole pixels per rendered
  # frame, so it only means anything against a fixed frame rate: this is that rate,
  # and the ballistics run on it rather than on the repaint loop. Frames that span
  # two ticks run both, frames that span none leave the bars where they are, so the
  # display is independent of how often the widget actually paints.
  #
  # 60 is what Webamp uses, and Webamp's reverse-engineered analyzer is where the
  # ladder comes from. Winamp's own "refresh rate" slider repeatedly halves its rate,
  # so 30 / 15 / 7.5 are the other authentic settings. Lower is chunkier, and in
  # `line` mode it is the flicker rate: colours change fallStep * visRefresh * rows
  # times a second while a bar falls, which is ~45 a second at these defaults.
  # 30 rather than 60 here: at 60 the oscilloscope is the thing that suffers, because
  # consecutive frames are not phase-locked to each other. Each one is a fresh ~11 ms
  # slice of audio landing wherever its waveform happens to sit, so at 60 a second the
  # trace does not travel, it seethes. Halving the clock gives each frame long enough
  # to be read as a shape before the next replaces it.
  #
  # This is the original's own remedy and its own value: its refresh slider halves from
  # 60, so 30 / 15 / 7.5 are the other authentic settings. It governs the analyzer's
  # ballistics too, which is why the falloff pair above is quoted against it.
  visRefresh : 30                      # Hz

  # --- Oscilloscope -----------------------------------------------------------
  # Trace style, the three the original offers. Only used by visualization "scope".
  #
  #   "dots"  one pixel per column, at that sample's own row. The trace scatters
  #           wherever the waveform moves faster than a column can follow.
  #   "lines" each column is joined to the one before it, so the trace stays
  #           continuous however fast it swings. The original's default, and this
  #           widget's.
  #   "solid" each column is filled from the centre line out to its sample, so the
  #           waveform reads as a filled shape rather than a line.
  #
  # Orthogonal to scopeSmooth below: all three run either quantised or smooth.
  scopeStyle : "lines"                 # dots | lines | solid

  # Drop the original's quantisation. Not one of its settings; this is ours.
  #
  # The classic scope is quantised twice over, and both are the same decision taken
  # for the same reason, so they are the same switch here:
  #
  #   position  a sample lands on one of 16 rows, which is what makes the trace a
  #             staircase. Smooth puts it at its exact height.
  #   colour    the ramp is applied in five hard bands. Smooth runs it as a vertical
  #             gradient instead, so the trace dims continuously toward the rails.
  #
  # What it means per style: "lines" becomes a stroked curve (see scopeLineWidth),
  # "solid" becomes a filled shape with a curved edge rather than a stack of cells,
  # and "dots" keeps its scatter but places each mark at its true height instead of
  # snapping it to a row.
  #
  # false is the faithful setting, and is what the fidelity tests run against.
  scopeSmooth : true                    # true | false

  # Width of the stroke under scopeStyle "lines" with scopeSmooth on, in px.
  scopeLineWidth : 5                    # px

  # Low-pass the waveform before drawing it: this many passes of a [1/4, 1/2, 1/4]
  # filter across the points. 0 is off, and off is what the original does.
  #
  # This is the other half of "smoother", and the more important half. Un-quantising
  # the trace removes the staircase, but it cannot remove the jitter underneath it,
  # because the points themselves are aliased: the daemon takes one sample per column
  # and throws the other ~85% of the window away, so anything above about 3.4 kHz
  # folds down into the trace as noise that jumps between frames. That is the original
  # behaviour, and it is a 1999 decision rather than an aesthetic one, as its own
  # source says in as many words: "interpolation is too expensive for this use".
  #
  # Filtering here is the cheap fix and it works on the points we already have. The
  # honest fix is to decimate properly in the daemon, which has all 512 samples and
  # currently discards them; this is a smaller change that gets most of the way.
  #
  # 1-2 reads as a steadier version of the same trace. Past about 4 it stops following
  # the waveform and starts drawing its envelope.
  scopeSmoothing : 1                    # passes, 0 = off

  # Size of a dot, in px. Only used by scopeStyle "dots".
  #
  #   a number  a square dot of that size, centred in its cell.
  #   "cell"    fill the whole cell, which is what the original does.
  #
  # **This is also the gap control.** The dots sit on a fixed grid, one per column,
  # spaced pane-width / points apart, which is 630 / 75 = 8.4px at this widget's
  # default size. That spacing is not adjustable from here, because it is the daemon
  # that decides how many points there are (`--scope`, see the note below). What is
  # adjustable is how much of each column the dot fills, and the gap is simply what is
  # left over:
  #
  #     gap = spacing - scopeDotSize
  #
  # So at 8.4px spacing: 3 gives a 5.4px gap, 6 gives 2.4px, and 8 very nearly closes
  # it. Sizes above the spacing are clamped to it, so the dots can come to touch but
  # never overlap into a solid bar.
  #
  # "cell" is the faithful setting and it is not the default, because faithful here
  # does not survive the change of scale. The original's pane is 75x16 *pixels*, so a
  # cell is one pixel and a filled cell is a dot. This widget spreads those same 75
  # columns and 16 rows over a 630x70 pane, where a cell is roughly 8x4 px and a
  # filled one reads as a dash. Shrinking the mark to a square is what keeps the
  # scatter looking like the thing it is imitating.
  #
  # The mark is centred in its cell either way, so this changes how the dots look
  # without moving any of them.
  scopeDotSize : 5                     # px | "cell"

  # Shape of a dot. Only used by scopeStyle "dots", and only when scopeDotSize is a
  # number: at "cell" the mark is the original's filled pixel and stays square, since
  # rounding the one authentic setting would leave nothing that is actually faithful.
  #
  #   "round"   a circle inscribed in the square below, so switching shape moves
  #             nothing and changes no spacing.
  #   "square"  the original's mark, scaled down.
  #
  # A circle reads smaller than a square of the same size, by about a fifth of the
  # area, so a round dot usually wants a point or two more of scopeDotSize than the
  # square that looked right.
  scopeDotShape : "round"              # round | square

  # Vertical gain on the trace, hard-clipped at the edges of the pane the way the
  # original's is.
  #
  # 1 is the original's own scaling and is what it says on the tin: the pane spans
  # half of full scale, so a track has to peak at -6 dBFS to fill it and anything
  # louder flattens against the rails. That was a reasonable bet in 1999, when
  # Winamp's preamp sat ahead of the visualization and the decade's masters ran hot.
  # It is a poor one against a modern library: measured here, a track peaking at
  # -16.6 dBFS uses a quarter of the pane and the trace barely leaves the centre line.
  #
  # So this is the knob for that, and 3 to 4 is the range that makes a quiet master
  # look the way Winamp looked on a loud one. It is deliberately not folded into the
  # default, because the default's job is to be the original.
  #
  # Note the analyzer's `gain` is a different setting on a different signal (an FFT
  # magnitude, not the waveform) and does not affect the trace.
  scopeGain : 1                        # 1 = the original's scaling

  # There is deliberately no point-count option here. The trace's horizontal
  # resolution is the daemon's: it sends 75 points a frame, which is the original's
  # pane width in pixels and its scope's one-sample-per-column, and the widget draws
  # exactly what arrives across whatever width it has. So `columns: 2` buys a wider
  # trace rather than a finer one, exactly as `bandWidth: "thin"` does; pass the
  # daemon `--scope 150` if you want the detail instead. `rows` and `visRefresh` do
  # apply, as the scope's vertical resolution and its own refresh rate.
  #
  # `bandWidth`, `colorStyle`, `peaks` and both falloffs are analyzer ballistics and
  # do nothing here: the scope has no ballistics, it draws the waveform as it is.

  # --- Look -------------------------------------------------------------------
  # What sits behind the bars.
  #
  #   "panel"   this collection's translucent blurred panel.
  #   "none"    nothing. The bars sit straight on the desktop with no pane behind
  #             them and no blur. The widget keeps its footprint and padding, so
  #             the bars do not move when you switch, and the fade still works
  #             (it is the whole panel's opacity either way).
  #
  # With "none" the "no audio daemon" message loses its backing, but keeps the
  # text-shadow, so it stays readable on most wallpapers.
  background : "panel"               # panel | none

  # Draw the dotted backdrop behind the bars.
  grid : true                          # true | false

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

  # The daemon's dB window, ceilDb - floorDb, which is 60 at its defaults (-72..-12).
  #
  # The widget needs it because the original's analyzer is linear in amplitude: its
  # FFT hands back sqrt(re^2 + im^2), which is compared straight against pixels and
  # clamped, with no dB conversion anywhere in the chain. (The one log10 in that FFT
  # is applied to the frequency index, a per-bin weighting running 0.024 to 1.0, so a
  # 32dB high-frequency tilt. It is a weighting, not a log of amplitude.) The daemon
  # does convert to dB, so this is what undoes it and recovers the amplitude the
  # original would have worked in.
  #
  # That reconstruction is the whole character of the display. A linear mapping leaves
  # quiet content on the floor and lets only real peaks climb; passing the daemon's dB
  # reading straight through instead lifts everything into the middle of the ramp. A
  # band 36dB down sits on the bottom row one way and halfway up the pane the other.
  # Measured over 20s of playback at the same ~1.5% of bars pinned at the ceiling:
  #
  #                    dark   green   amber   top four   median row
  #   linear (this)   26.1%   65.4%    6.8%       1.8%            2
  #   raw dB           2.7%   24.9%   58.5%      13.9%            9
  #
  # Both reach all sixteen ramp entries; the dB reading just spends its life in the
  # warm middle of them, which is not what the original looks like.
  #
  # Keep this matched to the daemon for a faithful reconstruction. Lowering it
  # deliberately is the gentlest way to tame the spikiness, since it compresses the
  # range the curve spans: at 48 the dark share above drops from 26% to 16% and the
  # display reads fuller. Reach for it before gain.
  dbSpan : 60                          # dB

  # Output gain, applied after the curve above and hard-clipped at full scale, the way
  # the original's is. Winamp's own gain sits on the waveform ahead of its FFT (it
  # divides by 24, so roughly 5x), which is the same place in the chain: on the linear
  # amplitude, not on a dB reading.
  #
  # 1.0 is the daemon's own scale and wants to stay there. It already pins about 1% of
  # bars at the ceiling, which is the original's character. Raising it is rarely the
  # answer to a display that reads wrong, because it moves the ceiling along with
  # everything else.
  gain : 1.0

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
#
# `dots` and `background` are transcribed for completeness but are never drawn: the
# backdrop dots always take the theme's neutral instead (see buildPalette), and the
# pane behind them is this collection's own panel, or nothing at all. `spectrum`,
# `oscilloscope` and `peak` are the three a skin actually supplies. The other two are
# kept so the block stays a faithful copy of the file's format, which is what makes
# another skin's values droppable straight in.
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
  # Lines 18-22, the oscilloscope ramp, centre of the trace outward. Near-greyscale
  # in the stock skin: white on the centre line falling to a grey-blue at the edges of
  # the pane, a drop of about 40% in luminance where the spectrum ramp sweeps a full
  # hue range. That gentleness is the reason the themed schemes below do not reuse
  # `monoRange` for it.
  oscilloscope: [
    '255,255,255' # 0 — the centre line
    '214,214,222'
    '181,189,189'
    '160,170,175'
    '148,156,165' # 4 — top and bottom of the pane
  ]
  peak: '150,150,150'
  dots: '24,33,41'
  background: '0,0,0'

# The original's two falloff ladders, kept in the units its analyzer works in and
# converted where they are used. A bar falls a flat BAR_FALLOFF/16 pixels per
# rendered frame on a 16px pane. A peak starts at PEAK_V0 pixels per frame and
# multiplies that velocity by PEAK_ACCEL every frame, so it hangs for a beat and then
# plummets, rather than accelerating evenly under gravity. Index 2 (12) and index 1
# (1.1) are a fresh Winamp's defaults, and this widget's.
#
# Per frame rather than per second is the whole point: whole-pixel steps on a fixed
# clock are what give the classic analyzer its stair-step cadence, and under
# colorStyle "line" that cadence *is* the flicker, because the bar's colour is
# sampled at its own height and so changes on every step. Rates smoothed out over
# real elapsed time read as a shimmer instead. See options.visRefresh for the clock.
# Steps in the oscilloscope ramp, and the ink opacities the themed schemes spread
# over them, centre of the trace outward.
#
# Deliberately not `options.monoRange`. That range is tuned for the analyzer, where a
# bar's height already carries the level and the ramp is free to fade to .3 at the
# quiet end; on the scope the ramp runs the other way round, so a .3 floor would leave
# the loudest excursions the faintest thing on the panel. .55 is roughly the drop the
# stock ramp makes (255 down to ~156 in luminance), which is what keeps a themed trace
# reading like the original's.
SCOPE_STEPS = 5
SCOPE_INK = [1, 0.55]                      # [centre line, edges of the pane]

BAR_FALLOFF = [3, 6, 12, 16, 32]           # sixteenths of a pixel per frame
PEAK_ACCEL  = [1.05, 1.1, 1.2, 1.4, 1.6]   # velocity multiplier per frame
PEAK_V0     = 3 / 256                      # initial peak velocity, pixels per frame
# Height of the pane the two ladders above are quoted against, which is fixed at the
# original's 16 rows however many rows this widget is drawing.
PANE_PX     = 16

# Option-driven CSS is resolved here rather than with Stylus `if` blocks.
# `if #{someOption} == someValue` interpolates to a comparison of two bare Stylus
# identifiers, which does not evaluate the way it reads: it silently takes the
# else branch every time. That went unnoticed for the position options, whose
# defaults want the else branch anyway, and left the non-default `background`
# settings dead. Building the finished declarations in CoffeeScript removes the
# guesswork.
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
GRID_GAP  = 'var(--grid-gap, 10px)'

# Column span, clamped: anything that is not 2 is one column. Read in two places, the
# footprint below and the band grouping in afterRender, which is exactly the coupling
# the `columns` option describes.
COLUMNS = if options.columns is 2 then 2 else 1

# A span of n columns is n·COL + (n-1)·GAP (LAYOUT.md). Left symbolic rather than
# resolved to 650px so it still follows a grid the controller computes differently,
# the same reason the single-column case reads a token instead of hardcoding 320.
gridWidthCss =
  if COLUMNS > 1
    "calc(#{GRID_COL} * #{COLUMNS} + #{GRID_GAP} * #{COLUMNS - 1})"
  else
    GRID_COL

widthCss  = if options.width  is 'grid' then gridWidthCss else "#{options.width}px"
heightCss = if options.height is 'grid' then GRID_UNIT else "#{options.height}px"
# Centring needs half the width, which has to stay symbolic when it is a token. The
# nested calc() in the two-column case is deliberate and valid: dividing a calc() by a
# plain number is allowed, and flattening it by hand would mean resolving the tokens.
halfWidthCss =
  if options.width is 'grid' then "calc(#{gridWidthCss} / -2)" else "-#{options.width / 2}px"

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
  // grid: foot of column 2, beside music.widget, #{COLUMNS}×1 (see LAYOUT.md)
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

  .panel.is-offline .viz-status,
  .panel.is-nowave .viz-status
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

  # Which screen edge to stack from when the controller does manage this widget. It
  # packs a column downward from the top by default, and this widget belongs at the
  # foot of the screen beside music.widget, so it says so rather than opting out.
  # Only a default: once the widget has been dragged, where it was dropped wins.
  domEl.setAttribute? 'data-layout-anchor',
    if options.verticalPosition is 'bottom' then 'bottom' else 'top'

  panel = domEl.querySelector('.panel')
  canvas = domEl.querySelector('.viz')
  status = domEl.querySelector('.viz-status')
  return unless panel and canvas
  ctx = canvas.getContext('2d')
  return unless ctx

  ROWS = Math.max(4, options.rows)
  SCOPE = options.visualization is 'scope'

  # Bands averaged into one bar. Halving this per column of span is what turns the
  # extra width into extra bars instead of fatter ones: thick mode's group of 4 becomes
  # 2, so 75 bands draw 38 bars rather than 19, each within a pixel of its old width.
  #
  # The floor of 1 is where thin mode lands, and it is a real limit rather than a
  # rounding detail: one bar per band is already the finest the wire format carries, so
  # a two-column thin display draws the same 75 bars twice as wide. Only the daemon's
  # `--bands` can add detail there.
  BASE_GROUP = if options.bandWidth is 'thick' then 4 else 1
  GROUP = Math.max(1, Math.round(BASE_GROUP / COLUMNS))

  # The vis clock, and the original's per-frame steps converted from pixels of its
  # 16px pane into fractions of full scale. Going through fractions rather than rows
  # is deliberate: `rows` then changes the resolution of the display without changing
  # how fast anything on it moves.
  TICK_MS   = 1000 / Math.max(1, options.visRefresh)
  MAX_TICKS = 16     # ceiling on catch-up after a stall, see advance()
  # Undo the daemon's dB mapping to recover the amplitude the original's analyzer works
  # in: the daemon sent v = (db - floorDb) / dbSpan, so the amplitude relative to its
  # ceiling is 10 ^ (dbSpan * (v - 1) / 20). Silence has to short-circuit, or the
  # display would floor at 10 ^ -3 instead of at nothing.
  DB_DECADES = options.dbSpan / 20
  shapeLevel = (v) -> if v <= 0 then 0 else Math.pow(10, DB_DECADES * (v - 1))

  sliderIdx = (n) -> Math.min(4, Math.max(0, n - 1))
  fallStep  = BAR_FALLOFF[sliderIdx(options.analyzerFalloff)] / 16 / PANE_PX
  peakAccel = PEAK_ACCEL[sliderIdx(options.peakFalloff)]
  peakVel0  = PEAK_V0 / PANE_PX

  fill = (rgb, alpha = 1) -> "rgba(#{rgb}, #{alpha})"

  state =
    queue: []            # band frames awaiting playback
    wqueue: []           # waveform frames, one per band frame; empty outside scope mode
    wave: null           # the waveform currently on screen, or null for a flat line
    scopeSeen: false     # the daemon has sent at least one waveform
    scopeGrad: null      # cached stroke gradient, dropped with the palette or the size
    dpr: 1               # device pixel ratio, for snapping the scope's column edges
    dt: 10.67            # ms between frames, replaced by the daemon's own value
    cursor: 0            # fractional position between queue[0] and queue[1]
    bands: 0             # band count the daemon is sending
    bars: 0              # bars actually drawn, after thin/thick grouping
    cur: null            # ballistic bar values, 0..1
    peak: null           # peak marker positions, 0..1
    peakVel: null        # peak fall velocity, full scale per vis tick
    tickAcc: 0           # ms of real time not yet spent on a vis tick
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

    # The themed schemes both take an ink lightness ramp for the trace rather than the
    # hue ramp the analyzer gets. The stock oscilloscope ramp is a near-greyscale
    # fall-off from a white centre line, so brightness is what carries "distance from
    # centre" there; running the data-series hues through it instead would tint the
    # trace by loudness and stop it reading as an oscilloscope.
    scopeInk = (ink) ->
      [hi, lo] = SCOPE_INK
      for i in [0...SCOPE_STEPS]
        fill(ink, round(hi + (lo - hi) * (i / (SCOPE_STEPS - 1))))

    # The backdrop dots are the one part of the palette that never takes a scheme's
    # colours. They are structure rather than data, a faint neutral for the bars to
    # read against, so they use the same --dot-grid value as every other widget in
    # this collection (rgba(ink / .05), see THEME.md). VISCOLOR gives them a solid
    # blue-grey, which was legible on Winamp's opaque black pane but on a translucent
    # panel reads as a second colour competing with the ramp, so that value is
    # deliberately ignored. Falls back to white ink with no theme-controller installed.
    ink = readInk()
    dots = fill(ink, .05)

    if options.colorScheme is 'monochrome'
      lo = Math.min(options.monoRange...)
      hi = Math.max(options.monoRange...)
      spectrum =
        for i in [0...steps]
          # Index 0 is the top of the ramp, so alpha runs hi -> lo down the list,
          # mirroring the Winamp ramp's hot-to-cool ordering.
          fill(ink, round(hi + (lo - hi) * (i / (steps - 1))))
      # Peak markers sit above the bar tops, so they take the brightest step and
      # stay the most solid thing on the panel.
      return
        spectrum: spectrum
        scope: scopeInk(ink)
        peak: fill(ink, round(hi))
        dots: dots

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
        return
          spectrum: rampFrom(stops, steps)
          scope: scopeInk(ink)
          peak: fill(ink, .8)
          dots: dots
      # No controller, or a theme that publishes no series roles: fall through to
      # the Winamp ramp rather than inventing colours.

    spectrum: (fill(c) for c in VISCOLOR.spectrum)
    scope: (fill(c) for c in VISCOLOR.oscilloscope)
    peak: fill(VISCOLOR.peak)
    dots: dots

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
    state.dpr = dpr
    w = canvas.clientWidth
    h = canvas.clientHeight
    return false unless w > 0 and h > 0
    want = [Math.round(w * dpr), Math.round(h * dpr)]
    if canvas.width isnt want[0] or canvas.height isnt want[1]
      canvas.width = want[0]
      canvas.height = want[1]
      state.dotPattern = null
      state.scopeGrad = null
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
      state.scopeGrad = null
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

      # The waveform rides the same burst, one entry per band frame, and is queued in
      # lockstep so the two stay aligned through every drain and drop below. Only in
      # scope mode: the analyzer never reads it, and holding a second queue for it
      # would be pure churn.
      if SCOPE
        if msg.w and msg.w.length is msg.f.length
          state.scopeSeen = true
          panel.classList.remove('is-nowave')
          state.wqueue.push(v) for v in msg.w
        else
          # A daemon built before `--scope`, or one running `--scope 0`. Say so on the
          # panel: the alternative is a flat line, which looks exactly like silence.
          state.wqueue.push(null) for f in msg.f
          unless state.scopeSeen
            status?.textContent = 'daemon sends no waveform'
            panel.classList.add('is-nowave')

      state.lastDataT = performance.now()
      state.lastSignalT = state.lastDataT if frameSignal(msg)

      # Latency guard: if playback has fallen behind the source, drop the backlog
      # rather than letting the display drift permanently behind the music.
      maxQ = Math.max(2, Math.ceil(options.maxLatencyMs / state.dt))
      if state.queue.length > maxQ
        dropFrames(state.queue.length - maxQ)

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
      state.wqueue.length = 0
      # Dropped rather than left on screen, so a vanished daemon settles to a flat
      # line instead of freezing the trace mid-swing.
      state.wave = null
      scheduleRetry()

  # --- playback -------------------------------------------------------------
  # The one place either queue is shortened from the front. Both are shifted together
  # or the waveform drifts out of step with the bars it arrived beside, which shows up
  # as a trace running ahead of the music by however many frames were dropped.
  dropFrames = (n) ->
    return unless n > 0
    state.queue.splice(0, n)
    state.wqueue.splice(0, n) if state.wqueue.length
    return

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

  # The original steps its ballistics once per rendered frame, in fixed whole-pixel
  # amounts, rather than evaluating them as a continuous function of elapsed time.
  # Reproducing that means running them off a clock of their own: a repaint spanning
  # two ticks runs both, one spanning none leaves the bars exactly where they are.
  # Scaling the steps by real elapsed time instead would land the bars on the same
  # heights on average, but it lets a colour boundary be crossed at any moment in
  # between, which in "line" mode reads as a shimmer rather than a stair.
  advance = (elapsed) ->
    return unless state.cur

    # Interpolate between the two frames straddling the playback cursor. The queue is
    # drained on real time whether or not a tick is due, so audio never drifts.
    target = null
    if state.queue.length
      state.cursor += elapsed / state.dt
      while state.cursor >= 1 and state.queue.length > 1
        dropFrames(1)
        state.cursor -= 1
      state.cursor = 0 if state.queue.length is 1
      target = [state.queue[0], state.queue[1] or state.queue[0], Math.min(1, Math.max(0, state.cursor))]

    state.tickAcc += elapsed
    ticks = Math.floor(state.tickAcc / TICK_MS)
    state.tickAcc -= ticks * TICK_MS
    return if ticks < 1
    # A wake from sleep or a spell on a hidden desktop must not replay a second of
    # ticks. There is nothing to catch up to: the display only has to land in the
    # right place, and the peaks it dropped on the way were never on screen.
    ticks = Math.min(ticks, MAX_TICKS)

    # The scope has no ballistics to run: it shows the waveform as it is. What the vis
    # clock still buys it is the refresh rate, so the frame on screen is latched here
    # rather than in the repaint loop and `visRefresh` means the same thing for both
    # visualizations. Frames arrive faster than the clock ticks, so some are never
    # drawn, which is exactly what the original does by sampling whatever is current
    # at its own refresh rate.
    if SCOPE
      w = state.wqueue[0] or null
      # Filtered here rather than in the renderer so it costs one pass per vis tick
      # instead of one per repaint, and so every style sees the same waveform.
      state.wave = if w and SMOOTH_PASSES > 0 then smoothWave(w) else w
      return

    for i in [0...state.bars]
      v = 0
      if target
        a = bandValue(target[0], i)
        b = bandValue(target[1], i)
        v = a + (b - a) * target[2]
        # Curve first, then gain, then clip. That order is the original's: its gain
        # sits on the waveform ahead of the FFT, so it multiplies an amplitude rather
        # than a dB reading, and the ceiling is a hard clip on the result.
        v = Math.min(1, shapeLevel(v) * options.gain)

      for tick in [0...ticks]
        # Instant attack, flat falloff: the bar jumps straight to a louder value and
        # only the descent is rate-limited. Easing the rise as well is what makes a
        # modern meter look soft next to this one.
        if v >= state.cur[i]
          state.cur[i] = v
        else
          state.cur[i] = Math.max(v, state.cur[i] - fallStep)

        # Peaks hold where the bar left them, then accelerate away. The velocity is
        # multiplied each tick rather than added to, which is what makes a peak seem
        # to hang for a moment before dropping fast.
        if state.cur[i] >= state.peak[i]
          state.peak[i] = state.cur[i]
          state.peakVel[i] = peakVel0
        else
          state.peak[i] = Math.max(0, state.peak[i] - state.peakVel[i])
          state.peakVel[i] *= peakAccel
    return

  quiet = ->
    if SCOPE
      # Rest is a flat trace on the centre line. The tolerance is one byte either way,
      # for a source that dithers its silence rather than sending true zeroes.
      w = state.wave
      return true unless w
      for v in w
        return false if v > 129 or v < 127
      return true
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

  # The panel carries a message the user needs to read: an unreachable daemon, or one
  # that sends no waveform for the scope to draw. Both keep the panel up, because the
  # fade would take the message down with it and leave an empty desktop as the only
  # symptom.
  showingError = -> panel.classList.contains('is-offline') or
                    panel.classList.contains('is-nowave')

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

  # --- drawing: the analyzer ------------------------------------------------
  drawBars = (w, h) ->
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
    return

  # --- drawing: the oscilloscope --------------------------------------------
  # The centre line. The original's pane is 16 rows and silence sits on row 7, the
  # upper of the two middle ones, so the trace rides a row closer to the top than to
  # the bottom; `rows` only changes the resolution around that.
  SCOPE_CENTER = Math.floor((ROWS - 1) / 2)
  SMOOTH = options.scopeSmooth is true
  LINE_W = Math.max(0.1, options.scopeLineWidth or 1)
  SMOOTH_PASSES = Math.max(0, Math.round(options.scopeSmoothing or 0))

  # A [1/4, 1/2, 1/4] pass, repeated. The two endpoints hold their own value: they
  # have no outside neighbour, and borrowing one would drag the ends of the trace
  # toward the centre line and put a permanent dip at each edge of the pane.
  smoothWave = (src) ->
    out = (v for v in src)
    n = out.length
    return out if n < 3 or SMOOTH_PASSES < 1
    for pass in [0...SMOOTH_PASSES]
      prev = out[0]
      for i in [1...n - 1]
        cur = out[i]
        out[i] = prev * 0.25 + cur * 0.5 + out[i + 1] * 0.25
        prev = cur
    out

  # Row (0 = the top of the pane) for one waveform byte, 128 being zero.
  #
  # This is the original's own scaling, and it is a 2x zoom that hard-clips: it puts
  # eight bytes in a row across a 16-row pane, so the pane spans half of full scale and
  # anything past -6 dBFS flattens against the top or the bottom. That clipping is a
  # large part of why a loud track's scope reads as a thick band rather than a wave,
  # and why a quiet passage still has somewhere to go.
  SCOPE_GAIN = Math.max(0, options.scopeGain ? 1)
  # 0 means "fill the cell", which is both the "cell" setting and the degenerate case
  # of a size at or above the cell, so the two need no separate handling below.
  DOT_PX = if options.scopeDotSize is 'cell' then 0 else Math.max(0, options.scopeDotSize or 0)
  DOT_ROUND = options.scopeDotShape isnt 'square'
  # Note the minus: a positive sample moves the trace UP the pane.
  #
  # Worth spelling out, because the obvious reading of the wire format gets it
  # backwards. The daemon sends what Web Audio sends, an unsigned byte with 128 as
  # zero, and mapping that straight onto a canvas (whose y grows downward) puts
  # positive samples below the line. The original keeps its pane bottom-up and builds
  # the row as `sample/8 + 8`, so positive is up. Its spectrum analyzer settles the
  # question rather than leaving it to inference: a bar of height v there is drawn by
  # stepping the buffer forward one row at a time, and a taller bar has to go up.
  scopeRow = (v) ->
    r = SCOPE_CENTER - Math.round((v - 128) * SCOPE_GAIN * ROWS / 128)
    Math.max(0, Math.min(ROWS - 1, r))

  # The same mapping as scopeRow with the rounding taken out: a px position rather
  # than a row index, so the stroke is free to sit between rows. Clamped to the pane
  # rather than to the last row centre, so a loud passage flattens against the edge
  # exactly as the quantised trace does.
  scopeY = (v, h, rowH) ->
    offset = (v - 128) * SCOPE_GAIN * ROWS / 128
    Math.max(0, Math.min(h, (SCOPE_CENTER + 0.5 - offset) * rowH))

  # The five ramp entries as a vertical gradient, mirrored about the centre line so a
  # stroke dims toward the rails the way the lit cells do. Cached: building it is a
  # handful of allocations and the ramp only changes with the theme or the size.
  scopeGradient = (h) ->
    return state.scopeGrad if state.scopeGrad
    ramp = palette().scope
    n = ramp.length
    mid = (SCOPE_CENTER + 0.5) / ROWS       # the centre line is not h/2, see scopeRow
    g = ctx.createLinearGradient(0, 0, 0, h)
    # Added top-down, so the stops come out in ascending order without sorting.
    for i in [n - 1..0] by -1
      g.addColorStop(mid * (1 - i / (n - 1)), ramp[i])
    for i in [1...n]
      g.addColorStop(mid + (1 - mid) * (i / (n - 1)), ramp[i])
    state.scopeGrad = g
    g

  # Which of the five ramp entries a row takes: two rows to a step, counted out from
  # the centre. Reproduced from the reference table rather than derived from the
  # distance, because it is not symmetric. The steps are anchored on the centre *pair*
  # of rows, so the half above the line and the half below it round opposite ways, and
  # only the bottom of the pane ever reaches the last entry.
  scopeColor = (row) ->
    y = if ROWS is 16 then row else Math.round(row * 15 / (ROWS - 1))
    idx = if y >= 14 then 4
    else if y >= 12 then 3
    else if y >= 10 then 2
    else if y >= 8  then 1
    else if y >= 6  then 0
    else if y >= 4  then 1
    else if y >= 2  then 2
    else 3
    palette().scope[idx]

  drawScope = (w, h) ->
    wave = state.wave
    pts = if wave then wave.length else 0
    rowH = h / ROWS
    dpr = state.dpr or 1
    # Columns abut with no gap (the original's scope has none, and `barGap` is an
    # analyzer setting), so a fractional edge would leave a hairline of panel showing
    # between every pair. Snapping to device pixels closes them.
    snap = (v) -> Math.round(v * dpr) / dpr
    thin = 1 / dpr

    # Nothing to draw yet, or the daemon has gone. The original holds a flat line on
    # the centre row rather than blanking the pane, and so does this: it is also what
    # the fade settles onto, so the panel dims from a line instead of from a freeze.
    #
    # Except when the panel is carrying a message, because the status text is centred
    # too and the line lands straight through it. The analyzer has no equivalent
    # problem: with no data its bars are simply zero and it draws nothing at all.
    unless pts
      return if showingError()
      if SMOOTH
        # Matched to the stroke, or the rest state would be a fat quantised bar that
        # the trace never touches.
        ctx.beginPath()
        ctx.moveTo(0, (SCOPE_CENTER + 0.5) * rowH)
        ctx.lineTo(w, (SCOPE_CENTER + 0.5) * rowH)
        ctx.lineWidth = Math.max(thin, LINE_W)
        ctx.strokeStyle = palette().scope[0]
        ctx.stroke()
        return
      ctx.fillStyle = palette().scope[0]
      ctx.fillRect(0, snap(SCOPE_CENTER * rowH), w, Math.max(thin, snap(rowH)))
      return

    colW = w / pts

    if SMOOTH
      # Every mark sits at the centre of its column, the same grid the quantised
      # styles draw on, so turning this on moves nothing horizontally. The gradient
      # replaces the five colour bands, which is the other half of un-quantising.
      grad = scopeGradient(h)
      midY = (SCOPE_CENTER + 0.5) * rowH

      if options.scopeStyle is 'dots'
        # One fillStyle for the lot: a gradient is evaluated in canvas space, so each
        # dot picks up the ramp at its own height without being asked.
        ctx.fillStyle = grad
        r = Math.max(thin, Math.min((if DOT_PX > 0 then DOT_PX else colW), colW)) / 2
        for j in [0...pts]
          x = (j + 0.5) * colW
          # Held inside the pane, as in the quantised branch, so an extreme reads as
          # an extreme rather than as a half-clipped smaller dot.
          y = Math.max(r, Math.min(h - r, scopeY(wave[j], h, rowH)))
          ctx.beginPath()
          if DOT_ROUND then ctx.arc(x, y, r, 0, Math.PI * 2)
          else ctx.rect(x - r, y - r, r * 2, r * 2)
          ctx.fill()
        return

      ctx.beginPath()
      for j in [0...pts]
        y = scopeY(wave[j], h, rowH)
        x = (j + 0.5) * colW
        if j is 0 then ctx.moveTo(x, y) else ctx.lineTo(x, y)

      if options.scopeStyle is 'solid'
        # Closed back along the centre line, so the fill is the area between the trace
        # and where silence would sit, which is what the quantised solid fills cell by
        # cell.
        ctx.lineTo((pts - 0.5) * colW, midY)
        ctx.lineTo(0.5 * colW, midY)
        ctx.closePath()
        ctx.fillStyle = grad
        ctx.fill()
        return

      # "lines": round joins, because the alternative on a trace this steep is a spike
      # at every direction change.
      ctx.lineWidth = Math.max(thin, LINE_W)
      ctx.lineJoin = 'round'
      ctx.lineCap = 'round'
      ctx.strokeStyle = grad
      ctx.stroke()
      return

    last = scopeRow(wave[0])

    for j in [0...pts]
      row = scopeRow(wave[j])
      ctx.fillStyle = scopeColor(row)

      switch options.scopeStyle
        when 'dots'
          # One cell per column, at its own sample. Wherever the waveform moves
          # faster than a column can follow, the trace breaks into a scatter.
          top = bottom = row
        when 'solid'
          # Filled from the centre pair outward. A sample below the line fills down
          # from the lower of the two middle rows and one above fills up from the
          # upper, which is what keeps silence a single row rather than a slab.
          if row > SCOPE_CENTER
            top = SCOPE_CENTER + 1
            bottom = row
          else
            top = row
            bottom = SCOPE_CENTER
        else
          # "lines": join this column to the one before it. The asymmetry is the
          # original's. A trace moving down the pane keeps the previous column's own
          # row, one moving up drops it, so an ascending edge does not paint a cell
          # that the previous column already painted.
          top = row
          bottom = last
          if bottom < top
            [top, bottom] = [bottom, top]
            top += 1

      last = row
      continue if bottom < top

      # Edges rather than widths: rounding each edge once means column j's right edge
      # and column j+1's left edge are the same number, however the division fell.
      x0 = snap(j * colW)
      x1 = snap((j + 1) * colW)
      y0 = snap(top * rowH)
      y1 = snap((bottom + 1) * rowH)

      if DOT_PX and options.scopeStyle is 'dots'
        # Clamped to the column spacing, so dots can touch but never overlap. It is
        # deliberately NOT also clamped to the row height: a row is a sixteenth of the
        # pane (4.4px here) and capping the dot there would pin the gap at 4px however
        # large a dot was asked for, which is exactly the setting failing to do its job.
        # A dot taller than its row simply overlaps its neighbours' rows, which on a
        # scatter is what a bigger dot is supposed to look like.
        d = Math.min(DOT_PX, x1 - x0)
        # Held inside the pane so a dot on the top or bottom row is not sliced in half
        # by the edge, which would read as a smaller dot rather than an extreme one.
        dy = Math.max(0, Math.min(h - d, (y0 + y1 - d) / 2))
        dx = snap((x0 + x1 - d) / 2)
        dy = snap(dy)
        size = Math.max(thin, d)
        if DOT_ROUND
          # Inscribed in exactly the square the other branch would have filled, so the
          # two shapes share a centre and the setting changes nothing but the outline.
          # arc() rather than roundRect() for the same reason clipRounded uses arcTo:
          # it does not depend on which WebKit version Ubersicht happens to ship.
          r = size / 2
          ctx.beginPath()
          ctx.arc(dx + r, dy + r, r, 0, Math.PI * 2)
          ctx.fill()
        else
          ctx.fillRect(dx, dy, size, size)
      else
        ctx.fillRect(x0, y0, Math.max(thin, x1 - x0), Math.max(thin, y1 - y0))
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

      if SCOPE then drawScope(w, h) else drawBars(w, h)

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
      panel.classList.toggle('is-silent', settled and not showingError())

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
