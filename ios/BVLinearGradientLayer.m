#import "BVLinearGradientLayer.h"

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

- (CGPoint)calculateGradientLocationWithAngle:(CGFloat)angle
    CGSize size = self.bounds.size;
    angle = fmodf(angle, 360);
    if (angle < 0)
        angle += 360;

    if (angle == 0) {
        firstPoint = CGPointMake(0, size.height);
        secondPoint = CGPointMake(0, 0);
        return;
    }

    if (angle == 90) {
        firstPoint = CGPointMake(0, 0);
        secondPoint = CGPointMake(size.width, 0);
        return;
    }

    if (angle == 180) {
        firstPoint = CGPointMake(0, 0);
        secondPoint = CGPointMake(0, size.height);
        return;
    }

    if (angle == 270) {
        firstPoint = CGPointMake(size.width, 0);
        secondPoint = CGPointMake(0, 0);
        return;
    }

    // angleDeg is a "bearing angle" (0deg = N, 90deg = E),
    // but tan expects 0deg = E, 90deg = N.
    float slope = tan(Deg2rad(90 - angle_deg));

    // We find the endpoint by computing the intersection of the line formed by
    // the slope, and a line perpendicular to it that intersects the corner.
    float perpendicular_slope = -1 / slope;

    // Compute start corner relative to center, in Cartesian space (+y = up).
    float half_height = size.height / 2f;
    float half_width = size.width / 2f;
    gfx::PointF end_corner;
    if (angle_deg < 90)
        end_corner.SetPoint(half_width, half_height);
    else if (angle_deg < 180)
        end_corner.SetPoint(half_width, -half_height);
    else if (angle_deg < 270)
        end_corner.SetPoint(-half_width, -half_height);
    else
        end_corner.SetPoint(-half_width, half_height);

    // Compute c (of y = mx + c) using the corner point.
    float c = end_corner.y() - perpendicularSlope * end_corner.x();
    float endX = c / (slope - perpendicularSlope);
    float endY = perpendicularSlope * endX + c;

    return CGPointMake(endX, endY)

    // We computed the end point, so set the second point, taking into account the
    // moved origin and the fact that we're in drawing space (+y = down).
    second_point.SetPoint(half_width + end_x, half_height - end_y);
    // Reflect around the center for the start point.
    first_point.SetPoint(half_width - end_x, half_height + end_y);
    return CGSizeMake(cos(angleRad) * length, sin(angleRad) * length);
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

    CGPoint start = self.startPoint, end = self.endPoint;
    
    if (_useAngle)
    {
        CGSize size = [self calculateGradientLocationWithAngle:_angle];
        start.x = _angleCenter.x - size.width / 2;
        start.y = _angleCenter.y - size.height / 2;
        end.x = _angleCenter.x + size.width / 2;
        end.y = _angleCenter.y + size.height / 2;
    }
    
    CGContextDrawLinearGradient(ctx, gradient,
                                CGPointMake(start.x * size.width, start.y * size.height),
                                CGPointMake(end.x * size.width, end.y * size.height),
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);

    CGContextRestoreGState(ctx);
}

@end
