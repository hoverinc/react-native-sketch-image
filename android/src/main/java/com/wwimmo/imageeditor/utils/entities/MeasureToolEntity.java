package com.wwimmo.imageeditor.utils.entities;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
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

import com.wwimmo.imageeditor.utils.layers.Layer;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;

public class MeasureToolEntity extends MotionEntity {
    private static final int CORNER_RADIUS = 8;
    private static final int BORDER_PADDING = 16;
    private static final int POINTS_COUNT = 2;
    private static final int POINT_TOUCH_AREA = 100;
    private static final int HALF_POINT_TOUCH_AREA = POINT_TOUCH_AREA / 2;
    private static final int INNER_RADIUS = 14;
    private static final int OUTER_RADIUS = 22;
    private static final int OUTER_RADIUS_CONNECTION = OUTER_RADIUS - 1;
    private static final int STROKE_WIDTH = 4;
    private static final int LENS_WIDTH = 260;
    private static final int LENS_HEIGHT = 160;
    private static final int ZOOM = 2;
    private final int mWidth;
    private final int mHeight;
    private final List<PointF> currentPoints;
    private final TextPaint mTextPaint;
    float zoomStrokeWidth = 2;
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

    public MeasureToolEntity(@NonNull Layer layer,
                             @IntRange(from = 1) int canvasWidth,
                             @IntRange(from = 1) int canvasHeight) {
        super(layer, canvasWidth, canvasHeight);

        this.mWidth = canvasWidth;
        this.mHeight = canvasHeight;
        this.mStrokeColor = Color.BLACK;
        currentPoints = new ArrayList<>();
        updateEntity(false);
        mTextPaint = new TextPaint();
        mTextPaint.setAntiAlias(true);
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
        if (currentPoints.size() > 0) {
            for (int i = 0; i < currentPoints.size(); i++) {
                PointF pointF = currentPoints.get(i);

                if (pointF == selectedPoint) {
                    // highlight point
                    this.mPaint.setAlpha(100);
                    this.mPaint.setStyle(Paint.Style.FILL);
                    this.mCanvas.drawCircle(pointF.x, pointF.y, POINT_TOUCH_AREA, this.mPaint);
                    this.mPaint.setAlpha(255);
                }
                boolean hasText = mCurrentText != null;
                if (i > 0) {
                    // path between points
                    PointF prevPointF = currentPoints.get(i - 1);
                    drawConnection(prevPointF, pointF, !hasText);
                    if (hasText) {
                        drawLineIndicator(prevPointF, pointF, OUTER_RADIUS, this.mPaint);
                    }
                }
                if (!hasText) {
                    this.drawPoint(pointF, mPaint);
                }
                mPaint.setStrokeWidth(savedStrokeWidth);

                if (i == 1 && mCurrentText != null) {
                    drawText(
                            currentPoints.get(0), pointF,
                            mCanvas, mTextPaint, mPaint, mCurrentText
                    );
                }
            }
            if (selectedPoint != null && backgroundRef.get() != null) {
                this.drawZoomLens(selectedPoint, backgroundRef.get());
            }
            mPaint.setStrokeWidth(savedStrokeWidth);
        }


        this.mCanvas.restore();
    }

