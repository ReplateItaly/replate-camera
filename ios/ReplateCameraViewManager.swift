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
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

class ReplateCameraView : UIView, ARSessionDelegate {

    static var arView: ARView!
    static var anchorEntity: AnchorEntity!
    static var model: Entity!
    static var spheresModels: [ModelEntity] = []
    static var upperSpheresSet: [Bool] = [Bool](repeating: false, count: 72)
    static var lowerSpheresSet: [Bool] = [Bool](repeating: false, count: 72)
    static var totalPhotosTaken: Int = 0
    static var photosFromDifferentAnglesTaken = 0
    static var INSTANCE: ReplateCameraView!

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

    static func addRecognizer(){
        let recognizer = UITapGestureRecognizer(target: ReplateCameraView.INSTANCE,
                                                action: #selector(ReplateCameraView.INSTANCE.viewTapped(_:)))
        ReplateCameraView.arView.addGestureRecognizer(recognizer)
    }
    
    func requestCameraPermissions(){

        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
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
    
    
    @objc private func viewTapped(_ recognizer: UITapGestureRecognizer) {
        print("VIEW TAPPED")
//        guard !ReplateCameraView.arView.canBecomeFocused else {
//            return
//        }
        
        let tapLocation: CGPoint = recognizer.location(in: ReplateCameraView.arView)
        let estimatedPlane: ARRaycastQuery.Target = .estimatedPlane
        let alignment: ARRaycastQuery.TargetAlignment = .horizontal
        
        let result: [ARRaycastResult] = ReplateCameraView.arView.raycast(from: tapLocation,
                                                       allowing: estimatedPlane,
                                                       alignment: alignment)
        
        guard let rayCast: ARRaycastResult = result.first
        else { return }
        let anchor = AnchorEntity(raycastResult: rayCast)
        print("ANCHOR FOUND\n", anchor.transform)
        if (ReplateCameraView.model == nil && ReplateCameraView.anchorEntity == nil){
            ReplateCameraView.anchorEntity = anchor
            let anchorTransform = anchor.transform
            //            let path = Bundle.main.path(forResource: "anchor", ofType: "usdz")!
            //            let url = URL(fileURLWithPath: path)
            //            let entity: ModelEntity = try! ModelEntity.loadModel(contentsOf: url)
            
            //            if #available(iOS 15.0, *) {
            //                entity.model!.mesh.
            //                ReplateCameraView.spheresModels = Array(entity.model!.mesh.contents.models)
            //            }
            //            entity.scale *= 4.5
            //            entity.position = SIMD3(anchorTransform.columns.3.x, anchorTransform.columns.3.y, anchorTransform.columns.3.z)
            
            func createSphere(position: SIMD3<Float>) -> ModelEntity {
                let sphereMesh = MeshResource.generateSphere(radius: 0.0025)
                let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .white.withAlphaComponent(0.7), isMetallic: false)])
                sphereEntity.position = position
                return sphereEntity
            }
            
            func createSpheres(y: Float){
                let radius = Float(0.1)
                for i in 0..<72 {
                    let angle = Float(i) * (Float.pi / 180) * 5 // 10 degrees in radians
                    let x = radius * cos(angle)
                    let z = radius * sin(angle)
                    let spherePosition = SIMD3<Float>(x, y, z)
                    let sphereEntity = createSphere(position: spherePosition)
                    ReplateCameraView.spheresModels.append(sphereEntity)
                    ReplateCameraView.anchorEntity.addChild(sphereEntity)
                }
            }
            
            createSpheres(y: 0.0)
            createSpheres(y: 0.3)
            ReplateCameraView.arView.scene.anchors.append(ReplateCameraView.anchorEntity)
        }
    }

    func setupAR() {
        print("Setup AR")
        let width = self.frame.width
        let height = self.frame.height
        ReplateCameraView.arView = ARView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        ReplateCameraView.arView.backgroundColor = hexStringToUIColor(hexColor: "#32a852")
        addSubview(ReplateCameraView.arView)
        ReplateCameraView.arView.session.delegate = self
        let configuration = ARWorldTrackingConfiguration()
//        guard let obj = ARReferenceObject.referenceObjects(inGroupNamed: "AR Resource Group",
//                                                           bundle: nil)
//        else { fatalError("See no reference object") }
//        print(obj)
        configuration.planeDetection = ARWorldTrackingConfiguration.PlaneDetection.horizontal
//        ReplateCameraView.arView.debugOptions = [
//            .showAnchorOrigins,
//            .showAnchorGeometry
//        ]
        if #available(iOS 16.0, *) {
            print("recommendedVideoFormatForHighResolutionFrameCapturing")
            configuration.videoFormat = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing ?? ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution ?? ARWorldTrackingConfiguration.supportedVideoFormats[0]
        } else {
            print("Alternative high resolution method")
            let maxResolutionFormat = ARWorldTrackingConfiguration.supportedVideoFormats.max(by: { format1, format2 in
                let resolution1 = format1.imageResolution.width * format1.imageResolution.height
                let resolution2 = format2.imageResolution.width * format2.imageResolution.height
                return resolution1 < resolution2
            })!
            configuration.videoFormat = maxResolutionFormat
        }
