//
//  MeasurementEntity.h
//  RNImageEditor
//
//

#import "base/MotionEntity.h"

@interface MeasurementEntity : MotionEntity

@property (nonatomic) NSString *text;
@property (nonatomic) NSDictionary *textAttributes;
@property (nonatomic) CGSize textSize;
@property (nonatomic) NSMutableParagraphStyle *style;
@property (nonatomic) CGFloat fontSize;
@property (nonatomic) NSString *fontType;
@property (nonatomic) UIFont *font;
@property (nonatomic) CGSize initialBoundsSize;
@property (nonatomic) BOOL localFocused;


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
                     entityStrokeColor: (UIColor *)entityStrokeColor;

- (BOOL)addPoint:(CGPoint)point;

- (BOOL)isPointInEntity:(CGPoint)point;
- (void)addText:(NSString *)text withTextSize:(NSNumber *)fontSize withFontType:(NSString *)fontType;
- (BOOL)isTextStep;
- (void)setBackground:(CGImageRef)imageSource;
- (void)setEndpointImage:(UIImage *)image;

@end
