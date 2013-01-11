/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <Foundation/Foundation.h>
#import "WorldWind/Util/WWTile.h"

@class WWTessellator;
@class WWDrawContext;
@class WWTerrainGeometry;
@class WWLevel;

/**
* Provides an elevation tile class for use within WWTessellator. Applications typically do not interact with this
* class.
*/
@interface WWTerrainTile : WWTile

/// @name Attributes

/// The tessellator this tile is used by.
/// The tessellator property is weak because the tessellator can point to the tile,
/// thereby creating a cycle. A strong reference to the tessellator is always held by the Globe.
@property(readonly, nonatomic, weak) WWTessellator* tessellator;

/// The terrain geometry for this tile.
@property(nonatomic) WWTerrainGeometry* terrainGeometry;

/// The number of cells in which to subdivide terrain tiles in the longitudinal direction. This property governs the
// density of triangles in the tile.
@property(readonly, nonatomic) int numLonCells;

/// The number of cells in which to subdivide terrain tiles in the latitudinal direction. This property governs the
// density of triangles in the tile.
@property(readonly, nonatomic) int numLatCells;

/// @name Initializing Terrain Tiles

/**
* Initializes a terrain tile.
*
* @param sector The sector this tile covers.
* @param level The level this tile is associated with.
* @param row This tile's row in the associated level.
* @param column This tile's column in the associated level.
* @param tessellator The tessellator containing this tile.
*
* @return This terrain tile, initialized.
*
* @exception NSInvalidArgumentException if the specified sector, level or tessellator are nil,
* or the row and column numbers are less than zero.
*/
- (WWTerrainTile*) initWithSector:(WWSector*)sector
                            level:(WWLevel*)level
                              row:(int)row
                           column:(int)column
                      tessellator:(WWTessellator*)tessellator;

/// @name Rendering Operations (Not typically called by applications.)

/**
* Prepare this tile for rendering.
*
* @param dc The current draw context
*/
- (void) beginRendering:(WWDrawContext*)dc;

/**
* Restore state modified during rendering.
*
* @param dc The current draw context.
*/
- (void) endRendering:(WWDrawContext*)dc;

/**
* Draw the tile.
*
* @param dc The current draw context.
*/
- (void) render:(WWDrawContext*)dc;

/**
* Draw a wireframe representation of the tile that displays the tile's tessellation triangles.
*
* @param dc The current draw context.
*/
- (void) renderWireframe:(WWDrawContext*)dc;

@end
