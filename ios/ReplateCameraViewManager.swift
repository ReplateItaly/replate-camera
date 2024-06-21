import ARKit
import RealityKit
import UIKit
import AVFoundation

@objc(ReplateCameraViewManager)
class ReplateCameraViewManager: RCTViewManager {
    
    override func view() -> (ReplateCameraView) {
        let replCameraView = ReplateCameraView()
        return replCameraView
    }
    
    @objc override static func requiresMainQueueSetup() -> Bool {
        return false
    }
    
    
}

extension UIImage {
    func rotate(radians: Float) -> UIImage {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move origin to middle
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

class ReplateCameraView: UIView, ARSessionDelegate {
    
    static var arView: ARView!
    static var anchorEntity: AnchorEntity!
    static var model: Entity!
    static var spheresModels: [ModelEntity] = []
    static var upperSpheresSet: [Bool] = [Bool](repeating: false, count: 72)
    static var lowerSpheresSet: [Bool] = [Bool](repeating: false, count: 72)
    static var totalPhotosTaken: Int = 0
    static var photosFromDifferentAnglesTaken = 0
    static var INSTANCE: ReplateCameraView!
    static var sphereRadius = Float(0.0025 * 2)
    static var spheresRadius = Float(0.15)
    static var sphereAngle = Float(5)
    static var spheresHeight = Float(0.3)
    static var dragSpeed = CGFloat(7000)
    static var isPaused = false
    static var sessionId: UUID!
    static var focusModel: ModelEntity!
    static var distanceBetweenCircles = Float(0.15)
    
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        requestCameraPermissions()
        //        setupAR()
        ReplateCameraView.INSTANCE = self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        requestCameraPermissions()
        ReplateCameraView.INSTANCE = self
        //        setupAR()
    }
    
    static func addRecognizer() {
        let recognizer = UITapGestureRecognizer(target: ReplateCameraView.INSTANCE,
                                                action: #selector(ReplateCameraView.INSTANCE.viewTapped(_:)))
        ReplateCameraView.arView.addGestureRecognizer(recognizer)
        let panGestureRecognizer = UIPanGestureRecognizer(target: ReplateCameraView.INSTANCE, action: #selector(ReplateCameraView.INSTANCE.handlePan(_:)))
        ReplateCameraView.arView.addGestureRecognizer(panGestureRecognizer)
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: ReplateCameraView.INSTANCE, action: #selector(ReplateCameraView.INSTANCE.handlePinch(_:)))
        ReplateCameraView.arView.addGestureRecognizer(pinchGestureRecognizer)
    }
    
    func requestCameraPermissions() {
        
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            print("Camera permissions already granted")
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    print("Camera permissions granted")
                } else {
                    print("Camera permissions denied")
                }
            })
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Now you can safely access the size
        let width = self.frame.width
        let height = self.frame.height
        
        // Do something with width and height
        print("Width: \(width), Height: \(height)")
        self.setupAR()
    }
    
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        print("handle pan")
        guard let sceneView = gestureRecognizer.view as? ARView else {
            return
        }
        print("passed guard")
        if gestureRecognizer.state == .changed {
            print("triggered")
            let translation = gestureRecognizer.translation(in: sceneView)
            print(translation)
            let initialPosition = ReplateCameraView.anchorEntity.position
            ReplateCameraView.anchorEntity.position = initialPosition + SIMD3(Float(translation.x / ReplateCameraView.dragSpeed), 0, Float(translation.y / ReplateCameraView.dragSpeed))
            
            gestureRecognizer.setTranslation(.zero, in: sceneView)
        }
    }
    
    @objc func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let sceneView = gestureRecognizer.view as? ARView else {
            return
        }
        
        switch gestureRecognizer.state {
        case .changed:
            // Calculate the scale based on the gesture recognizer's scale
            let scale = Float(gestureRecognizer.scale)
            
            // Apply the scale to the anchor entity's transform
            let transform = ReplateCameraView.anchorEntity.transform
            
            ReplateCameraView.spheresModels.forEach { entity in
                ReplateCameraView.anchorEntity.removeChild(entity)
            }
            ReplateCameraView.anchorEntity.removeChild(ReplateCameraView.focusModel)
            ReplateCameraView.spheresModels = []
            ReplateCameraView.sphereRadius *= scale
            ReplateCameraView.spheresRadius *= scale
            ReplateCameraView.sphereAngle *= scale
            createSpheres(y: 0 + ReplateCameraView.spheresHeight)
            createSpheres(y: ReplateCameraView.distanceBetweenCircles + ReplateCameraView.spheresHeight)
            createFocusSphere()
            for i in 0...71 {
                let material = SimpleMaterial(color: .green, isMetallic: false)
                if (ReplateCameraView.upperSpheresSet[i]) {
                    let entity = ReplateCameraView.spheresModels[72 + i]
                    entity.model?.materials[0] = material
                }
                if (ReplateCameraView.lowerSpheresSet[i]) {
                    let entity = ReplateCameraView.spheresModels[i]
                    entity.model?.materials[0] = material
                }
                
            }
            // Reset the gesture recognizer's scale to 1 to avoid cumulative scaling
            gestureRecognizer.scale = 1.0
        default:
            break
        }
    }
    
    
    @objc private func viewTapped(_ recognizer: UITapGestureRecognizer) {
        print("VIEW TAPPED")
        let tapLocation: CGPoint = recognizer.location(in: ReplateCameraView.arView)
        let estimatedPlane: ARRaycastQuery.Target = .estimatedPlane
        let alignment: ARRaycastQuery.TargetAlignment = .horizontal
        
        let result: [ARRaycastResult] = ReplateCameraView.arView.raycast(from: tapLocation,
                                                                         allowing: estimatedPlane,
                                                                         alignment: alignment)
        
        guard let rayCast: ARRaycastResult = result.first
        else {
            return
        }
        let anchor = AnchorEntity(world: rayCast.worldTransform)
        //    anchor.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        //    anchor.transform.rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        print("ANCHOR FOUND\n", anchor.transform)
        let callback = ReplateCameraController.anchorSetCallback
        if (callback != nil) {
            callback!([])
            ReplateCameraController.anchorSetCallback = nil
        }
        if (ReplateCameraView.model == nil && ReplateCameraView.anchorEntity == nil) {
            ReplateCameraView.anchorEntity = anchor
            createSpheres(y: 0 + ReplateCameraView.spheresHeight)
            createSpheres(y: ReplateCameraView.distanceBetweenCircles + ReplateCameraView.spheresHeight)
            createFocusSphere()
            
            //DEBUG MESHES
            //            let xAxis = MeshResource.generateBox(width: 2, height: 0.001, depth: 0.01)
            //            let xLineEntity = ModelEntity(mesh: xAxis)
            //            xLineEntity.setPosition(SIMD3<Float>(0, 0, 0), relativeTo: ReplateCameraView.anchorEntity)
            //            xLineEntity.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
            //            ReplateCameraView.anchorEntity.addChild(xLineEntity)
            //            let xLineLeftSphere = MeshResource.generateSphere(radius: ReplateCameraView.sphereRadius * 5)
            //            let xLineLeftSphereEntity = ModelEntity(mesh: xLineLeftSphere)
            //            ReplateCameraView.anchorEntity.addChild(xLineLeftSphereEntity)
            //            xLineLeftSphereEntity.setPosition(SIMD3<Float>(-1, 0.002, 0), relativeTo: ReplateCameraView.anchorEntity)
            //            xLineLeftSphereEntity.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
            //            let xLineRightSphere = MeshResource.generateSphere(radius: ReplateCameraView.sphereRadius * 5)
            //            let xLineRightSphereEntity = ModelEntity(mesh: xLineRightSphere)
            //            ReplateCameraView.anchorEntity.addChild(xLineRightSphereEntity)
            //            xLineRightSphereEntity.setPosition(SIMD3<Float>(1, 0.002, 0), relativeTo: ReplateCameraView.anchorEntity)
            //            xLineRightSphereEntity.model?.materials = [SimpleMaterial(color: .yellow, isMetallic: false)]
            //            let yAxis = MeshResource.generateBox(width: 0.01, height: 0.001, depth: 2)
            //            let yLineEntity = ModelEntity(mesh: yAxis)
            //            yLineEntity.setPosition(SIMD3<Float>(0, 0, 0), relativeTo: ReplateCameraView.anchorEntity)
            //            let yLineLeftSphere = MeshResource.generateSphere(radius: ReplateCameraView.sphereRadius * 5)
            //            let yLineLeftSphereEntity = ModelEntity(mesh: yLineLeftSphere)
            //            ReplateCameraView.anchorEntity.addChild(yLineLeftSphereEntity)
            //            yLineLeftSphereEntity.setPosition(SIMD3<Float>(0, 0.002, -1), relativeTo: ReplateCameraView.anchorEntity)
            //            yLineLeftSphereEntity.model?.materials = [SimpleMaterial(color: .systemPink, isMetallic: false)]
            //            let yLineRightSphere = MeshResource.generateSphere(radius: ReplateCameraView.sphereRadius * 5)
            //            let yLineRightSphereEntity = ModelEntity(mesh: yLineRightSphere)
            //            ReplateCameraView.anchorEntity.addChild(yLineRightSphereEntity)
            //            yLineRightSphereEntity.setPosition(SIMD3<Float>(0, 0.002, 1), relativeTo: ReplateCameraView.anchorEntity)
            //            yLineRightSphereEntity.model?.materials = [SimpleMaterial(color: .orange, isMetallic: false)]
            //            yLineEntity.model?.materials = [SimpleMaterial(color: .purple, isMetallic: false)]
            //            ReplateCameraView.anchorEntity.addChild(yLineEntity)
            //            let circleEntity = ModelEntity(mesh: MeshResource.generateBox(size: 2, cornerRadius: 1))
            //            circleEntity.setPosition(SIMD3<Float>(0, 0, 0), relativeTo: ReplateCameraView.anchorEntity)
            //            circleEntity.model?.materials = [SimpleMaterial(color: .yellow, isMetallic: false)]
            
            
            ReplateCameraView.arView.scene.anchors.append(ReplateCameraView.anchorEntity)
        }
    }
    
    func createFocusSphere() {
        let sphereMesh = MeshResource.generateSphere(radius: ReplateCameraView.sphereRadius * 1.5)
        let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .white.withAlphaComponent(0.7), isMetallic: false)])
        sphereEntity.position = SIMD3(x: 0, y: ReplateCameraView.spheresHeight + (ReplateCameraView.distanceBetweenCircles / 2), z: 0)
        sphereEntity.model?.materials = [SimpleMaterial(color: .green.withAlphaComponent(1), isMetallic: false)]
        ReplateCameraView.focusModel = sphereEntity
        ReplateCameraView.anchorEntity.addChild(sphereEntity)
        sphereEntity.setPosition(sphereEntity.position, relativeTo: nil)
    }
    
    func createSphere(position: SIMD3<Float>) -> ModelEntity {
        let sphereMesh = MeshResource.generateSphere(radius: ReplateCameraView.sphereRadius)
        let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .white.withAlphaComponent(0.7), isMetallic: false)])
        sphereEntity.position = position
        return sphereEntity
    }
    
    func createSpheres(y: Float) {
        let radius = ReplateCameraView.spheresRadius
        for i in 0..<72 {
            // Adjust the angle calculation so that the first sphere starts at 0 degrees
            let angle = Float(i) * (Float.pi / 180) * 5 // 5 degrees in radians
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            let spherePosition = SIMD3<Float>(x, y, z)
            let sphereEntity = createSphere(position: spherePosition)
            if (i == 0) {
                let material = SimpleMaterial(color: .purple, isMetallic: true)
                sphereEntity.model?.materials[0] = material
            }
            ReplateCameraView.spheresModels.append(sphereEntity)
            ReplateCameraView.anchorEntity.addChild(sphereEntity)
        }
    }
    
    func setupAR() {
        print("Setup AR")
        reset()
        let width = self.frame.width
        let height = self.frame.height
        ReplateCameraView.arView = ARView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        ReplateCameraView.arView.backgroundColor = hexStringToUIColor(hexColor: "#32a852")
        addSubview(ReplateCameraView.arView)
        ReplateCameraView.arView.session.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        configuration.videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: {
                // replace with your desired frame rate range
                (30...45).contains($0.framesPerSecond)
        }) ?? ARWorldTrackingConfiguration.supportedVideoFormats.max(by: { format1, format2 in
            let resolution1 = format1.imageResolution.width * format1.imageResolution.height
            let resolution2 = format2.imageResolution.width * format2.imageResolution.height
            return resolution1 < resolution2
        })!
        ReplateCameraView.arView.renderOptions.insert(ARView.RenderOptions.disableMotionBlur)
        ReplateCameraView.arView.renderOptions.insert(ARView.RenderOptions.disableCameraGrain)
        ReplateCameraView.arView.renderOptions.insert(ARView.RenderOptions.disableAREnvironmentLighting)
        ReplateCameraView.arView.renderOptions.insert(ARView.RenderOptions.disableHDR)
        ReplateCameraView.arView.renderOptions.insert(ARView.RenderOptions.disableFaceMesh)
        ReplateCameraView.arView.renderOptions.insert(ARView.RenderOptions.disableGroundingShadows)
        ReplateCameraView.arView.renderOptions.insert(ARView.RenderOptions.disablePersonOcclusion)
        //        guard let obj = ARReferenceObject.referenceObjects(inGroupNamed: "AR Resource Group",
        //                                                           bundle: nil)
        //        else { fatalError("See no reference object") }
        //        print(obj)
        //        configuration.planeDetection = ARWorldTrackingConfiguration.PlaneDetection.horizontal
        //                ReplateCameraView.arView.debugOptions = [
        //                    .showAnchorOrigins,
        //                    .showAnchorGeometry
        //                ]
