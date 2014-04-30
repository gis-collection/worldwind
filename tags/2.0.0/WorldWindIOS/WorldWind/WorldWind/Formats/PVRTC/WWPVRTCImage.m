/*
 Copyright (C) 2013 United States Government as represented by the Administrator of the
 National Aeronautics and Space Administration. All Rights Reserved.
 
 @version $Id$
 */

#import <UIKit/UIKit.h>
#import "WorldWind/Formats/PVRTC/WWPVRTCImage.h"
#import "WorldWind/WWLog.h"
#import "WorldWind/Util/WWUtil.h"

@implementation WWPVRTCImage

- (WWPVRTCImage*) initWithContentsOfFile:(NSString*)filePath
{
    self = [super init];

    if (filePath == nil || [filePath length] == 0)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"File path is nil or zero length")
    }

    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        NSString* msg = [NSString stringWithFormat:@"File %@ does not exist", filePath];
        WWLOG_AND_THROW(NSInvalidArgumentException, msg);
    }

    // TODO: Throw an exception if the file is not a PVRTC image.

    _filePath = filePath;
    _imageBits = [[NSData alloc] initWithContentsOfFile:_filePath];

    if ([_imageBits length] == 0)
    {
        NSString* msg = [NSString stringWithFormat:@"Image file %@ is empty", _filePath];
        @throw WWEXCEPTION(NSInvalidArgumentException, msg);}

    [self readHeader];

    return self;
}

#ifdef DEBUG_PVR_ENCODE
void DebugPvrEncode();
#endif // DEBUG_PVR_ENCODE

+ (void) compressFile:(NSString*)filePath
{
    if (filePath == nil || [filePath length] == 0)
    {
        WWLOG_AND_THROW(NSInvalidArgumentException, @"File path is nil or zero length")
    }

    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        NSString* msg = [NSString stringWithFormat:@"File %@ does not exist", filePath];
        WWLOG_AND_THROW(NSInvalidArgumentException, msg);
    }

#ifdef DEBUG_PVR_ENCODE
    DebugPvrEncode();
#endif // DEBUG_PVR_ENCODE
    
    // Read the image as a UIImage, get its bits and pass them to the pvrtc compressor,
    // which writes the pvrtc image to a file of the same name and in the same location as the input file,
    // but with a .pvr extension.
    
    UIImage* uiImage = [UIImage imageWithContentsOfFile:filePath];
    if (uiImage == nil)
    {
        NSString* msg = [[NSString alloc] initWithFormat:@"Unable to load image file %@", filePath];
        WWLOG_AND_THROW(NSInvalidArgumentException, msg)
    }

    CGImageRef cgImage = [uiImage CGImage];

    int imageWidth = CGImageGetWidth(cgImage);
    int imageHeight = CGImageGetHeight(cgImage);
    if (imageWidth == 0 || imageHeight == 0)
    {
        NSString* msg = [[NSString alloc] initWithFormat:@"Image size is zero for file %@", filePath];
        WWLOG_AND_THROW(NSInvalidArgumentException, msg)
    }
    int textureSize = imageWidth * imageHeight * 4; // assume 4 bytes per pixel
    void* imageData = malloc((size_t) textureSize); // allocate space for the image

    CGContextRef context;
    @try
    {
        // Create a raw RGBA image from the incoming image. The raw bits will be compressed below.
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        context = CGBitmapContextCreate(imageData, (size_t) imageWidth, (size_t) imageHeight,
                8, (size_t) (4 * imageWidth), colorSpace, kCGImageAlphaPremultipliedLast);
        CGRect rect = CGRectMake(0, 0, imageWidth, imageHeight);
        CGContextClearRect(context, rect);
        CGContextDrawImage(context, rect, cgImage);

        // Compress the raw bits into PVRTC.
        NSString* outputPath = [WWUtil replaceSuffixInPath:filePath newSuffix:@"pvr"];
        [WWPVRTCImage doCompress:imageWidth height:imageHeight bits:imageData ouputPath:outputPath];
    }
    @finally
    {
        free(imageData); // release the memory allocated for the image
        CGContextRelease(context);
    }
}

#import <stdio.h>
#import <math.h>

typedef struct
{
    float r;
    float g;
    float b;
    float a;
} RawPixel;

typedef struct
{
    int width;      // actual width of image (>= 8)
    int height;     // actual height of image (>= 8)
    int widthBase;  // requested width of image
    int heightBase; // requested height of image
    void* bits;
} RawImage;

// Per PVRTC file format documentation at
// http://www.imgtec.com/powervr/insider/docs/PVR%20File%20Format.Specification.1.0.11.External.pdf
typedef struct
{
    uint32_t version;
    uint32_t flags;
    uint32_t pixel_format_lsb;
    uint32_t pixel_format_msb;
    uint32_t color_space;
    uint32_t channel_type;
    uint32_t height;
    uint32_t width;
    uint32_t depth;
    uint32_t num_surfaces;
    uint32_t num_faces;
    uint32_t num_mipmaps;
    uint32_t size_metadata;
} PVR_Header;

