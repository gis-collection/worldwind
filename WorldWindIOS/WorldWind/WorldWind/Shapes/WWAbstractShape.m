/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import "WorldWind/Shapes/WWAbstractShape.h"
#import "WorldWind/Geometry/WWExtent.h"
#import "WorldWind/Geometry/WWMatrix.h"
#import "WorldWind/Geometry/WWVec4.h"
#import "WorldWind/Navigate/WWNavigatorState.h"
#import "WorldWind/Pick/WWPickSupport.h"
#import "WorldWind/Pick/WWPickedObject.h"
#import "WorldWind/Render/WWDrawContext.h"
#import "WorldWind/Shaders/WWBasicProgram.h"
#import "WorldWind/Shapes/WWShapeAttributes.h"
#import "WorldWind/Util/WWColor.h"
#import "WorldWind/WorldWindConstants.h"

@implementation WWAbstractShape

- (WWAbstractShape*) init
{
    self = [super init];

    defaultAttributes = [[WWShapeAttributes alloc] init];
    [self setDefaultAttributes]; // give subclasses a chance to set defaults

    _highlighted = NO;
    _enabled = YES;
    _altitudeMode = WW_ALTITUDE_MODE_ABSOLUTE;
    _displayName = @"Shape";

    transformationMatrix = [[WWMatrix alloc] initWithIdentity];
    referencePoint = [[WWVec4 alloc] initWithZeroVector];
    pickSupport = [[WWPickSupport alloc] init];

    return self;
}

- (void) reset
{
    // Subclasses should override and invalidate themselves when this method is called.
}

- (void) setDefaultAttributes
{
    [defaultAttributes setInteriorEnabled:YES];
    [defaultAttributes setInteriorColor:[[WWColor alloc] initWithR:0.75 g:0.75 b:0.75 a:1]];

    [defaultAttributes setOutlineEnabled:NO];
    [defaultAttributes setOutlineColor:[[WWColor alloc] initWithR:0.25 g:0.25 b:0.25 a:1]];
    [defaultAttributes setOutlineWidth:1];
}

- (BOOL) isDrawOutline:(WWDrawContext*)dc
{
    return [self mustDrawOutline];
}

- (BOOL) isDrawInterior:(WWDrawContext*)dc
{
    return [self mustDrawInterior];
}

- (void) drawOutline:(WWDrawContext*)dc
{
    [self prepareToDrawOutline:dc attributes:activeAttributes];
    [self doDrawOutline:dc];
}

- (void) drawInterior:(WWDrawContext*)dc
{
    [self prepareToDrawInterior:dc attributes:activeAttributes];
    [self doDrawInterior:dc];
}

- (BOOL) isEnableDepthOffset:(WWDrawContext*)dc
{
    return NO;
}

- (float) depthOffsetFactor:(WWDrawContext*)dc
{
    return 1;
}

- (float) depthOffsetUnits:(WWDrawContext*)dc
{
    return 1;
}

- (void) render:(WWDrawContext*)dc
{
    if (!_enabled)
    {
        return;
    }

    if ([dc orderedRenderingMode])
    {
        [self drawOrderedRenderable:dc];

        if ([dc pickingMode])
        {
            [pickSupport resolvePick:dc];
        }
    }
    else
    {
        [self makeOrderedRenderable:dc];
    }
}

- (BOOL) intersectsFrustum:(WWDrawContext*)dc
{
    return _extent == nil || [_extent intersects:[[dc navigatorState] frustumInModelCoordinates]];
}

- (void) makeOrderedRenderable:(WWDrawContext*)dc
{
    [self determineActiveAttributes];
    if (activeAttributes == nil)
    {
        return;
    }

    if ([self mustRegenerateGeometry:dc])
    {
        [self doMakeOrderedRenderable:dc];

        // Remember the vertical exaggeration used to make this shape.
        verticalExaggeration = [dc verticalExaggeration];
    }

    if (![self intersectsFrustum:dc] || [dc isSmall:_extent numPixels:1])
    {
        return;
    }

    if (![self isOrderedRenderableValid:dc])
    {
        return;
    }

    layer = [dc currentLayer];

    [self addOrderedRenderable:dc];
}

- (void) doMakeOrderedRenderable:(WWDrawContext*)dc
{
    // Must be implemented by subclass
}

- (BOOL) isOrderedRenderableValid:(WWDrawContext*)dc
{
    // May be implemented by subclass

    return YES;
}

- (void) addOrderedRenderable:(WWDrawContext*)dc
{
    [dc addOrderedRenderable:self];
}

