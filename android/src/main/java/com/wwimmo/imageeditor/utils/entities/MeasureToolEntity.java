package com.wwimmo.imageeditor.utils.entities;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PointF;
import android.graphics.PorterDuff;

import androidx.annotation.IntRange;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.wwimmo.imageeditor.utils.layers.Layer;

import java.util.ArrayList;
import java.util.List;

public class MeasureToolEntity extends MotionEntity {
    private final int mWidth;
    private final int mHeight;
    private final float mBordersPadding;
    private float mStrokeWidth;
    private int mStrokeColor;

    private Paint mPaint;
    private Bitmap mBitmap;
    private Canvas mCanvas;
    private final List<PointF> currentPoints;
    private PointF selectedPoint;

    private static final int POINTS_COUNT = 2;
    private static final int MIN_POINTS_DISTANCE = 200;
    private static final int POINT_TOUCH_AREA = 100;

    public MeasureToolEntity(@NonNull Layer layer,
                             @IntRange(from = 1) int canvasWidth,
                             @IntRange(from = 1) int canvasHeight) {
        super(layer, canvasWidth, canvasHeight);

        this.mWidth = canvasWidth;
        this.mHeight = canvasHeight;
        this.mStrokeWidth = 5;
        this.mBordersPadding = 10;
        this.mStrokeColor = Color.BLACK;
        currentPoints = new ArrayList<>();
        updateEntity(false);
    }

    private void updateEntity(boolean moveToPreviousCenter) {
        configureArrowBitmap(null);

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

    private void configureArrowBitmap(@Nullable Paint paint) {
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
                if (i > 0) {
                    // path between points
                    PointF prevPointF = currentPoints.get(i - 1);
                    mCanvas.drawLine(prevPointF.x, prevPointF.y, pointF.x, pointF.y, mPaint);
                }
                this.drawPoint(pointF, mPaint);
                mPaint.setStrokeWidth(savedStrokeWidth);

            }
        }

        this.mCanvas.restore();
    }

    private void updatePaint(@Nullable Paint paint) {
        if (paint != null && isSelected()) {
            this.mStrokeColor = paint.getColor();
            this.mStrokeWidth = paint.getStrokeWidth();
        }

        this.mPaint = new Paint();
        this.mPaint.setColor(this.mStrokeColor);
        this.mPaint.setStrokeWidth(this.mStrokeWidth / getLayer().getScale());

        // This is essential for the overlapping paths to not result in a weird artefact
        this.mPaint.setStrokeJoin(Paint.Join.BEVEL);

        // TODO: border gets pixelated because it's just done once (initially)!
        this.mPaint.setAntiAlias(true);

        // When scaling the ArrowShape the border gets pixelated, this helps a bit against it.
        // TODO: FIX THIS by somehow scaling the shape as well and not just the bitmap...
        this.mPaint.setFilterBitmap(true);
        this.mPaint.setDither(true);
        this.mPaint.setStyle(Paint.Style.STROKE);
    }

    @Override
    protected void drawContent(@NonNull Canvas canvas, @Nullable Paint drawingPaint) {
        configureArrowBitmap(drawingPaint);
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
            return currentPoints.size() < POINTS_COUNT;
        }
        return false;
    }

    private void drawPoint(PointF point, Paint paint) {
        float x = point.x;
        float y = point.y;
        this.mPaint.setStyle(Paint.Style.FILL);
        this.mCanvas.drawCircle(x, y, 16, paint);
        paint.setStrokeWidth(2);
        this.mPaint.setStyle(Paint.Style.STROKE);
        this.mCanvas.drawCircle(x, y, 20, paint);
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
}
