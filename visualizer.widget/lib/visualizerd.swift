// visualizerd — audio spectrum daemon for the Übersicht visualizer widget.
//
// Author:  Dion Munk <dion@dionmunk.com>
// Source:  https://github.com/dionmunk/uebersicht-visualizer
// License: Creative Commons Attribution-NonCommercial 4.0 International
//          (CC BY-NC 4.0). See LICENSE at the repository root.
//
// Taps a CoreAudio *input* device (normally a Loopback/BlackHole virtual device
// fed by Music.app), runs an FFT over the samples, and broadcasts normalized
// band levels as JSON over a loopback-only WebSocket. The widget just draws.
//
// This exists because Übersicht's WebKit view cannot call getUserMedia: the app
// bundle carries no NSMicrophoneUsageDescription and does not implement the
// WKUIDelegate capture-permission callback. A separate binary gets its own TCC
// grant and sidesteps both problems.
//
//   visualizerd --list                 # show input-capable devices
//   visualizerd --device "Loopback Audio" --port 41417 --bands 32
//
// The audio engine only runs while at least one WebSocket client is connected,
// so a hidden or unloaded widget costs nothing.

import Foundation
import AVFoundation
import Accelerate
import Network
import CoreAudio
import AudioToolbox

// MARK: - Configuration

struct Config {
    var deviceName = "Music"
    // 41416 is Übersicht's HTTP server and 41417 is its widget-push socket, so
    // this deliberately sits clear of that pair.
    var port: UInt16 = 41500
    // 75 is the classic Winamp analyzer's band count; its "thick" mode groups these
    // in fours to get 19 bars. The widget can resample to any count, but running the
    // real number here means thin mode shows genuine resolution rather than
    // interpolated filler.
    var bandCount = 75
    var fftSize = 2048
    var minHz: Float = 32
    var maxHz: Float = 16_000
    // Normalization window. Anything at or below floorDb reads as silence, at or
    // above ceilDb reads as full scale. Measured against real playback, per-band
    // peaks span roughly -57..-17 dB, so this window keeps peaks near full scale
    // without pinning the whole display to the ceiling.
    var floorDb: Float = -72
    var ceilDb: Float = -12
    // Broadband RMS lives ~50 dB above individual bin peaks, so reusing the band
    // window pins it at ~0.9 on anything loud and makes it useless as a signal.
    var rmsFloorDb: Float = -60
    var rmsCeilDb: Float = -6
    // Music carries far less energy up top, so without a tilt the right-hand side
    // of the display barely moves. Applied in dB, ramped 0 -> tiltDb across bands.
    // 16 dB was picked against real playback at 75 bands: at 9 dB everything above
    // the bass sat in the bottom row and only the left third of the display moved.
    var tiltDb: Float = 16
    // NOTE: there is deliberately no buffer-size knob here. Setting
    // kAudioDevicePropertyBufferFrameSize would mutate a device other apps are
    // playing through, which interrupted playback, and it buys nothing: the frame
    // rate is set by the analyzer's hop, not by the callback size. AUHAL hands us
    // whatever the device's slice is (commonly 512-1024 frames) and the analyzer
    // emits every hop inside each buffer rather than one frame per callback, so
    // the output rate is identical either way.
    // Smoothing defaults to off (1.0 = pass the measured value straight through).
    // Bar ballistics belong to the renderer, not here: the widget models the classic
    // analyzer's instant attack + linear falloff, and a second exponential decay at
    // this layer would blunt exactly the snap that look depends on. Lower these only
    // if you want a softer display fed to every client.
    var attack: Float = 1.0    // per-frame rise coefficient (1 = instant)
    var decay: Float = 1.0     // per-frame fall coefficient (1 = no tail)
    var listOnly = false
    var selfTest = false
    var verbose = false
    /// Seconds after capture starts to yank the tap, leaving the engine up. Exercises
    /// the watchdog against the real failure rather than a simulated one. 0 disables.
    var simulateStallAfter: Double = 0
}

/// Log-spaced band edges in Hz. Shared by the analyzer and by --selftest so the
/// test reports the same bands the daemon actually broadcasts.
func bandEdgesHz(_ cfg: Config, sampleRate: Float) -> [(lo: Float, hi: Float)] {
    // Written out longhand with explicit types: as a single tuple-returning map
    // closure this defeats Swift's type checker.
    let binHz: Float = sampleRate / Float(cfg.fftSize)
    let top: Float = min(cfg.maxHz, sampleRate / 2 - binHz)
    let ratio: Float = top / cfg.minHz
    let n: Float = Float(cfg.bandCount)

    var edges: [(lo: Float, hi: Float)] = []
    edges.reserveCapacity(cfg.bandCount)
    for b in 0..<cfg.bandCount {
        let t0: Float = Float(b) / n
        let t1: Float = Float(b + 1) / n
        let f0: Float = cfg.minHz * pow(ratio, t0)
        let f1: Float = cfg.minHz * pow(ratio, t1)
        edges.append((lo: f0, hi: f1))
    }
    return edges
}

