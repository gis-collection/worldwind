/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import "WorldWind/WorldWindConstants.h"
#import "WorldWind/WWLog.h"

@class WWResourceLoader;

/**
* Provides access to World Wind singletons.
*/
@interface WorldWind : NSObject

/**
* Returns the singleton World Wind retrieval queue.
*
* @return The World Wind retrieval queue.
*/
+ (NSOperationQueue*) retrievalQueue;

/**
* Returns the singleton World Wind file loading queue.
*
* This queue is used to load files from disk on separate threads.
*
* @return The World Wind file loading queue.
*/
+ (NSOperationQueue*) loadQueue;

/**
* Returns the singleton World Wind resource loader.
*
* This loader encapsulates the pattern of asynchronously loading resources from the file-system or network to a memory
* cache.
*
* @return The World Wind resource loader.
*/
+ (WWResourceLoader*) resourceLoader;

/**
* Show or hide the device's network busy signal.
*
* Calls to this method are reference counted so the signal may still display even after calling this method. If so,
* it means that the method has been called by other code performing network activity.
*
* @param visible YES to turn the busy signal on, NO to turn it off.
*/
+ (void) setNetworkBusySignalVisible:(BOOL)visible;

/**
* Enables or disables offline mode.
*
* Offline mode determines whether World Wind is allowed to make requests to the network. If the mode is YES,
* World Wind does not make network requests.
*
* @param offlineMode YES to set World Wind to offline mode. NO to set it to normal mode.
*/
+ (void) setOfflineMode:(BOOL)offlineMode;

/**
* Indicates whether offline mode is active.
*
* @result YES if offline mode is active, otherwise NO (the default).
*/
+ (BOOL) isOfflineMode;

/**
* Indicates whether the network is reachable.
*
* @return YES if the network is reachable, otherwise NO.
*/
+ (BOOL) isNetworkAvailable;

@end
