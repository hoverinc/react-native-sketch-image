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
    CGImageRef background;
}

int MAX_POINTS_COUNT = 2;
int DEFAULT_SELECTED_POSITION = -1;
int TEXT_PADDING = 12;
float pointSize = 22;
float touchPointSize = 50;
int selectedPosition;

int LENS_WIDTH = 100;
int LENS_HEIGHT = 60;

int aimSize = 24;
int halfAimSize;
int aimEdge;

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
    halfAimSize = aimSize /2;
    aimEdge = aimSize / 3;

    points = [NSMutableArray new];
    return self;
}

- (BOOL)isCurrentPointsInRect:(CGRect)rect {
    for (int i=0; i < [points count]; i++) {
        NSValue *val = [points objectAtIndex:i];
        CGPoint p = [val CGPointValue];
        if (CGRectIntersectsRect(rect, [self buildRect:p withSize:touchPointSize])) {
            return true;
        }
    }
    return false;
}

- (CGPoint)getLabelPosition: (CGFloat)width withHeight:(CGFloat) height {
    CGFloat textRectWidth = width + 4 * TEXT_PADDING;
    CGFloat textRectHeight = height + 2 * TEXT_PADDING;
    // Top left
    if (![self isCurrentPointsInRect:CGRectMake(0, 0, textRectWidth, textRectHeight)]){
        return CGPointMake(textRectWidth / 2, textRectHeight / 2);
    }
    // Top right
    if (![self isCurrentPointsInRect:CGRectMake(
                                                self.bounds.size.width - textRectWidth, 0,
                                                textRectWidth, textRectHeight)
    ]){
        return CGPointMake(self.bounds.size.width - textRectWidth / 2, textRectHeight / 2);
    }
    // Bottom left
    return CGPointMake(self.bounds.size.width - textRectWidth / 2,self.bounds.size.height - textRectHeight / 2 - TEXT_PADDING / 2);
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

                // draw text
                if (i == 1 && [self text] != nil) {
                    [self drawText:contextRef];
                }
            }
            // draw actual point
            [self drawPoint:contextRef withPoint:p];
        }
        if (selectedPosition != DEFAULT_SELECTED_POSITION && background != nil) {
            NSValue *val = [points objectAtIndex:selectedPosition];
            CGPoint p = [val CGPointValue];
            [self drawZoomLens:p withinContext:contextRef withBackground:background];
        }
    }
}

- (void)drawZoomLens:(CGPoint) center withinContext:(CGContextRef)contextRef  withBackground:(CGImageRef)background {

    int x0 = center.x - touchPointSize / 2 - LENS_WIDTH;
    int y0 = center.y  - touchPointSize / 2 - LENS_HEIGHT;
    if (x0 < 0) {
        x0 = center.x + touchPointSize / 2;
    }
    if (y0 < 0) {
        y0 = center.y + touchPointSize /2;
    }

    // Calculate display rect
    float centerX = x0 + LENS_WIDTH / 2;
    float centerY = y0 + LENS_HEIGHT / 2;
    // Draw zoom lens

    CGFloat scaleX = CGImageGetWidth(background) / self.bounds.size.width;
    CGFloat scaleY = CGImageGetHeight(background) / self.bounds.size.height;
    CGRect centerRect = CGRectMake((center.x - LENS_WIDTH/4) * scaleX, (center.y - LENS_HEIGHT/4 ) * scaleY, LENS_WIDTH / 2 * scaleX, LENS_HEIGHT / 2 * scaleY);

    CGImageRef lensImage = CGImageCreateWithImageInRect(background, centerRect);

    CGContextTranslateCTM(contextRef, centerX, centerY);
    CGContextScaleCTM(contextRef, 1, -1);
    CGRect entityRect = CGRectMake(-LENS_WIDTH/2 , -LENS_HEIGHT/2, LENS_WIDTH , LENS_HEIGHT);
    CGContextDrawImage(contextRef, entityRect, lensImage);
    CGContextScaleCTM(contextRef, 1, -1);

    centerX = 0;
    centerY = 0;
    // Draw rect
    CGContextSetLineWidth(contextRef, 2);
    CGContextSetStrokeColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
    CGContextStrokeRect(contextRef, entityRect);
    // Draw center indicator


    CGRect aimRect = CGRectMake(centerX - halfAimSize, centerY - halfAimSize, aimSize, aimSize);
    CGContextStrokeEllipseInRect(contextRef, aimRect);
    CGContextFillEllipseInRect(contextRef, CGRectMake(centerX - 1,centerY - 1, 2, 2));
    CGContextBeginPath(contextRef);
    // Top to center
    CGContextMoveToPoint(contextRef, centerX, aimRect.origin.y);
    CGContextAddLineToPoint(contextRef, centerX, aimRect.origin.y + aimEdge);
    // Bottom to center
    CGContextMoveToPoint(contextRef, centerX, aimRect.origin.y + aimSize);
    CGContextAddLineToPoint(contextRef, centerX, aimRect.origin.y + aimSize - aimEdge);
    // Left to center
    CGContextMoveToPoint(contextRef, aimRect.origin.x, centerY);
    CGContextAddLineToPoint(contextRef, aimRect.origin.x + aimEdge, centerY);
    // Right to center
    CGContextMoveToPoint(contextRef, aimRect.origin.x + aimSize, centerY);
    CGContextAddLineToPoint(contextRef, aimRect.origin.x + aimSize - aimEdge, centerY);

    CGContextStrokePath(contextRef);
    // release background image
    CGImageRelease(background);
    CGImageRelease(lensImage);
}

