/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.

 @version $Id$
 */

#import <CoreLocation/CoreLocation.h>
#import "SimulationViewController.h"
#import "AircraftMarker.h"
#import "AppConstants.h"
#import "FlightRoute.h"
#import "RedrawingSlider.h"
#import "WorldWind/Render/WWSceneController.h"
#import "WorldWind/Geometry/WWPosition.h"
#import "WorldWind/Layer/WWLayerList.h"
#import "WorldWind/Layer/WWRenderableLayer.h"
#import "WorldWind/WorldWindConstants.h"
#import "WorldWind/WorldWindView.h"

//--------------------------------------------------------------------------------------------------------------------//
//-- AircraftSlider --//
//--------------------------------------------------------------------------------------------------------------------//

static const CGFloat AircraftSliderHeight = 4;

@interface AircraftSlider : RedrawingSlider
@end

@implementation AircraftSlider

- (CGRect) trackRectForBounds:(CGRect)bounds
{
    CGRect rect = [super trackRectForBounds:bounds];
    CGFloat dh = AircraftSliderHeight - CGRectGetHeight(rect);
    rect.size.height = AircraftSliderHeight;
    rect.origin.y -= dh / 2;

    return rect;
}

@end

//--------------------------------------------------------------------------------------------------------------------//
//-- SimulationViewController --//
//--------------------------------------------------------------------------------------------------------------------//

@implementation SimulationViewController

//--------------------------------------------------------------------------------------------------------------------//
//-- Initializing SimulationViewController --//
//--------------------------------------------------------------------------------------------------------------------//

- (SimulationViewController*) initWithWorldWindView:(WorldWindView*)wwv
{
    self = [super initWithNibName:nil bundle:nil];

    _wwv = wwv;

    simulationLayer = simulationLayer = [[WWRenderableLayer alloc] init];
    [[simulationLayer userTags] setObject:@"" forKey:TAIGA_HIDDEN_LAYER];
    [simulationLayer setEnabled:NO];
    [[[_wwv sceneController] layers] addLayer:simulationLayer];

    aircraftMarker = [[AircraftMarker alloc] init];
    [simulationLayer addRenderable:aircraftMarker];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleFlightRouteNotification:)
                                                 name:TAIGA_FLIGHT_ROUTE_CHANGED object:nil];

    return self;
}

//--------------------------------------------------------------------------------------------------------------------//
//-- Flight Route --//
//--------------------------------------------------------------------------------------------------------------------//

- (void) setFlightRoute:(FlightRoute*)flightRoute
{
    if (_flightRoute == flightRoute)
        return;

    _flightRoute = flightRoute;

    // Set the aircraft slider to the beginning of the flight route and update the simulation UI elements to match the
    // new flight route.
    [aircraftSlider setValue:0];
    [self handleFightRouteChanged];
}

- (void) handleFlightRouteNotification:(NSNotification*)notification
{
    FlightRoute* flightRoute = [notification object];
    if (flightRoute == _flightRoute)
    {
        [self handleFightRouteChanged];
    }
}

- (void) postAircraftPosition
{
    CLLocationCoordinate2D coordinate;
    CLLocationDistance altitude;
    CLLocationDirection course;
    NSDate* now = [NSDate date];

    [_flightRoute locationForPercent:[aircraftSlider value]
                            latitude:&coordinate.latitude
                           longitude:&coordinate.longitude
                            altitude:&altitude
                              course:&course];

    CLLocation* location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                         altitude:altitude
                                               horizontalAccuracy:0
                                                 verticalAccuracy:0
                                                           course:course
                                                            speed:0
                                                        timestamp:now];

    [[NSNotificationCenter defaultCenter] postNotificationName:TAIGA_CURRENT_AIRCRAFT_POSITION object:location];

    [[aircraftMarker position] setCLLocation:location altitude:altitude];
}

//--------------------------------------------------------------------------------------------------------------------//
//-- View Control Events --//
//--------------------------------------------------------------------------------------------------------------------//

- (void) handleAircraftSlider
{
    // Post the simulated aircraft position as the percentage along the flight route corresponding to the current
    // aircraft slider value.
    [self postAircraftPosition];
}

- (void) handleFightRouteChanged
{
    // Set the title label to the flight route display name + " Simulation", or nil if the flight route is nil.
    [titleLabel setText:[[_flightRoute displayName] stringByAppendingString:@" Simulation"]];

    // Disable the simulation layer if the flight route is nil or has no waypoints.
    [simulationLayer setEnabled:_flightRoute != nil && [_flightRoute waypointCount] > 0];

    // Post the simulated aircraft position as the percentage along the flight route corresponding to the current
    // aircraft slider value.
    [self postAircraftPosition];

    [[NSNotificationCenter defaultCenter] postNotificationName:WW_REQUEST_REDRAW object:self];
}

//--------------------------------------------------------------------------------------------------------------------//
//-- View Layout --//
//--------------------------------------------------------------------------------------------------------------------//

- (void) loadView
{
    UIView* view = [[UIView alloc] init];
    [view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [view setBackgroundColor:[UIColor colorWithWhite:0.8 alpha:1]];
    [view setAlpha:0.95];
    [self setView:view];

    doneButton = [[UIButton alloc] init];
    [doneButton setImage:[[UIImage imageNamed:@"433-x"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [view addSubview:doneButton];
    _doneControl = doneButton;

    titleLabel = [[UILabel alloc] init];
    [view addSubview:titleLabel];

    aircraftSlider = [[AircraftSlider alloc] init];
    [aircraftSlider addTarget:self action:@selector(handleAircraftSlider) forControlEvents:UIControlEventValueChanged];
    [aircraftSlider setMinimumTrackTintColor:[UIColor whiteColor]];
    [aircraftSlider setMaximumTrackTintColor:[UIColor blackColor]];
    [aircraftSlider setMinimumValueImage:[UIImage imageNamed:@"route-begin"]];
    [aircraftSlider setMaximumValueImage:[UIImage imageNamed:@"route-end"]];
    [view addSubview:aircraftSlider];

    [self layout];
}

- (void) layout
{
    NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(doneButton, titleLabel, aircraftSlider);
    [doneButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [aircraftSlider setTranslatesAutoresizingMaskIntoConstraints:NO];

    UIView* view = [self view];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[doneButton]-10-|"
                                                                 options:0 metrics:nil views:viewsDictionary]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-10-[doneButton]"
                                                                 options:0 metrics:nil views:viewsDictionary]];
    [view addConstraint:[NSLayoutConstraint constraintWithItem:titleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual
                                                        toItem:view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-10-[titleLabel]"
                                                                 options:0 metrics:nil views:viewsDictionary]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-50-[aircraftSlider]-50-|"
                                                                 options:0 metrics:nil views:viewsDictionary]];
    [view addConstraint:[NSLayoutConstraint constraintWithItem:aircraftSlider attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual
                                                        toItem:view attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
}

@end