func parseArgs() -> Config {
    var c = Config()
    var it = CommandLine.arguments.dropFirst().makeIterator()
    while let a = it.next() {
        switch a {
        case "--list", "-l":
            c.listOnly = true
        case "--selftest":
            c.selfTest = true
        case "--verbose", "-v":
            c.verbose = true
        case "--simulate-stall":
            if let v = it.next(), let n = Double(v) { c.simulateStallAfter = n }
        case "--device", "-d":
            if let v = it.next() { c.deviceName = v }
        case "--port", "-p":
            if let v = it.next(), let n = UInt16(v) { c.port = n }
        case "--bands", "-b":
            if let v = it.next(), let n = Int(v) { c.bandCount = max(4, min(128, n)) }
        case "--fft":
            // must stay a power of two for vDSP_fft_zrip
            if let v = it.next(), let n = Int(v), n > 0, (n & (n - 1)) == 0 { c.fftSize = n }
        case "--floor":
            if let v = it.next(), let n = Float(v) { c.floorDb = n }
        case "--ceil":
            if let v = it.next(), let n = Float(v) { c.ceilDb = n }
        case "--tilt":
            if let v = it.next(), let n = Float(v) { c.tiltDb = n }
        case "--attack":
            if let v = it.next(), let n = Float(v) { c.attack = max(0.01, min(1, n)) }
        case "--decay":
            if let v = it.next(), let n = Float(v) { c.decay = max(0.01, min(1, n)) }
        case "--help", "-h":
            print("""
            visualizerd — audio spectrum daemon

              --list, -l              list input-capable audio devices and exit
              --simulate-stall <sec>  pull the tap that long after capture starts,
                                      to exercise the watchdog
              --selftest              push a synthetic tone through the analyzer
                                      and print the result (no device, no TCC)
              --device, -d <name>     input device to tap (default: Music)
              --port, -p <n>          WebSocket port (default: 41500)
              --bands, -b <n>         number of frequency bands (default: 32)
              --fft <n>               FFT window, power of two (default: 2048)
              --floor <dB>            level mapped to 0 (default: -72)
              --ceil <dB>             level mapped to 1 (default: -12)
              --tilt <dB>             high-frequency lift across bands (default: 9)
              --attack <0..1>         rise smoothing (default: 0.65)
              --decay <0..1>          fall smoothing (default: 0.14)
            """)
            exit(0)
        default:
            break
        }
    }
    return c
}

// MARK: - CoreAudio device enumeration

struct Device {
    let id: AudioDeviceID
    let name: String
    let channels: Int
}

private func deviceString(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var addr = AudioObjectPropertyAddress(mSelector: selector,
                                          mScope: kAudioObjectPropertyScopeGlobal,
                                          mElement: kAudioObjectPropertyElementMain)
    var size = UInt32(MemoryLayout<CFString?>.size)
    var value: CFString? = nil
    let status = withUnsafeMutablePointer(to: &value) {
        AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
    }
    guard status == noErr, let s = value else { return nil }
    return s as String
}

private func inputChannelCount(_ id: AudioDeviceID) -> Int {
    var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                          mScope: kAudioDevicePropertyScopeInput,
                                          mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
    let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size),
                                               alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
    let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
    return list.reduce(0) { $0 + Int($1.mNumberChannels) }
}

func inputDevices() -> [Device] {
    var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                          mScope: kAudioObjectPropertyScopeGlobal,
                                          mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    let system = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids.compactMap { id in
        let ch = inputChannelCount(id)
        guard ch > 0, let name = deviceString(id, kAudioObjectPropertyName) else { return nil }
        return Device(id: id, name: name, channels: ch)
    }
}

/// Exact (case-insensitive) match wins; otherwise fall back to a substring match
/// so "Loopback" finds "Loopback Audio".
func findDevice(named wanted: String) -> Device? {
    let devices = inputDevices()
    let needle = wanted.lowercased()
    if let exact = devices.first(where: { $0.name.lowercased() == needle }) { return exact }
    return devices.first(where: { $0.name.lowercased().contains(needle) })
}

// MARK: - Spectrum analyzer

struct SpectrumFrame {
    let bands: [Float]
    let rms: Float
}

final class Analyzer {
    private let cfg: Config
    private let fftSize: Int
    private let half: Int
    private let hop: Int
    private let log2n: vDSP_Length
    private let setup: FFTSetup

    private let ring: UnsafeMutablePointer<Float>
    private let work: UnsafeMutablePointer<Float>
    private let windowed: UnsafeMutablePointer<Float>
    private let realp: UnsafeMutablePointer<Float>
    private let imagp: UnsafeMutablePointer<Float>
    private var window: [Float]
    // Deliberately a raw pointer, not [Float]: the per-band peak below needs a
    // pointer *into* the buffer, and `&array[i]` yields a pointer to a temporary
    // holding a single element, so vDSP would read past it.
    private let mags: UnsafeMutablePointer<Float>

    private var ringPos = 0
    private var filled = 0
    private var sinceEmit = 0

    private var bandBins: [(lo: Int, hi: Int)] = []
    private var levels: [Float]
    private var lastSampleRate: Float = 0

    /// Broadband level (0..1), useful for a pulse/glow that tracks overall loudness.
    private(set) var rms: Float = 0
    /// Pre-normalization per-band dB, kept so --verbose can report what the real
    /// signal looks like instead of what the clamped output looks like.
    private(set) var rawDb: [Float]
    /// Hop-boundary analyses performed, for rate diagnostics.
    private(set) var analyses: Int = 0

