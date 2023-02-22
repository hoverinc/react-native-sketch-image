#import "RNImageEditorManager.h"
#import "RNImageEditor.h"
#import "RNImageEditorData.h"
#import <React/RCTEventDispatcher.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>
#import "RNImageEditorUtility.h"
#import "BackgroundText.h"
#import "entities/base/Enumerations.h"
#import "entities/base/MotionEntity.h"
#import "entities/CircleEntity.h"
#import "entities/RectEntity.h"
#import "entities/TriangleEntity.h"
#import "entities/ArrowEntity.h"
#import "entities/TextEntity.h"
#import "entities/RulerEntity.h"
#import "entities/MeasurementEntity.h"
#import <React/RCTImageSource.h>
#import <React/RCTImageLoader.h>
#import <React/RCTBridge.h>

@implementation RNImageEditor
{
    NSMutableArray *_allShapes;
    RCTEventDispatcher *_eventDispatcher;
    RCTBridge *_bridge;
    NSMutableArray *_paths;
    RNImageEditorData *_currentPath;

    CGSize _lastSize;

    CGContextRef _drawingContext, _translucentDrawingContext;
    CGImageRef _frozenImage, _translucentFrozenImage;
    BOOL _needsFullRedraw;

    UIImage *_backgroundImage;
    UIImage *_backgroundImageScaled;
    NSString *_backgroundImageContentMode;
    NSString *_currentFilePath;

    NSArray *_arrTextOnSketch, *_arrSketchOnText;
    int measuredHeight;
    int measuredWidth;

    Boolean _isMeasurementInProgress;
    Boolean _shouldHandleEndMove;
}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher withBridge:(RCTBridge *)bridge
{
    self = [super init];
    if (self) {
        _bridge = bridge;
        _eventDispatcher = eventDispatcher;
        _paths = [NSMutableArray new];
        _allShapes = [NSMutableArray new];
        _needsFullRedraw = YES;

        self.backgroundColor = [UIColor clearColor];
        self.clearsContextBeforeDrawing = YES;

        self.motionEntities = [NSMutableArray new];
        self.selectedEntity = nil;
        self.entityBorderColor = [UIColor clearColor];
        self.entityBorderStyle = DASHED;
        self.entityBorderStrokeWidth = 1.0;
        self.entityStrokeWidth = 5.0;
        self.entityStrokeColor = [UIColor blackColor];

        self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        self.tapGesture.delegate = self;
        self.tapGesture.numberOfTapsRequired = 1;

        self.rotateGesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotate:)];
        self.rotateGesture.delegate = self;

        self.moveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMove:)];
        self.moveGesture.delegate = self;
        self.moveGesture.minimumNumberOfTouches = 1;
        self.moveGesture.maximumNumberOfTouches = 1;

        self.scaleGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleScale:)];
        self.scaleGesture.delegate = self;

        self.longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        self.longPressGesture.delegate = self;
        self.longPressGesture.numberOfTapsRequired = 1;

        [self addGestureRecognizer:self.tapGesture];
        [self addGestureRecognizer:self.rotateGesture];
        [self addGestureRecognizer:self.moveGesture];
        [self addGestureRecognizer:self.scaleGesture];
        [self addGestureRecognizer:self.longPressGesture];

    }
    return self;
}

- (void)dealloc {
    CGContextRelease(_drawingContext);
    _drawingContext = nil;
    CGImageRelease(_frozenImage);
    _frozenImage = nil;
}


// Make multiple GestureRecognizers work
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return TRUE;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGRect bounds = self.bounds;

    if (_needsFullRedraw) {
        [self setFrozenImageNeedsUpdate];
        CGContextClearRect(_drawingContext, bounds);
        for (RNImageEditorData *path in _paths) {
            [path drawInContext:_drawingContext];
        }
        _needsFullRedraw = NO;
    }

    if (!_frozenImage) {
        _frozenImage = CGBitmapContextCreateImage(_drawingContext);
    }

    if (!_translucentFrozenImage && _currentPath.isTranslucent) {
        _translucentFrozenImage = CGBitmapContextCreateImage(_translucentDrawingContext);
    }

    if (_backgroundImage) {
        if (!_backgroundImageScaled) {
            _backgroundImageScaled = [self scaleImage:_backgroundImage toSize:bounds.size contentMode: _backgroundImageContentMode];
        }

        [_backgroundImageScaled drawInRect:bounds];
    }

    for (BackgroundText *text in _arrSketchOnText) {
        [text.text drawInRect: text.drawRect withAttributes: text.attribute];
    }

    if (_frozenImage) {
        CGContextDrawImage(context, bounds, _frozenImage);
    }

    if (_translucentFrozenImage && _currentPath.isTranslucent) {
        CGContextDrawImage(context, bounds, _translucentFrozenImage);
    }

    for (BackgroundText *text in _arrTextOnSketch) {
        [text.text drawInRect: text.drawRect withAttributes: text.attribute];
    }

    for (MotionEntity *entity in self.motionEntities) {
        [entity updateStrokeSettings:self.entityBorderStyle
                   borderStrokeWidth:self.entityBorderStrokeWidth
                   borderStrokeColor:self.entityBorderColor
                   entityStrokeWidth:self.entityStrokeWidth
                   entityStrokeColor:self.entityStrokeColor];

        [entity setMeasuredSize:measuredWidth withHeight:measuredHeight];
        if ([entity isSelected]) {
            [entity setNeedsDisplay];

            if ([entity class] == [MeasurementEntity class]){
                CGRect entityRect = CGRectMake(0, 0, rect.size.width, rect.size.height);
                CGImageRef imgRef = CGBitmapContextCreateImage(context);
                [((MeasurementEntity *)entity) setBackground:imgRef];
            }
        }

        [self addSubview:entity];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (!CGSizeEqualToSize(self.bounds.size, _lastSize)) {
        _lastSize = self.bounds.size;
        CGContextRelease(_drawingContext);
        _drawingContext = nil;
        [self createDrawingContext];
        _needsFullRedraw = YES;
        _backgroundImageScaled = nil;

        for (BackgroundText *text in [_arrTextOnSketch arrayByAddingObjectsFromArray: _arrSketchOnText]) {
            CGPoint position = text.position;
            if (!text.isAbsoluteCoordinate) {
                position.x *= self.bounds.size.width;
                position.y *= self.bounds.size.height;
            }
            position.x -= text.drawRect.size.width * text.anchor.x;
            position.y -= text.drawRect.size.height * text.anchor.y;
            text.drawRect = CGRectMake(position.x, position.y, text.drawRect.size.width, text.drawRect.size.height);
        }

        [self setNeedsDisplay];
    }
}

