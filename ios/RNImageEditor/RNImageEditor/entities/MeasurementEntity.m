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
    NSMutableArray *pointsVisited;
    CGImageRef background;
    UIImage* endpointImage;
}

float ENDPOINT_OFFSET_RATIO = 0.125;
bool hasFocusHighlight = false;
int MAX_POINTS_COUNT = 2;
int DEFAULT_SELECTED_POSITION = -1;
int TEXT_PADDING = 8;
int TEXT_BOX_SIZE = 24;
float pointSize = 12;
float touchPointSize = 37;
int selectedPosition;

int LENS_WIDTH = 72;
int LENS_HEIGHT = 72;

int aimSize = 4;


// Pulsing point indicator
CGFloat pulseScale = 1.0;
BOOL isGrowing;
BOOL isTimerRunning;
NSTimer *timer;


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
    pointsVisited = [NSMutableArray new];
    return self;
}

- (float)getTouchRadius {
    return touchPointSize;
}

- (BOOL)isCurrentPointsInRect:(CGRect)rect {
    float touchArea = 2 * [self getTouchRadius];
    for (int i=0; i < [points count]; i++) {
        NSValue *val = [points objectAtIndex:i];
        CGPoint p = [val CGPointValue];
        if (CGRectIntersectsRect(rect, [self buildRect:p withSize:touchArea])) {
            return true;
        }
    }
    return false;
}

- (CGPoint)getCornerPosition: (CGFloat)width withHeight:(CGFloat) height {
    int sidePadding =TEXT_PADDING;
    CGFloat resultRectWidth = width + sidePadding;
    CGFloat resultRectHeight = height + sidePadding;

    // Bottom left
    // Check for minimum visible rect
    CGFloat calculatedHeight = self.bounds.size.height;
    if (self.measuredHeight > 0 && self.measuredHeight < calculatedHeight) {
        calculatedHeight = self.measuredHeight;
    }
    if (![self isCurrentPointsInRect:CGRectMake(0, calculatedHeight - resultRectHeight, resultRectWidth, resultRectHeight)]) {
        return CGPointMake(resultRectWidth / 2 + sidePadding / 2, calculatedHeight - resultRectHeight / 2 - sidePadding / 2);
    }

    // Top left
    if (![self isCurrentPointsInRect:CGRectMake(0, 0, resultRectWidth, resultRectHeight)]){
        return CGPointMake(resultRectWidth / 2, resultRectHeight / 2);
    }
    // Top right
    if (![self isCurrentPointsInRect:CGRectMake(
                                                self.bounds.size.width - resultRectWidth, 0,
                                                resultRectWidth, resultRectHeight)
    ]){
        return CGPointMake(self.bounds.size.width - resultRectWidth / 2, resultRectHeight / 2);
    }

    return CGPointMake(self.bounds.size.width - resultRectWidth / 2, calculatedHeight - resultRectHeight / 2 - sidePadding / 2);
}

- (void)drawContent:(CGRect)rect withinContext:(CGContextRef)contextRef {
    if ([points count] > 0) {
        for (int i=0; i < [points count]; i++) {

            NSValue *val = [points objectAtIndex:i];
            CGPoint p = [val CGPointValue];

            // draw line between points
            if (i > 0) {
                NSValue *preVal = [points objectAtIndex:i - 1];
                CGPoint prevPoint = [preVal CGPointValue];
                [self drawConnection:contextRef withStartPoint:prevPoint withEndPoint:p withOffsetEnable:false];
            }
            BOOL pointSelect = selectedPosition == i && self.localFocused;

            // draw highlight
            if (pointSelect == TRUE) {
                CGPoint point = p;
                // Draw selection indicator
                CGContextSetLineWidth(contextRef, 8);
                CGContextSetStrokeColorWithColor(contextRef, [[self.entityStrokeColor colorWithAlphaComponent:0.5f] CGColor]);
                CGContextAddArc(contextRef, point.x  , point.y, touchPointSize , 0, 2*M_PI, 0);
                CGContextStrokePath(contextRef);
            }else if ([points count] > 1) {
                // Pulsing indicator
                // Calculate the pulsing circle's size
                CGFloat arcWidth =  8 * pulseScale;
                CGContextSetLineWidth(contextRef, arcWidth);
                CGContextSetStrokeColorWithColor(contextRef, [[self.entityStrokeColor colorWithAlphaComponent:0.5f] CGColor]);
                CGContextAddArc(contextRef, p.x  , p.y, 14 , 0, 2 * M_PI, 0);
                CGContextStrokePath(contextRef);
            }
            // Restore
            CGContextSetLineWidth(contextRef, 2);
            CGContextSetStrokeColorWithColor(contextRef, [self.entityStrokeColor CGColor]);

            bool hasText = [self text] != nil;
            // draw text
            if (i == 1 && hasText) {
                NSValue *preVal = [points objectAtIndex:i - 1];
                CGPoint prevPoint = [preVal CGPointValue];
                CGPoint centerPoint = [self getTextUncrossedPosition:prevPoint withB:p withTextWidth:self.textSize.width/2];

                [self drawText:contextRef withCenterPoint:centerPoint];
            }
            // draw actual point
            [self drawPoint:contextRef withPoint:p];
        }
        if (selectedPosition != DEFAULT_SELECTED_POSITION && background != nil && self.localFocused) {
            NSValue *val = [points objectAtIndex:selectedPosition];
            CGPoint p = [val CGPointValue];
            [self drawZoomLens:p withinContext:contextRef withBackground:background];
        }

        // Draw indicator for not touched points, one at a time
        if ([pointsVisited count] > 1 && endpointImage != nil) {
            bool visitedFirst = [[pointsVisited objectAtIndex:0] boolValue];
            bool visitedSecond = [[pointsVisited objectAtIndex:1] boolValue];
            if (!visitedSecond && selectedPosition != 1) {
                // Highlight second
                [self drawNotVisitedPointIndicator:contextRef withPoint:[[points objectAtIndex:1] CGPointValue]];
            }else if (!visitedFirst  && selectedPosition != 0) {
                // Highlight first
                [self drawNotVisitedPointIndicator:contextRef withPoint:[[points objectAtIndex:0] CGPointValue]];
            }

        }
    }
}

