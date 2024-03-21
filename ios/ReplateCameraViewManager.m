#import <React/RCTViewManager.h>
#import <React/RCTUIManager.h>
#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(ReplateCameraViewManager, RCTViewManager)

// RCT_EXPORT_VIEW_PROPERTY(rect, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(color, NSString)


@end


@interface RCT_EXTERN_MODULE(ReplateCameraController, NSObject)

RCT_EXTERN_METHOD(takePhoto:(RCTPromiseResolveBlock*)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getPhotosCount:(RCTPromiseResolveBlock*)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(isScanComplete:(RCTPromiseResolveBlock*)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

@end
