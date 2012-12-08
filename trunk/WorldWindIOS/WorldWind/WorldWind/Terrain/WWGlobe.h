/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <Foundation/Foundation.h>

@class WWTessellator;
@class WWTerrainTileList;
@class WWDrawContext;
@class WWVec4;

@interface WWGlobe : NSObject

@property(readonly) double equatorialRadius;
@property(readonly) double polarRadius;
@property(readonly) double es;
@property(readonly) WWTessellator* tessellator;

- (WWGlobe*) init;

- (WWTerrainTileList*) tessellate:(WWDrawContext*)dc;

- (void) computePointFromPosition:(double)latitude longitude:(double)longitude altitude:(double)altitude
                           outputPoint:(WWVec4*)result;
- (void) computePointFromPosition:(double)latitude longitude:(double)longitude altitude:(double)altitude
                           offset:(WWVec4*)offset outputArray:(float*)result;

@end
