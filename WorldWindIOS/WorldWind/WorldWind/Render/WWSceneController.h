/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>

@class WWDrawContext;
@class WWFrameStatistics;
@class WWGlobe;
@class WWGpuResourceCache;
@class WWLayerList;
@class WWPickedObjectList;
@class WWVec4;
@protocol WWNavigatorState;

/**
* Directs the rendering of the globe and associated layers. The scene controller causes the globe's terrain to be
* generated and the layer list to be traversed and the layers drawn in their listed order. The scene controller
* resets the draw context prior to each frame and otherwise manages the draw context. (The draw context maintains
* rendering state. See WWDrawContext.)
*/
@interface WWSceneController : NSObject
{
@protected
    WWDrawContext* drawContext;
}

/// @name Scene Controller Attributes

/// The globe to display.
@property(readonly, nonatomic) WWGlobe* globe;
/// The layers to display. Layers are displayed in the order given in the layer list.
@property(readonly, nonatomic) WWLayerList* layers;
/// The current navigator state defining the current viewing state.
@property(nonatomic) id <WWNavigatorState> navigatorState;
/// The GPU resource cache in which to hold and manage all OpenGL resources.
@property(readonly, nonatomic) WWGpuResourceCache* gpuResourceCache;
/// The frame statistics associated with the most recent frame.
@property(nonatomic) WWFrameStatistics* frameStatistics;

/// @name Initializing a Scene Controller

/**
* Initialize the scene controller.
*
* This method allocates and initializes a globe and a layer list and attaches them to this scene controller. It also
* allocates and initializes a GPU resource cache and a draw context.
*
* @return This instance initialized to default values.
*/
- (WWSceneController*) init;

/// @name Initiating Rendering

/**
* Causes the scene controller to render a frame using the current state of its associate globe and layer list.
*
* The viewport is understood to be in the OpenGL screen coordinate system of the WorldWindView, with its origin in the
* bottom-left corner and axes that extend up and to the right from the origin point.
*
* An OpenGL context must be current when this method is called.
*
* @param viewport The viewport in which to draw the globe, in OpenGL screen coordinates.
*/
- (void) render:(CGRect)viewport;

/// @name Operations on Scene Controller

/**
* Release resources currently held by the scene controller.
*
* This scene controller may still be used subsequently.
*/
- (void) dispose;

/// @name Supporting Methods of Interest Only to Subclasses

/**
* Reset the draw context to its default values.
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*/
- (void) resetDrawContext;

/**
* Top-level method called by render to generate the frame.
*
* The viewport is understood to be in the OpenGL screen coordinate system of the WorldWindView, with its origin in the
* bottom-left corner and axes that extend up and to the right from the origin point.
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*
* @param viewport The viewport in which to draw the globe, in OpenGL screen coordinates.
*/
- (void) drawFrame:(CGRect)viewport;

/**
* Establishes default OpenGL state for rendering the frame.
*
* The viewport is understood to be in the OpenGL screen coordinate system of the WorldWindView, with its origin in the
* bottom-left corner and axes that extend up and to the right from the origin point.
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*
* @param viewport The viewport in which to draw the globe, in OpenGL screen coordinates.
*/
- (void) beginFrame:(CGRect)viewport;

/**
* Resets OpenGL state to OpenGL defaults after the frame is generated.
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*/
- (void) endFrame;

/**
* Invokes glClear to clear the frame buffer and depth buffer.
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*/
- (void) clearFrame;

/**
* Causes the globe to create the terrain visible with the current viewing state.
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*/
- (void) createTerrain;

/**
* Renders the layer list and the list of ordered renderables.
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*/
- (void) doDraw;

/**
* Low-level method to traverse the layer list and call each layer's render method.
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*/
- (void) drawLayers;

/**
* Traverses the list of ordered renderables and calls their render method.
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*/
- (void) drawOrderedRenderables;

/**
* Performs a pick of the current model. Traverses the terrain to determine the geographic position at the specified
* pick point, and traverses pickable shapes to determine which intersect the pick point.
*
* The viewport is understood to be in the OpenGL screen coordinate system of the WorldWindView, with its origin in the
* bottom-left corner and axes that extend up and to the right from the origin point.
*
* The pick point is understood to be in the UIKit coordinate system of the WorldWindView, with its origin in the
* top-left corner and axes that extend down and to the right from the origin point. See the section titled View Geometry
* and Coordinate Systems in the [View Programming Guide for iOS](http://developer.apple.com/library/ios/#documentation/WindowsViews/Conceptual/ViewPG_iPhoneOS/WindowsandViews/WindowsandViews.html).
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*
* @param viewport The viewport in which to perform the pick, in OpenGL screen coordinates.
* @param pickPoint The point to test for pickable items, in UIKit coordinates.
*
* @return A list of picked items, which is empty if no items are at the specified pick point.
*/
- (WWPickedObjectList*) pick:(CGRect)viewport pickPoint:(CGPoint)pickPoint;

/**
* Performs a pick of the globe's current terrain. Traverses the terrain to determine the geographic position at the
* specified pick point but ignores pickable shapes.
*
* The viewport is understood to be in the OpenGL screen coordinate system of the WorldWindView, with its origin in the
* bottom-left corner and axes that extend up and to the right from the origin point.
*
* The pick point is understood to be in the UIKit coordinate system of the WorldWindView, with its origin in the
* top-left corner and axes that extend down and to the right from the origin point. See the section titled View Geometry
* and Coordinate Systems in the [View Programming Guide for iOS](http://developer.apple.com/library/ios/#documentation/WindowsViews/Conceptual/ViewPG_iPhoneOS/WindowsandViews/WindowsandViews.html).
*
* This method is not meant to be called by applications. It is called internally as needed. Subclasses may override
* this method to implement alternate or additional behavior.
*
* @param viewport The viewport in which to perform the pick, in OpenGL screen coordinates.
* @param pickPoint The point to test against the globe's current terrain, in UIKit coordinates.
*
* @return A list containing the picked terrain item, or an empty list if the terrain does not intersect the
* specified pick point.
*/
- (WWPickedObjectList*) pickTerrain:(CGRect)viewport pickPoint:(CGPoint)pickPoint;

@end