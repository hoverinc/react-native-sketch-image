package com.wwimmo.imageeditor.utils.entities;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PointF;
import android.graphics.PorterDuff;
import android.graphics.Rect;
import android.graphics.RectF;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.util.DisplayMetrics;
import android.util.TypedValue;

import androidx.annotation.IntRange;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.wwimmo.imageeditor.utils.Utility;
import com.wwimmo.imageeditor.utils.layers.Layer;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;

public class MeasureToolEntity extends MotionEntity {
    private static final int BORDER_PADDING = 16;
    private static final int POINTS_COUNT = 2;
    private static final int POINT_TOUCH_AREA = 74 / 2;
    private static final int INNER_RADIUS = 12 / 2;
    private static final int OUTER_RADIUS = 16 / 2;
    private static final int TEXT_BOX_SIZE = 24;
    private static final int TEXT_BOX_PADDING = 8;

    private static final int OUTER_RADIUS_CONNECTION = OUTER_RADIUS - 1;
    private static final int STROKE_WIDTH = 4;
    private static final int LENS_SIZE = 72;
    private static final int ZOOM = 3;
    private static final float ENDPOINT_OFFSET_RATIO = 1f / 8f;
    private static final int alpha = (int) (255 * 0.3f);
    private final int mWidth;
    private final int mHeight;
    private final List<PointF> currentPoints;
    private final List<Boolean> pointsVisited;
    private final TextPaint mTextPaint;
    private final String endpointImage;
    private int mStrokeColor;
    private Paint mPaint;
    private Bitmap mBitmap;
    private Canvas mCanvas;
    private PointF selectedPoint;
    private String mCurrentText;
    private float mScaledDensity;
    private WeakReference<Bitmap> backgroundRef;
    private Bitmap mZoomBitmap;
    private Canvas mZoomCanvas;
    private boolean focused;
    private Bitmap endpointBitmap;
    private RectF endpointRect;
    // scaled values for the shapes
    private int innerRadius;
    private int outerRadius;
    private int touchRadius;
    private int lensSize;
    private int strokeWidth;
    private int textBoxSize;
    private int textBoxPadding;


    public MeasureToolEntity(@NonNull Layer layer,
                             @IntRange(from = 1) int canvasWidth,
                             @IntRange(from = 1) int canvasHeight,
                             @Nullable String endpointImage,
                             DisplayMetrics dm) {
        super(layer, canvasWidth, canvasHeight);

        this.mWidth = canvasWidth;
        this.mHeight = canvasHeight;
        this.mStrokeColor = Color.BLACK;
        currentPoints = new ArrayList<>();
        pointsVisited = new ArrayList<>();
        updateEntity(false);
        mTextPaint = new TextPaint();
        mTextPaint.setAntiAlias(true);
        this.endpointImage = endpointImage;
        this.init(dm);
    }

    private void init(DisplayMetrics dm) {
        innerRadius = Utility.convertDpToPx(dm, INNER_RADIUS);
        outerRadius = Utility.convertDpToPx(dm, OUTER_RADIUS);
        touchRadius = Utility.convertDpToPx(dm, POINT_TOUCH_AREA);
        lensSize = Utility.convertDpToPx(dm, LENS_SIZE);
        strokeWidth = Utility.convertDpToPx(dm, STROKE_WIDTH);
        textBoxSize = Utility.convertDpToPx(dm, TEXT_BOX_SIZE);
        textBoxPadding = Utility.convertDpToPx(dm, TEXT_BOX_PADDING);
    }

    private void updateEntity(boolean moveToPreviousCenter) {
        configureBitmap(null);

        float width = this.mBitmap.getWidth();
        float height = this.mBitmap.getHeight();

        float widthAspect = 1.0F * canvasWidth / this.mBitmap.getWidth();
        float heightAspect = 1.0F * canvasHeight / this.mBitmap.getHeight();

        // fit the smallest size
        holyScale = Math.min(widthAspect, heightAspect);

        // initial position of the entity
        srcPoints[0] = 0;
        srcPoints[1] = 0;
        srcPoints[2] = width;
        srcPoints[3] = 0;
        srcPoints[4] = width;
        srcPoints[5] = height;
        srcPoints[6] = 0;
        srcPoints[7] = height;
        srcPoints[8] = 0;
        srcPoints[8] = 0;

        if (moveToPreviousCenter) {
            moveCenterTo(absoluteCenter());
        }
    }

