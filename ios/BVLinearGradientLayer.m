#import "BVLinearGradientLayer.h"

#include <math.h>
#import <UIKit/UIKit.h>

@implementation BVLinearGradientLayer

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        self.needsDisplayOnBoundsChange = YES;
        self.masksToBounds = YES;
        _startPoint = CGPointMake(0.5, 0.0);
        _endPoint = CGPointMake(0.5, 1.0);
        _angleCenter = CGPointMake(0.5, 0.5);
        _angle = 45.0;
    }

    return self;
}

- (void)setColors:(NSArray<id> *)colors
{
    _colors = colors;
    [self setNeedsDisplay];
}

- (void)setLocations:(NSArray<NSNumber *> *)locations
{
    _locations = locations;
    [self setNeedsDisplay];
}

- (void)setStartPoint:(CGPoint)startPoint
{
    _startPoint = startPoint;
    [self setNeedsDisplay];
}

- (void)setEndPoint:(CGPoint)endPoint
{
    _endPoint = endPoint;
    [self setNeedsDisplay];
}

- (void)display {
    [super display];

    BOOL hasAlpha = NO;

    for (NSInteger i = 0; i < self.colors.count; i++) {
        hasAlpha = hasAlpha || CGColorGetAlpha(self.colors[i].CGColor) < 1.0;
    }

    UIGraphicsBeginImageContextWithOptions(self.bounds.size, !hasAlpha, 0.0);
    CGContextRef ref = UIGraphicsGetCurrentContext();
    [self drawInContext:ref];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    self.contents = (__bridge id _Nullable)(image.CGImage);
    self.contentsScale = image.scale;

    UIGraphicsEndImageContext();
}
    
- (void)setUseAngle:(BOOL)useAngle
{
    _useAngle = useAngle;
    [self setNeedsDisplay];
}

- (void)setAngleCenter:(CGPoint)angleCenter
{
    _angleCenter = angleCenter;
    [self setNeedsDisplay];
}

- (void)setAngle:(CGFloat)angle
{
    _angle = angle;
    [self setNeedsDisplay];
}

// This method is adapted and ported from the Chromium implementation:
// https://source.chromium.org/chromium/chromium/src/+/main:third_party/blink/renderer/core/css/css_gradient_value.cc;l=883-952;drc=919811d4a39a74216d96d1f1c346efef3ef85e85
/*
 * Copyright (C) 2008 Apple Inc.  All rights reserved.
 * Copyright (C) 2015 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
- (NSArray *)endPointsFromAngle:(CGFloat)angle
{
    CGSize size = self.bounds.size;
    angle = fmodf(angle, 360);
    if (angle < 0)
        angle += 360;

    // Avoid undefined slopes
    if (angle == 0) {
        return @[
            [NSValue valueWithCGPoint:CGPointMake(0, size.height)],
            [NSValue valueWithCGPoint:CGPointMake(0, 0)]
        ];
    }

    if (angle == 90) {
        return @[
            [NSValue valueWithCGPoint:CGPointMake(0, 0)],
            [NSValue valueWithCGPoint:CGPointMake(size.width, 0)]
        ];
    }

    if (angle == 180) {
        return @[
            [NSValue valueWithCGPoint:CGPointMake(0, 0)],
            [NSValue valueWithCGPoint:CGPointMake(0, size.height)]
        ];
    }

    if (angle == 270) {
        return @[
            [NSValue valueWithCGPoint:CGPointMake(size.width, 0)],
            [NSValue valueWithCGPoint:CGPointMake(0, 0)]
        ];
    }

    // angleDeg is a "bearing angle" (0deg = N, 90deg = E),
    // but tan expects 0deg = E, 90deg = N.
    float slope = tan((90 - angle) * M_PI / 180.0);

    // We find the endpoint by computing the intersection of the line formed by
    // the slope, and a line perpendicular to it that intersects the corner.
    float perpendicularSlope = -1 / slope;

    // Compute start corner relative to center, in Cartesian space (+y = up).
    float halfHeight = size.height / 2.0;
    float halfWidth = size.width / 2.0;
    CGPoint endCorner;
    if (angle < 90)
        endCorner = CGPointMake(halfWidth, halfHeight);
    else if (angle < 180)
        endCorner = CGPointMake(halfWidth, -halfHeight);
    else if (angle < 270)
        endCorner = CGPointMake(-halfWidth, -halfHeight);
    else
        endCorner = CGPointMake(-halfWidth, halfHeight);

    // Compute c (of y = mx + c) using the corner point.
    float c = endCorner.y - perpendicularSlope * endCorner.x;
    float endX = c / (slope - perpendicularSlope);
    float endY = perpendicularSlope * endX + c;

    // Translate the end point around the angle center, and relect across to get the start point
    CGPoint angleCenterReal = CGPointMake(_angleCenter.x * size.width, _angleCenter.y * size.height);
    return @[
        [NSValue valueWithCGPoint:CGPointMake(angleCenterReal.x - endX, angleCenterReal.y + endY)],
        [NSValue valueWithCGPoint:CGPointMake(angleCenterReal.x + endX, angleCenterReal.y - endY)]
    ];
}
    
- (void)drawInContext:(CGContextRef)ctx
{
    [super drawInContext:ctx];

    CGContextSaveGState(ctx);

    CGSize size = self.bounds.size;
    if (!self.colors || self.colors.count == 0 || size.width == 0.0 || size.height == 0.0)
        return;


    CGFloat *locations = nil;

    locations = malloc(sizeof(CGFloat) * self.colors.count);

    for (NSInteger i = 0; i < self.colors.count; i++)
    {
        if (self.locations.count > i)
        {
            locations[i] = self.locations[i].floatValue;
        }
        else
        {
            locations[i] = (1.0 / (self.colors.count - 1)) * i;
        }
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSMutableArray *colors = [[NSMutableArray alloc] initWithCapacity:self.colors.count];
    for (UIColor *color in self.colors) {
        [colors addObject:(id)color.CGColor];
    }

    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)colors, locations);

    free(locations);

    CGPoint start, end;
    
    if (_useAngle)
    {
        NSArray<NSValue *> *anglePoints = [self endPointsFromAngle:_angle];
        start = anglePoints[0].CGPointValue;
        end = anglePoints[1].CGPointValue;
    }
    else
    {
        start = CGPointMake(self.startPoint.x * size.width, self.startPoint.y * size.height);
        end = CGPointMake(self.endPoint.x * size.width, self.endPoint.y * size.height);
    }
    
    CGContextDrawLinearGradient(ctx, gradient,
                                start,
                                end,
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);

    CGContextRestoreGState(ctx);
}

@end