- (void)createDrawingContext {
    CGFloat scale = self.window.screen.scale;
    CGSize size = self.bounds.size;
    size.width *= scale;
    size.height *= scale;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    _drawingContext = CGBitmapContextCreate(nil, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    _translucentDrawingContext = CGBitmapContextCreate(nil, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);

    CGContextConcatCTM(_drawingContext, CGAffineTransformMakeScale(scale, scale));
    CGContextConcatCTM(_translucentDrawingContext, CGAffineTransformMakeScale(scale, scale));
}

- (void)setFrozenImageNeedsUpdate {
    CGImageRelease(_frozenImage);
    CGImageRelease(_translucentFrozenImage);
    _frozenImage = nil;
    _translucentFrozenImage = nil;
}

- (BOOL)openSketchFile:(NSString *)filename directory:(NSString*) directory contentMode:(NSString*)mode {
    if (filename) {
        UIImage *image = [UIImage imageWithContentsOfFile: [directory stringByAppendingPathComponent: filename]];
        image = image ? image : [UIImage imageNamed: filename];
        if(image) {
            if (image.imageOrientation != UIImageOrientationUp) {
                UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
                [image drawInRect:(CGRect){0, 0, image.size}];
                UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                image = normalizedImage;
            }
            _backgroundImage = image;
            _backgroundImageScaled = nil;
            _backgroundImageContentMode = mode;
            _currentFilePath = filename;
            [self setNeedsDisplay];

            return YES;
        }
    }
    return NO;
}

- (void)setMeasuredHeight:(NSInteger)height {
    measuredHeight = (int) height;
}

- (void)setMeasuredWidth:(NSInteger)width {
    measuredWidth = (int) width;
}

- (void)setCanvasText:(NSArray *)aText {
    NSMutableArray *arrTextOnSketch = [NSMutableArray new];
    NSMutableArray *arrSketchOnText = [NSMutableArray new];
    NSDictionary *alignments = @{
                                 @"Left": [NSNumber numberWithInteger:NSTextAlignmentLeft],
                                 @"Center": [NSNumber numberWithInteger:NSTextAlignmentCenter],
                                 @"Right": [NSNumber numberWithInteger:NSTextAlignmentRight]
                                 };

    for (NSDictionary *property in aText) {
        if (property[@"text"]) {
            NSMutableArray *arr = [@"TextOnSketch" isEqualToString: property[@"overlay"]] ? arrTextOnSketch : arrSketchOnText;
            BackgroundText *text = [BackgroundText new];
            text.text = property[@"text"];
            UIFont *font = nil;
            if (property[@"font"]) {
                font = [UIFont fontWithName: property[@"font"] size: property[@"fontSize"] == nil ? 12 : [property[@"fontSize"] floatValue]];
                font = font == nil ? [UIFont systemFontOfSize: property[@"fontSize"] == nil ? 12 : [property[@"fontSize"] floatValue]] : font;
            } else if (property[@"fontSize"]) {
                font = [UIFont systemFontOfSize: [property[@"fontSize"] floatValue]];
            } else {
                font = [UIFont systemFontOfSize: 12];
            }
            text.font = font;
            text.anchor = property[@"anchor"] == nil ?
                CGPointMake(0, 0) :
                CGPointMake([property[@"anchor"][@"x"] floatValue], [property[@"anchor"][@"y"] floatValue]);
            text.position = property[@"position"] == nil ?
                CGPointMake(0, 0) :
                CGPointMake([property[@"position"][@"x"] floatValue], [property[@"position"][@"y"] floatValue]);
            long color = property[@"fontColor"] == nil ? 0xFF000000 : [property[@"fontColor"] longValue];
            UIColor *fontColor =
            [UIColor colorWithRed:(CGFloat)((color & 0x00FF0000) >> 16) / 0xFF
                            green:(CGFloat)((color & 0x0000FF00) >> 8) / 0xFF
                             blue:(CGFloat)((color & 0x000000FF)) / 0xFF
                            alpha:(CGFloat)((color & 0xFF000000) >> 24) / 0xFF];
            NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            NSString *a = property[@"alignment"] ? property[@"alignment"] : @"Left";
            style.alignment = [alignments[a] integerValue];
            style.lineHeightMultiple = property[@"lineHeightMultiple"] ? [property[@"lineHeightMultiple"] floatValue] : 1.0;
            text.attribute = @{
                               NSFontAttributeName:font,
                               NSForegroundColorAttributeName:fontColor,
                               NSParagraphStyleAttributeName:style
                               };
            text.isAbsoluteCoordinate = ![@"Ratio" isEqualToString:property[@"coordinate"]];
            CGSize textSize = [text.text sizeWithAttributes:text.attribute];

            CGPoint position = text.position;
            if (!text.isAbsoluteCoordinate) {
                position.x *= self.bounds.size.width;
                position.y *= self.bounds.size.height;
            }
            position.x -= textSize.width * text.anchor.x;
            position.y -= textSize.height * text.anchor.y;
            text.drawRect = CGRectMake(position.x, position.y, textSize.width, textSize.height);
            [arr addObject: text];
        }
    }
    _arrTextOnSketch = [arrTextOnSketch copy];
    _arrSketchOnText = [arrSketchOnText copy];
    [self setNeedsDisplay];
}

- (void)newPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth {
    if (CGColorGetComponents(strokeColor.CGColor)[3] != 0.0) {
        self.entityStrokeColor = strokeColor;
    }
    self.entityStrokeWidth = strokeWidth;

    _currentPath = [[RNImageEditorData alloc]
                    initWithId: pathId
                    strokeColor: strokeColor
                    strokeWidth: strokeWidth];
    [_paths addObject: _currentPath];
}

- (void) addPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth points:(NSArray*) points {
    if (CGColorGetComponents(strokeColor.CGColor)[3] != 0.0) {
        self.entityStrokeColor = strokeColor;
    }

    bool exist = false;
    for(int i=0; i<_paths.count; i++) {
        if (((RNImageEditorData*)_paths[i]).pathId == pathId) {
            exist = true;
            break;
        }
    }

    if (!exist) {
        RNImageEditorData *data = [[RNImageEditorData alloc] initWithId: pathId
                                                  strokeColor: strokeColor
                                                  strokeWidth: strokeWidth
                                                       points: points];
        [_paths addObject: data];
        [data drawInContext:_drawingContext];
        [self setFrozenImageNeedsUpdate];
        [self setNeedsDisplay];
    }
}

- (void)deletePath:(int) pathId {
    int index = -1;
    for(int i=0; i<_paths.count; i++) {
        if (((RNImageEditorData*)_paths[i]).pathId == pathId) {
            [_allShapes removeObject:@(((RNImageEditorData*)_paths[i]).pathId).stringValue];
            index = i;
            break;
        }
    }

    if (index > -1) {
        [_paths removeObjectAtIndex: index];
        _needsFullRedraw = YES;
        [self setNeedsDisplay];
        [self notifyPathsUpdate];
        [self onDrawingStateChanged];
    }
}

- (void)addPointX: (float)x Y: (float)y isMove:(BOOL)isMove {
    if (!self.selectedEntity && (![self findEntityAtPointX:x andY:y] || isMove)) {
        CGPoint newPoint = CGPointMake(x, y);
        CGRect updateRect = [_currentPath addPoint: newPoint];

        if (_currentPath.isTranslucent) {
            CGContextClearRect(_translucentDrawingContext, self.bounds);
            [_currentPath drawInContext:_translucentDrawingContext];
        } else {
            [_currentPath drawLastPointInContext:_drawingContext];
        }

        [self setFrozenImageNeedsUpdate];
        [self setNeedsDisplayInRect:updateRect];
        if ([_currentPath.points count] > 0){
            [self onDrawingStateChangedWithStroke:true];
        }
    }
}

- (void)endPath {
    if (_currentPath.isTranslucent) {
        [_currentPath drawInContext:_drawingContext];
    }
    if ([_currentPath.points count] > 0) {
        [_allShapes addObject:@(_currentPath.pathId).stringValue];
        [self onDrawingStateChangedWithStroke:false];
    }
    _currentPath = nil;
    [self notifyPathsUpdate];

}

- (void) clear {
    [_paths removeAllObjects];
    [self.motionEntities removeAllObjects];
    [_allShapes removeAllObjects];
    _currentPath = nil;
    _needsFullRedraw = YES;
    [self setNeedsDisplay];
    [self notifyPathsUpdate];
    [self onDrawingStateChanged];
}

- (UIImage*)createImageWithTransparentBackground: (BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize {
    if (_backgroundImage && cropToImageSize) {
        CGRect rect = CGRectMake(0, 0, _backgroundImage.size.width, _backgroundImage.size.height);
        UIGraphicsBeginImageContextWithOptions(rect.size, !transparent, 1);
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (!transparent) {
            CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
            CGContextFillRect(context, rect);
        }
        CGRect targetRect = [RNImageEditorUtility fillImageWithSize:self.bounds.size toSize:rect.size contentMode:@"AspectFill"];
        CGFloat scaleFactor = [RNImageEditorUtility getScaleDifference:self.bounds.size toSize:rect.size contentMode:@"AspectFill"];
        if (includeImage) {
            [_backgroundImage drawInRect:rect];
        }

        if (includeText) {
            for (BackgroundText *text in _arrSketchOnText) {
                [text.text drawInRect: text.drawRect withAttributes: text.attribute];
            }
        }

        CGContextDrawImage(context, targetRect, _frozenImage);
        CGContextDrawImage(context, targetRect, _translucentFrozenImage);

        if (includeText) {
            for (BackgroundText *text in _arrTextOnSketch) {
                [text.text drawInRect: text.drawRect withAttributes: text.attribute];
            }
        }

        for (MotionEntity *entity in self.motionEntities) {
            CGContextSaveGState(context);

            // Scale shapes because we cropToImageSize
            CGContextScaleCTM(context, scaleFactor, scaleFactor);

            // Center the context around the view's anchor point
            CGContextTranslateCTM(context, [entity center].x, [entity center].y);

            // Apply the view's transform about the anchor point
            CGContextConcatCTM(context, [entity transform]);

            // Offset by the portion of the bounds left of and above the anchor point
            CGContextTranslateCTM(context, -[entity bounds].size.width * [[entity layer] anchorPoint].x, -[entity bounds].size.height * [[entity layer] anchorPoint].y);

            // Render the entity
            [entity.layer renderInContext:context];

            CGContextRestoreGState(context);
        }

        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return img;
    } else {
        CGRect rect = self.bounds;
        UIGraphicsBeginImageContextWithOptions(rect.size, !transparent, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (!transparent) {
            CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
            CGContextFillRect(context, rect);
        }
        if (_backgroundImage && includeImage) {
            CGRect targetRect = [RNImageEditorUtility fillImageWithSize:_backgroundImage.size toSize:rect.size contentMode:_backgroundImageContentMode];
            [_backgroundImage drawInRect:targetRect];
        }

        if (includeText) {
            for (BackgroundText *text in _arrSketchOnText) {
                [text.text drawInRect: text.drawRect withAttributes: text.attribute];
            }
        }

        CGContextDrawImage(context, rect, _frozenImage);
        CGContextDrawImage(context, rect, _translucentFrozenImage);

        if (includeText) {
            for (BackgroundText *text in _arrTextOnSketch) {
                [text.text drawInRect: text.drawRect withAttributes: text.attribute];
            }
        }

        for (MotionEntity *entity in self.motionEntities) {
            CGContextSaveGState(context);

            // Center the context around the view's anchor point
            CGContextTranslateCTM(context, [entity center].x, [entity center].y);

            // Apply the view's transform about the anchor point
            CGContextConcatCTM(context, [entity transform]);

            // Offset by the portion of the bounds left of and above the anchor point
            CGContextTranslateCTM(context, -[entity bounds].size.width * [[entity layer] anchorPoint].x, -[entity bounds].size.height * [[entity layer] anchorPoint].y);

            // Render the entity
            [entity.layer renderInContext:context];

            CGContextRestoreGState(context);
        }

        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return img;
    }
}

- (NSString*)getMeasuredPosition:(BOOL) cropToImageSize{
    MeasurementEntity* lastEntity = nil;
    for (MotionEntity* entity in self.motionEntities) {
        if ([entity class] == [MeasurementEntity class]){
            lastEntity = (MeasurementEntity *) entity;
        }
    }
    if (lastEntity != nil) {
        float scale = 1;
        if (cropToImageSize == true) {
            scale = _backgroundImage.size.width / self.bounds.size.width;
        }
        NSMutableArray* points = [lastEntity getPoints];
        NSMutableArray* positions = [NSMutableArray new];
        for (NSValue* value in points) {
            CGPoint p = [value CGPointValue];
            int x = p.x * scale;
            int y = p.y * scale;
            NSString* position = [NSString stringWithFormat:@"[%d, %d]",x,y];
            [positions addObject:position];
        }
        NSString* result = [NSString stringWithFormat:@"[%@]",[positions componentsJoinedByString:@","]];
        return result;
    }
    return nil;
}

- (void)saveImageOfType:(NSString*) type folder:(NSString*) folder filename:(NSString*) filename withTransparentBackground:(BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize {
    UIImage *img = [self createImageWithTransparentBackground:transparent includeImage:includeImage includeText:(BOOL)includeText cropToImageSize:cropToImageSize];

    if (folder != nil && filename != nil) {
        NSURL *tempDir = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent: folder];
        NSError * error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:[tempDir path]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error == nil) {
            NSURL *fileURL = [[tempDir URLByAppendingPathComponent: filename] URLByAppendingPathExtension: type];
            NSData *imageData = [self getImageData:img type:type];
            NSString* measurementPosition = [self getMeasuredPosition:cropToImageSize];
            [self saveImageWithMetadata:imageData fileURL:fileURL withMeasurementPosition:measurementPosition];

            if (_onChange) {
                _onChange(@{ @"success": @YES, @"path": [fileURL path]});
            }
        } else {
            if (_onChange) {
                _onChange(@{ @"success": @NO, @"path": [NSNull null]});
            }
        }
    } else {
        if ([type isEqualToString: @"png"]) {
            img = [UIImage imageWithData: UIImagePNGRepresentation(img)];
        }
        UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }
}

- (void)saveImageWithMetadata:(NSData *)imageData fileURL:(NSURL*)fileURL withMeasurementPosition:(NSString*)measurementPosition
{
    NSString *originalFileName = [[_currentFilePath lastPathComponent] stringByDeletingPathExtension];
    NSString *uniqueImageId = [self getUniqueImageId:originalFileName];

    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);

    NSDictionary *metadataDict = (NSDictionary *) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    NSDictionary *exifDict = [metadataDict objectForKey:(NSString *)kCGImagePropertyExifDictionary];

    NSMutableDictionary *mutableMetadataDict = [metadataDict mutableCopy];
    NSMutableDictionary *mutableExifDict = [exifDict mutableCopy];

    [mutableExifDict setValue:uniqueImageId forKey:(NSString *)kCGImagePropertyExifImageUniqueID];

    if (measurementPosition != nil) {
        [mutableExifDict setValue:measurementPosition forKey:(NSString *)kCGImagePropertyPNGCopyright];
    }

    [mutableMetadataDict setObject:mutableExifDict forKey:(NSString *)kCGImagePropertyExifDictionary];

    NSMutableData *destData = [NSMutableData data];
    CGImageDestinationRef destination =
        CGImageDestinationCreateWithData((CFMutableDataRef)destData,CGImageSourceGetType(source), 1, NULL);
    CGImageDestinationAddImageFromSource(destination, source, 0, (CFDictionaryRef) mutableMetadataDict);
    CGImageDestinationFinalize(destination);

    [destData writeToURL:fileURL atomically:YES];

    CFRelease(destination);
    CFRelease(source);

    _currentFilePath = nil;
}

- (NSString *)getUniqueImageId:(NSString *)fileName
{
    NSString *reversedFileName = [self reverseString:fileName];
    NSRange firstChar = [reversedFileName rangeOfString:@"."];
    if (firstChar.length == 0) {
        firstChar = [reversedFileName rangeOfString:@"_"];
        if (firstChar.length == 0) {
            return fileName;
        }
    }

    NSUInteger firstCharIndex = firstChar.location;
    NSString *reversedUniqueImageId =
        [reversedFileName substringWithRange:NSMakeRange(0, firstCharIndex)];
    NSString *uniqueImageId = [self reverseString:reversedUniqueImageId];
    return uniqueImageId;
}

- (NSString *)reverseString:(NSString *)originalStr
{
    NSMutableString *reversedString = [NSMutableString string];
    NSInteger charIndex = [originalStr length];
    while (charIndex > 0) {
        charIndex--;
        NSRange subStrRange = NSMakeRange(charIndex, 1);
        [reversedString appendString:[originalStr substringWithRange:subStrRange]];
    }

    return reversedString;
}

- (UIImage *)scaleImage:(UIImage *)originalImage toSize:(CGSize)size contentMode: (NSString*)mode
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextClearRect(context, CGRectMake(0, 0, size.width, size.height));

    CGRect targetRect = [RNImageEditorUtility fillImageWithSize:originalImage.size toSize:size contentMode:mode];
    CGContextDrawImage(context, targetRect, originalImage.CGImage);

    CGImageRef scaledImage = CGBitmapContextCreateImage(context);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);

    UIImage *image = [UIImage imageWithCGImage:scaledImage];
    CGImageRelease(scaledImage);

    return image;
}