- (CGRect)buildRect:(CGPoint) center withSize:(float)size {
    return CGRectMake(center.x - size/2,center.y - size/2 ,size, size);
}

- (BOOL)addPoint:(CGPoint)point {

    if ([points count] < MAX_POINTS_COUNT) {
        [points addObject: [NSValue valueWithCGPoint:point]];
        return [points count] < MAX_POINTS_COUNT || [self text] == nil;
    }
    return [self text] == nil;
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

- (BOOL)undo {
    if ([self text] != nil){
        self.text = nil;
        return true;
    }
    NSUInteger currentCount = [points count];
    if (currentCount > 0) {
        [points removeLastObject];
        // Clear selection if remove selected point
        if (selectedPosition == currentCount) {
            selectedPosition = DEFAULT_SELECTED_POSITION;
        }
        return [points count] > 0;
    }
    return false;
}


- (NSInteger)getDrawingStep {
    // If point is selected or text added - them drawing has finished
    if (selectedPosition != DEFAULT_SELECTED_POSITION) return DEFAULT_DRAWING_STEP;
    if ([points count] < MAX_POINTS_COUNT) {
        return [points count];
    }else {
        return [points count] + ([self text] != nil ? 1 : 0);
    }
    return DEFAULT_DRAWING_STEP;
}

- (NSString *)getShapeType {
    return @"MeasurementTool";
}

- (void)addText:(NSString *)text withTextSize:(NSNumber *)fontSize withFontType:(NSString *)fontType {
    self.text = text;

    // Let's calculate the initial texts single line width here
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setAlignment:NSTextAlignmentCenter];
    [style setLineHeightMultiple:1.05];
    UIFont *font = [UIFont systemFontOfSize: [fontSize floatValue]];
    if (fontType) {
        font = [UIFont fontWithName: fontType size: [fontSize floatValue]];
    }
    NSDictionary *textAttributes = @{
                            NSFontAttributeName: font,
                            NSForegroundColorAttributeName: [UIColor whiteColor],
                            NSParagraphStyleAttributeName: style
                            };
    CGRect initialTextRect = [text boundingRectWithSize:CGSizeMake([self parentWidth], CGFLOAT_MAX)

                                              options:NSStringDrawingUsesLineFragmentOrigin
                                           attributes:textAttributes
                                              context:nil];
    self.style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [self.style setAlignment:NSTextAlignmentCenter];
    [self.style setLineHeightMultiple:1.05];
    self.fontSize = [fontSize floatValue];
    self.fontType = fontType;
    self.font = [UIFont systemFontOfSize: self.fontSize];
    if (self.fontType) {
        self.font = [UIFont fontWithName: self.fontType size: self.fontSize];
    }
    self.textAttributes = @{
                            NSFontAttributeName: self.font,
                            NSForegroundColorAttributeName: self.entityStrokeColor,
                            NSParagraphStyleAttributeName: self.style
                            };
    CGRect textRect = [self.text boundingRectWithSize:CGSizeMake(self.bounds.size.width, CGFLOAT_MAX)
                                              options:NSStringDrawingUsesLineFragmentOrigin
                                           attributes:self.textAttributes
                                              context:nil];
    self.textSize = textRect.size;

}

- (BOOL)isTextStep{
    return [self getDrawingStep] == MAX_POINTS_COUNT;
}


- (void)drawText:(CGContextRef)contextRef {


     self.textAttributes = @{
                            NSFontAttributeName: self.font,
                            NSForegroundColorAttributeName: [UIColor whiteColor],
                            NSParagraphStyleAttributeName: self.style
                            };

    CGPoint centerPoint = [self getLabelPosition:self.textSize.width withHeight:self.textSize.height];
    CGRect textRect = CGRectMake(
                                 centerPoint.x - self.textSize.width/2,
                                 centerPoint.y - self.textSize.height/2,
                                 self.textSize.width,
                                 self.textSize.height
                                 );
    // draw background
    CGRect rectWthPadding = CGRectMake(
                                       centerPoint.x - self.textSize.width/2 - TEXT_PADDING,
                                       centerPoint.y - self.textSize.height/2 - TEXT_PADDING /2,
                                       self.textSize.width + 2 * TEXT_PADDING,
                                       self.textSize.height + TEXT_PADDING
                                       );
    UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:rectWthPadding cornerRadius: 4];
    [roundedRect fillWithBlendMode: kCGBlendModeNormal alpha:1.0f];
    [self.entityStrokeColor setFill];
    [roundedRect fill];

    [self.text drawInRect:textRect withAttributes:self.textAttributes];
}

- (void)setBackground:(CGImageRef)imageSource {
    background = imageSource;
}

- (void)setIsSelected:(BOOL)isSelected {
    [super setIsSelected:isSelected];
    if (!isSelected) {
        selectedPosition = DEFAULT_SELECTED_POSITION;
        background = nil;
    }
}

@end
