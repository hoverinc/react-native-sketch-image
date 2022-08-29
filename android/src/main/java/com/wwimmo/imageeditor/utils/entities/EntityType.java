package com.wwimmo.imageeditor.utils.entities;

public enum EntityType {
    CIRCLE("Circle"),
    RECT("Rect"),
    SQUARE("Square"),
    TRIANGLE("Triangle"),
    ARROW("Arrow"),
    TEXT("Text"),
    IMAGE("Image"),
    RULER("Ruler"),
    MEASUREMENT_TOOL("MeasurementTool");


    public final String label;

    EntityType(String label) {
        this.label = label;
    }
}