//
//  ViewController.swift
//  ReactionTime
//
//  Created by Ilesh's 2018 o
//  Copyright © 2019 Ilesh's. All rights reserved.
//

import AVFoundation
import Vision
import UIKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet private weak var cameraView: UIView?
    @IBOutlet private weak var lblLable: UILabel!
    @IBOutlet private weak var btnAction: UIButton!
    @IBOutlet private weak var viewCenter: UIView!
    @IBOutlet private weak var highlightView: UIView?
    
    private let visionSequenceHandler = VNSequenceRequestHandler()
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
            else { return session }
        session.addInput(input)
        return session
    }()
    
    var isDetect:Bool! {
        didSet{
            self.viewCenter.layer.borderColor = isDetect ? #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1) : #colorLiteral(red: 0.9294117647, green: 0.1098039216, blue: 0.1411764706, alpha: 1)
            self.viewCenter.backgroundColor = isDetect ? #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1) : #colorLiteral(red: 0.9294117647, green: 0.1098039216, blue: 0.1411764706, alpha: 1)
        }
    }
    var isCount : Int = 0
    
    private var lastObservation: VNDetectedObjectObservation?
    private var startObservationTime : Date!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.isDetect = false
        
        self.viewCenter.layer.borderWidth = 2.0
        
        // hide the red focus area on load
        self.highlightView?.frame = .zero
        
        // make the camera appear on the screen
        self.cameraView?.layer.addSublayer(self.cameraLayer)
        
        // register to receive buffers from the camera
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        self.captureSession.addOutput(videoOutput)
        
        // begin the session
        self.captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // make sure the layer is the correct size
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
        self.cameraView?.layer.frame = self.cameraView?.bounds ?? .zero
        self.btnAction.layer.cornerRadius = self.btnAction.frame.height / 2
    }
    
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard
            // make sure the pixel buffer can be converted
            let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            // make sure that there is a previous observation we can feed into the request
            let lastObservation = self.lastObservation
            else { return }
        
        // create the request
        let request = VNTrackObjectRequest(detectedObjectObservation: lastObservation, completionHandler: self.handleVisionRequestUpdate)
        // set the accuracy to high
        // this is slower, but it works a lot better
        request.trackingLevel = .accurate
        
        // perform the request
        do {
            try self.visionSequenceHandler.perform([request], on: pixelBuffer)
            //self.startObservationTime = Date()
        } catch {
            print("Throws: \(error)")
        }
    }
    
    private func handleVisionRequestUpdate(_ request: VNRequest, error: Error?) {
        // Dispatch to the main queue because we are touching non-atomic, non-thread safe properties of the view controller
        DispatchQueue.main.async {
            // make sure we have an actual result
            guard let newObservation = request.results?.first as? VNDetectedObjectObservation else {
                return
            }
            self.lastObservation = newObservation
            
            if !(newObservation.confidence >= 0.9) { //CHAGNES IN THE FRAME
                var transformedRect = newObservation.boundingBox
                transformedRect.origin.y = 1 - transformedRect.origin.y
                let convertedRect = self.cameraLayer.layerRectConverted(fromMetadataOutputRect: transformedRect)
                print("X:\(abs(self.highlightView!.frame.origin.x - convertedRect.origin.x)):Y:\(abs(self.highlightView!.frame.origin.y - convertedRect.origin.y))")
                self.isDetect = true
                if abs(self.highlightView!.frame.origin.x - convertedRect.origin.x) > 10 || abs(self.highlightView!.frame.origin.y - convertedRect.origin.y) > 10 {
                    self.isCount += 1
                    if self.isCount != 1 {
                        let reactionTime = Date().timeIntervalSince(self.startObservationTime)
                        print("REACTION TIME: \(reactionTime)")
                        print("REACTION TIME milisecond: \(reactionTime*1000)")
                        print("New milisecond: \(reactionTime*1000)")
                        self.captureSession.stopRunning()
                        self.isDetect = false
                        DispatchQueue.main.async {
                            self.lblLable.text = "\(Int(reactionTime*1000)) ms"
                        }
                    }
                }
                self.highlightView?.frame = convertedRect
            }else{ //NOT CHANES IN THE FRAME
                print("NOT REACTION FOUND")
                self.isDetect = false
            }
        }
    }
    
    @IBAction private func btnActionClick(_ sender: UIButton) {
        lblLable.text = ""
        
        self.resetTapped(UIBarButtonItem())
        
        // COMMAND FIRST
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { (timer) in
            self.speekText(str: "DOWN")
        }
        
        // COMMAND SECOND
        Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { (timer) in
            self.speekText(str: "SET")
        }
        
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { (timer) in
            self.setPosition()
        }
    }
    
    func speekText(str:String) {
        // Line 1. Create an instance of AVSpeechSynthesizer.
        let speechSynthesizer = AVSpeechSynthesizer()
        // Line 2. Create an instance of AVSpeechUtterance and pass in a String to be spoken.
        let speechUtterance: AVSpeechUtterance = AVSpeechUtterance(string:str)
        speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // Line 4. Specify the voice. It is explicitly set to English here, but it will use the device default if not specified.
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        // Line 5. Pass in the urrerance to the synthesizer to actually speak.
        speechSynthesizer.speak(speechUtterance)
    }
    
    
    @IBAction private func userTapped(_ sender: UITapGestureRecognizer) {
    
    }
    
    private func setPosition(){
        //self.highlightView?.frame.size = CGSize(width: 200, height: 200)
        //self.highlightView?.center = self.cameraView!.center
        
        // convert the rect for the initial observation
        let originalRect = self.viewCenter.frame
        self.highlightView?.frame = originalRect
        var convertedRect = self.cameraLayer.metadataOutputRectConverted(fromLayerRect: originalRect)
        convertedRect.origin.y = 1 - convertedRect.origin.y
        
        // set the observation
        let newObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
        self.lastObservation = newObservation
        self.startObservationTime = Date()
        isCount = 0
        AudioServicesPlaySystemSound(1052);
    }
    
    
    @IBAction private func resetTapped(_ sender: UIBarButtonItem) {
        self.lastObservation = nil
        self.highlightView?.frame = .zero
        self.lblLable.text = ""
        self.captureSession.startRunning()
        self.isDetect = false
    }
}

extension TimeInterval {
    var minuteSecondMS: String {
        return String(format:"%d:%02d.%03d", minute, second, millisecond)
    }
    var minute: Int {
        return Int((self/60).truncatingRemainder(dividingBy: 60))
    }
    var second: Int {
        return Int(truncatingRemainder(dividingBy: 60))
    }
    var millisecond: Int {
        return Int((self*1000).truncatingRemainder(dividingBy: 1000))
    }
}