-(CGPoint)getTextUncrossedPosition:(CGPoint) a withB:(CGPoint) b withTextWidth:(float) textWidth {
    float centerX = (a.x + b.x) /2;
    float centerY = (a.y + b.y) /2;

    float offsetX = textWidth + touchPointSize;
    float offsetY = touchPointSize;

    CGFloat angle = atan2(b.y - a.y, b.x - a.x);
    CGFloat smallThreshold = 0.1;
    CGFloat offsetXDiag = offsetX * cos(angle + M_PI_2);
    CGFloat offsetYDiag = offsetY * sin(angle + M_PI_2);

    return CGPointMake(centerX + offsetXDiag, centerY + offsetYDiag);
}

-(void)drawNotVisitedPointIndicator:(CGContextRef) contextRef withPoint:(CGPoint)point {
    CGImageRef imageRef = nil;
        if (endpointImage != nil) {
            imageRef = endpointImage.CGImage;
        }

    if (imageRef != nil && endpointImage.size.width > 0) {
        CGFloat width = endpointImage.size.width;
        CGFloat height = endpointImage.size.height;

        CGContextSaveGState(contextRef);
        CGContextTranslateCTM(contextRef, point.x + width/2, point.y + height/2 + 20);
        CGContextScaleCTM(contextRef, 1.0, -1.0);
        CGRect endpointRect = CGRectMake(-width /2, -height/2, width, height);
        CGContextDrawImage(contextRef,endpointRect, imageRef);
        CGContextScaleCTM(contextRef, 1.0, -1.0);
        CGContextTranslateCTM(contextRef, 0, 0);
        CGContextRestoreGState(contextRef);
    }
}

void drawCircularImageInContext(CGContextRef context, CGImageRef image, CGRect rect) {
    CGContextSaveGState(context);
    CGPathRef circlePath = CGPathCreateWithEllipseInRect(rect, NULL);
    CGContextAddPath(context, circlePath);
    CGContextClip(context);
    CGContextDrawImage(context, rect, image);
    CGPathRelease(circlePath);
    CGContextRestoreGState(context);
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
    if (scaleX ==0 || scaleY ==0){
        return;
    }
    CGRect centerRect = CGRectMake((center.x - LENS_WIDTH/4) * scaleX, (center.y - LENS_HEIGHT/4 ) * scaleY, LENS_WIDTH / 2 * scaleX, LENS_HEIGHT / 2 * scaleY);
    CGImageRef lensImage = CGImageCreateWithImageInRect(background, centerRect);

    // Draw zoomed image
    CGPoint drawingCenter = [self getCornerPosition:LENS_WIDTH withHeight:LENS_HEIGHT];
    CGRect entityRect = CGRectMake(-LENS_WIDTH/2 , -LENS_HEIGHT/2, LENS_WIDTH , LENS_HEIGHT);
    CGContextTranslateCTM(contextRef, drawingCenter.x, drawingCenter.y);
    CGContextScaleCTM(contextRef, 1, -1);
    drawCircularImageInContext(contextRef, lensImage, entityRect);
    CGContextScaleCTM(contextRef, 1, -1);
    // release background image
    CGImageRelease(background);
    CGImageRelease(lensImage);


    centerX = 0;
    centerY = 0;
    // Draw circle
    CGContextSetLineWidth(contextRef, 4);
    CGContextSetStrokeColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
    CGContextStrokeEllipseInRect(contextRef, entityRect);
    // Restore line width
    CGContextSetLineWidth(contextRef, 2);

    // Draw center indicator
    CGRect aimRect = CGRectMake(centerX - aimSize/2, centerY - aimSize/2, aimSize, aimSize);
    CGContextSetFillColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
    CGContextFillEllipseInRect(contextRef, aimRect);
}

