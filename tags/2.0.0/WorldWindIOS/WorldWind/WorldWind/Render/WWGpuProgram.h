/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>
#import "WorldWind/Util/WWCacheable.h"
#import "WorldWind/Util/WWDisposable.h"

@class WWGpuShader;
@class WWMatrix;
@class WWColor;

/**
* Represents an OpenGL shading language (GLSL) shader program and provides methods for identifying and accessing shader
* variables. Shader programs are created by instances of this class and made current when the instance's bind
* method is invoked.
*/
@interface WWGpuProgram : NSObject <WWCacheable, WWDisposable>
{
@protected
    WWGpuShader* vertexShader;
    WWGpuShader* fragmentShader;
    NSMutableDictionary* attributeLocations;
    NSMutableDictionary* uniformLocations;
}

/// @name GPU Program Attributes

/// The OpenGL program ID of this shader.
@property(readonly, nonatomic) GLuint programId;

/// @name Initializing GPU Programs

/**
* Initializes a GPU program with specified source code for vertex and fragment shaders.
*
* An OpenGL context must be current when this method is called.
*
* This method creates OpenGL shaders for the specified shader sources and attaches them to a new GLSL program. The
* method compiles the shaders and links the program if compilation is successful. Use the bind method to make the
* program current during rendering.
*
* @param vertexSource A null-terminated string containing the source code for the vertex shader.
* @param fragmentSource A null-terminated string containing the source code for the fragment shader.
*
* @return This GPU program linked with the specified shaders.
*
* @exception NSInvalidArgumentException If either shader source is nil or empty, the shaders cannot be compiled, or
* linking of the compiled shaders into a program fails.
*/
- (WWGpuProgram*) initWithShaderSource:(const char*)vertexSource fragmentShader:(const char*)fragmentSource;

/// @name Operations on GPU Programs

/**
* Makes this GPU program the current program in the current OpenGL context.
*
* An OpenGL context must be current when this method is called.
*/
- (void) bind;

/**
* Releases this GPU program's OpenGL program and associated shaders. Upon return this GPU program's OpenGL program ID
 * is 0 as is that of its associated shaders.
 *
 * An OpenGL context must be current when this method is called.
*/
- (void) dispose;

/// @name Accessing Vertex Attributes

/**
* Returns the GLSL attribute location of a specified attribute name.
*
* An OpenGL context must be current when this method is called.
*
* @param attributeName The name of the attribute whose location is determined.
*
* @return The OpenGL attribute location of the specified attribute, or -1 if the attribute is not found.
*
* @exception NSInvalidArgumentException If the specified name is nil or empty.
*/
- (int) attributeLocation:(NSString*)attributeName;

/// @name Accessing Uniform Variables

/**
* Returns the GLSL uniform variable location of a specified uniform name.
*
* An OpenGL context must be current when this method is called.
*
* @param uniformName The name of the uniform variable whose location is determined.
*
* @return The OpenGL location of the specified uniform variable, or -1 if the name is not found.
*
* @exception NSInvalidArgumentException If the specified name is nil or empty.
*/
- (int) uniformLocation:(NSString*)uniformName;

/**
* Loads the specified matrix as the value of a GLSL 4x4 matrix uniform variable with the specified location index.
*
* An OpenGL context must be current when this method is called, and an OpenGL program must be bound. The result of this
* method is undefined if there is no current OpenGL context or no current program.
*
* This converts the matrix into column-major order prior to loading its components into the GLSL uniform variable, but
* does not modify the specified matrix.
*
* @param matrix The matrix to set the uniform variable to.
* @param location The location index of the uniform variable in the currently bound OpenGL program.
*
* @exception NSInvalidArgumentException If the matrix is nil.
*/
+ (void) loadUniformMatrix:(WWMatrix*)matrix location:(GLuint)location;

/**
* Loads the specified color as the value of a GLSL vec4 uniform variable with the specified location index.
*
* An OpenGL context must be current when this method is called, and an OpenGL program must be bound. The result of this
* method is undefined if there is no current OpenGL context or no current program.
*
* This multiplies the red, green and blue components by the alpha component prior to loading the color in the GLSL
* uniform variable, but does not modify the specified color.
*
* @param color The color to set the uniform variable to.
* @param location The location index of the uniform variable in the currently bound OpenGL program.
*
* @exception NSInvalidArgumentException If the color is nil.
*/
+ (void) loadUniformColor:(WWColor*)color location:(GLuint)location;

/**
* Loads the specified pick color as the value of a GLSL vec4 uniform variable with the specified location index.
*
* An OpenGL context must be current when this method is called, and an OpenGL program must be bound. The result of this
* method is undefined if there is no current OpenGL context or no current program.
*
* This converts the color from a packed 32-bit integer representation in the range [0,255] to a floating-point
* representation in the range [0,1]. The red, green, blue and alpha components are otherwise loaded in the GLSL uniform
* variable without modification.
*
* @param color The color to set the uniform variable to.
* @param location The location index of the uniform variable in the currently bound OpenGL program.
*/
+ (void) loadUniformPickColor:(unsigned int)color location:(GLuint)location;

/**
* Loads the specified float value to a specified uniform location.
*
* @param value The value to pass to the shaders.
* @param location The uniform location to pass the value to.
*/
+ (void) loadUniformFloat:(float)value location:(GLuint)location;

/// @name Supporting Methods

/**
* Links the specified GLSL program.
*
* An OpenGL context must be current when this method is called.
*
* This method is not meant to be invoked by applications. It is invoked internally as needed.
*
* @param program The OpenGL program ID of the program to link.
*
* @return YES if linking was successful, otherwise NO.
*/
- (BOOL) link:(GLuint)program;

@end