- (NSString*) transferToBase64OfType: (NSString*) type withTransparentBackground: (BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize {
    UIImage *img = [self createImageWithTransparentBackground:transparent includeImage:includeImage includeText:(BOOL)includeText cropToImageSize:cropToImageSize];
    NSData *data = [self getImageData:img type:type];
    return [data base64EncodedStringWithOptions: NSDataBase64Encoding64CharacterLineLength];
}

- (NSData*)getImageData:(UIImage*)img type:(NSString*) type {
    NSData *data;
    if ([type isEqualToString: @"jpg"]) {
        data = UIImageJPEGRepresentation(img, 0.9);
    } else {
        data = UIImagePNGRepresentation(img);
    }
    return data;
}

#pragma mark - MotionEntites related code
- (void)setShapeConfiguration:(NSDictionary *)dict {
    if (![dict[@"shapeBorderColor"] isEqual:[NSNull null]]) {
        long shapeBorderColorLong = [dict[@"shapeBorderColor"] longValue];
        UIColor *shapeBorderColor = [UIColor colorWithRed:(CGFloat)((shapeBorderColorLong & 0x00FF0000) >> 16) / 0xFF
                                                    green:(CGFloat)((shapeBorderColorLong & 0x0000FF00) >> 8) / 0xFF
                                                     blue:(CGFloat)((shapeBorderColorLong & 0x000000FF)) / 0xFF
                                                    alpha:(CGFloat)((shapeBorderColorLong & 0xFF000000) >> 24) / 0xFF];
        if (CGColorGetComponents(shapeBorderColor.CGColor)[3] != 0.0) {
            self.entityBorderColor = shapeBorderColor;
        }
    }

    if (![dict[@"shapeBorderStyle"] isEqual:[NSNull null]]) {
        NSString *borderStyle = dict[@"shapeBorderStyle"];
        switch ([@[@"Dashed", @"Solid"] indexOfObject: borderStyle]) {
            case 0:
                self.entityBorderStyle = DASHED;
                break;
            case 1:
                self.entityBorderStyle = SOLID;
            case NSNotFound:
            default: {
                self.entityBorderStyle = DASHED;
                break;
            }
        }
    }

    if (![dict[@"shapeBorderStrokeWidth"] isEqual:[NSNull null]]) {
        self.entityBorderStrokeWidth = [dict[@"shapeBorderStrokeWidth"] doubleValue];
    }

    if (![dict[@"shapeColor"] isEqual:[NSNull null]]) {
        long shapeColorLong = [dict[@"shapeColor"] longValue];
        UIColor *shapeColor = [UIColor colorWithRed:(CGFloat)((shapeColorLong & 0x00FF0000) >> 16) / 0xFF
                                              green:(CGFloat)((shapeColorLong & 0x0000FF00) >> 8) / 0xFF
                                               blue:(CGFloat)((shapeColorLong & 0x000000FF)) / 0xFF
                                              alpha:(CGFloat)((shapeColorLong & 0xFF000000) >> 24) / 0xFF];
        if (CGColorGetComponents(shapeColor.CGColor)[3] != 0.0) {
            self.entityStrokeColor = shapeColor;
        }
    }

    if (![dict[@"shapeStrokeWidth"] isEqual:[NSNull null]]) {
        self.entityStrokeWidth = [dict[@"shapeStrokeWidth"] doubleValue];
    }
}

- (void)addEntity:(NSString *)entityType textShapeFontType:(NSString *)textShapeFontType textShapeFontSize:(NSNumber *)textShapeFontSize textShapeText:(NSString *)textShapeText imageShapeAsset:(NSString *)imageShapeAsset {
    bool hasMeasurement  = _measurementEntity != nil;
    bool hasTextType = [@"Text" isEqual:entityType];
    bool hasTextStep =_measurementEntity.isTextStep;
    BOOL shouldContinue = hasMeasurement && hasTextType && hasTextStep;

    if (_measurementEntity != nil && !shouldContinue) {
        [[self motionEntities] removeObject:_measurementEntity];
        [_allShapes removeObject:_measurementEntity.entityId];
        [_measurementEntity removeFromSuperview];
        _measurementEntity = nil;
        self.selectedEntity = nil;
        [self setNeedsDisplay];
    }
    switch ([@[@"Circle", @"Rect", @"Square", @"Triangle", @"Arrow", @"Text", @"Image", @"Ruler", @"MeasurementTool"] indexOfObject: entityType]) {
        case 1:
            [self addRectEntity:300 andHeight:150];
            break;
        case 2:
            [self addRectEntity:300 andHeight:300];
            break;
        case 3:
            [self addTriangleEntity];
            break;
        case 4:
            [self addArrowEntity];
            break;
        case 5:
            if (shouldContinue) {
                [_measurementEntity addText:textShapeText withTextSize:textShapeFontSize withFontType:textShapeFontType];
                [self onDrawingStateChanged];
                [self setNeedsDisplay];
                _measurementEntity = nil;
                [self unselectShape];
                [self onDrawingStateChanged];
            } else {
                [self addTextEntity:textShapeFontType withFontSize:textShapeFontSize withText:textShapeText];
            }
            break;
        case 6:
            // TODO: ImageEntity Doesn't exist yet
            break;
        case 7:
            [self addRulerEntity];
            break;
        case 8:
            [self addMeasurementEntity:imageShapeAsset];
            break;
        case 0:
        case NSNotFound:
        default: {
            [self addCircleEntity];
            break;
        }
    }
}

- (void)addCircleEntity {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);

    CircleEntity *entity = [[CircleEntity alloc]
                            initAndSetupWithParent:self.bounds.size.width
                            parentHeight:self.bounds.size.height
                            parentCenterX:centerX
                            parentCenterY:centerY
                            parentScreenScale:self.window.screen.scale
                            width:300
                            height:300
                            bordersPadding:5.0f
                            borderStyle:self.entityBorderStyle
                            borderStrokeWidth:self.entityBorderStrokeWidth
                            borderStrokeColor:self.entityBorderColor
                            entityStrokeWidth:self.entityStrokeWidth
                            entityStrokeColor:self.entityStrokeColor];

    [self onAddShape:entity];
}