//        configuration.detectionObjects = obj
        ReplateCameraView.arView.session.run(configuration)
        
        ReplateCameraView.arView.addCoaching()
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
    }


    @objc var color: String = "" {
        didSet {
            self.backgroundColor = hexStringToUIColor(hexColor: color)
        }
    }

    func hexStringToUIColor(hexColor: String) -> UIColor {
        let stringScanner = Scanner(string: hexColor)

        if(hexColor.hasPrefix("#")) {
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
        ReplateCameraView.arView.session.pause()
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Handle resuming session after interruption

        // Resume the AR session
        ReplateCameraView.arView.session.run(ARWorldTrackingConfiguration())
    }

}

@objc(ReplateCameraController)
class ReplateCameraController: RCTEventEmitter {
    
    static var INSTANCE: ReplateCameraController!
    
    override init() {
        super.init()
        ReplateCameraController.INSTANCE = self
    }

    @objc(getPhotosCount:rejecter:)
    func getPhotosCount(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) -> Void{
        resolver(ReplateCameraView.totalPhotosTaken)
    }
    
    @objc(isScanComplete:rejecter:)
    func isScanComplete(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) -> Void{
        resolver(ReplateCameraView.photosFromDifferentAnglesTaken == 144)
    }
    
    @objc(getRemainingAnglesToScan:rejecter:)
    func getRemainingAnglesToScan(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) -> Void{
        resolver(144 - ReplateCameraView.photosFromDifferentAnglesTaken)
    }
    