- (void) drawOrderedRenderable:(WWDrawContext*)dc
{
    [self beginDrawing:dc];

    @try
    {
        [self doDrawOrderedRenderable:dc];
    }
    @finally
    {
        [self endDrawing:dc];
    }

}

- (void) doDrawOrderedRenderable:(WWDrawContext*)dc
{
    if ([dc pickingMode])
    {
        unsigned int color = [dc uniquePickColor];
        [pickSupport addPickableObject:[self createPickedObject:dc colorCode:color]];
        [(WWBasicProgram*) [dc currentProgram] loadPickColor:color];
    }

    [self applyModelviewProjectionMatrix:dc];
    [dc drawOutlinedShape:self];
}

- (BOOL) mustRegenerateGeometry:(WWDrawContext*)dc
{
    // Should be implemented by subclass

    return YES;
}

- (void) determineActiveAttributes
{
    if (_highlighted && _highlightAttributes != nil)
    {
        activeAttributes = _highlightAttributes;
    }
    else if (_attributes != nil)
    {
        activeAttributes = _attributes;
    }
    else
    {
        activeAttributes = defaultAttributes;
    }
}

- (BOOL) mustDrawInterior
{
    return activeAttributes != nil && [activeAttributes interiorEnabled];
}

- (BOOL) mustDrawOutline
{
    return activeAttributes != nil && [activeAttributes outlineEnabled];
}

- (void) beginDrawing:(WWDrawContext*)dc
{
    [dc bindProgramForKey:[WWBasicProgram programKey] class:[WWBasicProgram class]];

    WWBasicProgram* program = (WWBasicProgram*) [dc currentProgram];
    glEnableVertexAttribArray([program vertexPointLocation]);
}

- (void) endDrawing:(WWDrawContext*)dc
{
    // Restore the global OpenGL vertex attribute array state. This step must be performed before the GL program binding
    // is restored below in order to access the vertex attribute array indices from the current program.
    WWBasicProgram* program = (WWBasicProgram*) [dc currentProgram];
    glDisableVertexAttribArray([program vertexPointLocation]);

    // Restore OpenGL state.
    [dc bindProgram:nil];
    glDepthMask(GL_TRUE);
    glLineWidth(1);
}

- (void) applyModelviewProjectionMatrix:(WWDrawContext*)dc
{
    WWMatrix* mvp = [[WWMatrix alloc] initWithMultiply:[[dc navigatorState] modelviewProjection]
                                               matrixB:transformationMatrix];
    [(WWBasicProgram *) [dc currentProgram] loadModelviewProjection:mvp];
}

- (void) prepareToDrawInterior:(WWDrawContext*)dc attributes:(WWShapeAttributes*)attributes
{
    if (attributes == nil || ![attributes interiorEnabled])
    {
        return;
    }

    if (![dc pickingMode])
    {
        WWColor* color = [attributes interiorColor];

        // Disable writing the shape's interior fragments to the depth buffer when the interior is semi-transparent.
        if ([color a] < 1)
        {
            glDepthMask(GL_FALSE);
        }

        // Load the current interior color into the current program's uniform variable.
        [(WWBasicProgram *) [dc currentProgram] loadColor:color];
    }
}

- (void) doDrawInterior:(WWDrawContext*)dc
{
    // Must be implemented by subclasses.
}

- (void) prepareToDrawOutline:(WWDrawContext*)dc attributes:(WWShapeAttributes*)attributes
{
    if (attributes == nil || ![attributes outlineEnabled])
    {
        return;
    }

    if (![dc pickingMode])
    {
        WWColor* color = [attributes outlineColor];

        // Disable writing the shape's outline fragments to the depth buffer when the outline is semi-transparent.
        if ([color a] < 1)
        {
            glDepthMask(GL_FALSE);
        }

        // Load the current outline color into the current program's uniform variable.
        [(WWBasicProgram *) [dc currentProgram] loadColor:color];
    }

    glLineWidth([attributes outlineWidth]);
}

- (void) doDrawOutline:(WWDrawContext*)dc
{
    // Must be implemented by subclasses.
}

- (WWPickedObject*) createPickedObject:(WWDrawContext*)dc colorCode:(unsigned int)colorCode
{
    return [[WWPickedObject alloc] initWithColorCode:colorCode
                                           pickPoint:[dc pickPoint]
                                          userObject:(_pickDelegate != nil ? _pickDelegate : self)
                                            position:[self referencePosition]
                                         parentLayer:layer];
}

@end