/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import "WorldWind/Layer/WWTiledImageLayer.h"
#import "WorldWind/Formats/PVRTC/WWPVRTCImage.h"
#import "WorldWind/Geometry/WWBoundingBox.h"
#import "WorldWind/Geometry/WWLocation.h"
#import "WorldWind/Geometry/WWSector.h"
#import "WorldWind/Navigate/WWNavigatorState.h"
#import "WorldWind/Render/WWDrawContext.h"
#import "WorldWind/Render/WWSurfaceTile.h"
#import "WorldWind/Render/WWSurfaceTileRenderer.h"
#import "WorldWind/Render/WWTexture.h"
#import "WorldWind/Render/WWTextureTile.h"
#import "WorldWind/Util/WWAbsentResourceList.h"
#import "WorldWind/Util/WWBulkRetriever.h"
#import "WorldWind/Util/WWFrameStatistics.h"
#import "WorldWind/Util/WWGpuResourceCache.h"
#import "WorldWind/Util/WWLevel.h"
#import "WorldWind/Util/WWLevelSet.h"
#import "WorldWind/Util/WWMath.h"
#import "WorldWind/Util/WWMemoryCache.h"
#import "WorldWind/Util/WWRetrieverToFile.h"
#import "WorldWind/Util/WWTileKey.h"
#import "WorldWind/Util/WWUtil.h"
#import "WorldWind/Util/WWWMSUrlBuilder.h"
#import "WorldWind/WorldWind.h"
#import "WorldWind/Geometry/WWMatrix.h"

//--------------------------------------------------------------------------------------------------------------------//
//-- Initializing Tiled Image Layers --//
//--------------------------------------------------------------------------------------------------------------------//

@implementation WWTiledImageLayer

- (WWTiledImageLayer*) initWithSector:(WWSector*)sector
                       levelZeroDelta:(WWLocation*)levelZeroDelta
                            numLevels:(int)numLevels
                 retrievalImageFormat:(NSString*)retrievalImageFormat
                            cachePath:(NSString*)cachePath
{
    if (sector == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Sector is nil")
    }

    if (levelZeroDelta == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Level 0 delta is nil")
    }

    if (numLevels < 1)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Number of levels is less than 1")
    }

    if (retrievalImageFormat == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Image format is nil")
    }

    if (cachePath == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Cache path is nil")
    }

    self = [super init];

    _retrievalImageFormat = retrievalImageFormat;
    _cachePath = cachePath;
    _timeout = 20; // seconds
    _textureFormat = WW_TEXTURE_RGBA_5551;

    levels = [[WWLevelSet alloc] initWithSector:sector
                                 levelZeroDelta:levelZeroDelta
                                      numLevels:numLevels];
    topLevelTiles = [[NSMutableArray alloc] init];
    currentTiles = [[NSMutableArray alloc] init];
    _currentTilesInvalid = YES;
    tileCache = [[WWMemoryCache alloc] initWithCapacity:500000 lowWater:400000];
    detailHintOrigin = 2.4;

    currentRetrievals = [[NSMutableSet alloc] init];
    currentLoads = [[NSMutableSet alloc] init];
    absentResources = [[WWAbsentResourceList alloc] initWithMaxTries:3 minCheckInterval:10];

    [self setPickEnabled:NO];

    // Set up to handle retrieval and image read monitoring.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTextureRetrievalNotification:)
                                                 name:WW_RETRIEVAL_STATUS // retrieval from net
                                               object:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTextureLoadNotification:)
                                                 name:WW_REQUEST_STATUS // opening image file on disk
                                               object:self];

    return self;
}

- (void) dispose
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setPickEnabled:(BOOL)pickEnabled
{
    // Picking can never be enabled for TiledImageLayer. It's disabled at initialization and can't be set.
}

//--------------------------------------------------------------------------------------------------------------------//
//-- Creating Image Tiles --//
//--------------------------------------------------------------------------------------------------------------------//

- (WWTile*) createTile:(WWSector*)sector level:(WWLevel*)level row:(int)row column:(int)column
{
    NSString* formatSuffix = _retrievalImageFormat;

    if ([_textureFormat isEqualToString:WW_TEXTURE_PVRTC_4BPP])
    {
        formatSuffix = @"pvr";
    }
    if ([_textureFormat isEqualToString:WW_TEXTURE_RGBA_5551])
    {
        formatSuffix = @"5551";
    }
    if ([_textureFormat isEqualToString:WW_TEXTURE_RGBA_8888])
    {
        formatSuffix = @"8888";
    }

    NSString* imagePath = [NSString stringWithFormat:@"%@/%d/%d/%d_%d.%@",
                                                     _cachePath, [level levelNumber], row, row, column, formatSuffix];

    return [[WWTextureTile alloc] initWithSector:sector level:level row:row column:column imagePath:imagePath];
}