    init(config: Config) {
        cfg = config
        fftSize = config.fftSize
        half = config.fftSize / 2
        hop = max(256, config.fftSize / 4)   // ~86 fps at 48k with a 2048 window
        log2n = vDSP_Length(log2(Double(config.fftSize)))
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        ring = .allocate(capacity: fftSize)
        work = .allocate(capacity: fftSize)
        windowed = .allocate(capacity: fftSize)
        realp = .allocate(capacity: half)
        imagp = .allocate(capacity: half)
        ring.initialize(repeating: 0, count: fftSize)
        work.initialize(repeating: 0, count: fftSize)
        windowed.initialize(repeating: 0, count: fftSize)
        realp.initialize(repeating: 0, count: half)
        imagp.initialize(repeating: 0, count: half)

        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_DENORM))
        mags = .allocate(capacity: half)
        mags.initialize(repeating: 0, count: half)
        levels = [Float](repeating: 0, count: config.bandCount)
        rawDb = [Float](repeating: -120, count: config.bandCount)
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        ring.deallocate(); work.deallocate(); windowed.deallocate()
        realp.deallocate(); imagp.deallocate(); mags.deallocate()
    }

    /// Log-spaced band edges. Recomputed whenever the device's sample rate changes.
    private func rebuildBands(sampleRate: Float) {
        let binHz = sampleRate / Float(fftSize)
        bandBins = bandEdgesHz(cfg, sampleRate: sampleRate).map { edge in
            var lo = Int(edge.lo / binHz)
            var hi = Int(edge.hi / binHz)
            lo = max(1, min(lo, half - 1))
            hi = max(lo + 1, min(hi, half))
            return (lo, hi)
        }
    }

    /// Nominal spacing between emitted frames, in milliseconds.
    var frameIntervalMs: Float {
        lastSampleRate > 0 ? Float(hop) / lastSampleRate * 1000 : 0
    }

    /// Feed mono samples. Returns every frame produced by this buffer.
    ///
    /// Callback sizes are not ours to choose: the HAL delivers whatever slice the
    /// device uses, and the old AVAudioEngine tap coalesced to ~100 ms. Emitting a
    /// single frame per callback would therefore tie the output rate to the buffer
    /// size and, on a large buffer, analyze one 42 ms window out of every 100 ms and
    /// drop the rest — transients in the gap would simply never appear. Instead we
    /// step the whole buffer at hop resolution and return the lot, which makes the
    /// frame rate independent of the callback size; the client plays them back on a
    /// jitter buffer.
    func feed(_ samples: UnsafePointer<Float>, count: Int, sampleRate: Float) -> [SpectrumFrame] {
        if sampleRate != lastSampleRate, sampleRate > 0 {
            lastSampleRate = sampleRate
            rebuildBands(sampleRate: sampleRate)
        }
        guard !bandBins.isEmpty else { return [] }

        var out: [SpectrumFrame] = []
        var i = 0
        while i < count {
            // Bound each copy by both the ring wrap and the next hop boundary, so
            // analysis lands exactly on hop multiples.
            let toWrap = fftSize - ringPos
            let toHop = max(1, hop - sinceEmit)
            let chunk = min(count - i, toWrap, toHop)

            (ring + ringPos).update(from: samples + i, count: chunk)
            ringPos = (ringPos + chunk) % fftSize
            filled = min(filled + chunk, fftSize)
            sinceEmit += chunk
            i += chunk

            if filled >= fftSize && sinceEmit >= hop {
                sinceEmit = 0
                out.append(analyze())
            }
        }
        return out
    }

    private func analyze() -> SpectrumFrame {
        analyses += 1
        // Linearize the ring: oldest sample sits at ringPos.
        let tail = fftSize - ringPos
        work.update(from: ring + ringPos, count: tail)
        (work + tail).update(from: ring, count: ringPos)

        var sumSq: Float = 0
        vDSP_measqv(work, 1, &sumSq, vDSP_Length(fftSize))
        let frameRms = sqrt(sumSq)
        let rmsDb = 20 * log10(frameRms + 1e-9)
        rms = clamp01((rmsDb - cfg.rmsFloorDb) / (cfg.rmsCeilDb - cfg.rmsFloorDb))

        vDSP_vmul(work, 1, window, 1, windowed, 1, vDSP_Length(fftSize))

        var split = DSPSplitComplex(realp: realp, imagp: imagp)
        windowed.withMemoryRebound(to: DSPComplex.self, capacity: half) { ptr in
            vDSP_ctoz(ptr, 2, &split, 1, vDSP_Length(half))
        }
        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
        vDSP_zvabs(&split, 1, mags, 1, vDSP_Length(half))

        // vDSP_fft_zrip returns values scaled by 2; the Hann window costs another
        // factor of 2 in coherent gain. Fold both in so dB numbers are meaningful.
        var scale = Float(2.0) / Float(fftSize)
        vDSP_vsmul(mags, 1, &scale, mags, 1, vDSP_Length(half))

        for (b, bin) in bandBins.enumerated() {
            // Peak within the band tracks transients better than a mean, which
            // washes out as the upper bands get wider.
            var peak: Float = 0
            vDSP_maxv(mags + bin.lo, 1, &peak, vDSP_Length(bin.hi - bin.lo))
            let db = 20 * log10(peak + 1e-9)
            rawDb[b] = db
            // Tilt in dB rather than scaling the normalized value: a multiplier
            // on an already-clamped 0..1 just crushes everything into the ceiling.
            let tilt = cfg.tiltDb * (Float(b) / Float(max(1, cfg.bandCount - 1)))
            let target = clamp01((db + tilt - cfg.floorDb) / (cfg.ceilDb - cfg.floorDb))

            let coeff = target > levels[b] ? cfg.attack : cfg.decay
            levels[b] += (target - levels[b]) * coeff
        }
        return SpectrumFrame(bands: levels, rms: rms)
    }

    private func clamp01(_ v: Float) -> Float { min(max(v, 0), 1) }
}

// MARK: - WebSocket server (loopback only)

