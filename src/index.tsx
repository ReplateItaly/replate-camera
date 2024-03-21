import {
  requireNativeComponent,
  UIManager,
  Platform,
  type ViewStyle,
  NativeModules,
} from 'react-native';

const LINKING_ERROR =
  `The package 'replate-camera' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

type ReplateCameraProps = {
  // rect: Object;
  color: string;
  style: ViewStyle;
};

const ComponentName = 'ReplateCameraView';

export const ReplateCameraView =
  UIManager.getViewManagerConfig(ComponentName) != null
    ? requireNativeComponent<ReplateCameraProps>(ComponentName)
    : () => {
        throw new Error(LINKING_ERROR);
      };

const ReplateCameraModule = NativeModules.ReplateCameraController
  ? NativeModules.ReplateCameraController
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function takePhoto(): Promise<string> {
  return ReplateCameraModule.takePhoto();
}

export function getPhotosCount(): Promise<number> {
  return ReplateCameraModule.getPhotosCount();
}

export function isScanComplete(): Promise<boolean> {
  return ReplateCameraModule.isScanComplete();
}
