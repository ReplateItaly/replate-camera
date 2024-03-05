import {
  requireNativeComponent,
  UIManager,
  Platform,
  type ViewStyle,
} from 'react-native';

const LINKING_ERROR =
  `The package 'replate-camera' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

type ReplateCameraProps = {
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