- (void)addRectEntity:(NSInteger)width andHeight: (NSInteger)height {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);

    RectEntity *entity = [[RectEntity alloc]
                          initAndSetupWithParent:self.bounds.size.width
                          parentHeight:self.bounds.size.height
                          parentCenterX:centerX
                          parentCenterY:centerY
                          parentScreenScale:self.window.screen.scale
                          width:width
                          height:height
                          bordersPadding:5.0f
                          borderStyle:self.entityBorderStyle
                          borderStrokeWidth:self.entityBorderStrokeWidth
                          borderStrokeColor:self.entityBorderColor
                          entityStrokeWidth:self.entityStrokeWidth
                          entityStrokeColor:self.entityStrokeColor];

    [self onAddShape:entity];
}

- (void)addTriangleEntity {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);

    TriangleEntity *entity = [[TriangleEntity alloc]
                              initAndSetupWithParent:self.bounds.size.width
                              parentHeight:self.bounds.size.height
                              parentCenterX:centerX
                              parentCenterY:centerY
                              parentScreenScale:self.window.screen.scale
                              width:300
                              height:300
                              bordersPadding:5.0f
                              borderStyle:self.entityBorderStyle
                              borderStrokeWidth:self.entityBorderStrokeWidth
                              borderStrokeColor:self.entityBorderColor
                              entityStrokeWidth:self.entityStrokeWidth
                              entityStrokeColor:self.entityStrokeColor];

    [self onAddShape:entity];
}