//        ReplateCameraView.arView.debugOptions = [.showStatistics]
//        if #available(iOS 16.0, *) {
//            print("recommendedVideoFormatForHighResolutionFrameCapturing")
//            configuration.videoFormat = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing ?? ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution ?? ARWorldTrackingConfiguration.supportedVideoFormats[0]
//        } else {
//            print("Alternative high resolution method")
//            let maxResolutionFormat = ARWorldTrackingConfiguration.supportedVideoFormats.max(by: { format1, format2 in
//                let resolution1 = format1.imageResolution.width * format1.imageResolution.height
//                let resolution2 = format2.imageResolution.width * format2.imageResolution.height
//                return resolution1 < resolution2
//            })!
//            configuration.videoFormat = maxResolutionFormat
//        }
        //        configuration.detectionObjects = obj
        ReplateCameraView.arView.session.run(configuration)
        ReplateCameraView.arView.addCoaching()
        ReplateCameraView.sessionId = ReplateCameraView.arView.session.identifier
    }
    
    @objc var color: String = "" {
        didSet {
            self.backgroundColor = hexStringToUIColor(hexColor: color)
        }
    }
    
    func hexStringToUIColor(hexColor: String) -> UIColor {
        let stringScanner = Scanner(string: hexColor)
        
        if (hexColor.hasPrefix("#")) {
            stringScanner.scanLocation = 1
        }
        var color: UInt32 = 0
        stringScanner.scanHexInt32(&color)
        
        let r = CGFloat(Int(color >> 16) & 0x000000FF)
        let g = CGFloat(Int(color >> 8) & 0x000000FF)
        let b = CGFloat(Int(color) & 0x000000FF)
        
        return UIColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: 1)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Handle AR frame updates
        // You can perform actions here, such as updating the AR content based on the camera frame
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Handle session interruption (e.g., app goes to the background)
        
        // Pause the AR session to save resources
        if (session.identifier == ReplateCameraView.sessionId) {
            ReplateCameraView.arView.session.pause()
            ReplateCameraView.isPaused = true
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Handle resuming session after interruption
        if (session.identifier == ReplateCameraView.sessionId) {
            ReplateCameraView.isPaused = false
            setupAR()
        }
    }
    
    func reset() {
        ReplateCameraView.anchorEntity = nil
        ReplateCameraView.model = nil
        ReplateCameraView.spheresModels = []
        ReplateCameraView.upperSpheresSet = [Bool](repeating: false, count: 72)
        ReplateCameraView.lowerSpheresSet = [Bool](repeating: false, count: 72)
        ReplateCameraView.totalPhotosTaken = 0
        ReplateCameraView.photosFromDifferentAnglesTaken = 0
        ReplateCameraView.sphereRadius = Float(0.0025 * 2)
        ReplateCameraView.spheresRadius = Float(0.15)
        ReplateCameraView.sphereAngle = Float(5)
        ReplateCameraView.spheresHeight = Float(0.01)
        ReplateCameraView.dragSpeed = CGFloat(7000)
        ReplateCameraView.arView = nil
    }
    
    static func generateImpactFeedback(strength: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: strength)
        impactFeedbackGenerator.prepare()
        impactFeedbackGenerator.impactOccurred()
    }
    
}

