/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <Foundation/Foundation.h>

@class UIImage;

/**
* Provides a collection of utility methods.
*/
@interface WWUtil : NSObject

// /// @name I/O and Caching
//
///**
//* Retrieves the data designated by a URL and saves it in a local file.
//*
//* @param url The URL from which to retrieve the data.
//* @param filePath The full path of the file in which to save the data. The directories in the path need not exist,
//* they will be created.
//* @param timeout The number of seconds to wait for a connection to the specified URL.
//*
//* @return YES if the operation was successful, otherwise NO. A log message is written if the operation is
//* unsuccessful.
//*
//* @exception NSInvalidArgumentException if the url or file path are nil or the file path is empty.
//*/
//+ (BOOL) retrieveUrl:(NSURL*)url toFile:(NSString*)filePath timeout:(NSTimeInterval)timeout;
//
///**
//* Retrieves the data designated by a URL and returns it.
//*
//* @param url The URL from which to retrieve the data.
//* @param timeout The number of seconds to wait for a connection to the specified URL.
//*
//* @return The retrieved data if the operation was successful, otherwise nil. A log message is written if the
//* operation is unsuccessful.
//*
//* @exception NSInvalidArgumentException if the url is nil.
//*/
//+ (NSData*) retrieveUrl:(NSURL*)url timeout:(NSTimeInterval)timeout;

/// @name Utilities

/**
* Generate a unique string.
*
* @return A unique string.
*/
+ (NSString*) generateUUID;

/**
* Returns the suffix for a specified mime type.
*
* @param mimeType The mime type, e.g. _image/png_.
*
* @return The suffix for the mime type, including the ".", e.g. _.png_, or nil if the mime type is not recognized.
*/
+ (NSString*) suffixForMimeType:(NSString*)mimeType;

/**
* Replaces the existing suffix of a file name with a new one.
*
* The right-most component after the final "." in the string is replaced. If there is no suffix, the new one is
* appended to the original string.
*
* @param path The path containing the original suffix. The right-most component after the final "." in the string is
* @param newSuffix The suffix to replace the original with. Do not specify the "."; it's implicit. If nil,
* the existing suffix,
 * if any, is stripped, including the ".", and the resulting string is returned.
*
* @return A new string with the original suffix replaced with the new one.
*/
+ (NSString*) replaceSuffixInPath:(NSString*)path newSuffix:(NSString*)newSuffix;

/**
* Replaces all characters not allowed in file names with "_".
*
* @param path The path to modify.
*
* @return The modified path.
*
* @exception NSInvalidArgumentException If the specified path is nil.
*/
+ (NSString*) makeValidFilePath:(NSString*)path;

+ (UIImage*) convertPDFToUIImage:(NSURL*)pdfURL;

@end