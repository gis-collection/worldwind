/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.

 @version $Id$
 */

#import <Foundation/Foundation.h>

@class Waypoint;

@interface WaypointFile : NSObject
{
@protected
    NSMutableArray* waypointArray;
    NSMutableDictionary* waypointKeyMap;
    void (^finished)(WaypointFile* waypointFile);
}

- (WaypointFile*) initWithWaypointLocations:(NSArray*)locationArray finishedBlock:(void (^)(WaypointFile*))finishedBlock;

- (NSArray*) waypoints;

- (NSArray*) waypointsMatchingText:(NSString*)text;

- (Waypoint*) waypointForKey:(NSString*)key;

@end