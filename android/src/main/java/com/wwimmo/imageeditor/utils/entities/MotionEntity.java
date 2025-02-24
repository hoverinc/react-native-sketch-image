package com.wwimmo.imageeditor.utils.entities;

import android.content.res.Resources;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.DashPathEffect;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.PointF;
import android.util.TypedValue;

import androidx.annotation.IntRange;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.wwimmo.imageeditor.utils.Utility;
import com.wwimmo.imageeditor.utils.layers.Layer;

import java.util.UUID;

@SuppressWarnings({"WeakerAccess"})
public abstract class MotionEntity {


    public static final int DEFAULT_DRAWING_STEP = -1;
    @NonNull
    protected final Layer layer;

    /**
     * transformation matrix for the entity
     */
    protected final Matrix matrix = new Matrix();
    /**
     * Initial points of the entity
     *
     * @see #destPoints
     */
    protected final float[] srcPoints = new float[10];  // x0, y0, x1, y1, x2, y2, x3, y3, x0, y0
    /**
     * Destination points of the entity
     * 5 points. Size of array - 10; Starting upper left corner, clockwise
     * last point is the same as first to close the circle
     * NOTE: saved as a field variable in order to avoid creating array in draw()-like methods
     */
    private final float[] destPoints = new float[10]; // x0, y0, x1, y1, x2, y2, x3, y3, x0, y0
    private final PointF pA = new PointF();
    private final PointF pB = new PointF();
    private final PointF pC = new PointF();
    private final PointF pD = new PointF();
    /**
     * maximum scale of the initial image, so that
     * the entity still fits within the parent canvas
     */
    protected float holyScale;
    /**
     * width of canvas the entity is drawn in
     */
    @IntRange(from = 0)
    protected int canvasWidth;
    /**
     * height of canvas the entity is drawn in
     */
    @IntRange(from = 0)
    protected int canvasHeight;
    /**
     * true - entity is selected and need to draw it's border
     * false - not selected, no need to draw it's border
     */
    private boolean isSelected;
    @NonNull
    private Paint borderPaint = new Paint();
    @NonNull
    private BorderStyle borderStyle = BorderStyle.DASHED;
    private final String id;
    private int measuredWidth, measuredHeight;

    public MotionEntity(@NonNull Layer layer,
                        @IntRange(from = 1) int canvasWidth,
                        @IntRange(from = 1) int canvasHeight) {
        id = UUID.randomUUID().toString();
        this.layer = layer;
        this.canvasWidth = canvasWidth;
        this.canvasHeight = canvasHeight;
    }

    public boolean isSelected() {
        return isSelected;
    }

    public void setIsSelected(boolean isSelected) {
        this.isSelected = isSelected;
    }

    /**
     * S - scale matrix, R - rotate matrix, T - translate matrix,
     * L - result transformation matrix
     * <p>
     * The correct order of applying transformations is : L = S * R * T
     * <p>
     * See more info: <a href="http://gamedev.stackexchange.com/questions/29260/transform-matrix-multiplication-order">Game Dev: Transform Matrix multiplication order</a>
     * <p>
     * Preconcat works like M` = M * S, so we apply preScale -> preRotate -> preTranslate
     * the result will be the same: L = S * R * T
     * <p>
     * NOTE: postconcat (postScale, etc.) works the other way : M` = S * M, in order to use it
     * we'd need to reverse the order of applying
     * transformations : post holy scale ->  postTranslate -> postRotate -> postScale
     */
    protected void updateMatrix() {
        // init matrix to E - identity matrix
        matrix.reset();

        float topLeftX = layer.getX() * canvasWidth;
        float topLeftY = layer.getY() * canvasHeight;

        float centerX = topLeftX + getWidth() * holyScale * 0.5F;
        float centerY = topLeftY + getHeight() * holyScale * 0.5F;

        // calculate params
        float rotationInDegree = layer.getRotationInDegrees();
        float scaleX = layer.getScale();
        float scaleY = layer.getScale();
        if (layer.isFlipped()) {
            // flip (by X-coordinate) if needed
            rotationInDegree *= -1.0F;
            scaleX *= -1.0F;
        }

        // applying transformations : L = S * R * T

        // scale
        matrix.preScale(scaleX, scaleY, centerX, centerY);

        // rotate
        matrix.preRotate(rotationInDegree, centerX, centerY);

        // translate
        matrix.preTranslate(topLeftX, topLeftY);

        // applying holy scale - S`, the result will be : L = S * R * T * S`
        matrix.preScale(holyScale, holyScale);
    }

    public float absoluteCenterX() {
        float topLeftX = layer.getX() * canvasWidth;
        return topLeftX + getWidth() * holyScale * 0.5F;
    }

    public float absoluteCenterY() {
        float topLeftY = layer.getY() * canvasHeight;
        return topLeftY + getHeight() * holyScale * 0.5F;
    }

