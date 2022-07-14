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

int MAX_POINTS_COUNT = 3;
float pointSize = 22;
float touchPointSize = 50;
CGPoint selectedPoint;

- (instancetype)initAndSetupWithParent: (NSInteger)parentWidth
                          parentHeight: (NSInteger)parentHeight
                         parentCenterX: (CGFloat)parentCenterX
                         parentCenterY: (CGFloat)parentCenterY
                     parentScreenScale: (CGFloat)parentScreenScale
                                 width: (NSInteger)width
                                height: (NSInteger)height
                        bordersPadding: (CGFloat)bordersPadding
                           borderStyle: (enum BorderStyle)borderStyle
                     borderStrokeWidth: (CGFloat)borderStrokeWidth
                     borderStrokeColor: (UIColor *)borderStrokeColor
                     entityStrokeWidth: (CGFloat)entityStrokeWidth
                     entityStrokeColor: (UIColor *)entityStrokeColor {

    CGFloat realParentCenterX = parentCenterX - width / 2;
    CGFloat realParentCenterY = parentCenterY - height / 2;
    CGFloat realWidth = width ;
    CGFloat realHeight = height;

    self = [super initAndSetupWithParent:parentWidth
                            parentHeight:parentHeight
                           parentCenterX:realParentCenterX
                           parentCenterY:realParentCenterY
                       parentScreenScale:parentScreenScale
                                   width:realWidth
                                  height:realHeight
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
            if (__CGPointEqualToPoint(selectedPoint, p)) {
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
    if ([points count] > 0) {
        for (int i=0; i < [points count]; i++) {
            NSValue *val = [points objectAtIndex:i];
            CGPoint p = [val CGPointValue];
            CGRect pointRect = [self buildRect:p withSize:touchPointSize];
            if (CGRectContainsPoint(pointRect, point)) {
                selectedPoint = p;
                return true;
            }
        }
    }
    return false;
}


- (void)drawConnection:(CGContextRef)contextRef withStartPoint:(CGPoint)startPoint withEndPoint:(CGPoint)endPoint {
    CGContextSetLineWidth(contextRef, 2);

    CGContextBeginPath(contextRef);
    CGContextMoveToPoint(contextRef, startPoint.x, startPoint.y);
    CGContextAddLineToPoint(contextRef, endPoint.x, endPoint.y);
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