- (void)addArrowEntity {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);

    ArrowEntity *entity = [[ArrowEntity alloc]
                              initAndSetupWithParent:self.bounds.size.width
                              parentHeight:self.bounds.size.height
                              parentCenterX:centerX
                              parentCenterY:centerY
                              parentScreenScale:self.window.screen.scale
                              width:300
                              height:300
                              bordersPadding:5.0f
                              borderStyle:self.entityBorderStyle
                              borderStrokeWidth:self.entityBorderStrokeWidth
                              borderStrokeColor:self.entityBorderColor
                              entityStrokeWidth:self.entityStrokeWidth
                              entityStrokeColor:self.entityStrokeColor];

    [self onAddShape:entity];
}

- (void)addRulerEntity {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);

    RulerEntity *entity = [[RulerEntity alloc]
                              initAndSetupWithParent:self.bounds.size.width
                              parentHeight:self.bounds.size.height
                              parentCenterX:centerX
                              parentCenterY:centerY
                              parentScreenScale:self.window.screen.scale
                              width:300
                              height:300
                              bordersPadding:5.0f
                              borderStyle:self.entityBorderStyle
                              borderStrokeWidth:self.entityBorderStrokeWidth
                              borderStrokeColor:self.entityBorderColor
                              entityStrokeWidth:self.entityStrokeWidth
                              entityStrokeColor:self.entityStrokeColor];

    [self onAddShape:entity];
}


