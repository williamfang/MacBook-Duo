import AppKit
import MetalKit
import MacBookDuoCore

final class MetalFoldRenderer: NSObject, MTKViewDelegate {
    struct Uniforms {
        var progress: Float
        var blur: Float
        var darkness: Float
        var tint: Float
        var aspect: Float
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let textureLoader: MTKTextureLoader
    private var texture: MTLTexture?
    private var parameters = FoldParameters.make(angle: 85)

    init?(view: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        commandQueue = queue
        textureLoader = MTKTextureLoader(device: device)
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60

        guard let shaderURL = Bundle.main.url(forResource: "Shaders", withExtension: "metal"),
              let shaderSource = try? String(contentsOf: shaderURL, encoding: .utf8),
              let library = try? device.makeLibrary(source: shaderSource, options: nil),
              let vertex = library.makeFunction(name: "foldVertex"),
              let fragment = library.makeFunction(name: "foldFragment") else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
        self.pipeline = pipeline
        super.init()
        view.delegate = self
    }

    func setImage(_ image: CGImage) throws {
        texture = try textureLoader.newTexture(cgImage: image, options: [
            .SRGB: false,
            .generateMipmaps: true,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue)
        ])
    }

    func setAngle(_ angle: Double) { parameters = .make(angle: angle) }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let buffer = commandQueue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: pass),
              let texture else { return }
        var uniforms = Uniforms(
            progress: Float(parameters.progress),
            blur: 5.5,
            darkness: Float(parameters.darkness),
            tint: Float(parameters.glassTint),
            aspect: Float(view.drawableSize.width / max(view.drawableSize.height, 1))
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }
}
