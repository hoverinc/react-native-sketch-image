//
//  Ruler.m
//  RNImageEditor
//
//

#import "base/MotionEntity.h"
#import "RulerEntity.h"

@implementation RulerEntity
{
}

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

    CGFloat realParentCenterX = parentCenterX - width / 4;
    CGFloat realParentCenterY = parentCenterY - height / 4;
    CGFloat realWidth = width / 2;
    CGFloat realHeight = height / 2;

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

    return self;
}

- (void)drawContent:(CGRect)rect withinContext:(CGContextRef)contextRef {
    CGContextSetLineWidth(contextRef, self.entityStrokeWidth / self.scale);
    CGContextSetStrokeColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
    CGContextSetLineJoin(contextRef, kCGLineJoinBevel);

    CGRect entityRect = CGRectMake(0, 0, rect.size.width, rect.size.height);
    CGFloat padding = (self.bordersPadding + self.entityStrokeWidth) / self.scale;
    entityRect = CGRectInset(entityRect, padding , padding);

    CGFloat maxX = CGRectGetMaxX(entityRect);
    CGFloat centerX = maxX / 2.0;
    CGFloat oneThirdX = maxX / 3.0;
    CGFloat minY = CGRectGetMinY(entityRect);
    CGFloat maxY = CGRectGetMaxY(entityRect);
    CGFloat oneThirdY = maxY / 3.0;
    CGFloat oneSideX = maxY / 8.0;

    CGContextBeginPath(contextRef);
    CGContextMoveToPoint(contextRef, centerX - oneSideX, maxY); // Draw bottom line
    CGContextAddLineToPoint(contextRef, centerX + oneSideX, maxY);
    CGContextMoveToPoint(contextRef, centerX, maxY); // Start at bottom center
    CGContextAddLineToPoint(contextRef, centerX, minY); // Draw line from bottom up
    CGContextMoveToPoint(contextRef, centerX - oneSideX, minY); // Draw top line
    CGContextAddLineToPoint(contextRef, centerX + oneSideX, minY);


    CGContextStrokePath(contextRef);
}

@end