typedef struct {
    uint32_t    wts;
    uint16_t    rgbLo;
    uint16_t    rgbHi;
} PVR_Block;

#define PVR_VERSION 0x03525650
#define PVR_FORMAT_PVRTC_4_RGBA 3

// TODO: All the functions below need to be converted to class methods to limit the scope of their name. Small
// functions can get by with simply prefixing their name with WW.

RawImage* NewImage(int width, int height);

void FreeImage(RawImage* image);

int EncodePvrImage(RawImage* src, PVR_Block** pvrImage);

int EncodePvrMipmap(RawImage* src, PVR_Block*** pvrMipmap, int** blockCounts);

void WritePvrFile(PVR_Block** PVR_Blocks, int* blockCounts, int levelCount, int dx, int dy, const char* name);

+ (void) doCompress:(int)width height:(int)height bits:(void*)bits ouputPath:(NSString*)outputPath
{
    RawImage rawImage;

    rawImage.width = width;
    rawImage.height = height;
    rawImage.widthBase = width;
    rawImage.heightBase = height;
    rawImage.bits = bits;

    PVR_Block** pvrMipmap;
    int* blockSizes;
    int levels = EncodePvrMipmap(&rawImage, &pvrMipmap, &blockSizes);

    WritePvrFile(pvrMipmap, blockSizes, levels, width, height, [outputPath cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (void) readHeader
{
    PVR_Header* header = (PVR_Header*) [_imageBits bytes];

    _imageWidth = header->width;
    _imageHeight = header->height;
    _numLevels = header->num_mipmaps;
}

// Quick and dirty test for power of 2.
bool IsPow2(int n)
{
    if (n <= 0) return false;

    while (n > 1)
    {
        if (n & 1) return false;

        n >>= 1;
    }

    return true;
}

// Get a pixel from an image.
void GetPixel(RawImage* image, int x, int y, RawPixel* pixel)
{
    uint8_t* pix = ((uint8_t*) image->bits) + (image->width * y + x) * 4;

    pixel->r = (float) pix[0];
    pixel->g = (float) pix[1];
    pixel->b = (float) pix[2];
    // ignore alpha
}

// Set a pixel in an image.
void SetPixel(RawImage* image, int x, int y, RawPixel* pixel)
{
    uint8_t* pix = ((uint8_t*) image->bits) + (image->width * y + x) * 4;

    pix[0] = (uint8_t) (pixel->r + 0.5);
    pix[1] = (uint8_t) (pixel->g + 0.5);
    pix[2] = (uint8_t) (pixel->b + 0.5);
    // ignore alpha
}

// initialize a pixel color.
void InitPixel(RawPixel* pixel, float r, float g, float b)
{
    pixel->r = r;
    pixel->g = g;
    pixel->b = b;
    // ignore alpha
}

// Add two pixel colors.
void AddPixel(RawPixel* pixelDst, RawPixel* pixelSrc0, RawPixel* pixelSrc1)
{
    pixelDst->r = pixelSrc0->r + pixelSrc1->r;
    pixelDst->g = pixelSrc0->g + pixelSrc1->g;
    pixelDst->b = pixelSrc0->b + pixelSrc1->b;
    // ignore alpha
}

// Subtract two pixel colors.
void SubPixel(RawPixel* pixelDst, RawPixel* pixelSrc0, RawPixel* pixelSrc1)
{
    pixelDst->r = pixelSrc0->r - pixelSrc1->r;
    pixelDst->g = pixelSrc0->g - pixelSrc1->g;
    pixelDst->b = pixelSrc0->b - pixelSrc1->b;
    // ignore alpha
}

// Compute the difference between two pixels and rescale to fit into a byte pixel.
void DeltaPixel(RawPixel* pixelDst, RawPixel* pixelSrc0, RawPixel* pixelSrc1)
{
    pixelDst->r = 0.5 * (pixelSrc0->r - pixelSrc1->r) + 128.0;
    pixelDst->g = 0.5 * (pixelSrc0->g - pixelSrc1->g) + 128.0;
    pixelDst->b = 0.5 * (pixelSrc0->b - pixelSrc1->b) + 128.0;
    // ignore alpha
}

// Scale a pixel color.
void ScalePixel(RawPixel* pixelDst, RawPixel* pixelSrc, float scale)
{
    pixelDst->r = pixelSrc->r * scale;
    pixelDst->g = pixelSrc->g * scale;
    pixelDst->b = pixelSrc->b * scale;
    // ignore alpha
}

// Interpolate a pixel color.
void LerpPixel(RawPixel* pixelDst, RawPixel* pixelSrc0, RawPixel* pixelSrc1, float wt0, float wt1)
{
    RawPixel pixTmp0;
    ScalePixel(&pixTmp0, pixelSrc0, wt0);

    RawPixel pixTmp1;
    ScalePixel(&pixTmp1, pixelSrc1, wt1);

    AddPixel(pixelDst, &pixTmp0, &pixTmp1);
}

// Compute the dot product of pixel components.
float DotPixel(RawPixel* pixel0, RawPixel* pixel1)
{
    // Ignore alpha.
    return pixel0->r * pixel1->r + pixel0->g * pixel1->g + pixel0->b * pixel1->b;
}

// Limit value to bounds.
float Clamp(float value, float min, float max)
{
    if (value < min)
        return min;

    if (value > max)
        return max;

    return value;
}

// Prevent pixel under/overflow.
void ClampPixel(RawPixel* pixelDst, RawPixel* pixelSrc)
{
    pixelDst->r = Clamp(pixelSrc->r, 0, 255);
    pixelDst->g = Clamp(pixelSrc->g, 0, 255);
    pixelDst->b = Clamp(pixelSrc->b, 0, 255);
    // Ignore alpha.
}

// Principal compoment analysis based on:
// http://en.wikipedia.org/wiki/Principal_component_analysis
void PCAPixel(RawPixel* pixelDst, RawPixel* pixelsSrc, int cpixels)
{
    float root3 = (float) 0.577350269189623;
    InitPixel(pixelDst, root3, root3, root3);

    for (int iter = 0; iter < 8; ++iter)
    {
        RawPixel pixelAccum;
        InitPixel(&pixelAccum, 0.0, 0.0, 0.0);

        for (int ipixel = 0; ipixel < cpixels; ++ipixel)
        {
            RawPixel* pixelCur = &pixelsSrc[ipixel];
            float dot = DotPixel(pixelDst, pixelCur);
            pixelAccum.r += dot * pixelCur->r;
            pixelAccum.g += dot * pixelCur->g;
            pixelAccum.b += dot * pixelCur->b;
        }

        // Normalize axis vector.
        float mag2 = DotPixel(&pixelAccum, &pixelAccum);
        float mag = sqrtf(mag2);
        if (mag > 0.0)
        {
            pixelDst->r = pixelAccum.r / mag;
            pixelDst->g = pixelAccum.g / mag;
            pixelDst->b = pixelAccum.b / mag;
            // Ignore alpha.
        }
        else
            return;
    }
}

// Gather neighboring pixels into an array.
void NeighborhoodPixels(RawImage* image, int xCenter, int yCenter, RawPixel* pixels)
{
    for (int yCur = yCenter - 2; yCur < yCenter + 2; ++yCur)
    {
        for (int xCur = xCenter - 2; xCur < xCenter + 2; ++xCur)
        {
            RawPixel pixelSrc;
            GetPixel(image, xCur, yCur, &pixelSrc);

            InitPixel(pixels,
                    2.0 * (pixelSrc.r - 128.0),
                    2.0 * (pixelSrc.g - 128.0),
                    2.0 * (pixelSrc.b - 128.0));
            ++pixels;
        }
    }
}

// Construct an image that identifies the primary color axis for blocks of 4x4 pixels using Pricipal Component Analysis (PCA).
void PCAImage(RawImage* imageDstHi, RawImage* imageDstLo, RawImage* imageDelta, RawImage* imageSrc, RawImage* imageLowpass)
{
    RawPixel pixelOffset;
    InitPixel(&pixelOffset, 256.0, 256.0, 256.0);

    for (int y = 2; y < imageSrc->height; y += 4)
    {
        for (int x = 2; x < imageSrc->width; x += 4)
        {
            RawPixel pixelLowpass;
            GetPixel(imageLowpass, x >> 2, y >> 2, &pixelLowpass);

            RawPixel pixels[16];
            NeighborhoodPixels(imageDelta, x, y, pixels);

            RawPixel pixelAxis;
            PCAPixel(&pixelAxis, pixels, 16);

            float wMin = 1.0e10;
            float wMax = -1.0e10;
            for (int yInner = -2; yInner < 2; ++yInner)
            {
                for (int xInner = -2; xInner < 2; ++xInner)
                {
                    // Project imageDelta onto PCA.
                    RawPixel pixelDelta;
                    GetPixel(imageDelta, x + xInner, y + yInner, &pixelDelta);

                    // Restore range from 0..256 to -256..256.
                    ScalePixel(&pixelDelta, &pixelDelta, 2.0);
                    SubPixel(&pixelDelta, &pixelDelta, &pixelOffset);

                    float w = DotPixel(&pixelAxis, &pixelDelta);

                    ScalePixel(&pixelDelta, &pixelAxis, w);
                    AddPixel(&pixelDelta, &pixelDelta, &pixelLowpass);

                    // TODO: compute clamped w for each case,
                    // then finally scale and add after best w found.
                    // If color over/underflow detected, ...
                    /*
                     if (pixelDelta.r > 255.0)
                     {
                     w *= (255.0 - pixelLowpass.r) / (pixelDelta.r - pixelLowpass.r);
                     ScalePixel(&pixelDelta, &pixelAxis, w);
                     AddPixel(&pixelDelta, &pixelDelta, &pixelLowpass);
                     }
                     else if (pixelDelta.r < 0.0)
                     {
                     w *= (0.0 - pixelLowpass.r) / (pixelDelta.r - pixelLowpass.r);
                     ScalePixel(&pixelDelta, &pixelAxis, w);
                     AddPixel(&pixelDelta, &pixelDelta, &pixelLowpass);
                     }

                     if (pixelDelta.g > 255.0)
                     {
                     w *= (255.0 - pixelLowpass.g) / (pixelDelta.g - pixelLowpass.g);
                     ScalePixel(&pixelDelta, &pixelAxis, w);
                     AddPixel(&pixelDelta, &pixelDelta, &pixelLowpass);
                     }
                     else if (pixelDelta.g < 0.0)
                     {
                     w *= (0.0 - pixelLowpass.g) / (pixelDelta.g - pixelLowpass.g);
                     ScalePixel(&pixelDelta, &pixelAxis, w);
                     AddPixel(&pixelDelta, &pixelDelta, &pixelLowpass);
                     }

                     if (pixelDelta.b > 255.0)
                     {
                     w *= (255.0 - pixelLowpass.b) / (pixelDelta.b - pixelLowpass.b);
                     ScalePixel(&pixelDelta, &pixelAxis, w);
                     AddPixel(&pixelDelta, &pixelDelta, &pixelLowpass);
                     }
                     else if (pixelDelta.b < 0.0)
                     {
                     w *= (0.0 - pixelLowpass.b) / (pixelDelta.b - pixelLowpass.b);
                     AddPixel(&pixelDelta, &pixelDelta, &pixelLowpass);
                     ScalePixel(&pixelDelta, &pixelAxis, w);
                     }
                     */

                    // Record weight extrema.
                    if (w > wMax) wMax = w;
                    if (w < wMin) wMin = w;
                }
            }

            RawPixel pixelSrc;
            GetPixel(imageLowpass, x >> 2, y >> 2, &pixelSrc);

            RawPixel pixelMin;
            ScalePixel(&pixelMin, &pixelAxis, wMin);
            AddPixel(&pixelMin, &pixelMin, &pixelSrc);
            ClampPixel(&pixelMin, &pixelMin);

            RawPixel pixelMax;
            ScalePixel(&pixelMax, &pixelAxis, wMax);
            AddPixel(&pixelMax, &pixelMax, &pixelSrc);
            ClampPixel(&pixelMax, &pixelMax);

            SetPixel(imageDstLo, x >> 2, y >> 2, &pixelMin);
            SetPixel(imageDstHi, x >> 2, y >> 2, &pixelMax);
        }
    }
}

// Compute the size of an image in bytes.
size_t SizeImage(int dx, int dy)
{
    // Each pixel fits into 4 bytes.
    return (size_t) (dx * dy * 4);
}

// Allocate a new image.
RawImage* NewImage(int width, int height)
{
    RawImage* image = (RawImage*) malloc(sizeof(RawImage));
    image->widthBase = width;
    image->heightBase = height;
    image->width = (width < 8) ? 8 : width;
    image->height = (height < 8) ? 8 : height;
    image->bits = (char*) malloc(SizeImage(image->width, image->height));

    return image;
}

// Deallocate a previously allocated image.
void FreeImage(RawImage* image)
{
    free(image->bits);
    image->bits = NULL;
    free(image);
}

// Expand actual size to valid legal size if too small
void ExpandImageX(RawImage* image)
{
    if (image->width != image->widthBase)
    {
        for (int y = 0; y < image->height; ++y)
        {
            for (int x = image->widthBase; x < image->width; ++x)
            {
                RawPixel pixel;
                GetPixel(image, x % image->widthBase, y, &pixel);
                SetPixel(image, x, y, &pixel);
            }
        }
    }
}

// Expand actual size to valid legal size if too small
void ExpandImageY(RawImage* image)
{
    if (image->height != image->heightBase)
    {
        for (int y = image->heightBase; y < image->height; ++y)
        {
            for (int x = 0; x < image->width; ++x)
            {
                RawPixel pixel;
                GetPixel(image, x, y % image->heightBase, &pixel);
                SetPixel(image, x, y, &pixel);
            }
        }
    }
}

// Expand actual size to valid legal size if too small
void ExpandImage(RawImage* image)
{
    ExpandImageX(image);
    ExpandImageY(image);
}

// Write a raw image to a file.
void WriteImage(RawImage* image, const char* name)
{
    FILE* file = fopen(name, "wb");

    fwrite(image->bits, 1, SizeImage(image->width, image->height), file);

    fclose(file);
}

// Downsample an image by a factor of 4 in both x and y directions.
void Downsample4Image(RawImage* dst, RawImage* src)
{
    int xBlockMax = (src->width > 2) ? 4 : (src->width > 1) ? 2 : 1;
    int yBlockMax = (src->height > 2) ? 4 : (src->height > 1) ? 2 : 1;

    for (int y = 0; y < src->height; y += 4)
    {
        for (int x = 0; x < src->width; x += 4)
        {
            RawPixel pixAccum;
            InitPixel(&pixAccum, 0.0, 0.0, 0.0);

            for (int xBlock = 0; xBlock < xBlockMax; ++xBlock)
            {
                for (int yBlock = 0; yBlock < yBlockMax; ++yBlock)
                {
                    RawPixel pixCur;
                    GetPixel(src, x + xBlock, y + yBlock, &pixCur);
                    AddPixel(&pixAccum, &pixAccum, &pixCur);
                }
            }
            ScalePixel(&pixAccum, &pixAccum, (1.0 / ((float) xBlockMax * yBlockMax)));
            SetPixel(dst, x >> 2, y >> 2, &pixAccum);
        }
    }
}

// Downsample an image by a factor of 2 in both x and y directions.
void Downsample2Image(RawImage* dst, RawImage* src)
{
    int xBlockMax = (src->width > 1) ? 2 : 1;
    int yBlockMax = (src->height > 1) ? 2 : 1;

    for (int y = 0; y < dst->height; ++y)
    {
        for (int x = 0; x < dst->width; ++x)
        {
            RawPixel pixAccum;
            InitPixel(&pixAccum, 0.0, 0.0, 0.0);

            for (int xBlock = 0; xBlock < xBlockMax; ++xBlock)
            {
                for (int yBlock = 0; yBlock < yBlockMax; ++yBlock)
                {
                    RawPixel pixCur;
                    GetPixel(src, (x << 1) + xBlock, (y << 1) + yBlock, &pixCur);
                    AddPixel(&pixAccum, &pixAccum, &pixCur);
                }
            }
            ScalePixel(&pixAccum, &pixAccum, (1.0 / ((float) xBlockMax * yBlockMax)));
            SetPixel(dst, x, y, &pixAccum);
        }
    }
}

// Upsample an image by a factor of 2 in the x direction.
void UpsampleXImage(RawImage* dst, RawImage* src)
{
    for (int yDst = 0; yDst < dst->height; ++yDst)
    {
        for (int xDst = 0; xDst < dst->width; ++xDst)
        {
            RawPixel pixelDst;
            RawPixel pixelSrc0;
            RawPixel pixelSrc1;

            int xSrc = xDst >> 1;
            int ySrc = yDst;

            GetPixel(src, xSrc, ySrc, &pixelSrc0);

            if (src->width == 1)
            {
                InitPixel(&pixelDst, pixelSrc0.r, pixelSrc0.g, pixelSrc0.b);
            }
            else if (xDst == 0)
            {
                GetPixel(src, xSrc + 1, ySrc, &pixelSrc1);

                LerpPixel(&pixelDst, &pixelSrc0, &pixelSrc1, (5.0 / 4.0), (-1.0 / 4.0));

                // Since we are extrapolating, we may over/underflow.
                ClampPixel(&pixelDst, &pixelDst);
            }
            else if (xDst == dst->width - 1)
            {
                GetPixel(src, xSrc - 1, ySrc, &pixelSrc1);

                LerpPixel(&pixelDst, &pixelSrc0, &pixelSrc1, (5.0 / 4.0), (-1.0 / 4.0));

                // Since we are extrapolating, we may over/underflow.
                ClampPixel(&pixelDst, &pixelDst);
            }
            else if (xDst & 1)
            {
                GetPixel(src, xSrc + 1, ySrc, &pixelSrc1);

                LerpPixel(&pixelDst, &pixelSrc0, &pixelSrc1, (3.0 / 4.0), (1.0 / 4.0));

            }
            else
            {
                GetPixel(src, xSrc - 1, ySrc, &pixelSrc1);

                LerpPixel(&pixelDst, &pixelSrc0, &pixelSrc1, (3.0 / 4.0), (1.0 / 4.0));
            }

            SetPixel(dst, xDst, yDst, &pixelDst);
        }
    }
}

// Upsample an image by a factor of 2 in the y direction.
void UpsampleYImage(RawImage* dst, RawImage* src)
{
    for (int yDst = 0; yDst < dst->height; ++yDst)
    {
        for (int xDst = 0; xDst < dst->width; ++xDst)
        {
            RawPixel pixelDst;
            RawPixel pixelSrc0;
            RawPixel pixelSrc1;

            int xSrc = xDst;
            int ySrc = yDst >> 1;

            GetPixel(src, xSrc, ySrc, &pixelSrc0);

            if (src->height == 1)
            {
                InitPixel(&pixelDst, pixelSrc0.r, pixelSrc0.g, pixelSrc0.b);
            }
            else if (yDst == 0)
            {
                GetPixel(src, xSrc, ySrc + 1, &pixelSrc1);

                LerpPixel(&pixelDst, &pixelSrc0, &pixelSrc1, (5.0 / 4.0), (-1.0 / 4.0));

                // Since we are extrapolating, we may over/underflow.
                ClampPixel(&pixelDst, &pixelDst);
            }
            else if (yDst == dst->height - 1)
            {
                GetPixel(src, xSrc, ySrc - 1, &pixelSrc1);

                LerpPixel(&pixelDst, &pixelSrc0, &pixelSrc1, (5.0 / 4.0), (-1.0 / 4.0));

                // Since we are extrapolating, we may over/underflow.
                ClampPixel(&pixelDst, &pixelDst);
            }
            else if (yDst & 1)
            {
                GetPixel(src, xSrc, ySrc + 1, &pixelSrc1);

                LerpPixel(&pixelDst, &pixelSrc0, &pixelSrc1, (3.0 / 4.0), (1.0 / 4.0));

            }
            else
            {
                GetPixel(src, xSrc, ySrc - 1, &pixelSrc1);

                LerpPixel(&pixelDst, &pixelSrc0, &pixelSrc1, (3.0 / 4.0), (1.0 / 4.0));
            }

            SetPixel(dst, xDst, yDst, &pixelDst);
        }
    }
}

// Upsample an image by a factor of 2 in both the x and y directions.
void Upsample2Image(RawImage* dst, RawImage* src)
{
    int dx = src->width;
    int dy = src->height;

    RawImage* upX2 = NewImage(dx << 1, dy);

    UpsampleXImage(upX2, src);

    UpsampleYImage(dst, upX2);

    FreeImage(upX2);

}

// Upsample an image by a factor of 4 in both the x and y directions.
void Upsample4Image(RawImage* dst, RawImage* src)
{
    int dx = src->width;
    int dy = src->height;

    RawImage* up2 = NewImage(dx << 1, dy << 1);

    Upsample2Image(up2, src);

    Upsample2Image(dst, up2);

    FreeImage(up2);
}

// Compute the difference of two images.
void DeltaImage(RawImage* dst, RawImage* src0, RawImage* src1)
{
    for (int yDst = 0; yDst < dst->height; ++yDst)
    {
        for (int xDst = 0; xDst < dst->width; ++xDst)
        {
            int xSrc = xDst;
            int ySrc = yDst;

            RawPixel pixelSrc0;
            GetPixel(src0, xSrc, ySrc, &pixelSrc0);

            RawPixel pixelSrc1;
            GetPixel(src1, xSrc, ySrc, &pixelSrc1);

            RawPixel pixelDst;
            DeltaPixel(&pixelDst, &pixelSrc0, &pixelSrc1);

            SetPixel(dst, xDst, yDst, &pixelDst);
        }
    }
}

// Compute the interpolation weight at each pixel and encode in an "iamge".
void WtImage(RawImage* wt, RawImage* src, RawImage* lo, RawImage* hi)
{
    int dx = wt->width;
    int dy = wt->height;

    for (int y = 0; y < dy; ++y)
    {
        for (int x = 0; x < dx; ++x)
        {
            RawPixel pixelLo;
            GetPixel(lo, x, y, &pixelLo);

            RawPixel pixelHi;
            GetPixel(hi, x, y, &pixelHi);

            RawPixel pixelSrc;
            GetPixel(src, x, y, &pixelSrc);

            RawPixel pixelSubSrc;
            SubPixel(&pixelSubSrc, &pixelSrc, &pixelLo);

            RawPixel pixelSubHi;
            SubPixel(&pixelSubHi, &pixelHi, &pixelLo);

            float lenSubHi = DotPixel(&pixelSubHi, &pixelSubHi);

            RawPixel pixelWt;
            float w = 0.0;

            if (lenSubHi > 0.0)
            {
                float lenSubSrc = DotPixel(&pixelSubSrc, &pixelSubHi);

                w = Clamp(lenSubSrc / lenSubHi, 0, 1);
            }

            w *= 255.0;

            InitPixel(&pixelWt, w, w, w);

            SetPixel(wt, x, y, &pixelWt);
        }
    }
}

// Interpolate two images with a weight "image"..
void LerpImage(RawImage* dst, RawImage* src0, RawImage* src1, RawImage* wt)
{
    int dx = dst->width;
    int dy = dst->height;

    for (int y = 0; y < dy; ++y)
    {
        for (int x = 0; x < dx; ++x)
        {
            RawPixel pixel0;
            GetPixel(src0, x, y, &pixel0);

            RawPixel pixel1;
            GetPixel(src1, x, y, &pixel1);

            RawPixel pixelWt;
            GetPixel(wt, x, y, &pixelWt);

            RawPixel pixelDst;
            SubPixel(&pixelDst, &pixel1, &pixel0);
            ScalePixel(&pixelDst, &pixelDst, pixelWt.r / 255.0);
            AddPixel(&pixelDst, &pixelDst, &pixel0);

            SetPixel(dst, x, y, &pixelDst);
        }
    }
}

// Initialize of PVRTC file header.
void InitPvrHeader(PVR_Header* header, int dx, int dy, int levels)
{
    memset(header, 0, sizeof(PVR_Header));

    header->version = PVR_VERSION;
    header->pixel_format_lsb = PVR_FORMAT_PVRTC_4_RGBA;
    header->width = dx;
    header->height = dy;
    header->depth = 1;
    header->num_surfaces = 1;
    header->num_faces = 1;
    header->num_mipmaps = (uint32_t) levels;
}

// Compute (x,y) from Morton index. See description at:
// http://en.wikipedia.org/wiki/Z-order_curve
void IndexToXY(unsigned int idx, int* x, int* y)
{
    int xCur = 0;
    int yCur = 0;

    int mask = 1;

    while (idx != 0)
    {
        if (idx & 2)
            xCur |= mask;

        if (idx & 1)
            yCur |= mask;

        mask <<= 1;
        idx >>= 2;
    }

    *x = xCur;
    *y = yCur;
}

// Encode an RGB888 pixel as RBG555.
uint16_t RGB555FromPixel(RawPixel* pixel)
{
    int r = (int) (pixel->r * 31.0 / 255.0 + 0.5);
    int g = (int) (pixel->g * 31.0 / 255.0 + 0.5);
    int b = (int) (pixel->b * 31.0 / 255.0 + 0.5);

    uint16_t rgb = 0;

    rgb |= 1;
    rgb <<= 5;
    rgb |= r;
    rgb <<= 5;
    rgb |= g;
    rgb <<= 5;
    rgb |= b;

    return rgb;
}

// Encode a 4x4 pixel block by 2 RGB555 pixel extrema and 2-bit weights for each pixel.
PVR_Block PackPVR_Block(RawImage* imageLo, RawImage* imageHi, RawImage* imageWt, int x, int y)
{
    RawPixel pixelLo;
    RawPixel pixelHi;

    GetPixel(imageLo, x, y, &pixelLo);
    GetPixel(imageHi, x, y, &pixelHi);

    uint16_t rgbLo = RGB555FromPixel(&pixelLo);
    uint16_t rgbHi = RGB555FromPixel(&pixelHi);

    // Clear "modulation mode" bit
    rgbHi &= ~1;
    rgbLo &= ~1;

    // Accumulator for 2-bit pixel weights.
    uint32_t wts = 0;

    for (int iy = 3; iy >= 0; --iy)
    {
        for (int ix = 3; ix >= 0; --ix)
        {
            wts <<= 2;

            RawPixel pixelWt;
            GetPixel(imageWt, (x << 2) + ix, (y << 2) + iy, &pixelWt);

            // Map intensity to interpolation bits
            // 0..1/4, 1/4..1/2, 1/2..3/4, 3/4..1 => 00, 01, 10, 11
            uint32_t wt = (uint32_t) pixelWt.r;
            wts |= (wt >> 6);
        }
    }

    PVR_Block block;
    block.rgbHi = rgbHi;
    block.rgbLo = rgbLo;
    block.wts = wts;

    return block;
}

// Encode an image as a PVRTC image.
int EncodePvrImage(RawImage* src, PVR_Block** pvrImage)
{
    int dx = src->width;
    int dy = src->height;

    // PVRTC only works for powers of 2!
    if (!IsPow2(dx) || !IsPow2(dy))
    {
        *pvrImage = NULL;
        return 0;
    }

    RawImage* down4 = NewImage(dx >> 2, dy >> 2);
    Downsample4Image(down4, src);

    // DEBUG: Dump low pass image.
    //WriteImage(down4, "testLopass.raw");

    RawImage* up4 = NewImage(dx, dy);
    Upsample4Image(up4, down4);

    // DEBUG: Dump upsampled low pass image.
    //WriteImage(up4, "testLopass4.raw");

    RawImage* delta = NewImage(dx, dy);
    DeltaImage(delta, src, up4);

    // DEBUG: Dump delta image.
    //WriteImage(delta, "testDelta.raw");

    RawImage* lo = NewImage(dx >> 2, dy >> 2);
    RawImage* hi = NewImage(dx >> 2, dy >> 2);
    PCAImage(hi, lo, delta, src, down4);

    RawImage* lo4 = NewImage(dx, dy);
    Upsample4Image(lo4, lo);

    RawImage* hi4 = NewImage(dx, dy);
    Upsample4Image(hi4, hi);

    // DEBUG: Dump color extrema images in both downsampled and upsampled form.
    //WriteImage(hi, "testHi.raw");
    //WriteImage(lo, "testLo.raw");
    //WriteImage(hi4, "testHi4.raw");
    //WriteImage(lo4, "testLo4.raw");

    // Using a full RawImage for the wieghts is overkill, since all we
    // really need is an 8-bit integer quantity. This simply reuses existing
    // machinery rather than defining a completely new one.
    RawImage* wt = NewImage(dx, dy);
    WtImage(wt, src, lo4, hi4);

    // DEBUG: Simulate and dump interpolated image.
    //RawImage* pvrtc = NewImage(dx, dy);
    //LerpImage(pvrtc, lo4, hi4, wt);
    //WriteImage(pvrtc, "testPvrtc.raw");

    // DEBUG: Dump error image.
    //RawImage* error = NewImage(dx, dy);
    //DeltaImage(error, src, pvrtc);
    //WriteImage(error, "testError.raw");

    int blockCount = (dx >> 2) * (dy >> 2);
    *pvrImage = (PVR_Block *) malloc((size_t) blockCount * sizeof(PVR_Block));
    PVR_Block* blockDst = *pvrImage;
    int blockCur = 0;

    for (unsigned int idx = 0; ; ++idx)
    {
        int x;
        int y;

        IndexToXY(idx, &x, &y);

        if (x < (dx >> 2) && y < (dy >> 2))
        {
            PVR_Block block = PackPVR_Block(lo, hi, wt, x, y);
            *blockDst++ = block;
            ++blockCur;
        }

        if (x >= (dx >> 2) && y >= (dy >> 2))
            break;
    }

    //assert(blockCount == blockCur);

    FreeImage(wt);
    FreeImage(hi4);
    FreeImage(lo4);
    FreeImage(lo);
    FreeImage(hi);
    FreeImage(delta);
    FreeImage(up4);
    FreeImage(down4);

    return blockCount;
}

// Encode an image mipmap as a PVRTC image.
int EncodePvrMipmap(RawImage* src, PVR_Block*** pvrMipmap, int** blockCounts)
{
    int levelMax = 0;
    int xyMax = (src->widthBase > src->heightBase) ? src->widthBase : src->heightBase;

    while (xyMax != 0)
    {
        ++levelMax;
        xyMax >>= 1;
    }

    *blockCounts = (int*) malloc((size_t)levelMax * sizeof(int));
    *pvrMipmap = (PVR_Block**) malloc((size_t)levelMax * sizeof(PVR_Block*));

    int* blockCount = *blockCounts;
    PVR_Block** pvrImage = *pvrMipmap;

    RawImage* imageCur = src;

    for (int level = 0; level < levelMax; ++level)
    {
        *blockCount = EncodePvrImage(imageCur, pvrImage);
        ++blockCount;
        ++pvrImage;

        int width = imageCur->widthBase >> 1;
        if (width == 0)
            width = 1;

        int height = imageCur->heightBase >> 1;
        if (height == 0)
            height = 1;

        RawImage* imageNxt = NewImage(width, height);

        Downsample2Image(imageNxt, imageCur);

        if (imageCur != src)
            FreeImage(imageCur);

        imageCur = imageNxt;
    }

    if (imageCur != src)
        FreeImage(imageCur);

    return levelMax;
}

// TODO: What would be required to write the compressed texture to memory rather than disk? If not too difficult,
// go ahead and implement that.

// Write a PVRTC file.
void WritePvrFile(PVR_Block** PVR_Blocks, int* blockCounts, int levelCount, int dx, int dy, const char* name)
{
    // TODO: This function should be using framework (NS) methods for file I/O and catching and logging I/O
    // exceptions.

    PVR_Header header;

    InitPvrHeader(&header, dx, dy, levelCount);

    FILE* file = fopen(name, "wb");

    fwrite(&header, 1, sizeof(PVR_Header), file);

    for (int level = 0; level < levelCount; ++level)
    {
        PVR_Block* blocks = PVR_Blocks[level];
        int count = blockCounts[level];
        fwrite(blocks, 1, (size_t)count * sizeof(PVR_Block), file);
    }

    fclose(file);
}

#ifdef DEBUG_PVR_ENCODE
void DebugPvrEncode()
{
    NSString* pathTest = @"/Users/danm/Library/Application Support/iPhone Simulator/6.1/Applications/5A21CAD1-FD0E-4ACD-B6BD-A6A0731F774E/Library/Caches/BMNG/Earth_256x256.jpg";
    UIImage* uiImageTest = [UIImage imageWithContentsOfFile:pathTest];
    CGImageRef cgImageTest = [uiImageTest CGImage];
    
    int imageWidthTest = CGImageGetWidth(cgImageTest);
    int imageHeightTest = CGImageGetHeight(cgImageTest);
    int textureSizeTest = imageWidthTest * imageHeightTest * 4; // assume 4 bytes per pixel
    void* imageDataTest = malloc((size_t) textureSizeTest); // allocate space for the image
    
    CGColorSpaceRef colorSpaceTest = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextTest = CGBitmapContextCreate(imageDataTest, (size_t) imageWidthTest, (size_t) imageHeightTest,
                                                     8, (size_t) (4 * imageWidthTest), colorSpaceTest, kCGImageAlphaPremultipliedLast);
    CGRect rectTest = CGRectMake(0, 0, imageWidthTest, imageHeightTest);
    CGContextClearRect(contextTest, rectTest);
    CGContextDrawImage(contextTest, rectTest, cgImageTest);
    
    NSString* outputPathTest = [WWUtil replaceSuffixInPath:pathTest newSuffix:@"pvr"];
    [WWPVRTCImage doCompress:imageWidthTest height:imageHeightTest bits:imageDataTest ouputPath:outputPathTest];
}
#endif // DEBUG_PVR_ENCODE

@end