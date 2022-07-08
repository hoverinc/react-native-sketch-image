/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow strict-local
 */

import type { Node } from "react";
import React, { useRef, useState } from "react";
import { Alert, Platform, ScrollView, StyleSheet, Text, TouchableOpacity, useColorScheme, View } from "react-native";

import { Colors } from "react-native/Libraries/NewAppScreen";

import RNImageEditor, { ImageEditor } from "@hoverinc/react-native-sketch-canvas";
import { RNCamera } from "react-native-camera";
import { BuildInUIComponents } from "./src/BuildInUIComponents";
import { CanvasOnly } from "./src/CanvasOnly";

const App: () => Node = () => {
  const isDarkMode = useColorScheme() === "dark";
  const [state, setAllState] = useState({
    example: 0,
    color: "#FF0000",
    thickness: 5,
    message: "",
    photoPath: null,
    scrollEnabled: true,
    touchEnabled: true,
  });
  const canvas = useRef();
  const canvas1 = useRef();
  const canvas2 = useRef();
  const camera = useRef();

  const setState = (partial) => {
    setAllState(prev => ({
      ...prev,
      ...partial,
    }));
  };
  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  const takePicture = async () => {
    if (camera.current) {
      const options = { quality: 0.5, base64: true };
      const data = await camera.current.takePictureAsync(options);
      setState({
        photoPath: data.uri.replace("file://", ""),
      });
    }
  };

  return (
    <View style={styles.container}>
      {
        state.example === 0 &&
        <View style={{ justifyContent: "center", alignItems: "center", width: 340 }}>
          <TouchableOpacity onPress={() => {
            setState({ example: 1 });
          }}>
            <Text style={{ alignSelf: "center", marginTop: 15, fontSize: 18 }}>- Example 1 -</Text>
            <Text>Use build-in UI components</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => {
            setState({ example: 2 });
          }}>
            <Text style={{ alignSelf: "center", marginTop: 15, fontSize: 18 }}>- Example 2 -</Text>
            <Text>Use canvas only and customize UI components</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => {
            setState({ example: 3 });
          }}>
            <Text style={{ alignSelf: "center", marginTop: 15, fontSize: 18 }}>- Example 3 -</Text>
            <Text>Sync two canvases</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => {
            setState({ example: 4 });
          }}>
            <Text style={{ alignSelf: "center", marginTop: 15, fontSize: 18 }}>- Example 4 -</Text>
            <Text>Take a photo first</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => {
            setState({ example: 5 });
          }}>
            <Text style={{ alignSelf: "center", marginTop: 15, fontSize: 18 }}>- Example 5 -</Text>
            <Text>Load local image</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => {
            setState({ example: 6 });
          }}>
            <Text style={{ alignSelf: "center", marginTop: 15, fontSize: 18 }}>- Example 6 -</Text>
            <Text>Draw text on canvas</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => {
            setState({ example: 7 });
          }}>
            <Text style={{ alignSelf: "center", marginTop: 15, fontSize: 18 }}>- Example 7 -</Text>
            <Text>Multiple canvases in ScrollView</Text>
          </TouchableOpacity>
        </View>
      }

      {
        state.example === 1 &&
        <BuildInUIComponents canvas={canvas} setState={setState} state={state} styles={styles} />
      }

      {
        state.example === 2 &&
        <CanvasOnly canvas={canvas} setState={setState} state={state} styles={styles} />
      }

      {
        state.example === 3 &&
        <View style={{ flex: 1, flexDirection: "column" }}>
          <RNImageEditor
            ref={canvas1}
            user={"user1"}
            containerStyle={{ backgroundColor: "transparent", flex: 1 }}
            canvasStyle={{ backgroundColor: "transparent", flex: 1 }}
            onStrokeEnd={data => {
            }}
            closeComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Close</Text></View>}
            onClosePressed={() => {
              setState({ example: 0 });
            }}
            undoComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Undo</Text></View>}
            onUndoPressed={(id) => {
              canvas2.current.deletePath(id);
            }}
            clearComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Clear</Text></View>}
            onClearPressed={() => {
              canvas2.current.clear();
            }}
            eraseComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Eraser</Text></View>}
            strokeComponent={color => (
              <View style={[{ backgroundColor: color }, styles.strokeColorButton]} />
            )}
            strokeSelectedComponent={(color, index, changed) => {
              return (
                <View style={[{ backgroundColor: color, borderWidth: 2 }, styles.strokeColorButton]} />
              );
            }}
            strokeWidthComponent={(w) => {
              return (<View style={styles.strokeWidthButton}>
                  <View style={{
                    backgroundColor: "white",
                    marginHorizontal: 2.5,
                    width: Math.sqrt(w / 3) * 10,
                    height: Math.sqrt(w / 3) * 10,
                    borderRadius: Math.sqrt(w / 3) * 10 / 2,
                  }} />
                </View>
              );
            }}
            defaultStrokeIndex={0}
            defaultStrokeWidth={5}
            saveComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Save</Text></View>}
            savePreference={() => {
              return {
                folder: "RNImageEditor",
                filename: String(Math.ceil(Math.random() * 100000000)),
                transparent: true,
                imageType: "jpg",
              };
            }}
            onSketchSaved={(success, path) => {
              Alert.alert(success ? "Image saved!" : "Failed to save image!", path);
            }}
            onStrokeEnd={(path) => {
              canvas2.current.addPath(path);
            }}
            onPathsChange={(pathsCount) => {
              console.log("pathsCount(user1)", pathsCount);
            }}
          />
          <RNImageEditor
            ref={canvas2}
            user={"user2"}
            containerStyle={{ backgroundColor: "transparent", flex: 1 }}
            canvasStyle={{ backgroundColor: "transparent", flex: 1 }}
            onStrokeEnd={data => {
            }}
            undoComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Undo</Text></View>}
            onUndoPressed={(id) => {
              canvas1.current.deletePath(id);
            }}
            clearComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Clear</Text></View>}
            onClearPressed={() => {
              canvas1.current.clear();
            }}
            eraseComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Eraser</Text></View>}
            strokeComponent={color => (
              <View style={[{ backgroundColor: color }, styles.strokeColorButton]} />
            )}
            strokeSelectedComponent={(color, index, changed) => {
              return (
                <View style={[{ backgroundColor: color, borderWidth: 2 }, styles.strokeColorButton]} />
              );
            }}
            strokeWidthComponent={(w) => {
              return (<View style={styles.strokeWidthButton}>
                  <View style={{
                    backgroundColor: "white",
                    marginHorizontal: 2.5,
                    width: Math.sqrt(w / 3) * 10,
                    height: Math.sqrt(w / 3) * 10,
                    borderRadius: Math.sqrt(w / 3) * 10 / 2,
                  }} />
                </View>
              );
            }}
            defaultStrokeIndex={0}
            defaultStrokeWidth={5}
            saveComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Save</Text></View>}
            savePreference={() => {
              return {
                folder: "RNImageEditor",
                filename: String(Math.ceil(Math.random() * 100000000)),
                transparent: true,
                imageType: "jpg",
              };
            }}
            onSketchSaved={(success, path) => {
              Alert.alert(success ? "Image saved!" : "Failed to save image!", path);
            }}
            onStrokeEnd={(path) => {
              canvas1.current.addPath(path);
            }}
            onPathsChange={(pathsCount) => {
              console.log("pathsCount(user2)", pathsCount);
            }}
          />
        </View>
      }

      {
        state.example === 4 &&
        (state.photoPath === null ?
          <View style={styles.cameraContainer}>
            <RNCamera
              ref={camera}
              style={styles.preview}
              type={RNCamera.Constants.Type.back}
              flashMode={RNCamera.Constants.FlashMode.on}
              permissionDialogTitle={"Permission to use camera"}
              permissionDialogMessage={"We need your permission to use your camera phone"}
            />
            <View style={{ flex: 0, flexDirection: "row", justifyContent: "center" }}>
              <TouchableOpacity
                onPress={takePicture}
                style={styles.capture}
              >
                <Text style={{ fontSize: 14 }}> SNAP </Text>
              </TouchableOpacity>
            </View>
          </View>
          :
          <View style={{ flex: 1, flexDirection: "row" }}>
            <RNImageEditor
              localSourceImage={{ filename: state.photoPath, directory: null, mode: "AspectFit" }}
              containerStyle={{ backgroundColor: "transparent", flex: 1 }}
              canvasStyle={{ backgroundColor: "transparent", flex: 1 }}
              onStrokeEnd={data => {
              }}
              closeComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Close</Text></View>}
              onClosePressed={() => {
                setState({ example: 0 });
              }}
              undoComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Undo</Text></View>}
              onUndoPressed={(id) => {
                // Alert.alert('do something')
              }}
              clearComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Clear</Text></View>}
              onClearPressed={() => {
                // Alert.alert('do something')
              }}
              eraseComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Eraser</Text></View>}
              strokeComponent={color => (
                <View style={[{ backgroundColor: color }, styles.strokeColorButton]} />
              )}
              strokeSelectedComponent={(color, index, changed) => {
                return (
                  <View style={[{ backgroundColor: color, borderWidth: 2 }, styles.strokeColorButton]} />
                );
              }}
              strokeWidthComponent={(w) => {
                return (<View style={styles.strokeWidthButton}>
                    <View style={{
                      backgroundColor: "white",
                      marginHorizontal: 2.5,
                      width: Math.sqrt(w / 3) * 10,
                      height: Math.sqrt(w / 3) * 10,
                      borderRadius: Math.sqrt(w / 3) * 10 / 2,
                    }} />
                  </View>
                );
              }}
              defaultStrokeIndex={0}
              defaultStrokeWidth={5}
              saveComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Save</Text></View>}
              savePreference={() => {
                return {
                  folder: "RNImageEditor",
                  filename: String(Math.ceil(Math.random() * 100000000)),
                  transparent: false,
                  imageType: "png",
                };
              }}
              onSketchSaved={(success, path) => {
                Alert.alert(success ? "Image saved!" : "Failed to save image!", path);
              }}
              onPathsChange={(pathsCount) => {
                console.log("pathsCount", pathsCount);
              }}
            />
          </View>)
      }

      {
        state.example === 5 &&
        <View style={{ flex: 1, flexDirection: "row" }}>
          <RNImageEditor
            localSourceImage={{ filename: "whale.png", directory: ImageEditor.MAIN_BUNDLE, mode: "AspectFit" }}
            // localSourceImage={{ filename: 'bulb.png', directory: RNImageEditor.MAIN_BUNDLE }}
            containerStyle={{ backgroundColor: "transparent", flex: 1 }}
            canvasStyle={{ backgroundColor: "transparent", flex: 1 }}
            onStrokeEnd={data => {
            }}
            closeComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Close</Text></View>}
            onClosePressed={() => {
              setState({ example: 0 });
            }}
            undoComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Undo</Text></View>}
            onUndoPressed={(id) => {
              // Alert.alert('do something')
            }}
            clearComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Clear</Text></View>}
            onClearPressed={() => {
              // Alert.alert('do something')
            }}
            eraseComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Eraser</Text></View>}
            strokeComponent={color => (
              <View style={[{ backgroundColor: color }, styles.strokeColorButton]} />
            )}
            strokeSelectedComponent={(color, index, changed) => {
              return (
                <View style={[{ backgroundColor: color, borderWidth: 2 }, styles.strokeColorButton]} />
              );
            }}
            strokeWidthComponent={(w) => {
              return (<View style={styles.strokeWidthButton}>
                  <View style={{
                    backgroundColor: "white",
                    marginHorizontal: 2.5,
                    width: Math.sqrt(w / 3) * 10,
                    height: Math.sqrt(w / 3) * 10,
                    borderRadius: Math.sqrt(w / 3) * 10 / 2,
                  }} />
                </View>
              );
            }}
            defaultStrokeIndex={0}
            defaultStrokeWidth={5}
            saveComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Save</Text></View>}
            savePreference={() => {
              return {
                folder: "RNImageEditor",
                filename: String(Math.ceil(Math.random() * 100000000)),
                transparent: false,
                includeImage: false,
                cropToImageSize: false,
                imageType: "jpg",
              };
            }}
            onSketchSaved={(success, path) => {
              Alert.alert(success ? "Image saved!" : "Failed to save image!", path);
            }}
            onPathsChange={(pathsCount) => {
              console.log("pathsCount", pathsCount);
            }}
          />
        </View>
      }

      {
        state.example === 6 &&
        <View style={{ flex: 1, flexDirection: "row" }}>
          <RNImageEditor
            text={[
              {
                text: "Welcome to my GitHub",
                font: "fonts/IndieFlower.ttf",
                fontSize: 30,
                position: { x: 0, y: 0 },
                anchor: { x: 0, y: 0 },
                coordinate: "Absolute",
                fontColor: "red",
              },
              {
                text: "Center\nMULTILINE",
                fontSize: 25,
                position: { x: 0.5, y: 0.5 },
                anchor: { x: 0.5, y: 0.5 },
                coordinate: "Ratio",
                overlay: "SketchOnText",
                fontColor: "black",
                alignment: "Center",
                lineHeightMultiple: 1,
              },
              {
                text: "Right\nMULTILINE",
                fontSize: 25,
                position: { x: 1, y: 0.25 },
                anchor: { x: 1, y: 0.5 },
                coordinate: "Ratio",
                overlay: "TextOnSketch",
                fontColor: "black",
                alignment: "Right",
                lineHeightMultiple: 1,
              },
              {
                text: "Signature",
                font: "Zapfino",
                fontSize: 40,
                position: { x: 0, y: 1 },
                anchor: { x: 0, y: 1 },
                coordinate: "Ratio",
                overlay: "TextOnSketch",
                fontColor: "#444444",
              },
            ]}
            containerStyle={{ backgroundColor: "transparent", flex: 1 }}
            canvasStyle={{ backgroundColor: "transparent", flex: 1 }}
            onStrokeEnd={data => {
            }}
            closeComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Close</Text></View>}
            onClosePressed={() => {
              setState({ example: 0 });
            }}
            undoComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Undo</Text></View>}
            onUndoPressed={(id) => {
              // Alert.alert('do something')
            }}
            clearComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Clear</Text></View>}
            onClearPressed={() => {
              // Alert.alert('do something')
            }}
            eraseComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Eraser</Text></View>}
            strokeComponent={color => (
              <View style={[{ backgroundColor: color }, styles.strokeColorButton]} />
            )}
            strokeSelectedComponent={(color, index, changed) => {
              return (
                <View style={[{ backgroundColor: color, borderWidth: 2 }, styles.strokeColorButton]} />
              );
            }}
            strokeWidthComponent={(w) => {
              return (<View style={styles.strokeWidthButton}>
                  <View style={{
                    backgroundColor: "white",
                    marginHorizontal: 2.5,
                    width: Math.sqrt(w / 3) * 10,
                    height: Math.sqrt(w / 3) * 10,
                    borderRadius: Math.sqrt(w / 3) * 10 / 2,
                  }} />
                </View>
              );
            }}
            defaultStrokeIndex={0}
            defaultStrokeWidth={5}
            saveComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Save</Text></View>}
            savePreference={() => {
              return {
                folder: "RNImageEditor",
                filename: String(Math.ceil(Math.random() * 100000000)),
                transparent: false,
                includeImage: false,
                includeText: false,
                cropToImageSize: false,
                imageType: "jpg",
              };
            }}
            onSketchSaved={(success, path) => {
              Alert.alert(success ? "Image saved!" : "Failed to save image!", path);
            }}
            onPathsChange={(pathsCount) => {
              console.log("pathsCount", pathsCount);
            }}
          />
        </View>
      }

      {
        state.example === 7 &&
        <View style={{ flex: 1, flexDirection: "row" }}>
          <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 36 }}
                      scrollEnabled={state.scrollEnabled}
          >
            <TouchableOpacity onPress={() => setState({ example: 0 })}>
              <Text>Close</Text>
            </TouchableOpacity>
            <ImageEditor
              text={[
                { text: "Page 1", position: { x: 20, y: 20 }, fontSize: Platform.select({ ios: 24, android: 48 }) },
                {
                  text: "Signature",
                  font: Platform.select({ ios: "Zapfino", android: "fonts/IndieFlower.ttf" }),
                  position: { x: 20, y: 220 },
                  fontSize: Platform.select({ ios: 24, android: 48 }),
                  fontColor: "red",
                },
              ]}
              localSourceImage={{ filename: "whale.png", directory: ImageEditor.MAIN_BUNDLE, mode: "AspectFit" }}
              style={styles.page}
              onStrokeStart={() => setState({ scrollEnabled: false })}
              onStrokeEnd={() => setState({ scrollEnabled: true })}
            />
            <ImageEditor
              text={[{
                text: "Page 2",
                position: { x: 0.95, y: 0.05 },
                anchor: { x: 1, y: 0 },
                coordinate: "Ratio",
                fontSize: Platform.select({ ios: 24, android: 48 }),
              }]}
              style={styles.page}
              onStrokeStart={() => setState({ scrollEnabled: false })}
              onStrokeEnd={() => setState({ scrollEnabled: true })}
            />
            <ImageEditor
              text={[{
                text: "Page 3",
                position: { x: 0.5, y: 0.95 },
                anchor: { x: 0.5, y: 1 },
                coordinate: "Ratio",
                fontSize: Platform.select({ ios: 24, android: 48 }),
              }]}
              style={styles.page}
              onStrokeStart={() => setState({ scrollEnabled: false })}
              onStrokeEnd={() => setState({ scrollEnabled: true })}
            />
            <ImageEditor
              text={[{
                text: "Page 4",
                position: { x: 20, y: 20 },
                fontSize: Platform.select({ ios: 24, android: 48 }),
              }]}
              style={styles.page}
              onStrokeStart={() => setState({ scrollEnabled: false })}
              onStrokeEnd={() => setState({ scrollEnabled: true })}
            />
          </ScrollView>
        </View>
      }
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#F5FCFF",
  },
  strokeColorButton: {
    marginHorizontal: 2.5,
    marginVertical: 8,
    width: 30,
    height: 30,
    borderRadius: 15,
  },
  strokeWidthButton: {
    marginHorizontal: 2.5,
    marginVertical: 8,
    width: 30,
    height: 30,
    borderRadius: 15,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#39579A",
  },
  functionButton: {
    marginHorizontal: 2.5,
    marginVertical: 8,
    height: 30,
    width: 60,
    backgroundColor: "#39579A",
    justifyContent: "center",
    alignItems: "center",
    borderRadius: 5,
  },
  cameraContainer: {
    flex: 1,
    flexDirection: "column",
    backgroundColor: "black",
    alignSelf: "stretch",
  },
  preview: {
    flex: 1,
    justifyContent: "flex-end",
  },
  capture: {
    flex: 0,
    backgroundColor: "#fff",
    borderRadius: 5,
    padding: 15,
    paddingHorizontal: 20,
    alignSelf: "center",
    margin: 20,
  },
  page: {
    flex: 1,
    height: 300,
    elevation: 2,
    marginVertical: 8,
    backgroundColor: "white",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.75,
    shadowRadius: 2,
  },

  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: "600",
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: "400",
  },
  highlight: {
    fontWeight: "700",
  },
});

export default App;
