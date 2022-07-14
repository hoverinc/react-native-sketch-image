//
//  MeasurementEntity.h
//  RNImageEditor
//
//

#import "base/MotionEntity.h"

@interface MeasurementEntity : MotionEntity

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
                     entityStrokeColor: (UIColor *)entityStrokeColor;

- (BOOL)addPoint:(CGPoint)point;

- (BOOL)isPointInEntity:(CGPoint)point;

@end