- (CGRect)buildRect:(CGPoint) center withSize:(float)size {
    return CGRectMake(center.x - size/2,center.y - size/2 ,size, size);
}

- (BOOL)addPoint:(CGPoint)point {
    if ([points count] < MAX_POINTS_COUNT) {
        [points addObject: [NSValue valueWithCGPoint:point]];
        [pointsVisited addObject: [NSNumber numberWithBool:FALSE]];
        [self setLocalFocused:true];

        if ([points count] > 1 && !isTimerRunning) {
            [self startTimer];
        }
        return [points count] < MAX_POINTS_COUNT || [self text] == nil;
    }
    return [self text] == nil;
}

- (BOOL)isPointInEntity:(CGPoint)point {
    selectedPosition = DEFAULT_SELECTED_POSITION;
    float touchArea = 2 * [self getTouchRadius];
    for (int i=0; i < [points count]; i++) {
        NSValue *val = [points objectAtIndex:i];
        CGPoint p = [val CGPointValue];
        CGRect pointRect = [self buildRect:p withSize:touchArea];
        if (CGRectContainsPoint(pointRect, point)) {
            selectedPosition = i;
            [self setLocalFocused:true];
            return true;
        }
    }

    [self setLocalFocused:false];
    return false;
}


- (void)rotateEntityBy:(CGFloat)rotationInRadians {
    // ignore call
}

- (void)moveEntityTo:(CGPoint)locationDiff {
    if (selectedPosition != DEFAULT_SELECTED_POSITION && [points count] > selectedPosition){
        NSValue *val = [points objectAtIndex:selectedPosition];
        CGPoint p = [val CGPointValue];
        p.x = p.x + locationDiff.x;
        p.y = p.y + locationDiff.y;
        points[selectedPosition] = [NSValue valueWithCGPoint:p];
        pointsVisited[selectedPosition] = [NSNumber numberWithBool:TRUE];
    }
}

- (void)scaleEntityBy:(CGFloat)newScale {
    // ignore call
}


-(double)distance:(float)x1 withY:(float)y1 withX2:(float)x2 withY2:(float)y2 {
    return hypot((x2 - x1), (y2 -y1));
}

-(double)getAngleBetweenPoints:(CGPoint)startPoint withEndPoint:(CGPoint)endPoint {
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

    return theta;
}

-(void)drawLineIndicator:(CGPoint)startPoint withEndPoint:(CGPoint)endPoint withSize:(int)size withContext:(CGContextRef)contextRef {
    CGContextSetLineWidth(contextRef, 2);
    CGContextSetStrokeColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
    CGContextBeginPath(contextRef);
    double thetaTop = [self getAngleBetweenPoints:startPoint withEndPoint:endPoint] - M_PI / 2;
    double thetaBottom = thetaTop - M_PI;
    // for the start point
    float x1 = startPoint.x + size * cos(thetaTop);
    float y1 = startPoint.y + size * sin(thetaTop);

    float x2 = startPoint.x + size * cos(thetaBottom);
    float y2 = startPoint.y + size * sin(thetaBottom);

    CGContextMoveToPoint(contextRef, x1, y1);
    CGContextAddLineToPoint(contextRef, x2, y2);
    CGContextStrokePath(contextRef);

    // for the end point
    x1 = endPoint.x + size * cos(thetaTop);
    y1 = endPoint.y + size * sin(thetaTop);

    x2 = endPoint.x + size * cos(thetaBottom);
    y2 = endPoint.y + size * sin(thetaBottom);
    CGContextMoveToPoint(contextRef, x1, y1);
    CGContextAddLineToPoint(contextRef, x2, y2);
    CGContextStrokePath(contextRef);
}

- (CGPoint)getOuterRadiusPoint:(CGPoint)startPoint withEndPoint:(CGPoint)endPoint withRadius:(float) radius {
    double theta = [self getAngleBetweenPoints:startPoint withEndPoint:endPoint];

    float x = startPoint.x + radius * cos(theta);
    float y = startPoint.y + radius * sin(theta);
    return CGPointMake(x, y);
}