    @Override
    protected void updateMatrix() {
//        super.updateMatrix();
    }

    private void configureBitmap(@Nullable Paint paint) {
        updatePaint(paint);
        if (this.mBitmap == null) {
            this.mBitmap = Bitmap.createBitmap(getWidth(), getHeight(), Bitmap.Config.ARGB_8888);
            this.mCanvas = new Canvas(this.mBitmap);
        }
        this.mCanvas.save();
        this.mCanvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR);
        float savedStrokeWidth = mPaint.getStrokeWidth();
        float outerRadiusFull = outerRadius + innerRadius + strokeWidth / 2f;

        if (currentPoints.size() > 0) {
            for (int i = 0; i < currentPoints.size(); i++) {
                PointF pointF = currentPoints.get(i);

                if (pointF == selectedPoint && focused) {
                    // highlight point
                    this.mPaint.setAlpha(alpha);
                    this.mPaint.setStrokeWidth(strokeWidth * 2);
                    this.mPaint.setStyle(Paint.Style.STROKE);
                    float touchArea = getTouchRadius();
                    this.mCanvas.drawCircle(pointF.x, pointF.y, touchArea, this.mPaint);
                } else if (currentPoints.size() > 1) {
                    this.mPaint.setAlpha(alpha);
                    this.mPaint.setStyle(Paint.Style.STROKE);
                    this.mPaint.setStrokeWidth(strokeWidth * 3);
                    this.mCanvas.drawCircle(pointF.x, pointF.y, outerRadiusFull, this.mPaint);
                }
                this.mPaint.setAlpha(255);
                this.mPaint.setStyle(Paint.Style.FILL);

                if (i > 0) {
                    // path between points
                    PointF prevPointF = currentPoints.get(i - 1);
                    drawConnection(prevPointF, pointF, false);
                }

                this.drawPoint(pointF, this.mPaint);

                mPaint.setStrokeWidth(savedStrokeWidth);

                if (i == 1 && mCurrentText != null) {
                    drawText(
                            currentPoints.get(0), pointF,
                            mCanvas, mTextPaint, mPaint, mCurrentText
                    );
                }
            }
            if (selectedPoint != null && backgroundRef.get() != null && focused) {
                this.drawZoomLens(selectedPoint, backgroundRef.get());
            }
            mPaint.setStrokeWidth(savedStrokeWidth);
        }

        if (currentPoints.size() > 1 && this.endpointBitmap != null) {
            boolean firstVisited = this.pointsVisited.get(0);
            boolean secondVisited = this.pointsVisited.get(1);
            if (!secondVisited && selectedPoint != this.currentPoints.get(1)) {
                // Highlight second
                PointF imageCenterPoint = new PointF();
                PointF oppositePoint = this.currentPoints.get(1);
                imageCenterPoint.set(oppositePoint.x, oppositePoint.y + outerRadiusFull + 2 * strokeWidth);
                this.drawImageEndpoint(imageCenterPoint, mPaint);
            } else if (!firstVisited && selectedPoint != this.currentPoints.get(0)) {
                // Highlight first
                PointF imageCenterPoint = new PointF();
                PointF oppositePoint = this.currentPoints.get(0);
                imageCenterPoint.set(oppositePoint.x, oppositePoint.y + outerRadiusFull + 2 * strokeWidth);
                this.drawImageEndpoint(imageCenterPoint, mPaint);
            }
        }