- (WWTile*) createTile:(WWTileKey*)key
{
    WWLevel* level = [levels level:[key levelNumber]];
    int row = [key row];
    int column = [key column];

    WWSector* sector = [WWTile computeSector:level row:row column:column];

    return [self createTile:sector level:level row:row column:column];
}

//--------------------------------------------------------------------------------------------------------------------//
//-- Bulk Retrieval --//
//--------------------------------------------------------------------------------------------------------------------//

#define BULK_RETRIEVER_SIMULTANEOUS_TILES 8
#define BULK_RETRIEVER_SLEEP_INTERVAL 0.1

- (double) dataSizeForSectors:(NSArray*)sectors targetResolution:(double)targetResolution
{
    if (sectors == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Sectors is nil")
    }

    int lastLevel = [[levels levelForTexelSize:targetResolution] levelNumber];

    NSUInteger tileCount = 0;
    for (WWSector* sector in sectors)
    {
        tileCount += [levels tileCountForSector:sector lastLevel:lastLevel];
    }

    double tw = [levels tileWidth];
    double th = [levels tileHeight];
    return tileCount * tw * th * 2.0 / 1.0e6; // assumes 2-bytes per pixel
}

- (void) performBulkRetrieval:(WWBulkRetriever*)retriever
{
    if (retriever == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Retriever is nil")
    }

    int lastLevel = [[levels levelForTexelSize:[retriever targetResolution]] levelNumber];
    NSUInteger simultaneousTileCount = BULK_RETRIEVER_SIMULTANEOUS_TILES;
    NSUInteger completedTileCount = 0;

    NSMutableArray* tiles = [[NSMutableArray alloc] initWithCapacity:simultaneousTileCount];
    NSMutableArray* completedTiles = [[NSMutableArray alloc] initWithCapacity:simultaneousTileCount];

    NSUInteger tileCount = 0;
    for (WWSector* sector in [retriever sectors])
    {
        tileCount += [levels tileCountForSector:sector lastLevel:lastLevel];
    }

    for (WWSector* sector in [retriever sectors])
    {
        NSEnumerator* tileEnumerator = [levels tileEnumeratorForSector:sector lastLevel:lastLevel];

        do
        {
            @autoreleasepool
            {
                for (WWTile* tile in tiles)
                {
                    if ([self retrieveTileImage:(WWTextureTile*) tile] != nil) // tile absent or local
                    {
                        [self bulkRetriever:retriever tilesCompleted:++completedTileCount tileCount:tileCount];
                        [completedTiles addObject:tile];
                    }
                }

                [tiles removeObjectsInArray:completedTiles];
                [completedTiles removeAllObjects];

                while ([tiles count] < simultaneousTileCount && ![retriever mustStopBulkRetrieval])
                {
                    @autoreleasepool
                    {
                        id nextObject = [tileEnumerator nextObject];
                        if (nextObject == nil)
                        {
                            break;
                        }

                        WWTile* nextTile = [self createTile:(WWTileKey*) nextObject];
                        if ([self retrieveTileImage:(WWTextureTile*) nextTile] != nil) // tile absent or local
                        {
                            [self bulkRetriever:retriever tilesCompleted:++completedTileCount tileCount:tileCount];
                        }
                        else
                        {
                            [tiles addObject:nextTile];
                        }
                    }
                }
            }

            [NSThread sleepForTimeInterval:BULK_RETRIEVER_SLEEP_INTERVAL];
        }
        while ([tiles count] > 0 && ![retriever mustStopBulkRetrieval]);
    }
}

- (void) bulkRetriever:(WWBulkRetriever*)retriever tilesCompleted:(NSUInteger)completed tileCount:(NSUInteger)count
{
    float progress = WWCLAMP((float) completed / (float) count, 0, 1);
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [retriever setProgress:progress];
    });
}

//--------------------------------------------------------------------------------------------------------------------//
//-- Methods of Interest Only to Subclasses --//
//--------------------------------------------------------------------------------------------------------------------//