- (void)handleLoadImage: (RCTImageSource *)imageShapeAsset {
    if (imageShapeAsset != nil){
        RCTImageLoader *loader = (RCTImageLoader*)[_bridge moduleForClass:[RCTImageLoader class]];

        [loader loadImageWithURLRequest:imageShapeAsset.request
                                   size:imageShapeAsset.size
                                  scale:1
                                clipped:YES
                             resizeMode:RCTResizeModeStretch
                          progressBlock:nil
                       partialLoadBlock:nil
                        completionBlock:^(NSError *error, id imageOrData) {
            UIImage *loadedImage;
            if ([imageOrData isKindOfClass:[NSData class]]) {
                loadedImage = [UIImage imageWithData:imageOrData];
            } else {
                loadedImage = imageOrData;
            }

            if (_measurementEntity != nil) {
                [_measurementEntity setEndpointImage:loadedImage];
                [_measurementEntity setNeedsDisplay];
            }
        }];

    }else {
        if (_measurementEntity != nil) {
            [_measurementEntity setEndpointImage:nil];
        }
    }

}


- (void)addMeasurementEntity: (RCTImageSource *)imageShapeAsset {

    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);

    MeasurementEntity *entity = [[MeasurementEntity alloc]
                              initAndSetupWithParent:self.bounds.size.width
                              parentHeight:self.bounds.size.height
                              parentCenterX:centerX
                              parentCenterY:centerY
                              parentScreenScale:self.window.screen.scale
                              bordersPadding:5.0f
                              borderStyle:self.entityBorderStyle
                              borderStrokeWidth:self.entityBorderStrokeWidth
                              borderStrokeColor:self.entityBorderColor
                              entityStrokeWidth:self.entityStrokeWidth
                              entityStrokeColor:self.entityStrokeColor];

    _measurementEntity = entity;
    [self handleLoadImage:imageShapeAsset];
    [self onAddShape:entity];
}


