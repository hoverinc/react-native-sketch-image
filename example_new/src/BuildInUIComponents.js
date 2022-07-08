import React from "react";
import RNImageEditor from "@hoverinc/react-native-sketch-canvas";
import { Alert, Text, View } from "react-native";


export const BuildInUIComponents = ({styles, state, canvas, setState}) => {


  return <View style={{ flex: 1, flexDirection: "row" }}>
    <RNImageEditor
      ref={canvas}
      touchEnabled={state.touchEnabled}
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
        canvas.current.addShape({ shapeType: "Circle" });
        // canvas.current.addShape({ shapeType: "Rect" });
        // this.canvas.addShape({ shapeType: 'Square' });
        // this.canvas.addShape({ shapeType: 'Triangle' });
        // this.canvas.addShape({ shapeType: 'Arrow' });
        // this.canvas.addShape({ shapeType: 'Text', textShapeFontSize: 10, textShapeText: "Added TextShape from JS" });
        // this.canvas.addShape({ shapeType: 'Text', textShapeFontType: 'fonts/IndieFlower.ttf', textShapeFontSize: 5, textShapeText: "Added TextShape with custom TypeFace" });
        // Alert.alert('do something')
      }}
      clearComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Clear</Text></View>}
      onClearPressed={() => {
        // this.canvas.decreaseSelectedShapeFontsize();
        // this.canvas.increaseSelectedShapeFontsize();
        // this.canvas.changeSelectedShapeText("Random text " + Math.random());
        // Alert.alert('do something')
      }}
      eraseComponent={<View style={styles.functionButton}><Text style={{ color: "white" }}>Eraser</Text></View>}
      deleteSelectedShapeComponent={<View style={styles.functionButton}><Text
        style={{ color: "white" }}>Delete</Text></View>}
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
      onShapeSelectionChanged={(isShapeSelected) => {
        setState({ touchEnabled: !isShapeSelected });
      }}
      shapeConfiguration={{ shapeBorderColor: "black", shapeBorderStyle: "Dashed", shapeBorderStrokeWidth: 1 }}
    />
  </View>
}
