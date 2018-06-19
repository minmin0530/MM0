//
//  Renderer.swift
//  desktop
//
//  Created by IzumiYoshiki on 2018/06/09.
//  Copyright © 2018年 IzumiYoshiki. All rights reserved.
//

import Foundation
import MetalKit
import Metal

struct Vertex2 {
    var position: vector_float4
    var color: vector_float4
    var normal: vector_float3
}

let alignedUniformsSize = (MemoryLayout<Uniforms>.size & ~0xFF) + 0x100

let maxBuffersInFlight = 3

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
//    var colorMap: MTLTexture
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var rotation: Float = 0
    
//    var mesh: MTKMesh

    
    
    
    var depthState2: MTLDepthStencilState
//    var uniforms2: UnsafeMutablePointer<Uniforms>
//    var dynamicUniformBuffer2: MTLBuffer
    var mtlVertexDescriptor2: MTLVertexDescriptor
    
    var eye: float3 = float3(0.0, 0.0, 4)
    var light: float3 = float3(-450.0, -450.0, 2.0)
    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        self.depthState2 = (metalKitView.device?.makeDepthStencilState(descriptor:depthStateDesciptor)!)!
        mtlVertexDescriptor2 = MTLVertexDescriptor()
        
        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor2)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

//       super.init(metalKitView: metalKitView)

        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        self.dynamicUniformBuffer = (metalKitView.device?.makeBuffer(length:uniformBufferSize,
                                                                     options:[MTLResourceOptions.storageModeShared])!)!
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)

        super.init()
    }

    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertex_func")
        let fragmentFunction = library?.makeFunction(name: "fragment_func")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    
    func draw(in view: MTKView) {

        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        
        let aspect = Float(1.0) //Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)

        uniforms[0].projectionMatrix = projectionMatrix
        
        let rotationAxis = float3(1, 1, 0)
        let modelMatrix = matrix4x4_rotation(radians: rotation, axis: rotationAxis)
        let viewMatrix = matrix_lookAt(eye: eye, target:float3(0,0,0), up:float3(0,1,0))
        //matrix4x4_translation(0.0, 0.0, -8.0)
        uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        uniforms[0].lightPosition = light
        rotation += 0.01

//        eye.z -= 0.01
//        light.x -= 1
//        light.y -= 1

//        NSLog(String(light.x))
        
        view.device = MTLCreateSystemDefaultDevice()
        guard let device = view.device else {
            NSLog("Failed to create Metal device")
            return
        }
        let vertexData = [
            Vertex2(position: [ 1.0,  0.0, 0.0, 1.0], color: [0, 0, 1, 1], normal: [0.0, 0.0, 1.0]),
            Vertex2(position: [-1.0,  0.0, 0.0, 1.0], color: [0, 0, 1, 1], normal: [0.0, 0.0, 1.0]),
            Vertex2(position: [ 0.0,  1.0, 0.0, 1.0], color: [0, 0, 1, 1], normal: [0.0, 0.0, 1.0]),
            Vertex2(position: [ 1.0,  0.0, 0.0, 1.0], color: [0, 0, 1, 1], normal: [0.0, 0.0, 1.0]),
            Vertex2(position: [-1.0,  0.0, 0.0, 1.0], color: [0, 0, 1, 1], normal: [0.0, 0.0, 1.0]),
            Vertex2(position: [ 0.0, -1.0, 0.0, 1.0], color: [0, 0, 1, 1], normal: [0.0, 0.0, 1.0]),
                          ]
        let vertexBuffer = device.makeBuffer(bytes: vertexData, length: 82 * vertexData.count, options:[])
        
        guard let library = device.makeDefaultLibrary() else {
            NSLog("Failed to create library")
            return
        }
        let vertexFunction = library.makeFunction(name:"vertex_func")
        let fragmentFunction = library.makeFunction(name:"fragment_func")
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor2
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        renderPipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        do {
            let renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
            }
            guard let drawable = view.currentDrawable else {
                return
            }
            
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
            let commandQueue = view.device?.makeCommandQueue()
            let commandBuffer = commandQueue?.makeCommandBuffer()
            let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            renderCommandEncoder?.setRenderPipelineState(renderPipelineState)
            renderCommandEncoder?.setDepthStencilState(depthState2)
            renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderCommandEncoder?.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
//            renderCommandEncoder?.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)

            
            
            renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 2)
            renderCommandEncoder?.endEncoding()
            commandBuffer?.present(_: drawable)
            commandBuffer?.commit()
        } catch let error {
            NSLog("\(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }

}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: float3) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func matrix_lookAt(eye: float3, target: float3, up: float3) -> matrix_float4x4 {
    var m = [
        Float(1.0), Float(0.0), Float(0.0), Float(0.0),
        Float(0.0), Float(1.0), Float(0.0), Float(0.0),
        Float(0.0), Float(0.0), Float(1.0), Float(0.0),
        Float(0.0), Float(0.0), Float(0.0), Float(1.0),
    ]
    var l = Float(0.0)
    var t = [Float(0.0), Float(0.0), Float(0.0)]
    t[0] = eye[0] - target[0]
    t[1] = eye[1] - target[1]
    t[2] = eye[2] - target[2]
    var tt = t[0]*t[0]+t[1]*t[1]+t[2]*t[2]
    l = sqrt(tt)
    m[ 2] = t[0] / l
    m[ 6] = t[1] / l;
    m[10] = t[2] / l;
    
    
    t[0] = up[1] * m[10] - up[2] * m[ 6];
    t[1] = up[2] * m[ 2] - up[0] * m[10];
    t[2] = up[0] * m[ 6] - up[1] * m[ 2];
    tt = t[0]*t[0]+t[1]*t[1]+t[2]*t[2]
    l = sqrt(tt);
    m[0] = t[0] / l;
    m[4] = t[1] / l;
    m[8] = t[2] / l;
    
    
    m[1] = m[ 6] * m[8] - m[10] * m[4];
    m[5] = m[10] * m[0] - m[ 2] * m[8];
    m[9] = m[ 2] * m[4] - m[ 6] * m[0];
    
    m[12] = -(eye[0] * m[0] + eye[1] * m[4] + eye[2] * m[ 8]);
    m[13] = -(eye[0] * m[1] + eye[1] * m[5] + eye[2] * m[ 9]);
    m[14] = -(eye[0] * m[2] + eye[1] * m[6] + eye[2] * m[10]);
    
    return matrix_float4x4.init(columns:(vector_float4(m[0], m[1], m[2], m[3]),
                                         vector_float4(m[4], m[5], m[6], m[7]),
                                         vector_float4(m[8], m[9], m[10], m[11]),
                                         vector_float4(m[12], m[13], m[14], m[15])))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