    @objc(takePhoto:rejecter:)
       func takePhoto(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) -> Void {
           
           //DEVICE ORIENTATION
           guard let anchorNode = ReplateCameraView.anchorEntity else {
               rejecter("[ReplateCameraController]", "Error saving photo", NSError(domain: "ReplateCameraController", code: 001, userInfo: nil));
               return
           }
           
           // Assuming you have two points
           let point1 = SIMD3<Float>(anchorNode.position.x,
                                     anchorNode.position.y,
                                     anchorNode.position.z)
           let point2 = SIMD3<Float>(anchorNode.position.x,
                                     anchorNode.position.y + 0.3,
                                     anchorNode.position.z)
           
           // Function to calculate the angle between two vectors
           func angleBetweenVectors(_ vector1: SIMD3<Float>, _ vector2: SIMD3<Float>) -> Float {
               let dotProduct = dot(normalize(vector1), normalize(vector2))
               return acos(dotProduct)
           }
           
           // Threshold angle for considering if the device is pointing towards a point
           let thresholdAngle: Float = 0.3 // Adjust this threshold as needed
           var deviceTargetInFocus = -1
           // Check if the device is pointing towards one of the two points
           if let cameraTransform = ReplateCameraView.arView.session.currentFrame?.camera.transform {
               let deviceDirection = SIMD3<Float>(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
               
               let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
               
               let directionToFirstPoint = normalize(point1 - cameraPosition)
               let directionToSecondPoint = normalize(point2 - cameraPosition)
               
               let angleToFirstPoint = angleBetweenVectors(deviceDirection, directionToFirstPoint)
               let angleToSecondPoint = angleBetweenVectors(deviceDirection, directionToSecondPoint)
               print("Camera Y: \(cameraPosition.y)")
               let isPointingAtFirstPoint = angleToFirstPoint < thresholdAngle && cameraPosition.y < 0.25
               let isPointingAtSecondPoint = angleToSecondPoint < thresholdAngle && cameraPosition.y >= 0.25
               if (isPointingAtFirstPoint) {
                   deviceTargetInFocus = 0
               }else if(isPointingAtSecondPoint){
                   deviceTargetInFocus = 1
               }
               // Now you can determine if the device is pointing towards one of the two points
               print("Is pointing at first point: \(isPointingAtFirstPoint)")
               print("Is pointing at second point: \(isPointingAtSecondPoint)")
           } else {
               print("Camera transform data not available")
               rejecter("[ReplateCameraController]", "Camera transform data not available", NSError(domain: "ReplateCameraController", code: 003, userInfo: nil))
               return
           }
           
          print("Take photo")
           if(deviceTargetInFocus != -1){
               if let image = ReplateCameraView.arView?.session.currentFrame?.capturedImage {
                   let ciimg = CIImage(cvImageBuffer: image)
                   let ciImage = ciimg
                   let cgImage = ReplateCameraController.cgImage(from: ciImage)!
                   let uiImage = UIImage(cgImage: cgImage)
                   let finImage = uiImage.rotate(radians: .pi/2) // Adjust radians as needed

                   print("Saving photo")
                   if let url = ReplateCameraController.saveImageAsJPEG(finImage) {
                       resolver(url.absoluteString)
                       print("Saved photo")
                       updateSpheres(deviceTargetInFocus: deviceTargetInFocus)
                       return
                   }
               }
           }else{
               rejecter("[ReplateCameraController]", "Object not in focus", NSError(domain: "ReplateCameraController", code: 002, userInfo: nil))
               return
           }
           
           print("Error saving photo")
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
    
    @objc
    func sendTutorialEndedEvent(){
        self.sendEvent(withName: "arTutorialCompleted", body: true)
    }
    
    
    func updateSpheres(deviceTargetInFocus: Int) {
        guard let anchorNode = ReplateCameraView.anchorEntity else { return }
        
        // Get the camera's pose
        if let frame = ReplateCameraView.arView.session.currentFrame {
            let cameraTransform = frame.camera.transform
            
            // Calculate the angle between the camera and the anchor
            let anchorPosition = SCNVector3(anchorNode.position.x,
                                            anchorNode.position.y,
                                            anchorNode.position.z)
            let cameraPosition = SCNVector3(cameraTransform.columns.3.x,
                                            cameraTransform.columns.3.y,
                                            cameraTransform.columns.3.z)
            
            let angleToAnchor = calculateAngle(cameraPosition, anchorPosition)
            
            let sphereIndex = Int(floor(angleToAnchor/5))
            var mesh: ModelEntity?
            if(deviceTargetInFocus == 1 && !ReplateCameraView.upperSpheresSet[sphereIndex]){
                if(!ReplateCameraView.upperSpheresSet[sphereIndex]){
                    ReplateCameraView.upperSpheresSet[sphereIndex] = true
                    ReplateCameraView.photosFromDifferentAnglesTaken += 1
                }
                mesh = ReplateCameraView.spheresModels[72+sphereIndex]
            }else if(deviceTargetInFocus == 0 && !ReplateCameraView.lowerSpheresSet[sphereIndex]){
                if(!ReplateCameraView.lowerSpheresSet[sphereIndex]){
                    ReplateCameraView.lowerSpheresSet[sphereIndex] = true
                    ReplateCameraView.photosFromDifferentAnglesTaken += 1
                }
                mesh = ReplateCameraView.spheresModels[sphereIndex]
            }
            if (mesh != nil){
                let material = SimpleMaterial(color: .green, isMetallic: false)
                mesh?.model?.materials[0] = material
            }
        }
    }
    
    func calculateAngle(_ vector1: SCNVector3, _ vector2: SCNVector3) -> Float {
        // Calculate the angle in 2D plane (x-z plane) using atan2
        let angle = atan2(vector1.z, vector1.x)
        
        // Convert from radians to degrees
        var angleInDegrees = GLKMathRadiansToDegrees(Float(angle))
        
        // Adjust the angle to be between 0 and 360 degrees
        if angleInDegrees < 0 {
            angleInDegrees += 360
        }
        
        return angleInDegrees
    }

}

extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let length = sqrt(x*x + y*y + z*z)
        return SCNVector3(x/length, y/length, z/length)
    }
    
    static func Dot(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        return a.x*b.x + a.y*b.y + a.z*b.z
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
        coachingOverlay.center = self.convert(self.center, from:self.superview)
        // Set the Augmented Reality goal
        coachingOverlay.goal = .horizontalPlane
        // Set the ARSession
        coachingOverlay.session = self.session
        // Set the delegate for any callbacks
        coachingOverlay.delegate = self
        coachingOverlay.setActive(true, animated: true)
    }
    // Example callback for the delegate object
    public func coachingOverlayViewDidDeactivate(
        _ coachingOverlayView: ARCoachingOverlayView
    ) {
        print("DEACTIVATED")
        ReplateCameraController.INSTANCE.sendTutorialEndedEvent()
        ReplateCameraView.addRecognizer()
        print("CRASHED")
    }
}