    private void drawZoomLens(PointF centerPoint, Bitmap background) {
        // Draw rect near the point
        float x0 = centerPoint.x - POINT_TOUCH_AREA;
        float y0 = centerPoint.y - POINT_TOUCH_AREA;
        if (x0 < LENS_WIDTH) {
            x0 = centerPoint.x + POINT_TOUCH_AREA + LENS_WIDTH;
        }
        if (y0 < LENS_HEIGHT) {
            y0 = centerPoint.y + POINT_TOUCH_AREA + LENS_HEIGHT;
        }

        RectF drawingRect = new RectF(
                x0 - LENS_WIDTH,
                y0 - LENS_HEIGHT,
                x0,
                y0
        );


        // Add zooming area
        if (mZoomBitmap == null) {
            mZoomBitmap = Bitmap.createBitmap(LENS_WIDTH, LENS_HEIGHT, Bitmap.Config.ARGB_8888);
            mZoomCanvas = new Canvas(this.mZoomBitmap);
        }

        int zoomedHalfWidth = LENS_WIDTH / ZOOM / 2;
        int zoomedHalfHeight = LENS_HEIGHT / ZOOM / 2;
        float scaleX = (float) background.getWidth() / this.mCanvas.getWidth();
        float scaleY = (float) background.getHeight() / this.mCanvas.getHeight();
        int srcCenterX = (int) (centerPoint.x * scaleX);
        int srcCenterY = (int) (centerPoint.y * scaleY);
        Rect srcRect = new Rect(
                srcCenterX - zoomedHalfWidth,
                srcCenterY - zoomedHalfHeight,
                srcCenterX + zoomedHalfWidth,
                srcCenterY + zoomedHalfHeight
        );

        Rect targetRect = new Rect(0, 0, LENS_WIDTH, LENS_HEIGHT);
        mZoomCanvas.save();
        mZoomCanvas.drawBitmap(background, srcRect, targetRect, null);
        mZoomCanvas.restore();
        // Post effect
        mCanvas.save();
        mCanvas.drawBitmap(mZoomBitmap, null, drawingRect, null);
        mCanvas.restore();

        this.mPaint.setStyle(Paint.Style.STROKE);
        this.mCanvas.drawRect(drawingRect, this.mPaint);

        // Add center indicator
        float centerX = drawingRect.centerX();
        float centerY = drawingRect.centerY();

        this.mPaint.setStyle(Paint.Style.FILL);
        this.mCanvas.drawCircle(centerX, centerY, zoomStrokeWidth, this.mPaint);
        this.mPaint.setStyle(Paint.Style.STROKE);
        this.mPaint.setStrokeWidth(zoomStrokeWidth);
        this.mCanvas.drawCircle(centerX, centerY, OUTER_RADIUS, this.mPaint);

        int lineSize = OUTER_RADIUS / 3;
        // top to center
        this.mCanvas.drawLine(centerX, centerY - OUTER_RADIUS, centerX, centerY - lineSize, this.mPaint);
        // center to bottom
        this.mCanvas.drawLine(centerX, centerY + lineSize, centerX, centerY + OUTER_RADIUS, this.mPaint);
        // left to center
        this.mCanvas.drawLine(centerX - OUTER_RADIUS, centerY, centerX - lineSize, centerY, this.mPaint);
        // right to center
        this.mCanvas.drawLine(centerX + lineSize, centerY, centerX + OUTER_RADIUS, centerY, this.mPaint);
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
        for (int i = 0; i < currentPoints.size(); i++) {
            PointF currentPoint = currentPoints.get(i);
            if (rect.intersect(
                    currentPoint.x - HALF_POINT_TOUCH_AREA,
                    currentPoint.y - HALF_POINT_TOUCH_AREA,
                    currentPoint.x + HALF_POINT_TOUCH_AREA,
                    currentPoint.y + HALF_POINT_TOUCH_AREA)) {
                return true;
            }
        }
        return false;
    }

    private PointF getLabelStartPoint(float textWidth, float textHeight) {
        RectF cornerRect = new RectF();
        float textRectWidth = textWidth + 2f * BORDER_PADDING;
        float textRectHeight = textHeight + 1.5f * BORDER_PADDING;
        cornerRect.set(0, 0, textRectWidth, textRectHeight);
        // Top left
        if (!isCurrentPointsInRect(cornerRect)) {
            return new PointF(2 * BORDER_PADDING, textRectHeight / 2f);
        }
        // Top right
        cornerRect.set(getWidth() - textRectWidth, 0, getWidth(), textRectHeight);
        if (!isCurrentPointsInRect(cornerRect)) {
            return new PointF(getWidth() - textRectWidth, textRectHeight / 2f);
        }
        // Bottom right
        cornerRect.set(getWidth() - textRectWidth, getHeight() - textRectHeight, getWidth(), getHeight());
        if (!isCurrentPointsInRect(cornerRect)) {
            return new PointF(getWidth() - textRectWidth, getHeight() - textHeight - 2 * BORDER_PADDING);
        }

        // Bottom left
        return new PointF(2 * BORDER_PADDING, getHeight() - textHeight - 2 * BORDER_PADDING);
    }


