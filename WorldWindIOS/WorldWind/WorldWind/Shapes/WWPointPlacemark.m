/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.

 @version $Id$
 */

#import "WorldWind/Shapes/WWPointPlacemark.h"
#import "WorldWind/Shapes/WWPointPlacemarkAttributes.h"
#import "WorldWind/Geometry/WWMatrix.h"
#import "WorldWind/Geometry/WWPosition.h"
#import "WorldWind/Geometry/WWVec4.h"
#import "WorldWind/Navigate/WWNavigatorState.h"
#import "WorldWind/Pick/WWPickedObject.h"
#import "WorldWind/Pick/WWPickSupport.h"
#import "WorldWind/Render/WWDrawContext.h"
#import "WorldWind/Render/WWGpuProgram.h"
#import "WorldWind/Render/WWTexture.h"
#import "WorldWind/Terrain/WWTerrain.h"
#import "WorldWind/Util/WWColor.h"
#import "WorldWind/Util/WWGpuResourceCache.h"
#import "WorldWind/Util/WWMath.h"
#import "WorldWind/Util/WWOffset.h"
#import "WorldWind/Util/WWResourceLoader.h"
#import "WorldWind/WorldWind.h"
#import "WorldWind/WorldWindConstants.h"
#import "WorldWind/WWLog.h"

#define DEFAULT_DEPTH_OFFSET -0.01

// Temporary objects shared by all point placemarks and used during rendering.
static WWVec4* point;
static WWMatrix* matrix;
static WWColor* color;
static WWPickSupport* pickSupport;
static WWTexture* currentTexture;

@implementation WWPointPlacemark

//--------------------------------------------------------------------------------------------------------------------//
//-- Initializing Point Placemarks --//
//--------------------------------------------------------------------------------------------------------------------//

+ (void) initialize
{
    static BOOL initialized = NO; // protects against erroneous explicit calls to this method
    if (!initialized)
    {
        initialized = YES;

        point = [[WWVec4 alloc] initWithZeroVector];
        matrix = [[WWMatrix alloc] initWithIdentity];
        color = [[WWColor alloc] init];
        pickSupport = [[WWPickSupport alloc] init];
    }
}

- (WWPointPlacemark*) initWithPosition:(WWPosition*)position
{
    if (position == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Position is nil")
    }

    self = [super init];

    // Placemark attributes.
    defaultAttributes = [[WWPointPlacemarkAttributes alloc] init];
    [self setDefaultAttributes];

    // Placemark geometry.
    placePoint = [[WWVec4 alloc] initWithZeroVector];
    imageTransform = [[WWMatrix alloc] initWithIdentity];

    _displayName = @"Placemark";
    _highlighted = NO;
    _enabled = YES;
    _position = position;
    _altitudeMode = WW_ALTITUDE_MODE_ABSOLUTE;

    return self;
}

//--------------------------------------------------------------------------------------------------------------------//
//-- Renderable Interface --//
//--------------------------------------------------------------------------------------------------------------------//

- (void) render:(WWDrawContext*)dc
{
    if (dc == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Draw context is nil")
    }

    if (!_enabled)
    {
        return;
    }

    if ([dc orderedRenderingMode])
    {
        [self drawOrderedRenderable:dc];

        if ([dc pickingMode])
        {
            [pickSupport resolvePick:dc layer:pickLayer];
        }
    }
    else
    {
        [self makeOrderedRenderable:dc];
    }
}

//--------------------------------------------------------------------------------------------------------------------//
//-- Methods of Interest Only to Subclasses --//
//--------------------------------------------------------------------------------------------------------------------//

- (void) setDefaultAttributes
{
    // Configure the default attributes to display a white 5x5 point centered on the placemark's position. We set only
    // imageScale since the remaining attributes default to appropriate values: imagePath=nil, imageColor=white and
    // imageOffset=center.
    [defaultAttributes setImageScale:5];
}

