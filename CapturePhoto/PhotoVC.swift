//
//  PhotoVC.swift
//  CapturePhoto
//
//  Created by Apple on 12/12/19.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import AVFoundation

enum CameraType {
    case rear
    case front
    case unknow
}

protocol PhotoVCDelegate: class {
    
    func didChooseImage(_ image: UIImage)
    
}

class PhotoVC: UIViewController {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var btnVideo: UIButton!
    @IBOutlet weak var btnCapture: UIButton!
    @IBOutlet weak var btnSwitchCamera: UIButton!
    @IBOutlet weak var btnFlash: UIButton!
    
    weak var delegate: PhotoVCDelegate?
    private var currentCameraType: CameraType = .unknow
    private var captureSession: AVCaptureSession?
    private var rearCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    private var captureOutput: AVCapturePhotoOutput?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var flashMode: AVCaptureDevice.FlashMode = .off
    private let bag = DisposeBag()
    private let deviceHelper = DeviceOrientationHelper()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initBinding()
        btnCapture.isEnabled = false
        btnCapture.layer.cornerRadius = btnCapture.frame.size.height / 2.0
        checkPermissionCamera()
        NotificationCenter.default.addObserver(self, selector: #selector(enableCaptureButton), name: .AVCaptureSessionDidStartRunning, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        
        deviceHelper.startObserverMotionUpdate()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.isHidden = false
        
        deviceHelper.stopObserverMotionUpdate()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionDidStartRunning, object: nil)
    }
    
    private func initBinding() {
        btnCapture.rx.tap
            .asObservable()
            .debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .subscribe(onNext: {[weak self] (_) in
                self?.captureImage()
            })
            .disposed(by: bag)
        
        btnFlash.rx.tap
            .asObservable()
            .debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .subscribe(onNext: {[weak self] (_) in
                self?.toggleFlashMode()
            })
            .disposed(by: bag)
        
        btnSwitchCamera.rx.tap
            .asObservable()
            .debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .subscribe(onNext: {[weak self] (_) in
                self?.switchCamera()
            })
            .disposed(by: bag)
    }
    
    @objc private func enableCaptureButton() {
        DispatchQueue.main.async {[weak self] in
            self?.btnCapture.isEnabled = true
        }
    }
    
    private func switchCamera() {
        guard let captureSession = captureSession else {
            return
        }
        
        switch currentCameraType {
        case .rear:
            if let currentInput = captureSession.inputs.first {
                captureSession.removeInput(currentInput)
                
                if let frontCamera = frontCamera, let frontInput = try? AVCaptureDeviceInput(device: frontCamera) {
                    if captureSession.canAddInput(frontInput) {
                        captureSession.addInput(frontInput)
                    
                        currentCameraType = .front
                    }
                }
            }
            break
        case .front:
            if let currentInput = captureSession.inputs.first {
                captureSession.removeInput(currentInput)
                
                if let rearCamera = rearCamera, let rearInput = try? AVCaptureDeviceInput(device: rearCamera) {
                    if captureSession.canAddInput(rearInput) {
                        captureSession.addInput(rearInput)
                        
                        currentCameraType = .rear
                    }
                }
            }
            break
        default:
            break
        }
    }
    
    private func toggleFlashMode() {
        switch flashMode {
        case .off:
            flashMode = .on
            break
        case .on:
            flashMode = .off
            break
        default:
            break
        }
    }
    
    private func captureImage() {
        let setting = AVCapturePhotoSettings()
        setting.flashMode = flashMode
        captureOutput?.capturePhoto(with: setting, delegate: self)
    }
    
    private func checkPermissionCamera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            prepareForCapture()
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) {[unowned self] (granted) in
                if granted {
                    self.prepareForCapture()
                }
            }
            break
        default:
            break
        }
    }
    
    private func prepareForCapture() {
        DispatchQueue.global(qos: .userInitiated).async {[weak self] in
            // create capture camera
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            discoverySession.devices.forEach {[unowned self] (captureDevice) in
                if captureDevice.position == .back {
                    self?.rearCamera = captureDevice
                } else if captureDevice.position == .front {
                    self?.frontCamera = captureDevice
                }
            }
            guard let rearCamera = self?.rearCamera, let frontCamera = self?.frontCamera else {
                return
            }
            self?.configure(captureDevice: rearCamera)
            self?.configure(captureDevice: frontCamera)
            
            self?.captureSession = AVCaptureSession()
            self?.captureSession?.beginConfiguration()
            self?.captureSession?.sessionPreset = .photo
            
            self?.configureCaptureInputs()
            self?.configureCaptureOutputs()
            
            self?.captureSession?.commitConfiguration()
            self?.captureSession?.startRunning()
            
            self?.displayPreview()
        }
    }
        
    private func configureCaptureInputs() {
        guard let captureSession = captureSession else {
            return
        }
        
        if let defaultDevice = AVCaptureDevice.default(for: .video) {
            if let cameraInput = try? AVCaptureDeviceInput(device: defaultDevice) {
                if captureSession.canAddInput(cameraInput) {
                    captureSession.addInput(cameraInput)
                    
                    switch defaultDevice.position {
                    case .back:
                        currentCameraType = .rear
                        break
                    case .front:
                        currentCameraType = .front
                        break
                    default:
                        currentCameraType = .unknow
                    }
                }
            }
        }
    }
    
    private func configureCaptureOutputs() {
        guard let captureSession = captureSession else {
            return
        }
        captureOutput = AVCapturePhotoOutput()
        let capturePhotoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])
        captureOutput?.setPreparedPhotoSettingsArray([capturePhotoSettings], completionHandler: nil)
        if captureSession.canAddOutput(captureOutput!) {
            captureSession.addOutput(captureOutput!)
        }
    }
    
    private func displayPreview() {
        guard let captureSession = captureSession else {
            return
        }
        if captureSession.isRunning {
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = .resizeAspectFill
            videoPreviewLayer?.connection?.videoOrientation = .portrait
            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                self.videoPreviewLayer?.frame = self.previewView.bounds
                self.previewView.layer.addSublayer(self.videoPreviewLayer!)
            }
        }
    }
    
    private func configure(captureDevice: AVCaptureDevice) {
        do {
            try captureDevice.lockForConfiguration()
            // set best format and best frame rate range for captureDevice
            var bestFormat: AVCaptureDevice.Format?
            var bestFrameRateRange: AVFrameRateRange?
            for format in captureDevice.formats {
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0.0 {
                        bestFormat = format
                        bestFrameRateRange = range
                    }
                }
            }
            if let bestFormat = bestFormat, let bestFrameRateRange = bestFrameRateRange {
                captureDevice.activeFormat = bestFormat
                // set min max duration frame rate
                let duration = bestFrameRateRange.minFrameDuration
                captureDevice.activeVideoMinFrameDuration = duration
                captureDevice.activeVideoMaxFrameDuration = duration
                // set focus mode
                if captureDevice.isFocusModeSupported(.autoFocus) {
                    captureDevice.focusMode = .autoFocus
                }
            }
            captureDevice.unlockForConfiguration()
        } catch {}
    }
    
    private func handlerImage(with imageData: Data) {
        let originImage = UIImage(data: imageData, scale: 0.4)
        if let cgOriginImage = originImage?.cgImage {
            var image = originImage
            if let orientation = imageOrientation() {
                image = UIImage(cgImage: cgOriginImage, scale: 1.0, orientation: orientation)
            }
            delegate?.didChooseImage(image!)
        }
    }
    
    private func imageOrientation() -> UIImage.Orientation? {
        guard let captureSession = captureSession else {
            return nil
        }
        
        guard let input = captureSession.inputs.first as? AVCaptureDeviceInput else {
            return nil
        }
        
        let currentOrientation = deviceHelper.currentOrientation
        if input.device.position == .back {
            switch currentOrientation {
            case .landscapeLeft:
                return .up
            case .landscapeRight:
                return .down
            case .portrait:
                return .left
            case .portraitUpsideDown:
                return .right
            default:
                return nil
            }
        }
        else {
            switch currentOrientation {
            case .landscapeLeft:
                return .downMirrored
            case .landscapeRight:
                return .upMirrored
            case .portrait:
                return .rightMirrored
            case .portraitUpsideDown:
                return .leftMirrored
            default:
                return nil
            }
        }
    }
    
}

extension PhotoVC: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error")
            return
        }
        
        if let imageData = photo.fileDataRepresentation() {
            handlerImage(with: imageData)
        }
    }
    
}
