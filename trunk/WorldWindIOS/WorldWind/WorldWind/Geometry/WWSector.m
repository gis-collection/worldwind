/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import "WorldWind/Geometry/WWSector.h"
#import "WorldWind/WWLog.h"
#import "WWVec4.h"
#import "WWLocation.h"

@implementation WWSector

- (WWSector*) initWithDegreesMinLatitude:(double)minLatitude
                             maxLatitude:(double)maxLatitude
                            minLongitude:(double)minLongitude
                            maxLongitude:(double)maxLongitude
{
    self = [super init];
    
    _minLatitude = minLatitude;
    _maxLatitude = maxLatitude;
    _minLongitude = minLongitude;
    _maxLongitude = maxLongitude;
    
    return self;
}

- (WWSector*) initWithFullSphere
{
    self = [super init];

    _minLatitude = -90;
    _maxLatitude = 90;
    _minLongitude = -180;
    _maxLongitude = 180;

    return self;
}

- (id) copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] initWithDegreesMinLatitude:_minLatitude maxLatitude:_maxLatitude minLongitude:_minLongitude maxLongitude:_maxLongitude];
}

- (void) centroidLocation:(WWLocation*)result
{
    if (result == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Result is nil")
    }

    result.latitude = 0.5 * (_minLatitude + _maxLatitude);
    result.longitude = 0.5 * (_minLongitude + _maxLongitude);
}

@end