        this.mCanvas.restore();
    }

    private void drawZoomLens(PointF centerPoint, Bitmap background) {
        // Draw rect near the point
        float x0 = centerPoint.x - touchRadius;
        float y0 = centerPoint.y - touchRadius;
        if (x0 < lensSize) {
            x0 = centerPoint.x + touchRadius + lensSize;
        }
        if (y0 < lensSize) {
            y0 = centerPoint.y + touchRadius + lensSize;
        }


        // Add zooming area
        if (mZoomBitmap == null) {
            mZoomBitmap = Bitmap.createBitmap(lensSize, lensSize, Bitmap.Config.ARGB_8888);
            mZoomCanvas = new Canvas(this.mZoomBitmap);
        }

        int zoomedHalfWidth = lensSize / ZOOM / 2;
        int zoomedHalfHeight = lensSize / ZOOM / 2;
        float scaleXY = (float) background.getWidth() / this.mCanvas.getWidth();
        int srcCenterX = (int) (centerPoint.x * scaleXY);
        int srcCenterY = (int) (centerPoint.y * scaleXY);
        Rect srcRect = new Rect(
                srcCenterX - zoomedHalfWidth,
                srcCenterY - zoomedHalfHeight,
                srcCenterX + zoomedHalfWidth,
                srcCenterY + zoomedHalfHeight
        );

        mZoomCanvas.save();
        // Draw the scaled image
        PointF drawPoint = this.getLensPoint(lensSize, lensSize);
        Rect targetRect = new Rect(0, 0, lensSize, lensSize);
        mZoomCanvas.save();
        mZoomCanvas.drawBitmap(background, srcRect, targetRect, null);
        mZoomCanvas.restore();
        // Post effect
        mCanvas.save();

        // Add center indicator
        int centerX = (int) drawPoint.x;
        int centerY = (int) drawPoint.y;
        // Create a circular path
        Path path = new Path();
        float halfLensSize = lensSize / 2f;
        path.addCircle(centerX, centerY, halfLensSize, Path.Direction.CW);
        // Clip the canvas to the circular path
        mCanvas.clipPath(path);
        RectF drawingRect = new RectF(
                centerX - halfLensSize,
                centerY - halfLensSize,
                centerX + halfLensSize,
                centerY + halfLensSize
        );
        mCanvas.drawBitmap(mZoomBitmap, null, drawingRect, null);
        mCanvas.restore();


        this.mPaint.setStyle(Paint.Style.STROKE);
        this.mPaint.setStrokeWidth(strokeWidth);
        this.mCanvas.drawCircle(centerX, centerY, halfLensSize, this.mPaint);

        this.mPaint.setStyle(Paint.Style.FILL);
        this.mCanvas.drawCircle(centerX, centerY, strokeWidth / 2f, this.mPaint);
    }


    private double distance(float x1, float y1, float x2, float y2) {
        return Math.hypot(x2 - x1, y2 - y1);
    }

    private double getAngleBetweenPoints(PointF startPoint, PointF endPoint) {
        // Build triangle
        double a = distance(startPoint.x, startPoint.y, endPoint.x, startPoint.y);
        double b = distance(endPoint.x, endPoint.y, endPoint.x, startPoint.y);

        float diffX = endPoint.x - startPoint.x;
        float diffY = endPoint.y - startPoint.y;
        double theta;
        // get the correct angle depends on points positions
        if (diffX <= 0 && diffY <= 0) {
            theta = Math.PI + Math.atan(b / a);
        } else if (diffX > 0 && diffY <= 0) {
            theta = -Math.atan(b / a);
        } else if (diffX <= 0 && diffY > 0) {
            theta = Math.PI - Math.atan(b / a);
        } else {
            theta = Math.atan(b / a);
        }
        return theta;
    }

    private PointF getOuterRadiusPoint(PointF startPoint, PointF endPoint, float radius) {
        double theta = getAngleBetweenPoints(startPoint, endPoint);
        float x = (float) (startPoint.x + radius * Math.cos(theta));
        float y = (float) (startPoint.y + radius * Math.sin(theta));
        // TODO done in the same way as iOS but could be reduced amount of created object if
        // use directly
        return new PointF(x, y);
    }


    private boolean isCurrentPointsInRect(RectF rect) {
        float touchArea = getTouchRadius();
        for (int i = 0; i < currentPoints.size(); i++) {
            PointF currentPoint = currentPoints.get(i);
            if (rect.intersect(
                    currentPoint.x - touchArea,
                    currentPoint.y - touchArea,
                    currentPoint.x + touchArea,
                    currentPoint.y + touchArea)) {
                return true;
            }
        }
        return false;
    }

    private PointF getLensPoint(float width, float height) {
        RectF cornerRect = new RectF();
        float padding = height / 3;
        float rectWidth = width + padding;
        float rectHeight = height + padding;

        // Bottom left
        int calculatedHeight = getHeight();
        if (getMeasuredHeight() > 0 && getMeasuredHeight() < calculatedHeight) {
            calculatedHeight = getMeasuredHeight();
        }
        cornerRect.set(0, calculatedHeight - rectHeight, rectWidth, calculatedHeight);
        if (!isCurrentPointsInRect(cornerRect)) {
            return new PointF(padding + width / 2, calculatedHeight - height / 2 - padding);
        }

        // Top left
        cornerRect.set(0, 0, rectWidth, rectHeight);
        if (!isCurrentPointsInRect(cornerRect)) {
            return new PointF(padding + width / 2, height / 2 + padding);
        }
        // Top right
        cornerRect.set(getWidth() - rectWidth, 0, getWidth(), rectHeight);
        if (!isCurrentPointsInRect(cornerRect)) {
            return new PointF(getWidth() - padding - width / 2, height / 2 + padding);
        }

        return new PointF(getWidth() - padding - width / 2, calculatedHeight - height / 2 - padding);
    }


    private void drawText(PointF a, PointF b, Canvas canvas, TextPaint textPaint, Paint bgPaint, String text) {
        Rect textRect = new Rect();
        textPaint.getTextBounds(text, 0, text.length(), textRect);
        int textWidth = (int) (textRect.width() + Math.max(2, mScaledDensity * 2));
        StaticLayout sl = new StaticLayout(
                text,
                textPaint,
                textWidth,
                Layout.Alignment.ALIGN_NORMAL,
                1.0f,
                1.0f,
                true
        );

        canvas.save();

        int halfTextHeight = textBoxSize / 2;
        int halfTextWidth = textWidth / 2;

        double angle = Math.atan2(b.y - a.y, b.x - a.x);

        float offsetXDiag = (float) ((textWidth / 2f + touchRadius) * Math.cos(angle + Math.PI / 2));
        float offsetYDiag = (float) (touchRadius * Math.sin(angle + Math.PI / 2));
        float midX = (a.x + b.x) / 2 + offsetXDiag;
        float midY = (a.y + b.y) / 2 + offsetYDiag;
        // Verify content fit the screen
        if (midX - textWidth <= 0 || midX + textWidth > getWidth()) {
            // switch to opposite side by X
            midX = (a.x + b.x) / 2 - offsetXDiag;
        }
        if (midY - halfTextHeight < 0 || midY + halfTextHeight > getHeight()) {
            // switch to opposite side by Y
            midY = (a.y + b.y) / 2 - offsetYDiag;
        }
        canvas.translate(midX, midY);
        // background first
        bgPaint.setStyle(Paint.Style.FILL);
        RectF bgRect = new RectF();
        bgRect.set(
                - textBoxPadding - halfTextWidth,
                -halfTextHeight,
                halfTextWidth + textBoxPadding,
                halfTextHeight
        );
        canvas.drawRoundRect(bgRect, textBoxPadding / 2f, textBoxPadding / 2f, bgPaint);
        // then text
        canvas.translate(-halfTextWidth, -halfTextHeight / 2f - textBoxPadding / 2f);
        sl.draw(canvas);


        canvas.restore();
    }

    private void drawConnection(PointF startPoint, PointF endPoint, boolean hasOffset) {
        if (hasOffset) {
            float radius = endpointBitmap != null ? endpointBitmap.getWidth() * ENDPOINT_OFFSET_RATIO : OUTER_RADIUS_CONNECTION;
            PointF newEnd = getOuterRadiusPoint(endPoint, startPoint, radius);
            PointF newStart = getOuterRadiusPoint(startPoint, endPoint, radius);
            mCanvas.drawLine(newStart.x, newStart.y, newEnd.x, newEnd.y, mPaint);
        } else {
            mPaint.setStrokeWidth(4);
            mCanvas.drawLine(startPoint.x, startPoint.y, endPoint.x, endPoint.y, mPaint);
        }

    }

    private void drawLineIndicator(PointF startPoint, PointF endPoint, int size, Paint mPaint) {
        double thetaTop = getAngleBetweenPoints(startPoint, endPoint) - Math.PI / 2;
        double thetaBottom = thetaTop - Math.PI;
        // for the start point
        float x1 = (float) (startPoint.x + size * Math.cos(thetaTop));
        float y1 = (float) (startPoint.y + size * Math.sin(thetaTop));

        float x2 = (float) (startPoint.x + size * Math.cos(thetaBottom));
        float y2 = (float) (startPoint.y + size * Math.sin(thetaBottom));
        mCanvas.drawLine(x1, y1, x2, y2, mPaint);

        // for the end pont
        x1 = (float) (endPoint.x + size * Math.cos(thetaTop));
        y1 = (float) (endPoint.y + size * Math.sin(thetaTop));

        x2 = (float) (endPoint.x + size * Math.cos(thetaBottom));
        y2 = (float) (endPoint.y + size * Math.sin(thetaBottom));
        mCanvas.drawLine(x1, y1, x2, y2, mPaint);
    }

    private void updatePaint(@Nullable Paint paint) {
        if (paint != null && isSelected()) {
            this.mStrokeColor = paint.getColor();
        }

        this.mPaint = new Paint();
        this.mPaint.setColor(this.mStrokeColor);

        // This is essential for the overlapping paths to not result in a weird artefact
        this.mPaint.setStrokeJoin(Paint.Join.BEVEL);

        // TODO: border gets pixelated because it's just done once (initially)!
        this.mPaint.setAntiAlias(true);

        // TODO: FIX THIS by somehow scaling the shape as well and not just the bitmap...
        this.mPaint.setFilterBitmap(true);
        this.mPaint.setDither(true);
        this.mPaint.setStyle(Paint.Style.STROKE);
        this.mPaint.setStrokeWidth(STROKE_WIDTH);
    }

    @Override
    protected void drawContent(@NonNull Canvas canvas, @Nullable Paint drawingPaint) {
        configureBitmap(drawingPaint);
        canvas.drawBitmap(this.mBitmap, matrix, this.mPaint);
    }

    @Override
    @NonNull
    public Layer getLayer() {
        return layer;
    }

    @Override
    public int getWidth() {
        return this.mWidth;
    }

    @Override
    public int getHeight() {
        return this.mHeight;
    }

    public void updateEntity() {
        updateEntity(true);
    }

    @Override
    public void release() {
        if (this.mBitmap != null && !this.mBitmap.isRecycled()) {
            this.mBitmap.recycle();
        }
    }

    public boolean addPoint(float x, float y) {
        if (currentPoints.size() < POINTS_COUNT) {
            PointF point = new PointF(x, y);
            currentPoints.add(point);
            pointsVisited.add(false);
            return currentPoints.size() < POINTS_COUNT || mCurrentText == null;
        }
        return mCurrentText == null;
    }

    private void drawImageEndpoint(PointF point, Paint paint) {
        if (endpointBitmap == null) return;
        if (endpointRect == null) {
            endpointRect = new RectF();
        }
        float x = point.x;
        float y = point.y;
        float height = endpointBitmap.getHeight();
        float width = endpointBitmap.getWidth();
        if (height > 0 && width > 0) {
            endpointRect.set(x, y, x + width, y + height);
            this.mCanvas.drawBitmap(endpointBitmap, null, endpointRect, paint);
        }
    }

    private void drawPoint(PointF point, Paint paint) {
        float x = point.x;
        float y = point.y;
        this.mPaint.setStyle(Paint.Style.FILL);
        this.mCanvas.drawCircle(x, y, innerRadius, paint);
    }


    @Override
    public boolean pointInLayerRect(PointF point) {
        selectedPoint = getSelectedPointInArea(point);
        setFocused(selectedPoint != null);
        return selectedPoint != null;
    }

    private PointF getSelectedPointInArea(PointF point) {
        PointF selected = null;
        float touchArea = getTouchRadius();
        for (int i = 0; i < currentPoints.size(); i++) {
            PointF originPoint = currentPoints.get(i);
            if (isInCircle(originPoint.x, originPoint.y, touchArea, point.x, point.y)) {
                selected = originPoint;
            }
        }
        return selected;
    }

    float getTouchRadius() {
        return touchRadius;
    }

    public boolean handleTranslate(PointF delta) {
        if (selectedPoint != null) {
            float newX = selectedPoint.x + delta.x;
            float newY = selectedPoint.y + delta.y;
            boolean toCloseToOtherPoint = false;
            for (int i = 0; i < currentPoints.size(); i++) {
                PointF originPoint = currentPoints.get(i);
                if (originPoint != selectedPoint && isInCircle(originPoint.x, originPoint.y, touchRadius, newX, newY)) {
                    toCloseToOtherPoint = true;
                    break;
                }
                if (originPoint == selectedPoint) {
                    pointsVisited.set(i, true);
                }
            }
            if (!toCloseToOtherPoint) {
                selectedPoint.set(newX, newY);
            }
            return true;
        }
        return false;
    }

    private boolean isInCircle(float x, float y, float radius, float touchX, float touchY) {
        return (Math.pow(x - touchX, 2) + Math.pow(y - touchY, 2) <= Math.pow(radius, 2));
    }

    @Override
    public boolean undo() {
        if (mCurrentText != null) {
            mCurrentText = null;
            return true;
        }
        if (!currentPoints.isEmpty()) {
            currentPoints.clear();
            pointsVisited.clear();
            return false;
        }
        return false;
    }

    @Override
    public String getShapeType() {
        return EntityType.MEASUREMENT_TOOL.label;
    }

    @Override
    public int getDrawingStep() {
        if (currentPoints.size() < POINTS_COUNT) {
            return 1;
        } else {
            return currentPoints.size() + (mCurrentText == null ? 0 : 1);
        }
    }

    public boolean isTextStep() {
        return getDrawingStep() == POINTS_COUNT && isAllVisited();
    }

    public boolean isAllVisited() {
        if (pointsVisited.size() < POINTS_COUNT) return false;
        for (int i = 0; i < pointsVisited.size(); i++) {
            if (!pointsVisited.get(i)) {
                return false;
            }
        }
        return true;
    }

    public void addText(String text, int fontSize, DisplayMetrics displayMetrics) {
        mCurrentText = text;
        float realFontSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, fontSize,
                displayMetrics);
        mTextPaint.setStyle(Paint.Style.FILL);
        mTextPaint.setTextSize(realFontSize);
        mTextPaint.setColor(Color.BLACK);
        mScaledDensity = displayMetrics.scaledDensity;
    }

    public void setBackground(Bitmap background) {
        backgroundRef = new WeakReference<>(background);
    }

    @Override
    public void setIsSelected(boolean isSelected) {
        super.setIsSelected(isSelected);
        if (!isSelected) {
            selectedPoint = null;
        }
    }


    public void setFocused(boolean focused) {
        this.focused = focused;
    }

    public String getEndpointImage() {
        return endpointImage;
    }

    public Bitmap getEndpointBitmap() {
        return endpointBitmap;
    }

    public void setEndpointBitmap(Bitmap endpointBitmap) {
        this.endpointBitmap = endpointBitmap;
    }

    public List<PointF> getCurrentPoints() {
        return currentPoints;
    }
}