- (void) doRender:(WWDrawContext*)dc
{
    if ([dc surfaceGeometry] == nil)
        return;

    if (_expiration != nil && [_expiration timeIntervalSinceNow] <= 0)
        _currentTilesInvalid = YES;

    // See if we can reuse the previous set of tiles. We can if the modelview-projection matrix, which governs the
    // frustum, is the same as when we last generated the set.
    if ([self currentTilesInvalid] || lasTtMVP == nil || ![[[dc navigatorState] modelviewProjection] isEqual:lasTtMVP])
    {
        [self assembleTiles:dc];
        [self setCurrentTilesInvalid:NO];
    }
    lasTtMVP = [[dc navigatorState] modelviewProjection];

    if ([currentTiles count] > 0)
    {
        [[dc surfaceTileRenderer] renderTiles:dc surfaceTiles:currentTiles opacity:[self opacity]];
        [[dc frameStatistics] incrementImageTileCount:[currentTiles count]];
    }
}

- (BOOL) isLayerInView:(WWDrawContext*)dc
{
    WWSector* visibleSector = [dc visibleSector];

    return visibleSector == nil || [visibleSector intersects:[levels sector]];
}

- (void) createTopLevelTiles
{
    [topLevelTiles removeAllObjects];

    [WWTile createTilesForLevel:[levels firstLevel]
                    tileFactory:self
                       tilesOut:topLevelTiles];
}

- (void) assembleTiles:(WWDrawContext*)dc
{
    [currentTiles removeAllObjects];

    if ([topLevelTiles count] == 0)
    {
        [self createTopLevelTiles];
    }

    for (WWTextureTile* tile in topLevelTiles)
    {
        [tile update:dc];

        currentAncestorTile = nil;

        if ([self isTileVisible:dc tile:tile])
        {
            [self addTileOrDescendants:dc tile:tile];
        }
    }
}

- (void) addTileOrDescendants:(WWDrawContext*)dc tile:(WWTextureTile*)tile
{
    if ([self tileMeetsRenderCriteria:dc tile:tile])
    {
        [self addTile:dc tile:tile];
        return;
    }

    WWTextureTile* ancestorTile = nil;

    @try
    {
        if ([self isTileTextureInMemory:dc tile:tile] || [[tile level] levelNumber] == 0)
        {
            ancestorTile = currentAncestorTile;
            currentAncestorTile = tile;
        }

        WWLevel* nextLevel = [levels level:[[tile level] levelNumber] + 1];
        NSArray* subTiles = [tile subdivide:nextLevel cache:tileCache tileFactory:self];
        for (WWTile* child in subTiles)
        {
            [child update:dc];

            if ([[levels sector] intersects:[child sector]]
                    && [self isTileVisible:dc tile:(WWTextureTile*) child])
            {
                [self addTileOrDescendants:dc tile:(WWTextureTile*) child];
            }
        }
    }
    @finally
    {
        if (ancestorTile != nil)
        {
            currentAncestorTile = ancestorTile;
        }
    }
}

- (void) addTile:(WWDrawContext*)dc tile:(WWTextureTile*)tile
{
    [tile setFallbackTile:nil];

    WWTexture* texture = (WWTexture*) [[dc gpuResourceCache] resourceForKey:[tile imagePath]];
    if (texture != nil)
    {
        [currentTiles addObject:tile];

        // If the tile's texture has expired, cause it to be re-retrieved. Note that the current,
        // expired texture is still used until the updated one arrives.
        if (_expiration != nil && [self isTextureExpired:texture])
        {
            [self loadOrRetrieveTileImage:dc tile:tile];
        }

        return;
    }

    [self loadOrRetrieveTileImage:dc tile:tile];

    if (currentAncestorTile != nil)
    {
        if ([self isTileTextureInMemory:dc tile:currentAncestorTile])
        {
            [tile setFallbackTile:currentAncestorTile];
            [currentTiles addObject:tile];
        }
        else if ([[currentAncestorTile level] levelNumber] == 0)
        {
            [self loadOrRetrieveTileImage:dc tile:currentAncestorTile];
        }
    }
}

- (BOOL) isTileVisible:(WWDrawContext*)dc tile:(WWTextureTile*)tile
{
    WWSector* visibleSector = [dc visibleSector];

    if (visibleSector != nil && ![visibleSector intersects:[tile sector]])
        return NO;

    return [[tile extent] intersects:[[dc navigatorState] frustumInModelCoordinates]];
}

- (BOOL) tileMeetsRenderCriteria:(WWDrawContext*)dc tile:(WWTextureTile*)tile
{
    return [levels isLastLevel:[[tile level] levelNumber]]
            || ![tile mustSubdivide:dc detailFactor:(detailHintOrigin + _detailHint)];
}

- (BOOL) isTileTextureInMemory:(WWDrawContext*)dc tile:(WWTextureTile*)tile
{
    return [dc.gpuResourceCache containsKey:[tile imagePath]];
}