final class WSServer {
    private let queue = DispatchQueue(label: "visualizerd.ws")
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: Client] = [:]

    /// Called on the server queue whenever the client count changes.
    var onClientCountChanged: ((Int) -> Void)?
    /// Sent to each client immediately on connect.
    var greeting: (() -> Data?)?
    /// Called once the listener is actually bound, not merely created.
    var onReady: (() -> Void)?

    private final class Client {
        let conn: NWConnection
        var inFlight = 0
        init(_ conn: NWConnection) { self.conn = conn }
    }

    func start(port: UInt16) throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        // Bind to loopback explicitly: this stream is desktop audio, it has no
        // business being reachable from the network.
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback),
                                                 port: NWEndpoint.Port(rawValue: port)!)
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)

        let l = try NWListener(using: params)
        l.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        l.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onReady?()
            case .failed(let e):
                FileHandle.standardError.write("visualizerd: listener failed: \(e)\n".data(using: .utf8)!)
                exit(1)
            default:
                break
            }
        }
        l.start(queue: queue)
        listener = l
    }

    private func accept(_ conn: NWConnection) {
        let client = Client(conn)
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.queue.async {
                    self.clients[ObjectIdentifier(client)] = client
                    self.onClientCountChanged?(self.clients.count)
                    if let hello = self.greeting?() { self.send(hello, to: client) }
                }
                self.receive(client)
            case .failed, .cancelled:
                self.remove(client)
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    private func receive(_ client: Client) {
        client.conn.receiveMessage { [weak self] _, context, _, error in
            guard let self else { return }
            if error != nil {
                self.remove(client)
                return
            }
            if let meta = context?.protocolMetadata.first as? NWProtocolWebSocket.Metadata,
               meta.opcode == .close {
                client.conn.cancel()
                self.remove(client)
                return
            }
            self.receive(client)   // we never act on inbound frames, just stay open
        }
    }

    private func remove(_ client: Client) {
        queue.async {
            if self.clients.removeValue(forKey: ObjectIdentifier(client)) != nil {
                self.onClientCountChanged?(self.clients.count)
            }
        }
    }

    private func send(_ data: Data, to client: Client) {
        // Drop frames for a client that is not keeping up rather than queueing
        // audio-rate messages without bound.
        guard client.inFlight < 3 else { return }
        client.inFlight += 1
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let ctx = NWConnection.ContentContext(identifier: "frame", metadata: [meta])
        client.conn.send(content: data, contentContext: ctx, isComplete: true,
                         completion: .contentProcessed { [weak self] _ in
            self?.queue.async { client.inFlight -= 1 }
        })
    }

    func broadcast(_ data: Data) {
        queue.async {
            for client in self.clients.values { self.send(data, to: client) }
        }
    }

    var clientCount: Int {
        queue.sync { clients.count }
    }
}

// MARK: - Capture

/// True if CoreAudio reports the device as running for *anyone*. This is the ground truth
/// the old device check was missing: the audio unit's own property read-back will happily
/// report the device that was asked for even when the render graph ended up elsewhere.
func deviceIsRunningSomewhere(_ id: AudioDeviceID) -> Bool {
    var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                          mScope: kAudioObjectPropertyScopeGlobal,
                                          mElement: kAudioObjectPropertyElementMain)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return false }
    return value != 0
}

/// Device-pinned input capture, built on AUHAL.
///
/// This was an `AVAudioEngine` + `installTap`, which looked right and even read the device
/// property back after setting it — but the read-back ran *before* `engine.prepare()`, and
/// starting the engine rebuilt the IO graph around a **default-device aggregate** (visible
/// as `CADefaultDeviceAggregate-<pid>` in `pmset -g assertions`). The configured device was
/// dropped on the floor and the unit rendered from the default input instead, i.e. whatever
/// microphone happens to be selected. Every symptom pointed the wrong way: audio flowed,
/// buffers arrived at the normal rate, nothing threw, and the log still named the loopback
/// device. The visualizer was reacting to the room rather than to the music.
///
/// AUHAL with the output element disabled has no reason to build that aggregate, so the
/// device set here is the device that renders. Verification now happens *after* the unit is
/// running, and asks CoreAudio which device is actually live rather than trusting the unit.
final class Capture {
    private var unit: AudioUnit?
    private var abl: UnsafeMutableAudioBufferListPointer?
    private var ablFrameCapacity = 0
    private var monoBuf: UnsafeMutablePointer<Float>
    private var monoCap: Int
    private var sampleRate: Double = 48000
    private var onSamples: ((UnsafePointer<Float>, Int, Float) -> Void)?
    /// Set by --simulate-stall: the render callback keeps firing but stops counting, which
    /// is precisely the failure the watchdog exists to catch.
    private var stalled = false
    private(set) var isRunning = false

    init() {
        monoCap = 16384
        monoBuf = .allocate(capacity: monoCap)
        monoBuf.initialize(repeating: 0, count: monoCap)
    }

    deinit {
        monoBuf.deallocate()
        releaseUnit()
    }

    /// Frames delivered by the tap so far, and the size of the last buffer.
    private(set) var tapCallbacks = 0
    /// Bumped on every successful start, so the watchdog can tell one capture session
    /// from the next without any reset plumbing between the two.
    private(set) var sessions = 0
    private(set) var lastFrameLength = 0
    var verbose = false