- (void)drawConnection:(CGContextRef)contextRef withStartPoint:(CGPoint)startPoint withEndPoint:(CGPoint)endPoint withOffsetEnable:(bool)hasOffset {
    CGContextSetLineWidth(contextRef, 4);
    CGContextBeginPath(contextRef);
    CGPoint newStart = startPoint;
    CGPoint newEnd = endPoint;
    if (hasOffset) {
        float radius = 10;
        if (endpointImage != nil && endpointImage.size.width > 0) {
            float imageOffsetRadius = endpointImage.size.width * ENDPOINT_OFFSET_RATIO;
            if (imageOffsetRadius > 0) {
                radius = imageOffsetRadius;
            }
        }
        newStart = [self getOuterRadiusPoint:startPoint withEndPoint:endPoint withRadius:radius];
        newEnd = [self getOuterRadiusPoint:endPoint withEndPoint:startPoint withRadius:radius];
    }

    CGContextSetStrokeColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
    CGContextMoveToPoint(contextRef, newStart.x, newStart.y);
    CGContextAddLineToPoint(contextRef, newEnd.x, newEnd.y);
    CGContextStrokePath(contextRef);
    // Restore
    CGContextSetLineDash(contextRef, 0, nil, 0);
}

- (void)drawPoint:(CGContextRef)contextRef withPoint:(CGPoint)point {
    CGContextSetAlpha(contextRef, 1);
    CGContextSetFillColorWithColor(contextRef, [self.entityStrokeColor CGColor]);
    CGContextFillEllipseInRect(contextRef, [self buildRect:point withSize:pointSize]);
}

- (BOOL)undo {
    if ([self text] != nil){
        self.text = nil;
        return true;
    }
    NSUInteger currentCount = [points count];
    if (currentCount > 0) {
        [points removeAllObjects];
        [pointsVisited removeAllObjects];
        // Clear selection if remove selected point
        if (selectedPosition == currentCount) {
            selectedPosition = DEFAULT_SELECTED_POSITION;
        }
        return false;
    }
    return false;
}


- (NSInteger)getDrawingStep {
    if ([points count] < MAX_POINTS_COUNT || ![self isAllVisited]) {
        return 1;
    }else {
        return [points count] + ([self text] != nil ? 1 : 0);
    }
    return DEFAULT_DRAWING_STEP;
}

- (BOOL)isTextStep{
    return [self getDrawingStep] == MAX_POINTS_COUNT && [self isAllVisited];
}

- (BOOL)isAllVisited {
    if ([pointsVisited count] < MAX_POINTS_COUNT) {
        return FALSE;
    }
    BOOL all = TRUE;
    for (int i=0; i < [pointsVisited count]; i++) {
        NSNumber* val = [pointsVisited objectAtIndex:i];
        if (![val boolValue]) {
            return FALSE;
        }
    }
    return all;
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

- (void)drawText:(CGContextRef)contextRef withCenterPoint: (CGPoint) centerPoint {
    self.textAttributes = @{
        NSFontAttributeName: self.font,
        NSForegroundColorAttributeName: [UIColor blackColor],
        NSParagraphStyleAttributeName: self.style
    };


    CGRect textRect = CGRectMake(
                                 centerPoint.x - self.textSize.width/2,
                                 centerPoint.y - self.textSize.height/2,
                                 self.textSize.width,
                                 self.textSize.height
                                 );
    // draw background
    CGRect rectWthPadding = CGRectMake(
                                       centerPoint.x - self.textSize.width/2 - TEXT_PADDING,
                                       centerPoint.y - TEXT_BOX_SIZE /2,
                                       self.textSize.width + 2 * TEXT_PADDING,
                                       TEXT_BOX_SIZE
                                       );
    UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:rectWthPadding cornerRadius: TEXT_PADDING / 2];
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

- (void)setEndpointImage:(UIImage *)image {
    endpointImage = image;
}

- (NSMutableArray *) getPoints {
    return points;
}

- (void)startTimer {
    if (!isTimerRunning) {
        // Starting timer broke the app
        //        timer = [NSTimer scheduledTimerWithTimeInterval:0.05
        //                                                      target:self
        //                                                    selector:@selector(animatePulse)
        //                                                    userInfo:nil
        //                                                     repeats:YES];
        isTimerRunning = YES;
    }
}

- (void)animatePulse {
    if (isGrowing) {
        pulseScale += 0.02;
        if (pulseScale >= 1.0) { // Maximum scale
            isGrowing = NO;
        }
    } else {
        pulseScale -= 0.02;
        if (pulseScale <= 0.0) { // Minimum scale
            isGrowing = YES;
        }
    }

    [self setNeedsDisplay]; // Redraw the view
}

@end
