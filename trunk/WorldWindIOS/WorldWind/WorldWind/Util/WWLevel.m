/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import "WorldWind/Util/WWLevel.h"
#import "WorldWind/Geometry/WWLocation.h"
#import "WorldWind/Util/WWLevelSet.h"
#import "WorldWind/WWLog.h"
#import "WorldWind/Geometry/WWSector.h"
#import "WorldWind/Util/WWMath.h"

@implementation WWLevel

- (WWLevel*) initWithLevelNumber:(int)levelNumber tileDelta:(WWLocation*)tileDelta parent:(WWLevelSet*)parent
{
    if (levelNumber < 0)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Level number is less than 0")
    }

    if (tileDelta == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Tile delta is nil")
    }

    if (parent == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Parent is nil")
    }

    self = [super init];

    _parent = parent;
    _levelNumber = levelNumber;
    _tileDelta = tileDelta;
    _texelSize = RADIANS([tileDelta latitude]) / [_parent tileHeight];

    return self;
}

- (int) tileWidth
{
    return [_parent tileWidth];
}

- (int) tileHeight
{
    return [_parent tileHeight];
}

- (WWSector*) sector
{
    return [_parent sector];
}

- (BOOL) isFirstLevel
{
    return [_parent firstLevel] == self;
}

- (BOOL) isLastLevel
{
    return [_parent lastLevel] == self;
}

- (WWLevel*) previousLevel
{
    return [_parent level:_levelNumber - 1];
}

- (WWLevel*) nextLevel
{
    return [_parent level:_levelNumber + 1];
}

- (NSComparisonResult) compare:(WWLevel*)level
{
    if (level == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Level is nil")
    }

    if (_levelNumber < level->_levelNumber)
        return NSOrderedAscending;

    if (_levelNumber > level->_levelNumber)
        return NSOrderedDescending;

    return NSOrderedSame;
}

@end