    func start(device: Device,
               onSamples: @escaping (UnsafePointer<Float>, Int, Float) -> Void) throws {
        guard !isRunning else { return }

        var desc = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                             componentSubType: kAudioUnitSubType_HALOutput,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
        guard let component = AudioComponentFindNext(nil, &desc) else {
            throw err(2, "no HAL output audio component")
        }
        var newUnit: AudioUnit?
        try check(AudioComponentInstanceNew(component, &newUnit), "instantiate HAL unit")
        guard let unit = newUnit else { throw err(2, "HAL unit came back nil") }
        self.unit = unit

        // Input on element 1, output off on element 0. Disabling output is what keeps
        // CoreAudio from pairing this with the default output device in an aggregate.
        var on: UInt32 = 1
        var off: UInt32 = 0
        try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO,
                                       kAudioUnitScope_Input, 1, &on, UInt32(MemoryLayout<UInt32>.size)),
                  "enable input element")
        try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO,
                                       kAudioUnitScope_Output, 0, &off, UInt32(MemoryLayout<UInt32>.size)),
                  "disable output element")

        var deviceID = device.id
        try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
                                       kAudioUnitScope_Global, 0, &deviceID,
                                       UInt32(MemoryLayout<AudioDeviceID>.size)),
                  "select device '\(device.name)'")

        // The hardware side of element 1 tells us the real rate and channel count.
        var hw = AudioStreamBasicDescription()
        var hwSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat,
                                       kAudioUnitScope_Input, 1, &hw, &hwSize),
                  "read hardware input format")
        guard hw.mSampleRate > 0, hw.mChannelsPerFrame > 0 else {
            releaseUnit()
            throw err(3, "device '\(device.name)' reported an empty input format")
        }
        sampleRate = hw.mSampleRate
        let channels = min(2, Int(hw.mChannelsPerFrame))

        // Ask for deinterleaved float so the downmix below is a plain vDSP add.
        var client = AudioStreamBasicDescription(
            mSampleRate: hw.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
                        | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
            mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 32, mReserved: 0)
        try check(AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat,
                                       kAudioUnitScope_Output, 1, &client,
                                       UInt32(MemoryLayout<AudioStreamBasicDescription>.size)),
                  "set client input format")

        var maxFrames: UInt32 = 4096
        var maxSize = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioUnitGetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice,
                                 kAudioUnitScope_Global, 0, &maxFrames, &maxSize)
        allocateBuffers(frames: max(4096, Int(maxFrames)), channels: channels)

        self.onSamples = onSamples
        self.stalled = false

        var callback = AURenderCallbackStruct(
            inputProc: { refCon, flags, timeStamp, bus, frames, _ in
                let capture = Unmanaged<Capture>.fromOpaque(refCon).takeUnretainedValue()
                return capture.render(flags: flags, timeStamp: timeStamp, bus: bus, frames: frames)
            },
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback,
                                       kAudioUnitScope_Global, 0, &callback,
                                       UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                  "install input callback")

        try check(AudioUnitInitialize(unit), "initialize HAL unit")
        try check(AudioOutputUnitStart(unit), "start HAL unit")

        // Only now is the question meaningful. Give the HAL a beat to bring the device up,
        // then confirm against CoreAudio instead of the unit's own property.
        var live = false
        for _ in 0..<30 {
            if deviceIsRunningSomewhere(device.id) { live = true; break }
            usleep(20_000)
        }
        if !live {
            let others = inputDevices()
                .filter { $0.id != device.id && deviceIsRunningSomewhere($0.id) }
                .map { $0.name }
            let blame = others.isEmpty ? "no input device is running"
                                       : "running instead: \(others.joined(separator: ", "))"
            releaseUnit()
            throw err(4, "asked for '\(device.name)' but it never started — \(blame)")
        }

        isRunning = true
        sessions += 1
    }

    func stop() {
        guard isRunning else { return }
        releaseUnit()
        isRunning = false
    }

    /// Reproduce the failure the watchdog exists for: keep the unit up and `isRunning`
    /// true, but stop counting callbacks, so buffers quietly stop reaching the analyzer
    /// with nothing thrown and nothing logged. Test hook, via --simulate-stall.
    func simulateStall() {
        guard isRunning else { return }
        stalled = true
    }

    // MARK: Render

    fileprivate func render(flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                            timeStamp: UnsafePointer<AudioTimeStamp>,
                            bus: UInt32,
                            frames: UInt32) -> OSStatus {
        guard let unit, let abl, Int(frames) <= ablFrameCapacity else { return noErr }
        let count = Int(frames)
        let bytes = UInt32(count * MemoryLayout<Float>.size)
        for i in 0..<abl.count { abl[i].mDataByteSize = bytes }

        let status = AudioUnitRender(unit, flags, timeStamp, bus, frames, abl.unsafeMutablePointer)
        guard status == noErr else { return status }
        guard !stalled, count > 0 else { return noErr }

        if count > monoCap { grow(to: count) }
        guard let first = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

        if abl.count == 1 {
            monoBuf.update(from: first, count: count)
        } else if let second = abl[1].mData?.assumingMemoryBound(to: Float.self) {
            vDSP_vadd(first, 1, second, 1, monoBuf, 1, vDSP_Length(count))
            var half: Float = 0.5
            vDSP_vsmul(monoBuf, 1, &half, monoBuf, 1, vDSP_Length(count))
        } else {
            monoBuf.update(from: first, count: count)
        }

        if verbose && tapCallbacks == 0 {
            FileHandle.standardError.write("""
            visualizerd: first tap buffer — \(count) frames, \
            \(Int(sampleRate)) Hz, \(abl.count) ch \
            (implies ~\(String(format: "%.1f", sampleRate / Double(count))) callbacks/sec)

            """.data(using: .utf8)!)
        }
        tapCallbacks += 1
        lastFrameLength = count
        onSamples?(monoBuf, count, Float(sampleRate))
        return noErr
    }

    // MARK: Plumbing

    private func allocateBuffers(frames: Int, channels: Int) {
        freeBuffers()
        let list = AudioBufferList.allocate(maximumBuffers: channels)
        for i in 0..<channels {
            let bytes = frames * MemoryLayout<Float>.size
            list[i] = AudioBuffer(mNumberChannels: 1,
                                  mDataByteSize: UInt32(bytes),
                                  mData: malloc(bytes))
        }
        abl = list
        ablFrameCapacity = frames
    }

    private func freeBuffers() {
        guard let abl else { return }
        for i in 0..<abl.count { free(abl[i].mData) }
        free(abl.unsafeMutablePointer)
        self.abl = nil
        ablFrameCapacity = 0
    }

    private func releaseUnit() {
        if let unit {
            AudioOutputUnitStop(unit)
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
        }
        unit = nil
        onSamples = nil
        freeBuffers()
    }

    private func err(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "visualizerd", code: code,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func check(_ status: OSStatus, _ what: String) throws {
        guard status != noErr else { return }
        releaseUnit()
        throw err(Int(status), "could not \(what) (OSStatus \(status))")
    }

    private func grow(to frames: Int) {
        monoBuf.deallocate()
        monoCap = frames * 2
        monoBuf = .allocate(capacity: monoCap)
        monoBuf.initialize(repeating: 0, count: monoCap)
    }
}

