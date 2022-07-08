package com.wwimmo.imageeditor.utils.entities;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PointF;
import android.graphics.PorterDuff;

import androidx.annotation.IntRange;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.wwimmo.imageeditor.utils.layers.Layer;

import java.util.ArrayList;
import java.util.List;

public class MeasureToolEntity extends MotionEntity {
    private int mWidth;
    private int mHeight;
    private float mBordersPadding;
    private float mStrokeWidth;
    private int mStrokeColor;

    private Paint mArrowPaint;
    private Bitmap mArrowBitmap;
    private Canvas mArrowCanvas;
    private List<PointF> currentPoints;

    private static final int POINTS_COUNT = 3;
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

        float width = this.mArrowBitmap.getWidth();
        float height = this.mArrowBitmap.getHeight();

        float widthAspect = 1.0F * canvasWidth / this.mArrowBitmap.getWidth();
        float heightAspect = 1.0F * canvasHeight / this.mArrowBitmap.getHeight();

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
        if (this.mArrowBitmap == null) {
            this.mArrowBitmap = Bitmap.createBitmap(getWidth(), getHeight(), Bitmap.Config.ARGB_8888);
            this.mArrowCanvas = new Canvas(this.mArrowBitmap);
        }
        this.mArrowCanvas.save();
        this.mArrowCanvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR);
        float savedStrokeWidth  = mArrowPaint.getStrokeWidth();
        if (currentPoints.size() > 0) {
            for (int i = 0; i < currentPoints.size(); i ++) {
                PointF pointF = currentPoints.get(i);
                this.drawPoint(pointF, mArrowPaint);
                mArrowPaint.setStrokeWidth(savedStrokeWidth);
                if (i > 0){
                    PointF prevPointF = currentPoints.get(i -1);
                    mArrowCanvas.drawLine(prevPointF.x, prevPointF.y, pointF.x, pointF.y, mArrowPaint);
                }
            }
        }

        this.mArrowCanvas.restore();
    }

    private void drawArrow() {
        int halfWidth = mWidth / 2;
        int halfHeight = mHeight / 2;
        int sideLine  = mHeight / 8;

        float centerX = getLayer().getX() + halfWidth;
        float centerY = getLayer().getY() + halfHeight;


        this.mArrowCanvas.drawCircle(centerX, centerY, 20, mArrowPaint);
    }

    private void updatePaint(@Nullable Paint paint) {
        if (paint != null && isSelected()) {
            this.mStrokeColor = paint.getColor();
            this.mStrokeWidth = paint.getStrokeWidth();
        }
        
        this.mArrowPaint = new Paint();
        this.mArrowPaint.setColor(this.mStrokeColor);
        this.mArrowPaint.setStrokeWidth(this.mStrokeWidth / getLayer().getScale());

        // This is essential for the overlapping paths to not result in a weird artefact
        this.mArrowPaint.setStrokeJoin(Paint.Join.BEVEL);

        // TODO: Arrow Border gets pixelated because it's just done once (initially)!
        this.mArrowPaint.setAntiAlias(true);

        // When scaling the ArrowShape the border gets pixelated, this helps a bit against it.
        // TODO: FIX THIS by somehow scaling the shape as well and not just the bitmap...
        this.mArrowPaint.setFilterBitmap(true);
        this.mArrowPaint.setDither(true);
        this.mArrowPaint.setStyle(Paint.Style.STROKE);
    }

    @Override
    protected void drawContent(@NonNull Canvas canvas, @Nullable Paint drawingPaint) {
        configureArrowBitmap(drawingPaint);
        canvas.drawBitmap(this.mArrowBitmap, matrix, this.mArrowPaint);
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
        if (this.mArrowBitmap != null && !this.mArrowBitmap.isRecycled()) {
            this.mArrowBitmap.recycle();
        }
    }

    public boolean addPoint(float x, float y) {
        if (currentPoints.size() < POINTS_COUNT) {
            currentPoints.add(new PointF(x, y));
            return true;
        }
        return false;
    }

    private void drawPoint(PointF point, Paint paint) {
        float x = point.x;
        float y = point.y;
        this.mArrowPaint.setStyle(Paint.Style.FILL);
        this.mArrowCanvas.drawCircle(x, y, 16, paint);
        paint.setStrokeWidth(2);
        this.mArrowPaint.setStyle(Paint.Style.STROKE);
        this.mArrowCanvas.drawCircle(x, y, 20, paint);
    }

    @Override
    public boolean pointInLayerRect(PointF point) {
        // TOD add custom check
        return false;
    }
}