//
//  ViewController.swift
//  ml
//
//  Created by 辻林大揮 on 2018/07/26.
//  Copyright © 2018年 chocovayashi. All rights reserved.
//
// cf https://i-app-tec.com/ios/avcapturevideodataoutput.html

import UIKit
import CoreML
import Vision
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var device: AVCaptureDevice!
    var session: AVCaptureSession!
    var output: AVCaptureVideoDataOutput!
    
    var enable = true
    
    let label = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.enable = true
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        /// カメラの設定などの初期化
        session = AVCaptureSession()
        device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        output = AVCaptureVideoDataOutput()
        session.addOutput(output)
        session.sessionPreset = .photo
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        var frame = view.bounds
        frame.size.height *= 0.7
        previewLayer.frame = frame
        view.layer.addSublayer(previewLayer)

        // ピクセルフォーマットを 32bit BGR + A とする
        output.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as AnyHashable as!
                String : Int(kCVPixelFormatType_32BGRA)]

        // フレームをキャプチャするためのサブスレッド用のシリアルキューを用意
        output.setSampleBufferDelegate(self, queue: DispatchQueue.main)

        output.alwaysDiscardsLateVideoFrames = true

        session.startRunning()

        label.frame.size.width = view.frame.width
        label.frame.origin.y = view.frame.height * 0.7 + 30
        label.frame.size.height = view.frame.height * 0.3 - 30
        label.numberOfLines = 0
        view.addSubview(label)
    }
    
    /// 画像から認識する関数
    func show(image: UIImage) {
        guard let model = try? VNCoreMLModel(for: MobileNet().model) else { return }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNClassificationObservation] else { return }
            self.label.text = results.enumerated()
                .filter { $0.offset < 5 }
                .map { $0.element }
                .map { $0.identifier + ": \($0.confidence)" }
                .reduce("") { $0 + "\n" + $1 }
        }
        
        // 認識させたい画像をいれる
        guard let ciImage = CIImage(image: image) else { return }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        guard (try? handler.perform([request])) != nil else { return } 
    }
    
    /// 画面をUIImageに変換するときの関数
    func captureOutput(_ captureOutput: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if !enable { return }
        enable = false
        let image = self.captureImage(sampleBuffer)
        show(image: image)
    }
    func captureImage(_ sampleBuffer:CMSampleBuffer) -> UIImage{
        let imageBuffer:CVImageBuffer =
            CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer,
                                     CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        let baseAddress:UnsafeMutableRawPointer =
            CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        
        let bytesPerRow:Int = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width:Int = CVPixelBufferGetWidth(imageBuffer)
        let height:Int = CVPixelBufferGetHeight(imageBuffer)
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let newContext:CGContext = CGContext(data: baseAddress,
                                             width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: bytesPerRow, space: colorSpace,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)!
        
        let imageRef:CGImage = newContext.makeImage()!
        let resultImage = UIImage(cgImage: imageRef,
                                  scale: 1.0, orientation: UIImageOrientation.right)
        
        return resultImage
    }
}