// MARK: - Main

let config = parseArgs()

if config.listOnly {
    let devices = inputDevices()
    if devices.isEmpty {
        print("No input-capable audio devices found.")
    } else {
        print("Input-capable audio devices:")
        for d in devices {
            print(String(format: "  %-32s %d ch", (d.name as NSString).utf8String!, d.channels))
        }
    }
    exit(0)
}

if config.selfTest {
    // Drives the exact analyzer the daemon uses with a known signal, so a silent
    // display can be attributed to routing rather than to the DSP.
    let sampleRate: Float = 48_000
    let toneHz: Float = 1_000
    let amplitude: Float = 0.1          // -20 dBFS
    let chunk = 1024

    let analyzer = Analyzer(config: config)
    let buf = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
    defer { buf.deallocate() }

    var phase: Float = 0
    var levels: [Float] = []
    let step = 2 * Float.pi * toneHz / sampleRate
    for _ in 0..<(Int(sampleRate) / chunk) {   // ~1 second, enough for smoothing to settle
        for i in 0..<chunk {
            buf[i] = amplitude * sin(phase)
            phase += step
            if phase > 2 * .pi { phase -= 2 * .pi }
        }
        if let last = analyzer.feed(buf, count: chunk, sampleRate: sampleRate).last {
            levels = last.bands
        }
    }

    guard !levels.isEmpty else {
        print("selftest FAILED: analyzer produced no output")
        exit(1)
    }

    let edges = bandEdgesHz(config, sampleRate: sampleRate)
    let ramp = Array(" .:-=+*#%@")
    print("selftest: \(Int(toneHz)) Hz sine at -20 dBFS, \(config.bandCount) bands\n")
    for (i, v) in levels.enumerated() {
        let filled = Int(v * 40)
        let bar = String(repeating: "#", count: filled)
        print(String(format: "  %2d  %6.0f-%-6.0f Hz  %.3f  %@",
                     i, edges[i].lo, edges[i].hi, v, bar))
    }
    let peak = levels.enumerated().max(by: { $0.element < $1.element })!
    let inBand = toneHz >= edges[peak.offset].lo && toneHz <= edges[peak.offset].hi
    print("\n  compact: " + levels.map { String(ramp[Int(min(0.999, $0) * 10)]) }.joined())
    print("  rms: \(String(format: "%.3f", analyzer.rms))")
    print("  peak band: \(peak.offset) "
          + "(\(Int(edges[peak.offset].lo))-\(Int(edges[peak.offset].hi)) Hz) "
          + "level \(String(format: "%.3f", peak.element))")
    print(inBand
          ? "\n  PASS: the tone landed in the band that contains \(Int(toneHz)) Hz"
          : "\n  FAIL: peak band does not contain \(Int(toneHz)) Hz")
    exit(inBand ? 0 : 1)
}

// Mutable because the watchdog re-resolves it: a device ID is not stable across an
// audio-stack re-enumeration, but the name the user configured is.
guard var device = findDevice(named: config.deviceName) else {
    let available = inputDevices().map { "  \($0.name)" }.joined(separator: "\n")
    FileHandle.standardError.write("""
    visualizerd: no input device matching '\(config.deviceName)'.

    Available:
    \(available.isEmpty ? "  (none)" : available)

    Route Music.app's output to a virtual device (Loopback / BlackHole) and pass
    its name with --device.

    """.data(using: .utf8)!)
    exit(2)
}

let analyzer = Analyzer(config: config)
let capture = Capture()
let server = WSServer()
var verboseTimer: DispatchSourceTimer?

// Preformatted so the hot path only concatenates a handful of small strings.
server.greeting = {
    let dt = analyzer.frameIntervalMs
    let payload = """
    {"type":"meta","device":\(jsonString(device.name)),\
    "bands":\(config.bandCount),"fft":\(config.fftSize),\
    "minHz":\(Int(config.minHz)),"maxHz":\(Int(config.maxHz)),\
    "dt":\(String(format: "%.2f", dt > 0 ? dt : 10.67))}
    """
    return payload.data(using: .utf8)
}

