/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.

 @version $Id$
 */

#import <Foundation/Foundation.h>
#import "WorldWind/Navigate/WWNavigatorState.h"

@class WWMatrix;
@class WWVec4;
@class WWFrustum;

/**
* Provides an implementation of the WWNavigatorState protocol.
*/
@interface WWBasicNavigatorState : NSObject<WWNavigatorState>
{
@protected
    // The inverses of the modelview, projection, and concatenated modelview-projection matrices.
    WWMatrix* modelviewInv;
    WWMatrix* projectionInv;
    WWMatrix* modelviewProjectionInv;
    // Constants computed during initialization and used in pixelSizeAtDistance.
    double pixelSizeScale;
    double pixelSizeOffset;
}

/// @name Navigator State Attributes

/// The navigator's modelview matrix.
@property (nonatomic, readonly) WWMatrix* modelview;

/// The navigator's projection matrix.
@property (nonatomic, readonly) WWMatrix* projection;

/// The navigator's combined modelview - projection matrix.
@property (nonatomic, readonly) WWMatrix* modelviewProjection;

/// The navigator's viewport rectangle in screen coordinates.
@property (nonatomic, readonly) CGRect viewport;

/// The navigator's eye point in model coordinates.
@property (nonatomic, readonly) WWVec4* eyePoint;

/// The navigator's forward vector in model coordinates.
@property (nonatomic, readonly) WWVec4* forward;

/// The navigator's forward-ray in model coordinates.
@property (nonatomic, readonly) WWLine* forwardRay;

/// The navigator's frustum in model coordinates.
@property (nonatomic, readonly) WWFrustum* frustumInModelCoordinates;

/// @name Initializing Navigator State

/**
* Initializes this navigator state.
*
* @param modelviewMatrix The navigator's modelview matrix.
* @param projectionMatrix The navigator's projection matrix.
* @param viewport The navigator's viewport rectangle in screen coordinates.
*
* @return The initialized instance.
*
* @exception NSInvalidArgumentException If any argument is nil.
*/
- (WWBasicNavigatorState*) initWithModelview:(WWMatrix*)modelviewMatrix
                                  projection:(WWMatrix*)projectionMatrix
                                    viewport:(CGRect)viewport;

@end