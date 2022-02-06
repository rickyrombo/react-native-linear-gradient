package com.BV.LinearGradient;

import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.uimanager.PixelUtil;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Shader;
import android.view.View;

public class LinearGradientView extends View {

    private final Paint mPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private Path mPathForBorderRadius;
    private RectF mTempRectForBorderRadius;
    private LinearGradient mShader;

    private float[] mLocations;
    private float[] mStartPos = {0, 0};
    private float[] mEndPos = {0, 1};
    private int[] mColors;
    private boolean mUseAngle = false;
    private float[] mAngleCenter = new float[]{0.5f, 0.5f};
    private float mAngle = 45f;
    private int[] mSize = {0, 0};
    private float[] mBorderRadii = {0, 0, 0, 0, 0, 0, 0, 0};


    public LinearGradientView(Context context) {
        super(context);
    }

    public void setStartPosition(ReadableArray startPos) {
        mStartPos = new float[]{(float) startPos.getDouble(0), (float) startPos.getDouble(1)};
        drawGradient();
    }

    public void setEndPosition(ReadableArray endPos) {
        mEndPos = new float[]{(float) endPos.getDouble(0), (float) endPos.getDouble(1)};
        drawGradient();
    }

    public void setColors(ReadableArray colors) {
        int[] _colors = new int[colors.size()];
        for (int i=0; i < _colors.length; i++)
        {
            _colors[i] = colors.getInt(i);
        }
        mColors = _colors;
        drawGradient();
    }

    public void setLocations(ReadableArray locations) {
        float[] _locations = new float[locations.size()];
        for (int i=0; i < _locations.length; i++)
        {
            _locations[i] = (float) locations.getDouble(i);
        }
        mLocations = _locations;
        drawGradient();
    }

    public void setUseAngle(boolean useAngle) {
        mUseAngle = useAngle;
        drawGradient();
    }

    public void setAngleCenter(ReadableArray in) {
        mAngleCenter = new float[]{(float) in.getDouble(0), (float) in.getDouble(1)};
        drawGradient();
    }

    public void setAngle(float angle) {
        mAngle = angle;
        drawGradient();
    }

    public void setBorderRadii(ReadableArray borderRadii) {
        float[] _radii = new float[borderRadii.size()];
        for (int i=0; i < _radii.length; i++)
        {
            _radii[i] = PixelUtil.toPixelFromDIP((float) borderRadii.getDouble(i));
        }
        mBorderRadii = _radii;
        updatePath();
        drawGradient();
    }

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        mSize = new int[]{w, h};
        updatePath();
        drawGradient();
    }

    private float[][] calculateGradientLocationWithAngle(float angle) {
        angle = angle % 360f;
        if (angle < 0f)
            angle += 360f;

        if (angle == 0f) {
            return new float[][] { 
                new float[] { 0f, mSize[1] },
                new float[] { 0f, 0f }
            };
        }

        if (angle == 90f) {
            return new float[][] { 
                new float[] { 0f, 0f },
                new float[] { mSize[0], 0f }
            };
        }

        if (angle == 180f) {
            return new float[][] { 
                new float[] { 0f, 0f },
                new float[] { 0f, mSize[1] }
            };
        }

        if (angle == 270f) {
            return new float[][] { 
                new float[] { mSize[0], 0f },
                new float[] { 0f, 0f }
            };
        }

        // angleDeg is a "bearing angle" (0deg = N, 90deg = E),
        // but tan expects 0deg = E, 90deg = N.
        float slope = (float)Math.tan((90 - angle) * Math.PI / 180.0f);

        // We find the endpoint by computing the intersection of the line formed by
        // the slope, and a line perpendicular to it that intersects the corner.
        float perpendicularSlope = -1 / slope;

        // Compute start corner relative to center, in Cartesian space (+y = up).
        float halfWidth = mSize[0] / 2;
        float halfHeight = mSize[1] / 2;
        float[] endCorner;
        if (angle < 90f) {
            endCorner = new float[] { halfWidth, halfHeight };
        } else if (angle < 180f) {
            endCorner = new float[] { halfWidth, -halfHeight };
        } else if (angle < 270f) {
            endCorner = new float[] { -halfWidth, -halfHeight };
        } else {
            endCorner = new float[] { -halfWidth, halfHeight };
        }

        // Compute c (of y = mx + c) using the corner point.
        float c = endCorner[1] - perpendicularSlope * endCorner[0];
        float endX = c / (slope - perpendicularSlope);
        float endY = perpendicularSlope * endX + c;

        // We computed the end point, so set the second point, taking into account the
        // moved origin and the fact that we're in drawing space (+y = down).
        // Reflect around the center for the start point.
        float centerX = mAngleCenter[0] * mSize[0];
        float centerY = mAngleCenter[1] * mSize[1];
        return new float[][] {
            new float[] { centerX + endX, centerY - endY },
            new float[] { centerX - endX, centerY + endY }
        };
    }

    private void drawGradient() {
        // guard against crashes happening while multiple properties are updated
        if (mColors == null || (mLocations != null && mColors.length != mLocations.length))
            return;

        float[] startPos;
        float[] endPos;

        if (mUseAngle && mAngleCenter != null) {
            float[][] positions = calculateGradientLocationWithAngle(mAngle);
            startPos = positions[0];
            endPos = positions[1];
        } else {
            startPos = new float[] { mStartPos[0] * mSize[0], mStartPos[1] * mSize[1] };
            endPos = new float[] { mEndPos[0] * mSize[0], mEndPos[1] * mSize[1] };
        }

        mShader = new LinearGradient(
                startPos[0],
                startPos[1],
                endPos[0],
                endPos[1],
            mColors,
            mLocations,
            Shader.TileMode.CLAMP);
        mPaint.setShader(mShader);
        invalidate();
    }

    private void updatePath() {
        if (mPathForBorderRadius == null) {
            mPathForBorderRadius = new Path();
            mTempRectForBorderRadius = new RectF();
        }
        mPathForBorderRadius.reset();
        mTempRectForBorderRadius.set(0f, 0f, (float) mSize[0], (float) mSize[1]);
        mPathForBorderRadius.addRoundRect(
            mTempRectForBorderRadius,
            mBorderRadii,
            Path.Direction.CW);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        if (mPathForBorderRadius == null) {
            canvas.drawPaint(mPaint);
        } else {
            canvas.drawPath(mPathForBorderRadius, mPaint);
        }
    }
}