func jsonString(_ s: String) -> String {
    let escaped = s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

/// A batch of frames plus the nominal spacing between them, so the client can pace
/// playback rather than dumping the whole burst into one repaint. Levels go out as
/// 0-255 integers; the widget cannot resolve more precision than that anyway.
func encode(frames: [SpectrumFrame], dtMs: Float) -> Data {
    var s = "{\"type\":\"f\",\"dt\":\(String(format: "%.2f", dtMs)),\"f\":["
    s.reserveCapacity(frames.count * (frames.first?.bands.count ?? 32) * 4 + 64)
    for (i, frame) in frames.enumerated() {
        if i > 0 { s += "," }
        s += "["
        for (j, v) in frame.bands.enumerated() {
            if j > 0 { s += "," }
            s += String(Int(min(max(v, 0), 1) * 255))
        }
        s += "]"
    }
    s += "],\"r\":["
    for (i, frame) in frames.enumerated() {
        if i > 0 { s += "," }
        s += String(Int(min(max(frame.rms, 0), 1) * 255))
    }
    s += "]}"
    return s.data(using: .utf8) ?? Data()
}

/// Install the tap and begin feeding the analyzer. Shared by the client-count handler
/// and the watchdog below, which is the only reason it is a function.
///
/// The device is looked up again by name every time. CoreAudio hands out fresh device
/// IDs when the audio stack re-enumerates, and attaching a display does exactly that, so
/// the ID resolved at launch can end up naming nothing. The configured name is the part
/// that stays true.
@discardableResult
func startCapture(_ note: String = "") -> Bool {
    // Refuse to fall back on the ID resolved earlier. CoreAudio reuses these numbers, so
    // an ID whose device has gone can already name a different one, and capture would
    // then succeed against the wrong hardware: a microphone, most likely, since those
    // outlive a virtual device across a re-enumeration. Better to report it missing and
    // let the watchdog try again.
    guard let fresh = findDevice(named: config.deviceName) else {
        FileHandle.standardError.write(
            "visualizerd: device '\(config.deviceName)' is not present right now\n".data(using: .utf8)!)
        return false
    }
    device = fresh
    do {
        try capture.start(device: device) { samples, frames, rate in
            let batch = analyzer.feed(samples, count: frames, sampleRate: rate)
            if !batch.isEmpty {
                server.broadcast(encode(frames: batch, dtMs: analyzer.frameIntervalMs))
            }
        }
        FileHandle.standardError.write(
            "visualizerd: capture started (\(device.name), id \(device.id))\(note)\n".data(using: .utf8)!)
        if config.simulateStallAfter > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + config.simulateStallAfter) {
                FileHandle.standardError.write("visualizerd: simulating a stall now\n".data(using: .utf8)!)
                capture.simulateStall()
            }
        }
        return true
    } catch {
        FileHandle.standardError.write("visualizerd: capture failed: \(error.localizedDescription)\n".data(using: .utf8)!)
        return false
    }
}

server.onClientCountChanged = { count in
    // Battery guard: no viewers, no capture. A hidden widget costs nothing.
    if count > 0 && !capture.isRunning {
        startCapture()
    } else if count == 0 && capture.isRunning {
        capture.stop()
        FileHandle.standardError.write("visualizerd: capture stopped (no clients)\n".data(using: .utf8)!)
    }
}

server.onReady = {
    FileHandle.standardError.write("""
    visualizerd: listening on ws://127.0.0.1:\(config.port)
    visualizerd: device '\(device.name)' (\(device.channels) ch), \(config.bandCount) bands
    visualizerd: idle until a client connects

    """.data(using: .utf8)!)
}

do {
    try server.start(port: config.port)
} catch {
    FileHandle.standardError.write("visualizerd: could not listen on port \(config.port): \(error)\n".data(using: .utf8)!)
    exit(1)
}

if config.verbose {
    capture.verbose = true
    var lastAnalyses = 0
    var lastCallbacks = 0
    let timer = DispatchSource.makeTimerSource(queue: .global())
    timer.schedule(deadline: .now() + 2, repeating: 2)
    timer.setEventHandler {
        guard capture.isRunning else { return }
        let a = analyzer.analyses, c = capture.tapCallbacks
        let da = Double(a - lastAnalyses) / 2.0
        let dc = Double(c - lastCallbacks) / 2.0
        lastAnalyses = a; lastCallbacks = c

        let db = analyzer.rawDb
        let lo = db.min() ?? 0, hi = db.max() ?? 0
        let mean = db.reduce(0, +) / Float(max(1, db.count))
        FileHandle.standardError.write(String(
            format: "visualizerd: %.1f tap/s, %.1f fft/s, buf %d | raw dB min %.1f mean %.1f max %.1f\n",
            dc, da, capture.lastFrameLength, lo, mean, hi).data(using: .utf8)!)
    }
    timer.resume()
    // Keep the source alive for the process lifetime.
    verboseTimer = timer
}

// MARK: - Capture watchdog

// A tap can stop delivering without ever failing.
//
// Attaching or removing a display makes CoreAudio re-enumerate the audio stack
// underneath a running engine. installTap has already succeeded, engine.start() has
// already succeeded, nothing throws and nothing logs, and no buffer arrives again. The
// capture then sits there "running" for as long as a client stays connected, because the
// one thing that stops it is the client count reaching zero. A widget left open on the
// desktop is a permanent client, so a dead tap stays dead until the daemon is restarted
// by hand. That is the failure this exists to end.
//
// Keyed on tap callbacks, never on signal level, so a quiet passage cannot trip it.
//
// A stall is specifically "it was delivering, and then it stopped". The distinction
// matters, because a virtual device with nothing playing into it does not reliably
// deliver zero-filled buffers the way a microphone does: measured on Loopback Audio, an
// idle device produced 2031 buffers in one 22-second run and none at all in the next. So
// "no buffers" cannot mean "broken" on its own, or every silent stretch would restart
// capture on a loop for as long as nothing was playing.
//
// Having delivered and then stopped is unambiguous, and it is exactly the observed
// failure: capture runs fine for hours, a display is attached, and the buffers stop.
let watchdogTick = 2.0
let watchdogGraceFloor = 6.0
let watchdogGraceCeiling = 60.0

