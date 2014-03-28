/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <Foundation/Foundation.h>

@class WWPosition;
@class MovingMapViewController;

@interface PositionReadoutController : UITableViewController
{
@protected
    NSMutableArray* tableCells;
    NSMutableArray* tableRowHeights;
}

@property (nonatomic) WWPosition* position;

@property (nonatomic) MovingMapViewController* mapViewController;

@property (nonatomic) UIPopoverController* presentingPopoverController;

@end