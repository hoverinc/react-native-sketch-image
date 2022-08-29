//
//  TextEntity.m
//  RNImageEditor
//
//  Created by Thomas Steinbrüchel on 30.10.18.
//  Copyright © 2018 Terry. All rights reserved.
//

#import "base/MotionEntity.h"
#import "TextEntity.h"

@implementation TextEntity
{
}

NSString * BORDER_COLOR = @"#1B5FA7";

- (instancetype)initAndSetupWithParent: (NSInteger)parentWidth
                          parentHeight: (NSInteger)parentHeight
                         parentCenterX: (CGFloat)parentCenterX
                         parentCenterY: (CGFloat)parentCenterY
                     parentScreenScale: (CGFloat)parentScreenScale
                                  text: (NSString *)text
                              fontType: (NSString *)fontType
                              fontSize: (CGFloat)fontSize
                        bordersPadding: (CGFloat)bordersPadding
                           borderStyle: (enum BorderStyle)borderStyle
                     borderStrokeWidth: (CGFloat)borderStrokeWidth
                     borderStrokeColor: (UIColor *)borderStrokeColor
                     entityStrokeWidth: (CGFloat)entityStrokeWidth
                     entityStrokeColor: (UIColor *)entityStrokeColor {

    // Let's calculate the initial texts single line width here
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setAlignment:NSTextAlignmentCenter];
    [style setLineHeightMultiple:1.05];
    UIFont *font = [UIFont systemFontOfSize: fontSize];
    if (fontType) {
        font = [UIFont fontWithName: fontType size: fontSize];
    }
    NSDictionary *textAttributes = @{
                            NSFontAttributeName: font,
                            NSForegroundColorAttributeName: entityStrokeColor,
                            NSParagraphStyleAttributeName: style
                            };
    CGRect initialTextRect = [text boundingRectWithSize:CGSizeMake(parentWidth, CGFLOAT_MAX)
                                              options:NSStringDrawingUsesLineFragmentOrigin
                                           attributes:textAttributes
                                              context:nil];
    CGFloat realParentCenterX = parentCenterX - (initialTextRect.size.width + bordersPadding * 2) / 2;
    CGFloat realParentCenterY = parentCenterY - initialTextRect.size.height / 4;


    self = [super initAndSetupWithParent:parentWidth
                            parentHeight:parentHeight
                           parentCenterX:realParentCenterX
                           parentCenterY:realParentCenterY
                       parentScreenScale:parentScreenScale
                                   width:initialTextRect.size.width + bordersPadding * 2
                                  height:initialTextRect.size.height
                          bordersPadding:bordersPadding
                             borderStyle:borderStyle
                       borderStrokeWidth:borderStrokeWidth
                       borderStrokeColor:borderStrokeColor
                       entityStrokeWidth:entityStrokeWidth
                       entityStrokeColor:entityStrokeColor];

    if (self) {
        self.MIN_SCALE = 0.3f;
        self.text = text;
        self.style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [self.style setAlignment:NSTextAlignmentCenter];
        [self.style setLineHeightMultiple:1.05];
        self.fontSize = fontSize;
        self.fontType = fontType;
        self.font = [UIFont systemFontOfSize: self.fontSize];
        if (self.fontType) {
            self.font = [UIFont fontWithName: self.fontType size: self.fontSize];
        }
        self.initialBoundsSize = self.bounds.size;
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

    return self;
}

- (void)updateText:(NSString *)newText {
    self.text = newText;
}

- (void)updateFontSize:(CGFloat)newFontSize {
    if (newFontSize >= 5 && newFontSize <= 25) {
        self.fontSize = newFontSize;
        self.font = [self.font fontWithSize:self.fontSize];
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
        self.bounds = CGRectMake(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.initialBoundsSize.height +  textRect.size.height);
    }
}

// Assumes input like "#00FF00" (#RRGGBB).
- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

- (void)drawContent:(CGRect)rect withinContext:(CGContextRef)contextRef {
    self.textAttributes = @{
                            NSFontAttributeName: self.font,
                            NSForegroundColorAttributeName: self.entityStrokeColor,
                            NSParagraphStyleAttributeName: self.style
                            };

    UIGraphicsBeginImageContextWithOptions(rect.size, NO, self.parentScreenScale * self.scale); // This (self.parentScreenScale * self.scale) fixes blurry text when scaling
    CGRect textRect = CGRectMake(rect.origin.x, rect.origin.y + (rect.size.height - self.textSize.height) / 2.0, rect.size.width, self.textSize.height);

    // draw background
    UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:textRect cornerRadius: 4];
    [roundedRect fillWithBlendMode: kCGBlendModeNormal alpha:1.0f];

    [[UIColor whiteColor] setFill];
    [roundedRect fill];
    [[self colorFromHexString:BORDER_COLOR] setStroke];
    [roundedRect stroke];


    [self.text drawInRect:textRect withAttributes:self.textAttributes];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    [result drawInRect:rect];
}

- (NSString *)getShapeType {
    return @"Text";
}

@end
