@objc(ReplateCameraController)
class ReplateCameraController: NSObject {

 @objc(takePhoto:rejecter:)
 func takePhoto(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) -> Void {
    print("Take photo")
    resolver("Photo taken")
 }

 @objc
 func constantsToExport() -> [String: Any]! {
   return ["someKey": "someValue"]
 }

}