- (void) makeOrderedRenderable:(WWDrawContext*)dc
{
    [self determineActiveAttributes:dc];
    if (activeAttributes == nil)
    {
        return;
    }

    [self doMakeOrderedRenderable:dc];
    if (CGRectIsEmpty(imageBounds))
    {
        return;
    }

    if (![self isPlacemarkVisible:dc])
    {
        return;
    }

    if ([dc pickingMode])
    {
        pickLayer = [dc currentLayer];
    }

    [dc addOrderedRenderable:self];
}

- (void) doMakeOrderedRenderable:(WWDrawContext*)dc
{
    [[dc terrain] surfacePointAtLatitude:[_position latitude]
                               longitude:[_position longitude]
                                  offset:[_position altitude]
                            altitudeMode:_altitudeMode
                                  result:placePoint];

    _eyeDistance = [[[dc navigatorState] eyePoint] distanceTo3:placePoint];

    if (![[dc navigatorState] project:placePoint result:point depthOffset:DEFAULT_DEPTH_OFFSET])
    {
        imageBounds = CGRectMake(0, 0, 0, 0);
        return; // The place point is clipped by the near plane or the far plane.
    }

    if (activeTexture != nil)
    {
        double w = [activeTexture imageWidth];
        double h = [activeTexture imageHeight];
        double s = [activeAttributes imageScale];
        [[activeAttributes imageOffset] subtractOffsetForWidth:w height:h xScale:s yScale:s result:point];
        [imageTransform setTranslation:[point x] y:[point y] z:[point z]];
        [imageTransform setScale:w * s y:h * s z:1];
    }
    else
    {
        double s = [activeAttributes imageScale];
        [[activeAttributes imageOffset] subtractOffsetForWidth:s height:s xScale:1 yScale:1 result:point];
        [imageTransform setTranslation:[point x] y:[point y] z:[point z]];
        [imageTransform setScale:s y:s z:1];
    }

    imageBounds = [WWMath boundingRectForUnitQuad:imageTransform];
}

- (void) determineActiveAttributes:(WWDrawContext*)dc
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

    NSString* imagePath = [activeAttributes imagePath];
    if (imagePath != nil)
    {
        activeTexture = [[WorldWind resourceLoader] textureForImagePath:imagePath cache:[dc gpuResourceCache]];
    }
    else
    {
        activeTexture = nil;
    }
}

- (BOOL) isPlacemarkVisible:(WWDrawContext*)dc
{
    CGRect viewport = [[dc navigatorState] viewport];

    if ([dc pickingMode])
    {
        CGPoint pickPoint = CGPointMake((CGFloat) [[dc pickPoint] x], CGRectGetHeight(viewport) - (CGFloat) [[dc pickPoint] y]);
        return CGRectContainsPoint(imageBounds, pickPoint);
    }
    else
    {
        return CGRectIntersectsRect(imageBounds, viewport);
    }
}

- (void) drawOrderedRenderable:(WWDrawContext*)dc
{
    [self beginDrawing:dc];

    @try
    {
        [self doDrawOrderedRenderable:dc];
        [self doDrawBatchOrderedRenderables:dc];
    }
    @finally
    {
        [self endDrawing:dc];
    }
}