    public PointF absoluteCenter() {
        float topLeftX = layer.getX() * canvasWidth;
        float topLeftY = layer.getY() * canvasHeight;

        float centerX = topLeftX + getWidth() * holyScale * 0.5F;
        float centerY = topLeftY + getHeight() * holyScale * 0.5F;

        return new PointF(centerX, centerY);
    }

    public void moveToCanvasCenter() {
        moveCenterTo(new PointF(canvasWidth * 0.5F, canvasHeight * 0.5F));
    }

    public void moveCenterTo(PointF moveToCenter) {
        PointF currentCenter = absoluteCenter();
        layer.postTranslate(1.0F * (moveToCenter.x - currentCenter.x) / canvasWidth,
                1.0F * (moveToCenter.y - currentCenter.y) / canvasHeight);
    }

    /**
     * For more info:
     * <a href="http://math.stackexchange.com/questions/190111/how-to-check-if-a-point-is-inside-a-rectangle">StackOverflow: How to check point is in rectangle</a>
     * <p>NOTE: it's easier to apply the same transformation matrix (calculated before) to the original source points, rather than
     * calculate the result points ourselves
     *
     * @param point point
     * @return true if point (x, y) is inside the triangle
     */
    public boolean pointInLayerRect(PointF point) {

        updateMatrix();
        // map rect vertices
        matrix.mapPoints(destPoints, srcPoints);

        pA.x = destPoints[0];
        pA.y = destPoints[1];
        pB.x = destPoints[2];
        pB.y = destPoints[3];
        pC.x = destPoints[4];
        pC.y = destPoints[5];
        pD.x = destPoints[6];
        pD.y = destPoints[7];

        return Utility.pointInTriangle(point, pA, pB, pC) || Utility.pointInTriangle(point, pA, pD, pC);
    }

    /**
     * http://judepereira.com/blog/calculate-the-real-scale-factor-and-the-angle-of-rotation-from-an-android-matrix/
     *
     * @param canvas       Canvas to draw
     * @param drawingPaint Paint to use during drawing
     */
    public final void draw(@NonNull Canvas canvas, @Nullable Paint drawingPaint) {

        updateMatrix();

        canvas.save();

        drawContent(canvas, drawingPaint);

        if (isSelected() && borderPaint.getColor() != Color.TRANSPARENT) {
            // get alpha from drawingPaint
            int storedAlpha = borderPaint.getAlpha();
            if (drawingPaint != null) {
                borderPaint.setAlpha(drawingPaint.getAlpha());
            }
            drawSelectedBg(canvas);
            // restore border alpha
            borderPaint.setAlpha(storedAlpha);
        }

        canvas.restore();
    }

    private void drawSelectedBg(Canvas canvas) {
        matrix.mapPoints(destPoints, srcPoints);
        if (this.borderStyle == BorderStyle.DASHED) {
            Paint dashedBorderPaint = borderPaint;
            dashedBorderPaint.setPathEffect(new DashPathEffect(new float[]{5, 5}, 0));
            dashedBorderPaint.setStyle(Paint.Style.STROKE);

            //noinspection Range
            canvas.drawLines(destPoints, 0, 8, dashedBorderPaint);
            //noinspection Range
            canvas.drawLines(destPoints, 2, 8, dashedBorderPaint);
        } else {
            //noinspection Range
            canvas.drawLines(destPoints, 0, 8, borderPaint);
            //noinspection Range
            canvas.drawLines(destPoints, 2, 8, borderPaint);
        }
    }

    @NonNull
    public Layer getLayer() {
        return layer;
    }

    public void setBorderPaint(@NonNull Paint borderPaint) {
        this.borderPaint = borderPaint;
    }

    public void setBorderStyle(@NonNull BorderStyle borderStyle) {
        this.borderStyle = borderStyle;
    }

    protected abstract void drawContent(@NonNull Canvas canvas, @Nullable Paint drawingPaint);

    public abstract int getWidth();

    public abstract int getHeight();

    public void release() {
        // free resources here
    }

    /**
     * Execute undo operation on the entity if possible. By default return false.
     *
     * @return true in case of event handled; false - otherwise, entity could be removed;
     */
    public boolean undo() {
        return false;
    }

    @Override
    protected void finalize() throws Throwable {
        try {
            release();
        } finally {
            //noinspection ThrowFromFinallyBlock
            super.finalize();
        }
    }

    /**
     * Return the current number of drawing step. Used for composite shapes.
     *
     * @return
     */
    public int getDrawingStep() {
        return DEFAULT_DRAWING_STEP;
    }

    public abstract String getShapeType();

    public String getId() {
        return id;
    }

    public void setMeasuredSize(int width, int height) {
        this.measuredWidth = width;
        this.measuredHeight = height;
    }


    public int getMeasuredWidth() {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, measuredWidth, Resources.getSystem().getDisplayMetrics());
    }

    public int getMeasuredHeight() {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, measuredHeight, Resources.getSystem().getDisplayMetrics());
    }
}