@objc(ReplateCameraController)
class ReplateCameraController: NSObject {
    
    static var completedTutorialCallback: RCTResponseSenderBlock?
    static var anchorSetCallback: RCTResponseSenderBlock?
    static var completedUpperSpheresCallback: RCTResponseSenderBlock?
    static var completedLowerSpheresCallback: RCTResponseSenderBlock?
    static var openedTutorialCallback: RCTResponseSenderBlock?
    
    @objc(registerOpenedTutorialCallback:)
    func registerOpenedTutorialCallback(_ myCallback: @escaping RCTResponseSenderBlock) {
        ReplateCameraController.openedTutorialCallback = myCallback
    }
    
    @objc(registerCompletedTutorialCallback:)
    func registerCompletedTutorialCallback(_ myCallback: @escaping RCTResponseSenderBlock) {
        ReplateCameraController.completedTutorialCallback = myCallback
    }
    
    @objc(registerAnchorSetCallback:)
    func registerAnchorSetCallback(_ myCallback: @escaping RCTResponseSenderBlock) {
        ReplateCameraController.anchorSetCallback = myCallback
    }
    
    @objc(registerCompletedUpperSpheresCallback:)
    func registerCompletedUpperSpheresCallback(_ myCallback: @escaping RCTResponseSenderBlock) {
        ReplateCameraController.completedUpperSpheresCallback = myCallback
    }
    
