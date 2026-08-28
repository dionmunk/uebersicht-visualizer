# Visualizer design notes

Why the daemon and the widget are built the way they are. This is the companion to
[README.md](README.md), which covers setup, options and troubleshooting. Everything here
describes behaviour that is live in `visualizer.widget/lib/visualizerd.swift`; if you
change that file, this is the document that moves with it.

Most of these notes exist because a failure mode looked like something else. The theme
running through all of them is that in CoreAudio, broken almost never announces itself:
audio keeps flowing, buffers keep arriving on schedule, nothing throws, and the log keeps
naming the device you asked for.

## Capture

### Why AUHAL and not AVAudioEngine

Capture was originally an `AVAudioEngine` plus `installTap`. It looked right, and it even
read the device property back after setting it. But the read-back ran *before*
`engine.prepare()`, and starting the engine rebuilt the IO graph around a **default-device
aggregate**, visible as `CADefaultDeviceAggregate-<pid>` in `pmset -g assertions`. The
configured device was dropped on the floor and the unit rendered from the default input
instead, which is to say whatever microphone happens to be selected.

Every symptom pointed the wrong way. Audio flowed, buffers arrived at the normal rate,
nothing threw, and the log still named the loopback device. The visualizer was reacting to
the room rather than to the music.

AUHAL with the output element disabled has no reason to build that aggregate, so the device
set here is the device that renders. Verification now happens *after* the unit is running,
and asks CoreAudio which device is actually live rather than trusting the unit.

### The device is re-resolved by name, then verified

Capture refuses to start on a device ID it cannot look up again, rather than falling back on
one resolved earlier. CoreAudio reuses those numbers, so an ID whose device has gone can
already name a different one, and a microphone will happily outlive a virtual device across
a re-enumeration.

After the unit is pointed at the device, the setting is read back and compared, because
`AudioUnitSetProperty` can report success while the unit keeps the system default input.
Neither failure announces itself, which is why the `capture started` line carries the
resolved device ID.

### The device ID is re-checked while capture runs

A virtual device can be replaced underneath a live tap. Loopback tears its devices down and
rebuilds them, and a rebuilt device keeps its name while getting a **new CoreAudio ID**. The
tap stays bound to the retired ID and keeps delivering buffers at a perfectly steady rate,
silent, forever.

Watching the buffer counter cannot catch this, because there is nothing wrong with the
count. Only the ID gives it away, so the watchdog re-resolves the name every 2 s and
restarts capture when the ID has moved.

This was observed directly: the daemon sat on id 142 delivering silence long after Loopback
had rebuilt the device as id 141. It is also how the visualizer once ended up watching a
microphone, since CoreAudio reuses retired IDs and a mic will take the number.

### The capture watchdog

A tap can stop delivering without ever failing. Attaching or removing a display makes
CoreAudio re-enumerate the audio stack underneath a running unit: the callback was already
installed, capture already started, nothing throws, nothing logs, and no buffer arrives
again. Capture then sits there *running* for as long as a client stays connected, because
the only thing that stops it is the client count reaching zero. A widget left open on the
desktop is a permanent client, so the daemon could stay silently dead until restarted by
hand.

A watchdog checks every 2 s and restarts capture when it goes quiet, re-resolving the device
by name as it does, since device IDs are not stable across a re-enumeration but the
configured name is.

It keys on callbacks, never on signal level, so a quiet passage cannot trip it. What counts
as a stall is specifically *it was delivering, and then it stopped*. That distinction is
load-bearing: a virtual device with nothing playing into it does **not** reliably deliver
zero-filled buffers the way a microphone does. Measured on an idle Loopback device, one
22-second run produced 2031 buffers and the next produced none. So "no buffers" cannot mean
"broken" on its own, or every silent stretch would restart capture on a loop for as long as
nothing was playing.

A session that has never delivered anything is therefore given one speculative restart and
then left alone. That covers a tap that was born dead, which does happen, and is worth
having: in testing, an idle device that started dead came back on that retry.

**That "once" is counted across sessions, not within one.** A restart is itself a new capture
session, so handing the retry back on every session boundary bounds nothing at all, and the
daemon quietly restarts capture forever against any device that happens to be idle. It is
earned back only when buffers actually arrive, or when the last client disconnects and
capture stops for real. The first version of this got it wrong and ran once a minute all
night, which matters for more than tidiness: every restart is a chance to reattach to the
wrong device, and that is exactly how the visualizer ended up watching a microphone.

The grace period doubles on each restart that does not take, up to a minute, so a device that
is genuinely gone costs one log line a minute rather than one every few seconds.

`--simulate-stall <sec>` pulls the tap while leaving the unit up and `isRunning`, reproducing
the failure exactly so the whole path can be exercised on demand.

## Analysis

### Callback sizes are not ours to choose

The HAL delivers whatever slice the device uses, and the old AVAudioEngine tap coalesced to
~100 ms. Emitting a single frame per callback would tie the output rate to the buffer size
and, on a large buffer, analyze one 42 ms window out of every 100 ms and drop the rest, so
transients falling in the gap would simply never appear.

Instead the analyzer steps the whole buffer at hop resolution and returns every frame, which
makes the frame rate independent of the callback size. The widget queues those and plays them
back on a jitter buffer, interpolating between frames. The cost is roughly 100 ms of latency,
which is constant and not noticeable in practice.

Setting `kAudioDevicePropertyBufferFrameSize` does not change the delivery size, and it
disrupts playback on a device other apps are using, so the daemon deliberately never touches
it.

### Normalization is measured, not guessed

Against real playback, per-band peaks span about -57..-17 dB, which is why the default window
is -72..-12. Broadband RMS sits ~40 dB higher and gets its own window (-60..-6), otherwise it
pins at ~0.9 on anything loud.

The daemon emits a faithful dB mapping and leaves the display curve to the widget, which
converts it back to amplitude (see `dbSpan`), so the data stays honest and the look stays
tunable.

## Display

### A paused source is not a silent stream

Pausing the music does not stop the frames. A virtual audio device keeps its clock running and
hands the daemon buffers of zeroes, which the daemon reports faithfully: measured against a
paused Music.app, the widget still receives ~94 frames/sec with every band and every `r` (RMS)
value at exactly 0. So "data is arriving" only means the pipeline is alive.

Anything that wants to know whether audio is *playing* therefore has to look inside the
frames, which `frameSignal` does off the daemon's `r` array. Two things depend on it: the fade
below, and the battery guard, which keys off the last frame that carried signal rather than the
last frame received.

### Fading

When the music pauses or stops the whole panel fades out (`fadeWhenSilent`), and fades back in
when audio returns. The trigger is the display coming to rest rather than the audio stopping,
because the bars are still falling for up to a second after a pause and fading over that reads
as a glitch. So the full sequence is: bars fall, `fadeAfterMs` (800) of stillness, then a
`fadeOutMs` (900) fade. Coming back is deliberately much quicker, `fadeInMs` (180), or the
first beat of a track is spent still fading up.

`visibility` flips to `hidden` only after the fade-out finishes, so the panel stops being
composited and blurred once it is gone rather than sitting there invisible at `opacity: 0`. An
unreachable daemon is deliberately exempt: that is an error state, not a quiet one, so the
panel stays up with its `no audio daemon` message legible.

### Battery

The daemon only opens the audio device while a WebSocket client is attached, and the widget
drops from `requestAnimationFrame` to a 250 ms tick once audio has been silent for
`idleAfterMs`. A hidden or unloaded widget costs nothing. Bursts of silence do not wake the
60 fps loop either; if they did it would wake and sleep again ten times a second for a paused
source.