- (BOOL) isTileTextureOnDisk:(WWTextureTile*)tile
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[tile imagePath]];
}

- (BOOL) isTextureExpired:(WWTexture*)texture
{
    if (_expiration == nil || [_expiration timeIntervalSinceNow] > 0)
    {
        return NO; // no expiration time or it's in the future
    }

    return [[texture fileModificationDate] timeIntervalSinceDate:_expiration] < 0;
}

- (BOOL) isTextureOnDiskExpired:(WWTextureTile*)tile
{
    if (_expiration != nil)
    {
        // Determine whether the disk image has expired.
        NSDictionary* fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:[tile imagePath] error:nil];
        NSDate* fileDate = [fileAttrs objectForKey:NSFileModificationDate];
        return [fileDate timeIntervalSinceDate:_expiration] < 0;
    }

    return NO;
}

- (void) loadOrRetrieveTileImage:(WWDrawContext*)dc tile:(WWTextureTile*)tile
{
    // See if it's already on disk.
    if ([self isTileTextureOnDisk:tile])
    {
        if ([self isTextureOnDiskExpired:tile])
        {
            [self retrieveTileImage:tile]; // Existing image file is out of date, so initiate retrieval of an up-to-date one.

            if ([self isTileTextureInMemory:dc tile:tile])
            {
                return; // Out-of-date tile is in memory so don't load the old image file again.
            }
        }

        // Load the existing image file whether it's out of date or not. This has the effect of showing expired
        // images until new ones arrive.
        [self loadTileImage:dc tile:tile];
    }
    else
    {
        [self retrieveTileImage:tile];
    }
}

- (void) loadTileImage:(WWDrawContext*)dc tile:(WWTextureTile*)tile
{
    @synchronized (currentLoads)
    {
        if ([currentLoads containsObject:[tile imagePath]])
        {
            return;
        }

        [currentLoads addObject:[tile imagePath]];
    }

    WWTexture* texture = [[WWTexture alloc] initWithImagePath:[tile imagePath]
                                                        cache:[dc gpuResourceCache]
                                                       object:self];
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
//            ^
//            {
//                [texture start];
//            });
    [texture setThreadPriority:0.1];
    [[WorldWind loadQueue] addOperation:texture];
}

- (NSString*) retrieveTileImage:(WWTextureTile*)tile
{
    // If the app is connected to the network, retrieve the image from there.

    if ([WorldWind isOfflineMode])
    {
        return nil; // don't know the tile's status in offline mode
    }

    NSString* pathKey = [WWUtil replaceSuffixInPath:[tile imagePath] newSuffix:nil];
    if ([absentResources isResourceAbsent:pathKey])
    {
        return WW_ABSENT;
    }

    @synchronized (currentRetrievals)
    {
        // Synchronize checking for the file on disk with adding the tile to currentRetrievals. This avoids unnecessary
        // retrievals initiated when a retrieval completes between the time this thread checks for the file on disk and
        // checks the currentRetrievals list.

        if ([self isTileTextureOnDisk:tile] && ![self isTextureOnDiskExpired:tile])
        {
            return WW_LOCAL;
        }
        else if ([currentRetrievals containsObject:pathKey])
        {
            return nil; // don't know the tile's status until retrieval completes
        }

        [currentRetrievals addObject:pathKey];
    }

    NSURL* url = [self resourceUrlForTile:tile imageFormat:_retrievalImageFormat];

    WWRetrieverToFile* retriever;
    if ([_textureFormat isEqualToString:WW_TEXTURE_PVRTC_4BPP]
            || [_textureFormat isEqualToString:WW_TEXTURE_RGBA_5551]
            || [_textureFormat isEqualToString:WW_TEXTURE_RGBA_8888])
    {
        // Download to a file with the download format suffix. The image will be decoded and possibly compressed when
        // the notification of download success is received in handleNotification above.
        NSString* suffix = [WWUtil suffixForMimeType:_retrievalImageFormat];
        NSString* filePath = [WWUtil replaceSuffixInPath:[tile imagePath] newSuffix:suffix];
        retriever = [[WWRetrieverToFile alloc] initWithUrl:url filePath:filePath object:self timeout:_timeout];
    }
    else
    {
        retriever = [[WWRetrieverToFile alloc] initWithUrl:url filePath:[tile imagePath] object:self timeout:_timeout];
    }

//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
//            ^
//            {
//                [retriever performRetrieval];
//            });

    [retriever setThreadPriority:0.0];
    [[WorldWind retrievalQueue] addOperation:retriever];

    return nil; // don't know the tile's status until retrieval completes
}