    @objc(registerCompletedLowerSpheresCallback:)
    func registerCompletedLowerSpheresCallback(_ myCallback: @escaping RCTResponseSenderBlock) {
        ReplateCameraController.completedLowerSpheresCallback = myCallback
    }
    
    @objc(getPhotosCount:rejecter:)
    func getPhotosCount(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) -> Void {
        resolver(ReplateCameraView.totalPhotosTaken)
    }
    
    @objc(isScanComplete:rejecter:)
    func isScanComplete(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) -> Void {
        resolver(ReplateCameraView.photosFromDifferentAnglesTaken == 144)
    }
    
    @objc(getRemainingAnglesToScan:rejecter:)
    func getRemainingAnglesToScan(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) -> Void {
        resolver(144 - ReplateCameraView.photosFromDifferentAnglesTaken)
    }
    
    @objc(takePhoto:resolver:rejecter:)
    func takePhoto(_ unlimited: Bool = false, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) -> Void {
        guard let anchorNode = ReplateCameraView.anchorEntity else {
            rejecter("[ReplateCameraController]", "No anchor set yet", NSError(domain: "ReplateCameraController", code: 001, userInfo: nil))
            return
        }
        
        // Calculate anchor position and height-related constants once
        let anchorPosition = anchorNode.position(relativeTo: nil)
        let spheresHeight = ReplateCameraView.spheresHeight
        let distanceBetweenCircles = ReplateCameraView.distanceBetweenCircles
        
        // Precomputed points
        let point1Y = anchorPosition.y + spheresHeight
        let point2Y = anchorPosition.y + distanceBetweenCircles + spheresHeight
        let twoThirdsDistance = point1Y + (2 / 3) * (point2Y - point1Y)

        var deviceTargetInFocus = -1
        
        // Simple angle threshold for checking if looking at anchor
        let angleThreshold: Float = 0.6  // Adjustable
        
        if let cameraTransform = ReplateCameraView.arView.session.currentFrame?.camera.transform {
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            let deviceDirection = normalize(SIMD3<Float>(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z))
            let directionToAnchor = normalize(anchorPosition - cameraPosition)
            let angleToAnchor = acos(dot(deviceDirection, directionToAnchor))
            
            // Check if camera is looking at the anchor
            if angleToAnchor < angleThreshold {
                // Use camera height to determine if looking at point1 or point2
                let cameraHeight = cameraPosition.y
                if cameraHeight < twoThirdsDistance {
                    deviceTargetInFocus = 0
                    print("Is pointing at first point")
                } else {
                    deviceTargetInFocus = 1
                    print("Is pointing at second point")
                }
            } else {
                print("Not pointing at anchor")
            }
        } else {
            print("Camera transform data not available")
            rejecter("[ReplateCameraController]", "Camera transform data not available", NSError(domain: "ReplateCameraController", code: 005, userInfo: nil))
            return
        }
        
        print("Take photo")
        if deviceTargetInFocus != -1 {
            let newAngle = updateSpheres(deviceTargetInFocus: deviceTargetInFocus)
            if !unlimited && !newAngle {
                rejecter("[ReplateCameraController]", "Too many images and the last one's not from a new angle", NSError(domain: "ReplateCameraController", code: 005, userInfo: nil))
                return
            }
            
            if let image = ReplateCameraView.arView?.session.currentFrame?.capturedImage {
                let ciImage = CIImage(cvImageBuffer: image)
                guard let cgImage = ReplateCameraController.cgImage(from: ciImage) else {
                    rejecter("[ReplateCameraController]", "Error converting CIImage to CGImage", NSError(domain: "ReplateCameraController", code: 004, userInfo: nil))
                    return
                }
                let uiImage = UIImage(cgImage: cgImage)
                let finImage = uiImage.rotate(radians: .pi / 2) // Adjust radians as needed
                
                guard let components = finImage.averageColor()?.getRGBComponents() else {
                    rejecter("[ReplateCameraController]", "Cannot get color components", NSError(domain: "ReplateCameraController", code: 003, userInfo: nil))
                    return
                }
                
                let averagePixelColor = (components.red + components.blue + components.green) / 3
                print("Average pixel color: \(averagePixelColor)")
                if averagePixelColor < 0.15 {
                    rejecter("[ReplateCameraController]", "Image too dark", NSError(domain: "ReplateCameraController", code: 004, userInfo: nil))
                    return
                }
                
                print("Saving photo")
                if let url = ReplateCameraController.saveImageAsJPEG(finImage) {
                    resolver(url.absoluteString)
                    print("Saved photo")
                    return
                } else {
                    rejecter("[ReplateCameraController]", "Error saving photo", NSError(domain: "ReplateCameraController", code: 001, userInfo: nil))
                    return
                }
            }
        } else {
            rejecter("[ReplateCameraController]", "Object not in focus", NSError(domain: "ReplateCameraController", code: 002, userInfo: nil))
            return
        }
        
        rejecter("[ReplateCameraController]", "Error saving photo", NSError(domain: "ReplateCameraController", code: 001, userInfo: nil))
    }
    
    
    static func cgImage(from ciImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
    
    
    static func saveImageAsJPEG(_ image: UIImage) -> URL? {
        // Convert UIImage to Data with JPEG representation
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            // Handle error if unable to convert to JPEG data
            print("Error converting UIImage to JPEG data")
            return nil
        }
        
        //        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // Get the temporary directory URL
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        
        // Create a unique filename (you can use a UUID or any other method to generate a unique name)
        let uniqueFilename = "image_\(Date().timeIntervalSince1970).jpg"
        
        // Combine the temporary directory URL with the unique filename to get the full file URL
        let fileURL = temporaryDirectoryURL.appendingPathComponent(uniqueFilename)
        
        do {
            // Write the JPEG data to the file
            try imageData.write(to: fileURL, options: .atomic)
            
            // Print the file URL for reference
            print("Image saved at: \(fileURL.absoluteString)")
            return fileURL
        } catch {
            // Handle the error if unable to write to the file
            print("Error saving image: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateSpheres(deviceTargetInFocus: Int) -> Bool {
        guard let anchorNode = ReplateCameraView.anchorEntity else {
            return false
        }
        
        // Get the camera's pose
        guard let frame = ReplateCameraView.arView.session.currentFrame else {
            return false
        }
        
        let cameraTransform = frame.camera.transform
        
        // Calculate the angle between the camera and the anchor
        let angleDegrees = ReplateCameraController.angleBetweenAnchorXAndCamera(anchor: anchorNode, cameraTransform: cameraTransform)
        let sphereIndex = max(Int(round(angleDegrees / 5.0)), 0) % 72 // Ensure sphereIndex stays within 0-71 bounds
        
        var mesh: ModelEntity?
        var newAngle = false
        var callback: RCTResponseSenderBlock? = nil
        print("Sphere index \(sphereIndex) - Spheres length \(ReplateCameraView.spheresModels.count)")
        if deviceTargetInFocus == 1 {
            if !ReplateCameraView.upperSpheresSet[sphereIndex] {
                ReplateCameraView.upperSpheresSet[sphereIndex] = true
                ReplateCameraView.photosFromDifferentAnglesTaken += 1
                newAngle = true
                mesh = ReplateCameraView.spheresModels[72 + sphereIndex]
                if ReplateCameraView.upperSpheresSet.allSatisfy({ $0 }) {
                    callback = ReplateCameraController.completedUpperSpheresCallback
                    ReplateCameraController.completedUpperSpheresCallback = nil
                }
            }
        } else if deviceTargetInFocus == 0 {
            if !ReplateCameraView.lowerSpheresSet[sphereIndex] {
                ReplateCameraView.lowerSpheresSet[sphereIndex] = true
                ReplateCameraView.photosFromDifferentAnglesTaken += 1
                newAngle = true
                mesh = ReplateCameraView.spheresModels[sphereIndex]
                if ReplateCameraView.lowerSpheresSet.allSatisfy({ $0 }) {
                    callback = ReplateCameraController.completedLowerSpheresCallback
                    ReplateCameraController.completedLowerSpheresCallback = nil
                }
            }
        }
        
        if let mesh = mesh {
            let material = SimpleMaterial(color: .green, isMetallic: false)
            mesh.model?.materials[0] = material
            ReplateCameraView.generateImpactFeedback(strength: .medium)
        }
        
        callback?([])
        
        return newAngle
    }
    
    static func angleBetweenAnchorXAndCamera(anchor: AnchorEntity, cameraTransform: simd_float4x4) -> Float {
        // Extract the position of the anchor and the camera from their transforms, ignoring the y-axis
        let anchorPositionXZ = simd_float2(anchor.transform.translation.x, anchor.transform.translation.z)
        // Transform the camera position to the anchor's local space
        let anchorTransform = anchor.transformMatrix(relativeTo: nil)
        let relativePosition = anchorTransform.inverse * cameraTransform
        let relativeCameraPositionXZ = simd_float2(relativePosition.columns.3.x, relativePosition.columns.3.z)
        
        // Calculate the direction vector from the anchor to the camera in the XZ plane
        let directionXZ = relativeCameraPositionXZ - anchorPositionXZ
        
        // Extract the x-axis of the anchor's transform in the XZ plane
        let anchorXAxisXZ = simd_float2(anchorTransform.columns.0.x, anchorTransform.columns.0.z)
        
        // Use atan2 to calculate the angle between the anchor's x-axis and the direction vector in the XZ plane
        let angle = atan2(directionXZ.y, directionXZ.x) - atan2(anchorXAxisXZ.y, anchorXAxisXZ.x)
        
        // Convert the angle to degrees
        var angleDegrees = angle * (180.0 / .pi)
        
        // Ensure the angle is within the range [0, 360)
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        
        return angleDegrees
    }
    
}

extension ARView: ARCoachingOverlayViewDelegate {
    func addCoaching() {
        print("ADD COACHING")
        // Create a ARCoachingOverlayView object
        let coachingOverlay = ARCoachingOverlayView()
        // Make sure it rescales if the device orientation changes
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(coachingOverlay)
        coachingOverlay.center = self.convert(self.center, from: self.superview)
        // Set the Augmented Reality goal
        coachingOverlay.goal = .horizontalPlane
        // Set the ARSession
        coachingOverlay.session = self.session
        // Set the delegate for any callbacks
        coachingOverlay.delegate = self
        coachingOverlay.setActive(true, animated: true)
        ReplateCameraView.generateImpactFeedback(strength: .light)
        let callback = ReplateCameraController.openedTutorialCallback
        if (callback != nil) {
            callback!([])
            ReplateCameraController.openedTutorialCallback = nil
        }
    }
    
    // Example callback for the delegate object
    public func coachingOverlayViewDidDeactivate(
        _ coachingOverlayView: ARCoachingOverlayView
    ) {
        print("DEACTIVATED")
        let callback = ReplateCameraController.completedTutorialCallback
        if (callback != nil) {
            callback!([])
            ReplateCameraController.completedTutorialCallback = nil
        }
        ReplateCameraView.generateImpactFeedback(strength: .heavy)
        ReplateCameraView.addRecognizer()
        print("CRASHED")
    }
}

extension UIImage {
    func averageColor() -> UIColor? {
        // Convert UIImage to CGImage
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        // Get width and height of the image
        let width = cgImage.width
        let height = cgImage.height
        
        // Create a data provider from CGImage
        guard let dataProvider = cgImage.dataProvider else {
            return nil
        }
        
        // Access pixel data
        guard let pixelData = dataProvider.data else {
            return nil
        }
        
        // Create a pointer to the pixel data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        
        // Loop through each pixel and calculate sum of RGB values
        for y in 0..<height {
            for x in 0..<width {
                let pixelInfo: Int = ((width * y) + x) * 4
                let red = CGFloat(data[pixelInfo]) / 255.0
                let green = CGFloat(data[pixelInfo + 1]) / 255.0
                let blue = CGFloat(data[pixelInfo + 2]) / 255.0
                
                totalRed += red
                totalGreen += green
                totalBlue += blue
            }
        }
        
        // Calculate average RGB values
        let count = CGFloat(width * height)
        let averageRed = totalRed / count
        let averageGreen = totalGreen / count
        let averageBlue = totalBlue / count
        
        // Create and return average color
        return UIColor(red: averageRed, green: averageGreen, blue: averageBlue, alpha: 1.0)
    }
}

extension UIColor {
    func getRGBComponents() -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Check if the color can be converted to RGB
        guard self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        return (red, green, blue)
    }
}

public extension simd_float2 {
    static func -(lhs: simd_float2, rhs: simd_float2) -> simd_float2 {
        return simd_float2(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
