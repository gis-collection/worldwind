/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <CoreLocation/CoreLocation.h>
#import "AppDelegate.h"
#import "MainScreenController.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"
#import "DDFileLogger.h"
#import "AppConstants.h"
#import "UnitsFormatter.h"
#import "Settings.h"
#import "GPSController.h"
#import "GDBMessageController.h"
#import <Crashlytics/Crashlytics.h>

@implementation AppDelegate
{
    UnitsFormatter* formatter;
}

- (BOOL) application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    [self startLogging];

    NSString* address = (NSString*) [Settings getObjectForName:TAIGA_GPS_DEVICE_ADDRESS];
    if (address == nil || address.length == 0)
    {
        [GPSController setDefaultGPSDeviceAddress];
    }

    address = (NSString*) [Settings getObjectForName:TAIGA_GDB_DEVICE_ADDRESS];
    if (address == nil || address.length == 0)
    {
        [GDBMessageController setDefaultGDBDeviceAddress];
    }

    MainScreenController* mainScreenController = [[MainScreenController alloc] init];

    [self.window setRootViewController:mainScreenController];

    // Set up to log position changes and GDB messages.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aircraftPositionChanged:)
                                                 name:TAIGA_CURRENT_AIRCRAFT_POSITION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gdbMessageReceived:)
                                                 name:TAIGA_GDB_MESSAGE object:nil];

    [Crashlytics startWithAPIKey:@"5cfb29d0cd7e2db68baa627ddfa10e6100679b6c"];

    [self.window makeKeyAndVisible];
    return YES;
}

- (void) startLogging
{
    formatter = [[UnitsFormatter alloc] init];

    [DDLog addLogger:[DDASLLogger sharedInstance]]; // Apple system logger
    [DDLog addLogger:[DDTTYLogger sharedInstance]]; // Console logger

    // Set up logging to log file.
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* logsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;

    DDLogFileManagerDefault* logFileManagerDefault = [[DDLogFileManagerDefault alloc]
            initWithLogsDirectory:logsDirectory];
    DDFileLogger* fileLogger = [[DDFileLogger alloc] initWithLogFileManager:logFileManagerDefault];
    [DDLog addLogger:fileLogger];
}

- (void) aircraftPositionChanged:(NSNotification*)notification
{
    CLLocation* location = [notification object];

    NSString* s = [formatter formatDegreesLatitude:location.coordinate.latitude
                                         longitude:location.coordinate.longitude
                                    metersAltitude:location.altitude];
    DDLogInfo(@"GPS: %@ (%d m accuracy)", s, (int) location.horizontalAccuracy);
}

- (void) gdbMessageReceived:(NSNotification*)notification
{
    NSString* message = [notification object];
    DDLogInfo(@"GDB Message: %@", message != nil ? message : @"NONE");
}

- (void) applicationWillResignActive:(UIApplication*)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void) applicationDidEnterBackground:(UIApplication*)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void) applicationWillEnterForeground:(UIApplication*)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void) applicationDidBecomeActive:(UIApplication*)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void) applicationWillTerminate:(UIApplication*)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
