//
//  MeasurementEntity.m
//  RNImageEditor
//
//

#import "base/MotionEntity.h"
#import "MeasurementEntity.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation MeasurementEntity
{
    NSMutableArray *points;
}

int MAX_POINTS_COUNT = 2;
int DEFAULT_SELECTED_POSITION = -1;
float pointSize = 22;
float touchPointSize = 50;
int selectedPosition;

- (instancetype)initAndSetupWithParent: (NSInteger)parentWidth
                          parentHeight: (NSInteger)parentHeight
                         parentCenterX: (CGFloat)parentCenterX
                         parentCenterY: (CGFloat)parentCenterY
                     parentScreenScale: (CGFloat)parentScreenScale
                        bordersPadding: (CGFloat)bordersPadding
                           borderStyle: (enum BorderStyle)borderStyle
                     borderStrokeWidth: (CGFloat)borderStrokeWidth
                     borderStrokeColor: (UIColor *)borderStrokeColor
                     entityStrokeWidth: (CGFloat)entityStrokeWidth
                     entityStrokeColor: (UIColor *)entityStrokeColor {

    CGFloat realParentCenterX = parentCenterX - parentWidth / 2;
    CGFloat realParentCenterY = parentCenterY - parentHeight / 2;
    selectedPosition = DEFAULT_SELECTED_POSITION;
    self = [super initAndSetupWithParent:parentWidth
                            parentHeight:parentHeight
                           parentCenterX:realParentCenterX
                           parentCenterY:realParentCenterY
                       parentScreenScale:parentScreenScale
                                   width:parentWidth
                                  height:parentHeight
                          bordersPadding:bordersPadding
                             borderStyle:borderStyle
                       borderStrokeWidth:borderStrokeWidth
                       borderStrokeColor:borderStrokeColor
                       entityStrokeWidth:entityStrokeWidth
                       entityStrokeColor:entityStrokeColor];

    if (self) {
        self.MIN_SCALE = 0.3f;
    }

    points = [NSMutableArray new];
    return self;
}

- (void)drawContent:(CGRect)rect withinContext:(CGContextRef)contextRef {
    if ([points count] > 0) {
        for (int i=0; i < [points count]; i++) {
            NSValue *val = [points objectAtIndex:i];
            CGPoint p = [val CGPointValue];
            // draw highlight
            if (selectedPosition == i) {
                CGRect highlightCircleRect = [self buildRect:p withSize:touchPointSize];
                CGContextSetAlpha(contextRef, 0.5);
                CGContextSetFillColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
                CGContextFillEllipseInRect(contextRef, highlightCircleRect);
                CGContextSetAlpha(contextRef, 1);
            }

            // draw line between points
            if (i > 0) {
                NSValue *preVal = [points objectAtIndex:i - 1];
                CGPoint prevPoint = [preVal CGPointValue];
                [self drawConnection:contextRef withStartPoint:prevPoint withEndPoint:p];
            }
            // draw actual point
            [self drawPoint:contextRef withPoint:p];
        }
    }
}

- (CGRect)buildRect:(CGPoint) center withSize:(float)size {
    return CGRectMake(center.x - size/2,center.y - size/2 ,size, size);
}

- (BOOL)addPoint:(CGPoint)point {
    if ([points count] < MAX_POINTS_COUNT) {
        [points addObject: [NSValue valueWithCGPoint:point]];
        return [points count] < MAX_POINTS_COUNT;
    }
    return false;
}

- (BOOL)isPointInEntity:(CGPoint)point {
    selectedPosition = DEFAULT_SELECTED_POSITION;
    if ([points count] == MAX_POINTS_COUNT) {
        for (int i=0; i < [points count]; i++) {
            NSValue *val = [points objectAtIndex:i];
            CGPoint p = [val CGPointValue];
            CGRect pointRect = [self buildRect:p withSize:touchPointSize];
            if (CGRectContainsPoint(pointRect, point)) {
                selectedPosition = i;
                return true;
            }
        }
    }
    return false;
}


- (void)rotateEntityBy:(CGFloat)rotationInRadians {
    // ignore call
}

- (void)moveEntityTo:(CGPoint)locationDiff {
    if (selectedPosition != DEFAULT_SELECTED_POSITION){
        NSValue *val = [points objectAtIndex:selectedPosition];
        CGPoint p = [val CGPointValue];
        p.x = p.x + locationDiff.x;
        p.y = p.y + locationDiff.y;
        points[selectedPosition] = [NSValue valueWithCGPoint:p];
    }
}

- (void)scaleEntityBy:(CGFloat)newScale {
    // ignore call
}


-(double)distance:(float)x1 withY:(float)y1 withX2:(float)x2 withY2:(float)y2 {
    return hypot((x2 - x1), (y2 -y1));
}

- (CGPoint)getOuterRadiusPoint:(CGPoint)startPoint withEndPoint:(CGPoint)endPoint withRadius:(float) radius {
    // Build triangle
    double a = [self distance:startPoint.x withY:startPoint.y withX2:endPoint.x withY2:startPoint.y];
    double b = [self distance:endPoint.x withY:endPoint.y withX2:endPoint.x withY2:startPoint.y];

    float diffX = endPoint.x - startPoint.x;
    float diffY = endPoint.y - startPoint.y;
    
    double theta;
    // get the correct angle depends on points positions
    if (diffX <= 0 && diffY <= 0) {
        theta = M_PI + atan(b/a);
    }else if (diffX > 0 && diffY <= 0) {
        theta =  - atan(b/a);
    } else if (diffX <= 0 && diffY > 0){
        theta = M_PI - atan(b/a);
    } else {
        theta = atan(b/a);
    }

    float x = startPoint.x + radius * cos(theta);
    float y = startPoint.y + radius * sin(theta);
    return CGPointMake(x, y);
}

- (void)drawConnection:(CGContextRef)contextRef withStartPoint:(CGPoint)startPoint withEndPoint:(CGPoint)endPoint {
    CGContextSetLineWidth(contextRef, 2);
    CGPoint newStart = [self getOuterRadiusPoint:startPoint withEndPoint:endPoint withRadius:10];
    CGPoint newEnd = [self getOuterRadiusPoint:endPoint withEndPoint:startPoint withRadius:10];

    CGContextBeginPath(contextRef);
    CGContextMoveToPoint(contextRef, newStart.x, newStart.y);
    CGContextAddLineToPoint(contextRef, newEnd.x, newEnd.y);
    CGContextStrokePath(contextRef);
}

- (void)drawPoint:(CGContextRef)contextRef withPoint:(CGPoint)point {
    CGContextSetAlpha(contextRef, 1);
    CGRect circleRect = [self buildRect:point withSize:pointSize];
    CGContextSetLineWidth(contextRef, 2);
    circleRect = CGRectInset(circleRect, 2 , 2);
    CGContextSetLineWidth(contextRef, 2);
    CGContextSetStrokeColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
    CGContextStrokeEllipseInRect(contextRef, circleRect);

    circleRect = [self buildRect:point withSize:pointSize];
    circleRect = CGRectInset(circleRect, 6 , 6);
    CGContextSetFillColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
    CGContextFillEllipseInRect(contextRef, circleRect);
}
@end