- (NSURL*) resourceUrlForTile:(WWTile*)tile imageFormat:(NSString*)imageFormat
{
    if (tile == nil)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Tile is nil")
    }

    if (imageFormat == nil || [imageFormat length] == 0)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"Image format is nil or empty")
    }

    if (_urlBuilder == nil)
    {
        WWLOG_AND_THROW(NSInternalInconsistencyException, @"URL builder is nil")
    }

    return [_urlBuilder urlForTile:tile imageFormat:imageFormat];
}

- (void) handleTextureLoadNotification:(NSNotification*)notification
{
    NSDictionary* avList = [notification userInfo];
    NSString* retrievalStatus = [avList valueForKey:WW_REQUEST_STATUS];
    NSString* imagePath = [avList valueForKey:WW_FILE_PATH];

    @try
    {
        if ([retrievalStatus isEqualToString:WW_SUCCEEDED])
        {
            [self setCurrentTilesInvalid:YES];
            NSNotification* redrawNotification = [NSNotification notificationWithName:WW_REQUEST_REDRAW object:self];
            [[NSNotificationCenter defaultCenter] postNotification:redrawNotification];
        }
    }
    @finally
    {
        @synchronized (currentLoads)
        {
            [currentLoads removeObject:imagePath];
        }
    }
}

- (void) handleTextureRetrievalNotification:(NSNotification*)notification
{
    NSDictionary* avList = [notification userInfo];
    NSString* retrievalStatus = [avList valueForKey:WW_RETRIEVAL_STATUS];
    NSString* imagePath = [avList valueForKey:WW_FILE_PATH];
    NSString* pathKey = [WWUtil replaceSuffixInPath:imagePath newSuffix:nil];
    NSNumber* responseCode = [avList valueForKey:WW_RESPONSE_CODE];
    NSURL* url = [avList objectForKey:WW_URL];

    // Check the response code.
    if (responseCode == nil || [responseCode intValue] != 200)
    {
        WWLog(@"Unexpected response code %@ retrieving %@",
        responseCode != nil ? [responseCode stringValue] : @"(no response code)", [url absoluteString]);

        [absentResources markResourceAbsent:pathKey];
        [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
        [currentRetrievals removeObject:pathKey];
        return;
    }

    // Check to see that the mime type returned is the same as the one requested. When these are inconsistent it
    // usually means that the request failed and the server returned an exception message in either HTML or XML.
    NSString* mimeType = [avList objectForKey:WW_MIME_TYPE];
    if (mimeType == nil || [mimeType caseInsensitiveCompare:_retrievalImageFormat] != NSOrderedSame)
    {
        // Any exception message would have been written to the output file. Read and show the message.
        NSError* error = nil;
        NSString* msg = [[NSString alloc] initWithContentsOfFile:imagePath
                                                        encoding:NSUTF8StringEncoding
                                                           error:&error];
        WWLog(@"Unexpeted mime type %@ for request %@: %@",
        mimeType != nil ? mimeType : @"(no mime type in response)", [url absoluteString], error == nil ? msg : @"");

        [absentResources markResourceAbsent:pathKey];
        [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
        [currentRetrievals removeObject:pathKey];
        return;
    }

    @try
    {
        if ([retrievalStatus isEqualToString:WW_SUCCEEDED])
        {
            if ([_textureFormat isEqualToString:WW_TEXTURE_PVRTC_4BPP])
            {
                [WWPVRTCImage compressFile:imagePath];
                [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
            }
            else if ([_textureFormat isEqualToString:WW_TEXTURE_RGBA_8888])
            {
                [WWTexture convertTextureTo8888:imagePath];
                [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
            }
            else if ([_textureFormat isEqualToString:WW_TEXTURE_RGBA_5551])
            {
                [WWTexture convertTextureTo5551:imagePath];
                [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
            }

            [self setCurrentTilesInvalid:YES];
            [absentResources unmarkResourceAbsent:pathKey];

            NSNotification* redrawNotification = [NSNotification notificationWithName:WW_REQUEST_REDRAW object:self];
            [[NSNotificationCenter defaultCenter] postNotification:redrawNotification];
        }
        else
        {
            [absentResources markResourceAbsent:pathKey];
        }
    }
    @catch (NSException* exception)
    {
        [absentResources markResourceAbsent:pathKey];
        [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];

        NSString* msg = [NSString stringWithFormat:@"loading texture data for file %@", imagePath];
        WWLogE(msg, exception);
    }
    @finally
    {
        @synchronized (currentRetrievals)
        {
            [currentRetrievals removeObject:pathKey];
        }
    }
}

@end