- (void)addTextEntity:(NSString *)fontType withFontSize: (NSNumber *)fontSize withText: (NSString *)text {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);

    TextEntity *entity = [[TextEntity alloc]
                           initAndSetupWithParent:self.bounds.size.width
                           parentHeight:self.bounds.size.height
                           parentCenterX:centerX
                           parentCenterY:centerY
                           parentScreenScale:self.window.screen.scale
                           text:text
                           fontType:fontType
                           fontSize:[fontSize floatValue]
                           bordersPadding:5.0f
                           borderStyle:self.entityBorderStyle
                           borderStrokeWidth:self.entityBorderStrokeWidth
                           borderStrokeColor:self.entityBorderColor
                           entityStrokeWidth:self.entityStrokeWidth
                           entityStrokeColor:self.entityStrokeColor];

    [self onAddShape:entity];
}

- (void)onAddShape:(MotionEntity *)entity {
    [self.motionEntities addObject:entity];
    [_allShapes addObject:entity.getEntityId];
    [self onShapeSelectionChanged:entity];
    [self selectEntity:entity];
    [self onDrawingStateChanged];
}

- (void)selectEntity:(MotionEntity *)entity {
    if (self.selectedEntity && self.selectedEntity != entity) {
        [self.selectedEntity setIsSelected:NO];
        [self.selectedEntity setNeedsDisplay];
    }
    if (entity) {
        [entity setIsSelected:YES];
        [entity setNeedsDisplay];
        [self setFrozenImageNeedsUpdate];
        [self setNeedsDisplayInRect:entity.bounds];
    } else {
        [self setNeedsDisplay];
    }
    self.selectedEntity = entity;
}

- (void)updateSelectionOnTapWithLocationPoint:(CGPoint)tapLocation {
    MotionEntity *nextEntity = [self findEntityAtPointX:tapLocation.x andY:tapLocation.y];
    // Protect from calling wrong events during drawing stroke
    bool shouldCallStateChanged = self.selectedEntity != nextEntity;
    [self onShapeSelectionChanged:nextEntity];
    [self selectEntity:nextEntity];
    if (shouldCallStateChanged) {
        [self onDrawingStateChanged];
    }
}

- (MotionEntity *)findEntityAtPointX:(CGFloat)x andY: (CGFloat)y {
    MotionEntity *nextEntity = nil;
    CGPoint point = CGPointMake(x, y);
    for (MotionEntity *entity in self.motionEntities) {
        if ([entity isPointInEntity:point]) {
            nextEntity = entity;
            break;
        }
    }
    return nextEntity;
}

- (void)releaseSelectedEntity {
    MotionEntity *entityToRemove = nil;
    for (MotionEntity *entity in self.motionEntities) {
        if ([entity isSelected]) {
            entityToRemove = entity;
            break;
        }
    }
    [self deleteShape:entityToRemove];
    [self onDrawingStateChanged];
}

- (void)unselectShape {
    [self selectEntity:nil];
}

-(void)deleteShape: (MotionEntity *)entityToRemove {
    if (entityToRemove) {
        [self.motionEntities removeObject:entityToRemove];
        [_allShapes removeObject:entityToRemove.getEntityId];
        [entityToRemove removeFromSuperview];
        entityToRemove = nil;
        [self selectEntity:entityToRemove];
        [self onShapeSelectionChanged:nil];
    }
}

- (void) undoShape {
    MotionEntity* lastEntity = nil;
    NSString* lastId = nil;
    if (self.selectedEntity == nil) {
        lastId = [_allShapes lastObject];
        if (lastId != nil) {
            NSCharacterSet* notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
            if ([lastId rangeOfCharacterFromSet:notDigits].location != NSNotFound) {
                lastEntity = [self.motionEntities lastObject];
            }
        }
    } else {
        lastEntity = self.selectedEntity;
    }
    if (lastEntity != nil) {
        bool result = [lastEntity undo];
        if (!result) {
            _measurementEntity = nil;
            [self deleteShape:lastEntity];
            [self onDrawingStateChanged];
        }else {
            [self selectEntity:lastEntity];
            // Select measurement tool to have possibility to continue drawing
            if ([lastEntity class] == [MeasurementEntity class]){
                _measurementEntity = lastEntity;
            }
            [self onDrawingStateChangedWithUndo:true];
        }
    } else if (lastId != nil) {
        [self deletePath:[lastId intValue]];
    }
}


- (void)increaseTextEntityFontSize {
    TextEntity *textEntity = [self getSelectedTextEntity];
    if (textEntity) {
        [textEntity updateFontSize:textEntity.fontSize + 1];
        [textEntity setNeedsDisplay];
    }
}

- (void)decreaseTextEntityFontSize {
    TextEntity *textEntity = [self getSelectedTextEntity];
    if (textEntity) {
        [textEntity updateFontSize:textEntity.fontSize - 1];
        [textEntity setNeedsDisplay];
    }
}

- (void)setTextEntityText:(NSString *)newText {
    TextEntity *textEntity = [self getSelectedTextEntity];
    if (textEntity && newText && [newText length] > 0) {
        [textEntity updateText:newText];
        [textEntity setNeedsDisplay];
    }
}

- (TextEntity *)getSelectedTextEntity {
    if (self.selectedEntity && [self.selectedEntity isKindOfClass:[TextEntity class]]) {
        return (TextEntity *)self.selectedEntity;
    } else {
        return nil;
    }
}