// Grows on each restart that does not take, so a device that is simply gone costs a log
// line a minute rather than one every few seconds. Reset the moment buffers return.
var watchdogGrace = watchdogGraceFloor
var watchdogLastCallbacks = 0
var watchdogStalledFor = 0.0
// Per capture session: whether buffers were ever seen, and whether the one speculative
// restart allowed to a session that never delivered has been spent.
var watchdogSession = -1
var watchdogSawBuffers = false
var watchdogColdRetried = false
var captureWatchdog: DispatchSourceTimer?

let watchdog = DispatchSource.makeTimerSource(queue: .global())
watchdog.schedule(deadline: .now() + watchdogTick, repeating: watchdogTick)
watchdog.setEventHandler {
    // Nothing to watch while nobody is listening. Idling without clients is the normal
    // resting state, not a stall.
    guard server.clientCount > 0 else {
        watchdogLastCallbacks = capture.tapCallbacks
        watchdogStalledFor = 0
        watchdogGrace = watchdogGraceFloor
        // Capture stops with the last client and starts clean with the next one, so the
        // speculative retry is earned back here and nowhere else.
        watchdogColdRetried = false
        return
    }

    // The device can be swapped out from under a running tap. Loopback tears its virtual
    // devices down and rebuilds them, and a rebuilt device keeps its name but gets a new
    // CoreAudio ID, so the tap stays bound to an ID that no longer exists. Nothing about
    // that looks broken from inside: buffers keep arriving on the retired ID, at a
    // perfectly steady rate, silent forever. Counting buffers cannot catch it, because
    // there is nothing wrong with the count. Only the ID gives it away.
    //
    // Worse, CoreAudio reuses retired IDs, so the tap can end up on whatever takes the
    // number next. A microphone is the likely candidate, and then the visualizer quietly
    // starts watching the room instead of the music.
    if capture.isRunning,
       let current = findDevice(named: config.deviceName),
       current.id != device.id {
        FileHandle.standardError.write("""
        visualizerd: '\(config.deviceName)' moved from id \(device.id) to \(current.id), \
        restarting capture

        """.data(using: .utf8)!)
        capture.stop()
        startCapture(" after the device moved")
        watchdogLastCallbacks = capture.tapCallbacks
        watchdogStalledFor = 0
        return
    }

    // A fresh session starts the stall reckoning over, but deliberately does NOT hand
    // back the speculative retry: a restart is itself a new session, so resetting it here
    // would let every retry earn another one and the "just once" would bound nothing.
    // That is not hypothetical. It ran all night against an idle device, once a minute,
    // and each of those restarts was a chance to reattach to the wrong device.
    if capture.sessions != watchdogSession {
        watchdogSession = capture.sessions
        watchdogSawBuffers = false
        watchdogLastCallbacks = capture.tapCallbacks
        watchdogStalledFor = 0
        return
    }

    if capture.isRunning {
        let callbacks = capture.tapCallbacks
        if callbacks != watchdogLastCallbacks {
            watchdogLastCallbacks = callbacks
            watchdogSawBuffers = true
            watchdogStalledFor = 0
            watchdogGrace = watchdogGraceFloor
            // Buffers are flowing, so whatever this tap needed it has had. Allow one
            // speculative retry again if it ever goes quiet from here.
            watchdogColdRetried = false
            return
        }
    }

    watchdogStalledFor += watchdogTick
    guard watchdogStalledFor >= watchdogGrace else { return }

    // Running, but nothing has ever arrived on this session. That is what a broken tap
    // looks like, and equally what an idle virtual device looks like, and the two cannot
    // be told apart from here. So spend exactly one restart on the possibility and then
    // sit quiet, rather than churning for as long as nothing happens to be playing.
    if capture.isRunning && !watchdogSawBuffers {
        guard !watchdogColdRetried else {
            watchdogStalledFor = 0
            return
        }
        watchdogColdRetried = true
    }

    // Three ways to arrive here, all wanting the same thing: a tap that delivered and
    // stopped, the one speculative retry above, or a previous restart that could not
    // reopen the device and left nothing running. Without that last case a failed restart
    // would never be retried, since the only other thing that starts capture is the
    // client count changing.
    let reason = !capture.isRunning ? "capture not running"
               : watchdogSawBuffers ? "no audio from the tap"
               : "no audio since capture started"
    FileHandle.standardError.write("""
    visualizerd: \(reason) for \(Int(watchdogStalledFor))s with \
    \(server.clientCount) client(s), restarting capture

    """.data(using: .utf8)!)
    watchdogStalledFor = 0
    watchdogGrace = min(watchdogGraceCeiling, watchdogGrace * 2)
    capture.stop()
    startCapture(" after a stall")
    watchdogLastCallbacks = capture.tapCallbacks
}
watchdog.resume()
// Keep the source alive for the process lifetime.
captureWatchdog = watchdog

signal(SIGINT) { _ in exit(0) }
signal(SIGTERM) { _ in exit(0) }

RunLoop.main.run()
