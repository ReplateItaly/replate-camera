import * as React from 'react';

import { StyleSheet, View } from 'react-native';
import { ReplateCameraView, reset, takePhoto } from 'replate-camera';
import { useEffect } from 'react';

export default function App() {
  useEffect(() => {
    setTimeout(() => {
      reset();
    }, 100);
  }, []);
  setInterval(() => {
    takePhoto(false)
      .then((uri) => {
        console.log('Photo taken:', uri);
      })
      .catch((error) => {
        console.error('Failed to take photo:', error);
      });
  }, 500);

  return (
    <View style={styles.container}>
      <ReplateCameraView
        // rect={{
        //   x: 0.1,
        //   y: 0.1,
        //   width: 0.8,
        //   height: 0.8,
        // }}
        color="#FF0000"
        style={styles.box}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    width: '100%',
    backgroundColor: '#68d0ff',
  },
  box: {
    width: '100%',
    height: '100%',
    marginVertical: 20,
    backgroundColor: '#c368ff',
  },
});