    private void drawText(PointF a, PointF b, Canvas canvas, TextPaint textPaint, Paint bgPaint, String text) {
        float centerX = (a.x + b.x) / 2;
        float centerY = (a.y + b.y) / 2;

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
        PointF textStartPoint = getLabelStartPoint(textWidth, sl.getHeight());
        float translateX = textStartPoint.x;
        float translateY = textStartPoint.y;

//        // calculate text center
//        // top x same, y above center
//        translateY = Math.min(a.y, b.y) - POINT_TOUCH_AREA;
//        // bottom
//        if (translateY - sl.getHeight() < 0) {
//            translateY = Math.max(a.y, b.y) + POINT_TOUCH_AREA;
//        }
        canvas.translate(translateX, translateY);
        // background first
        bgPaint.setStyle(Paint.Style.FILL);
        RectF bgRect = new RectF();
        bgRect.set(
                -BORDER_PADDING,
                -BORDER_PADDING,
                textWidth + BORDER_PADDING,
                sl.getHeight() + BORDER_PADDING
        );
        canvas.drawRoundRect(bgRect, CORNER_RADIUS, CORNER_RADIUS, bgPaint);
        // then text
        sl.draw(canvas);

        canvas.restore();
    }

    private void drawConnection(PointF startPoint, PointF endPoint, boolean hasOffset) {
        if (hasOffset) {
            PointF newEnd = getOuterRadiusPoint(endPoint, startPoint, OUTER_RADIUS_CONNECTION);
            PointF newStart = getOuterRadiusPoint(startPoint, endPoint, OUTER_RADIUS_CONNECTION);
            mCanvas.drawLine(newStart.x, newStart.y, newEnd.x, newEnd.y, mPaint);
        } else {
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
            currentPoints.add(new PointF(x, y));
            return currentPoints.size() < POINTS_COUNT || mCurrentText == null;
        }
        return mCurrentText == null;
    }

    private void drawPoint(PointF point, Paint paint) {
        float x = point.x;
        float y = point.y;
        this.mPaint.setStyle(Paint.Style.FILL);
        this.mCanvas.drawCircle(x, y, INNER_RADIUS, paint);
        this.mPaint.setStyle(Paint.Style.STROKE);
        this.mCanvas.drawCircle(x, y, OUTER_RADIUS, paint);
    }


    @Override
    public boolean pointInLayerRect(PointF point) {
        selectedPoint = getSelectedPointInArea(point);
        return selectedPoint != null;
    }

    private PointF getSelectedPointInArea(PointF point) {
        PointF selected = null;
        for (int i = 0; i < currentPoints.size(); i++) {
            PointF originPoint = currentPoints.get(i);
            if (isInCircle(originPoint.x, originPoint.y, POINT_TOUCH_AREA, point.x, point.y)) {
                selected = originPoint;
            }
        }
        return selected;
    }


    public boolean handleTranslate(PointF delta) {
        if (selectedPoint != null) {
            float newX = selectedPoint.x + delta.x;
            float newY = selectedPoint.y + delta.y;
            boolean toCloseToOtherPoint = false;
            for (int i = 0; i < currentPoints.size(); i++) {
                PointF originPoint = currentPoints.get(i);
                if (originPoint != selectedPoint && isInCircle(originPoint.x, originPoint.y, POINT_TOUCH_AREA, newX, newY)) {
                    toCloseToOtherPoint = true;
                    break;
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
        if (currentPoints.size() > 0) {
            int lastIndex = currentPoints.size() - 1;
            PointF last = currentPoints.get(lastIndex);
            if (last == selectedPoint) {
                selectedPoint = null;
            }
            currentPoints.remove(lastIndex);
            return currentPoints.size() > 0;
        }
        return false;
    }

    @Override
    public String getShapeType() {
        return EntityType.MEASUREMENT_TOOL.label;
    }

    @Override
    public int getDrawingStep() {
        // If point is selected - them drawing has finished
        if (selectedPoint != null) return DEFAULT_DRAWING_STEP;
        if (currentPoints.size() < POINTS_COUNT) {
            return currentPoints.size();
        } else {
            return currentPoints.size() + (mCurrentText == null ? 0 : 1);
        }
    }

    public boolean isTextStep() {
        return getDrawingStep() == POINTS_COUNT;
    }


    public void addText(String text, int fontSize, DisplayMetrics displayMetrics) {
        mCurrentText = text;
        float realFontSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, fontSize,
                displayMetrics);
        mTextPaint.setStyle(Paint.Style.FILL);
        mTextPaint.setTextSize(realFontSize);
        mTextPaint.setColor(Color.WHITE);
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
}