- (void)handleFinishMeasurement {
    // call before clear to notify RN about finished shape
    [self onDrawingStateChanged];
    _measurementEntity = nil;
    [self unselectShape];
    [self onShapeSelectionChanged:nil];
    [self onDrawingStateChanged];
}

#pragma mark - UIGestureRecognizers
- (void)handleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint tapLocation = [sender locationInView:sender.view];
        if (_measurementEntity != nil) {
            bool isSelectedPoint = [_measurementEntity isPointInEntity:tapLocation];
            if (!isSelectedPoint) {
                int prevStep = [_measurementEntity getDrawingStep];
                bool inProgress = [_measurementEntity addPoint:tapLocation];
                [_measurementEntity setLocalFocused:false];
                [_measurementEntity setNeedsDisplay];
                if (prevStep != [_measurementEntity getDrawingStep]) {
                    if (!inProgress) {
                        [self handleFinishMeasurement];
                    }
                    [self onDrawingStateChanged];
                }
            }
        } else {
            [self updateSelectionOnTapWithLocationPoint:tapLocation];
        }
    }
}

- (void)handleRotate:(UIRotationGestureRecognizer *)sender {
    UIGestureRecognizerState state = [sender state];
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
        if (self.selectedEntity && _measurementEntity == nil) {
            [self.selectedEntity rotateEntityBy:sender.rotation];
            [self setNeedsDisplayInRect:self.selectedEntity.bounds];
        }
        [sender setRotation:0.0];
    }
}

-(BOOL)shouldStartMove {
    return self.selectedEntity == nil || [self.selectedEntity class] == [MeasurementEntity class];
}

- (void)handleMove:(UIPanGestureRecognizer *)sender {
    UIGestureRecognizerState state = [sender state];
    if (state == UIGestureRecognizerStateBegan) {
        _isMeasurementInProgress = false;
        _shouldHandleEndMove = false;
        CGPoint tapLocation = [sender locationInView:sender.view];
        if ([self shouldStartMove] && self.measurementEntity == nil) {
            // select shape
            [self updateSelectionOnTapWithLocationPoint:tapLocation];
        } else {
            if (self.measurementEntity != nil && ![self.measurementEntity isPointInEntity:tapLocation] && [self.measurementEntity getDrawingStep] < 2) {
                // add new point
                _isMeasurementInProgress = [_measurementEntity addPoint:tapLocation];
                _shouldHandleEndMove = true;
                // Update UI
                [self.measurementEntity setNeedsDisplay];
            }
        }
    }

    if (self.selectedEntity) {
        if (state != UIGestureRecognizerStateCancelled) {
            [self.selectedEntity moveEntityTo:[sender translationInView:self.selectedEntity]];
            [sender setTranslation:CGPointZero inView:sender.view];
            [self setNeedsDisplayInRect:self.selectedEntity.bounds];
        }

        if (state == UIGestureRecognizerStateCancelled || state == UIGestureRecognizerStateEnded) {
            if ([self.selectedEntity class] == [MeasurementEntity class]) {
                [((MeasurementEntity *)self.selectedEntity) setLocalFocused:false];
            }
            if (_shouldHandleEndMove) {
                if (!_isMeasurementInProgress) {
                    [self handleFinishMeasurement];
                }
                [self onDrawingStateChanged];
            }
            _isMeasurementInProgress = false;
            _shouldHandleEndMove = false;
        }
    }
}

- (void)handleScale:(UIPinchGestureRecognizer *)sender {
    UIGestureRecognizerState state = [sender state];
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
        if (self.selectedEntity && _measurementEntity == nil) {
            [self.selectedEntity scaleEntityBy:sender.scale];
            [self setNeedsDisplayInRect:self.selectedEntity.bounds];
        }
        [sender setScale:1.0];
    }
}

#pragma mark - Outgoing events
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo: (void *) contextInfo {
    if (_onChange) {
        _onChange(@{ @"success": error != nil ? @NO : @YES });
    }
}

- (void)notifyPathsUpdate {
    if (_onChange) {
        _onChange(@{ @"pathsUpdate": @(_paths.count) });
    }
}

- (void)onShapeSelectionChanged:(MotionEntity *)nextEntity {
    BOOL isShapeSelected = NO;
    if (nextEntity) {
        isShapeSelected = YES;
    }
    if (_onChange) {
        if (isShapeSelected) {
            _onChange(@{ @"isShapeSelected": @YES });
        } else {
            // Add delay!
            _onChange(@{ @"isShapeSelected": @NO });
        }
    }
}

-(void)onDrawingStateChanged {
    [self onDrawingStateChangedWithUndo:false];
}

- (BOOL)canUndo {
    return [_allShapes count] > 0 ? true : false;
}

-(void)onDrawingStateChangedWithUndo:(BOOL)withUndo {
    if (_onChange) {
        if (self.selectedEntity == nil){
            _onChange(@{
                @"canUndo": @([self canUndo]),
                @"canDelete":@NO,
                @"drawingStep": @-1,
            });
        } else {
            _onChange(@{
                @"canUndo": @([self canUndo]),
                @"canDelete": [self.selectedEntity getDrawingStep] == -1 && !withUndo ? @YES : @NO,
                @"drawingStep": @([self.selectedEntity getDrawingStep]),
                @"shapeType": [self.selectedEntity getShapeType],
            });
        }
    }
}

- (void)onDrawingStateChangedWithStroke:(BOOL)withPointerDown {
    if (_onChange && self.selectedEntity == nil) {
        _onChange(@{
            @"canUndo": @([self canUndo]),
            @"canDelete": @NO,
            @"drawingStep": @(withPointerDown ? 0 : 1),
            @"shapeType": @"stroke",
        });
    }
}

@end
