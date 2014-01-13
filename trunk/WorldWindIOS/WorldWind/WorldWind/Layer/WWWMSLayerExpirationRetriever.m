/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import "WorldWind/Layer/WWWMSLayerExpirationRetriever.h"
#import "WorldWind/Layer/WWTiledImageLayer.h"
#import "WorldWind/Util/WWWMSCapabilities.h"
#import "WorldWind/WorldWindView.h"
#import "WorldWind/WWLog.h"

@implementation WWWMSLayerExpirationRetriever

- (WWWMSLayerExpirationRetriever*) initWithLayer:(id)layer
                                      layerNames:(NSArray*)layerNames
                                  serviceAddress:(NSString*)serviceAddress
{
    if (layer == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Layer is nil")
    }

    if (layerNames == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Layer names is nil")
    }

    if (serviceAddress == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Service address is nil")
    }

    self = [super init];

    _layer = layer;
    _layerNames = layerNames;
    _serviceAddress = serviceAddress;

    return self;
}

- (void) main
{
    WWWMSCapabilities __unused * caps =
            [[WWWMSCapabilities alloc] initWithServiceAddress:_serviceAddress
                                                finishedBlock:^(WWWMSCapabilities* capabilities)
                                                {
                                                    [self performSelectorOnMainThread:@selector(setExpiration:)
                                                                           withObject:capabilities
                                                                        waitUntilDone:NO];
                                                }];
}

- (void) setExpiration:(id)capabilities
{
    if (capabilities != nil)
    {
        NSDate* layerLastUpdateTime = [self determineLastUpdateDate:capabilities];
        if (layerLastUpdateTime != nil)
        {
            // Note that the "layer" may be a tiled image layer or an elevation model.
            [_layer setExpiration:layerLastUpdateTime];

            // Request a redraw so the layer can updated itself.
            [WorldWindView requestRedraw];
        }
    }
}

- (NSDate*) determineLastUpdateDate:(id)capabilities
{
    NSDate* date = nil;

    for (NSString* layerName in _layerNames)
    {
        NSDictionary* layerCaps = [capabilities namedLayer:layerName];
        if (layerCaps != nil)
        {
            NSDate* layerLastUpdateTime = [WWWMSCapabilities layerLastUpdateTime:layerCaps];
            if (layerLastUpdateTime != nil)
            {
                if (date == nil)
                {
                    date = layerLastUpdateTime;
                }
                else
                {
                    date = [date laterDate:layerLastUpdateTime];
                }
            }
        }
    }

    return date;
}

@end