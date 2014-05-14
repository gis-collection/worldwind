/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <Foundation/Foundation.h>
#import "WWRenderableLayer.h"

@interface METARLayer : WWRenderableLayer <NSXMLParserDelegate>

@property (atomic) NSNumber* refreshInProgress;

- (METARLayer*) init;

@end