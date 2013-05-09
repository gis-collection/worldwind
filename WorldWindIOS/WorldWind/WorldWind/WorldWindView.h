/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import "WorldWind/Util/WWDisposable.h"

@class WWSceneController;
@protocol WWNavigator;
@class WWPickedObjectList;
@class WWVec4;

@interface WorldWindView : UIView <WWDisposable>

@property (nonatomic, readonly) GLuint frameBuffer;
@property (nonatomic, readonly) GLuint colorBuffer;
@property (nonatomic, readonly) GLuint depthBuffer;
@property (nonatomic, readonly) GLuint pickingFrameBuffer;
@property (nonatomic, readonly) GLuint pickingColorBuffer;
@property (nonatomic, readonly) GLuint pickingDepthBuffer;
@property (nonatomic, readonly) CGRect viewport;
@property (nonatomic, readonly) EAGLContext* context;
@property (nonatomic, readonly) WWSceneController* sceneController;
@property (nonatomic) id<WWNavigator> navigator;
@property BOOL redrawRequested;

- (void) drawView;
- (void) tearDownGL;
- (void) handleNotification:(NSNotification*)notification;
- (WWPickedObjectList*) pick:(WWVec4*)pickPoint;

@end