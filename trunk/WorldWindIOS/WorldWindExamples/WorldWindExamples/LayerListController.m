/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import "LayerListController.h"
#import "WorldWind/WorldWindView.h"
#import "WorldWind/Render/WWSceneController.h"
#import "WorldWind/Layer/WWLayerList.h"
#import "WorldWind/Layer/WWLayer.h"

@implementation LayerListController

- (LayerListController*) initWithWorldWindView:(WorldWindView*)wwv
{
    self = [super initWithStyle:UITableViewStylePlain];

    _wwv = wwv;

    [[self navigationItem] setRightBarButtonItem:[self editButtonItem]];
    [[self navigationItem] setTitle:@"Layers"];

    return self;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView*)tableView
{
    return 1;
}

- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[_wwv sceneController] layers] count];
}

- (void) tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
    // Set the selected layer's visibility.

    WWLayer* layer = [[[_wwv sceneController] layers] layerAtIndex:(NSUInteger) [indexPath row]];
    [layer setEnabled:[layer enabled] ? NO : YES];
    [[self tableView] reloadData];
    [_wwv drawView];
}

- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    static NSString* cellIdentifier = @"cell";

    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }

    WWLayer* layer = [[[_wwv sceneController] layers] layerAtIndex:(NSUInteger) [indexPath row]];
    [[cell textLabel] setText:[layer displayName]];
    [[cell imageView] setImage:[UIImage imageNamed:[layer imageFile]]];
    [cell setShowsReorderControl:YES];
    [cell setAccessoryType:[layer enabled] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone];

    return cell;
}

- (BOOL) tableView:(UITableView*)tableView canMoveRowAtIndexPath:(NSIndexPath*)indexPath
{
    return YES;
}

- (void) tableView:(UITableView*)tableView
moveRowAtIndexPath:(NSIndexPath*)sourceIndexPath
       toIndexPath:(NSIndexPath*)destinationIndexPath
{
    [[[_wwv sceneController] layers] moveLayerAtRow:[sourceIndexPath row] toRow:[destinationIndexPath row]];
}

- (void) tableView:(UITableView*)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
 forRowAtIndexPath:(NSIndexPath*)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        [[[_wwv sceneController] layers] removeLayerAtRow:[indexPath row]];

        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                         withRowAnimation:UITableViewRowAnimationFade];
    }
}

@end