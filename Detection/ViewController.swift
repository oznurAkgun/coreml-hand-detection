//
//  ViewController.swift
//  Detection
//
//  Created by Öznur Akgün on 20.02.2021.
//

import UIKit
import AVFoundation
import Vision
import CoreML

class ViewController: UIViewController {
    private  let fingerDetectModel: AllFingerModel = {
        do {
            let config = MLModelConfiguration()
            return try AllFingerModel(configuration: config)
        } catch {
            fatalError("Couldn't create model")
        }
    }()
    
    private let handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        
        return request
    }()
    
    private let videoDataOutputQueue = DispatchQueue(
        label: "CameraFeedOutput",
        qos: .userInteractive
    )
    
    private var csvString = ""
    private var lineCount = 0
    private var isAnimationWaiting = false
    private var iconImageView = UIImageView()
    private let cameraView = UIView(frame: .zero)
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        addCameraInput()
        showCameraFeed()
        captureSession.startRunning()
        getCameraFrames()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.bounds
    }
    
    private func setup() {
        csvString = csvString.appending( "\("wristx"),\("wristy"),\("thumbCMCx"),\("thumbCMCy"),\("thumbMPx"),\("thumbMPy"),\("thumbIPx"),\("thumbIPy"),\("thumbTipx"),\("thumbTipy"),\("indexMCPx"),\("indexMCPy"),\("indexPIPx"),\("indexPIPy"),\("indexDIPx"),\("indexDIPy"),\("indexTipx"),\("indexTipy"),\("middleMCPx"),\("middleMCPy"),\("middlePIPx"),\("middlePIPy"),\("middleDIPx"),\("middleDIPy"),\("middleTipx"),\("middleTipy"),\("ringMCPx"),\("ringMCPy"),\("ringPIPx"),\("ringPIPy"),\("ringDIPx"),\("ringDIPy"),\("ringTipx"),\("ringTipy"),\("littleMCPx"),\("littleMCPy"),\("littlePIPx"),\("littlePIPy"),\("littleDIPx"),\("littleDIPy"),\("littleTipx"),\("littleTipy"),result\n")
       
        view.backgroundColor = .white
        view.addSubview(cameraView)
        cameraView.clipsToBounds = true
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            cameraView.heightAnchor.constraint(equalTo: cameraView.widthAnchor, multiplier: 2),
            cameraView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                mediaType: .video,
                position: .front).devices.first else {
            fatalError("No back camera device found, please make sure to run SimpleLaneDetection in an iOS device and not a simulator")
        }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)
    }
    
    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.cameraView.layer.addSublayer(self.previewLayer)
    }
    
    private func getCameraFrames() {
        let dataOutput = AVCaptureVideoDataOutput()
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        }
        
        captureSession.commitConfiguration()
    }
    

    func startAnimationIfNeeded(bottomPoint: CGPoint, result: Int) {
        if isAnimationWaiting {
            return
        }
        
        isAnimationWaiting = true
        iconImageView.removeFromSuperview()
        
        if result == 1 { //👍
            iconImageView = UIImageView(image: UIImage(named: "1pose"))
        } else if result == 2 { //🖐
            iconImageView = UIImageView(image: UIImage(named: "2pose"))
        } else if result == 3 { //👌
            iconImageView = UIImageView(image: UIImage(named: "3pose"))
        } else if result == 5 { //👇
            iconImageView = UIImageView(image: UIImage(named: "5pose"))
        } else if result == 6 { //👊
            iconImageView = UIImageView(image: UIImage(named: "6pose"))
        } else if result == 8 { //🤟
            iconImageView = UIImageView(image: UIImage(named: "8pose"))
        }
        iconImageView.frame = CGRect(x: bottomPoint.x, y: bottomPoint.y, width: 30, height: 30)
        iconImageView.translatesAutoresizingMaskIntoConstraints = true
        cameraView.addSubview(iconImageView)
        
        UIView.animate(withDuration: 0.5) { [weak self] in
            self?.iconImageView.frame.size = CGSize(width: 150, height: 150)
        } completion: { _ in
            UIView.animate(withDuration: 0.5) {
                self.iconImageView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                self.iconImageView.center = CGPoint(x: bottomPoint.x, y: -30)
            } completion: { _ in
                self.isAnimationWaiting = false
            }
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )
        do {
            try handler.perform([handPoseRequest])
            
            guard let results = handPoseRequest.results?.prefix(1),
                  !results.isEmpty else { return }
            
            try results.forEach { observation in
                let fingers = try observation.recognizedPoints(.all)
                //createCSVFile(fingers: fingers) //open it if you want fill dataset and then comment below
                detectFingerIfNeeded(fingers: fingers)
            }
        } catch {
            captureSession.stopRunning()
            print(error.localizedDescription)
        }
    }
    
    func createCSVFile(fingers: [VNHumanHandPoseObservation.JointName : VNRecognizedPoint]) {
        let landmarks: [VNHumanHandPoseObservation.JointName] = [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip, .indexMCP, .indexPIP, .indexDIP, .indexTip, .middleMCP, .middlePIP, .middleDIP, .middleTip, .ringMCP, .ringPIP, .ringDIP, .ringTip, .littleMCP, .littlePIP, .littleDIP, .littleTip]
        var line = ""
        landmarks.forEach { type in
            let strx = fingers[type]?.x ?? 0
            line = line.appending(String(strx))
            line = line.appending(",")
            let stry = fingers[type]?.y ?? 0
            line = line.appending(String(stry))
            line = line.appending(",")
        }
        
        lineCount += 1
        
        line = line.appending("1\n") //change 1 when every hand sign changed

        csvString = csvString.appending(line)

        if lineCount == 2000 {
            let fileManager = FileManager.default
            do {
                let path = try fileManager.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
                let fileURL = path.appendingPathComponent("FingerPoint1.csv")
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch let error {
                print(error)
            }
        }
    }
    
    func detectFingerIfNeeded(fingers: [VNHumanHandPoseObservation.JointName : VNRecognizedPoint]) {
        guard let modelOutput = try? fingerDetectModel.prediction(
                wristx:fingers[.wrist]?.x ?? 0,
                wristy: fingers[.wrist]?.y ?? 0,
                thumbCMCx: fingers[.thumbCMC]?.x ?? 0,
                thumbCMCy: fingers[.thumbCMC]?.y ?? 0,
                thumbMPx: fingers[.thumbMP]?.x ?? 0,
                thumbMPy: fingers[.thumbMP]?.y ?? 0,
                thumbIPx: fingers[.thumbIP]?.x ?? 0,
                thumbIPy: fingers[.thumbIP]?.y ?? 0,
                thumbTipx: fingers[.thumbTip]?.x ?? 0,
                thumbTipy: fingers[.thumbTip]?.y ?? 0,
                indexMCPx: fingers[.indexMCP]?.x ?? 0,
                indexMCPy: fingers[.indexMCP]?.y ?? 0,
                indexPIPx: fingers[.indexPIP]?.x ?? 0,
                indexPIPy: fingers[.indexPIP]?.y ?? 0,
                indexDIPx: fingers[.indexDIP]?.x ?? 0,
                indexDIPy: fingers[.indexDIP]?.y ?? 0,
                indexTipx: fingers[.indexTip]?.x ?? 0,
                indexTipy: fingers[.indexTip]?.y ?? 0,
                middleMCPx: fingers[.middleMCP]?.x ?? 0,
                middleMCPy: fingers[.middleMCP]?.y ?? 0,
                middlePIPx: fingers[.middlePIP]?.x ?? 0,
                middlePIPy: fingers[.middlePIP]?.y ?? 0,
                middleDIPx: fingers[.middleDIP]?.x ?? 0,
                middleDIPy: fingers[.middleDIP]?.y ?? 0,
                middleTipx: fingers[.middleTip]?.x ?? 0,
                middleTipy: fingers[.middleTip]?.y ?? 0,
                ringMCPx: fingers[.ringMCP]?.x ?? 0,
                ringMCPy: fingers[.ringMCP]?.y ?? 0,
                ringPIPx: fingers[.ringPIP]?.x ?? 0,
                ringPIPy: fingers[.ringPIP]?.y ?? 0,
                ringDIPx: fingers[.ringDIP]?.x ?? 0,
                ringDIPy: fingers[.ringDIP]?.y ?? 0,
                ringTipx: fingers[.ringTip]?.x ?? 0,
                ringTipy: fingers[.ringTip]?.y ?? 0,
                littleMCPx: fingers[.littleMCP]?.x ?? 0,
                littleMCPy: fingers[.littleMCP]?.y ?? 0,
            littlePIPx: fingers[.littlePIP]?.x ?? 0,
            littlePIPy: fingers[.littlePIP]?.y ?? 0,
            littleDIPx: fingers[.littleDIP]?.x ?? 0,
            littleDIPy: fingers[.littleDIP]?.y ?? 0,
            littleTipx: fingers[.littleTip]?.x ?? 0,
            littleTipy: fingers[.littleTip]?.y ?? 0
        ) else { return }
        
        DispatchQueue.main.async {
            let wristPoint = fingers[.wrist]
            let bottomPoint = self.previewLayer.layerPointConverted(
                fromCaptureDevicePoint: CGPoint(
                    x: wristPoint?.x ?? 0,
                    y: 1 - (wristPoint?.y ?? 0)
                )
            )
            self.startAnimationIfNeeded(
                bottomPoint: bottomPoint,
                result: Int(modelOutput.result)
            )
        }
    }
}