- (void) doDrawOrderedRenderable:(WWDrawContext*)dc;
{
    WWGpuProgram* program = [dc currentProgram];

    if ([dc pickingMode])
    {
        unsigned int pickColor = [dc uniquePickColor];
        [pickSupport addPickableObject:[self createPickedObject:dc colorCode:pickColor]];
        [program loadUniformColorInt:@"color" color:pickColor];
    }
    else
    {
        [color setToColor:[activeAttributes imageColor]];
        [color preMultiply];
        [program loadUniformColor:@"color" color:color];

        if (currentTexture != activeTexture) // avoid unnecessary texture state changes
        {
            BOOL enableTexture = [activeTexture bind:dc]; // returns NO if activeTexture is nil
            [program loadUniformBool:@"enableTexture" value:enableTexture];
            currentTexture = activeTexture;
        }
    }

    [matrix setToMatrix:[dc screenProjection]];
    [matrix multiplyMatrix:imageTransform];
    [program loadUniformMatrix:@"mvpMatrix" matrix:matrix];

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void) doDrawBatchOrderedRenderables:(WWDrawContext*)dc
{
    // Draw any subsequent point placemarks in the ordered renderable queue, removing each from the queue as it's
    // processed. This avoids reduces the overhead of setting up and tearing down OpenGL state for each placemark.

    id <WWOrderedRenderable> or = nil;
    Class selfClass = [self class];

    while ((or = [dc peekOrderedRenderable]) != nil && [or isKindOfClass:selfClass])
    {
        [dc popOrderedRenderable]; // Remove it from the ordered renderable queue.

        @try
        {
            [(WWPointPlacemark*) or doDrawOrderedRenderable:dc];
        }
        @catch (NSException* exception)
        {
            NSString* msg = [NSString stringWithFormat:@"rendering shape"];
            WWLogE(msg, exception);
            // Keep going. Render the rest of the ordered renderables.
        }
    }
}

- (void) beginDrawing:(WWDrawContext*)dc
{
    // Bind the default texture program. This sets the program as the current OpenGL program and the current draw
    // context program.
    WWGpuProgram* program = [dc defaultTextureProgram];

    // Configure the GL shader's vertex attribute arrays to use the unit quad vertex buffer object as the source of
    // vertex point coordinates and vertex texture coordinate.
    glBindBuffer(GL_ARRAY_BUFFER, [dc unitQuadBuffer]);
    int location = [program getAttributeLocation:@"vertexPoint"];
    glEnableVertexAttribArray((GLuint) location);
    glVertexAttribPointer((GLuint) location, 2, GL_FLOAT, GL_FALSE, 0, 0);

    location = [program getAttributeLocation:@"vertexTexCoord"];
    glEnableVertexAttribArray((GLuint) location);
    glVertexAttribPointer((GLuint) location, 2, GL_FLOAT, GL_FALSE, 0, 0);

    // Load the texture coordinate matrix and texture sampler unit. These uniform variables do not change during the
    // program's execution over multiple point placemarks.
    [matrix setToUnitYFlip];
    [program loadUniformMatrix:@"texCoordMatrix" matrix:matrix];
    [program loadUniformSampler:@"textureSampler" value:0];

    // Disable texturing when in picking mode. These uniform variables do not change during the program's execution over
    // multiple point placemarks.
    if ([dc pickingMode])
    {
        [program loadUniformBool:@"enableTexture" value:NO];
    }

    // Configure the GL depth state to suppress depth buffer writes.
    glDepthMask(GL_FALSE);

    // Clear the current texture reference. This ensures that the first texture used by a placemark is bound.
    currentTexture = nil;
}

- (void) endDrawing:(WWDrawContext*)dc
{
    WWGpuProgram* program = [dc currentProgram];

    // Restore the GL shader's vertex attribute array state. This step must be performed before the GL program binding
    // is restored below.
    GLuint location = (GLuint) [program getAttributeLocation:@"vertexPoint"];
    glDisableVertexAttribArray(location);

    location = (GLuint) [program getAttributeLocation:@"vertexTexCoord"];
    glDisableVertexAttribArray(location);

    // Restore the GL program binding, buffer binding, texture binding, and depth state.
    glUseProgram(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    glDepthMask(GL_TRUE);

    // Avoid keeping a dangling reference to the current texture.
    currentTexture = nil;
}

- (WWPickedObject*) createPickedObject:(WWDrawContext*)dc colorCode:(unsigned int)colorCode
{
    return [[WWPickedObject alloc] initWithColorCode:colorCode
                                          userObject:(_pickDelegate != nil ? _pickDelegate : self)
                                           pickPoint:[dc pickPoint]
                                            position:_position
                                           isTerrain:NO];
}

@end