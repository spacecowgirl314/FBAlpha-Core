/*
 Copyright (c) 2009, OpenEmu Team
 
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the OpenEmu Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "FBAGameCore.h"
#import <OpenEmuBase/OERingBuffer.h>
#import "OEArcadeSystemResponderClient.h"
#import <OpenGL/gl.h>

#include "libretro.h"

#define SAMPLERATE 32000

@interface FBAGameCore () <OEArcadeSystemResponderClient>
@end

NSUInteger FBAEmulatorValues[] = { RETRO_DEVICE_ID_JOYPAD_UP, RETRO_DEVICE_ID_JOYPAD_DOWN, RETRO_DEVICE_ID_JOYPAD_LEFT, RETRO_DEVICE_ID_JOYPAD_RIGHT, RETRO_DEVICE_ID_JOYPAD_X, RETRO_DEVICE_ID_JOYPAD_L, RETRO_DEVICE_ID_JOYPAD_R, RETRO_DEVICE_ID_JOYPAD_Y, RETRO_DEVICE_ID_JOYPAD_B, RETRO_DEVICE_ID_JOYPAD_A, RETRO_DEVICE_ID_JOYPAD_START, RETRO_DEVICE_ID_JOYPAD_SELECT };

FBAGameCore *_current;
@implementation FBAGameCore

static void audio_callback(int16_t left, int16_t right)
{
    GET_CURRENT_AND_RETURN();
    
    [[current ringBufferAtIndex:0] write:&left maxLength:2];
    [[current ringBufferAtIndex:0] write:&right maxLength:2];
}

static size_t audio_batch_callback(const int16_t *data, size_t frames)
{
    GET_CURRENT_AND_RETURN(frames);
    
    [[current ringBufferAtIndex:0] write:data maxLength:frames << 2];
    return frames;
}

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
    GET_CURRENT_AND_RETURN();
    
    current->videoWidth  = width;
    current->videoHeight = height;
    
//    NSLog(@"videoWidth: %i, videoHeight: %i", current->videoWidth, current->videoHeight);
    
    dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(height, the_queue, ^(size_t y){
        const uint16_t *src = (uint16_t*)data + y * (pitch >> 1); //pitch is in bytes not pixels
        uint16_t *dst = current->videoBuffer + y * width;
        
        memcpy(dst, src, sizeof(uint16_t)*width);
    });
}

//static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
//{
//    GET_CURRENT_AND_RETURN();
//    
//    // Normally our pitch is 2048 bytes.
////    int stride = 1024;
//    // If we have an interlaced mode, pitch is 1024 bytes.
////    if ( height == current->videoWidth )
////        stride = 1024;
//    //stride = current->thePitch; //2048
//    
//    current->videoWidth  = width;
//    current->videoHeight = height;
//    
//    dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    
//    // TODO opencl CPU device?
//    dispatch_apply(height, the_queue, ^(size_t y){
//        const uint16_t *src = (uint16_t*)data + y * (pitch >> 1);
//        uint16_t *dst = current->videoBuffer + y * current->videoWidth;
//        
//        for (int x = 0; x < width; x++) {
////            dst[x] = conv555Rto565(src[x]);
//            dst[x] = src[x];
//        }
//    });
//}

static void input_poll_callback(void)
{
    //NSLog(@"poll callback");
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
    GET_CURRENT_AND_RETURN(0);
    
    //NSLog(@"polled input: port: %d device: %d id: %d", port, device, id);
    
    if (port == 0 & device == RETRO_DEVICE_JOYPAD) {
        return current->pad[0][_id];
    }
//    else if(port == 1 & device == RETRO_DEVICE_JOYPAD) {
//        return current->pad[1][_id];
//    }
    
    return 0;
}

static bool environment_callback(unsigned cmd, void *data)
{
    GET_CURRENT_AND_RETURN(false);
    
    switch(cmd)
    {
        case RETRO_ENVIRONMENT_SET_ROTATION :
        {
            unsigned rotation = *(const unsigned *)data;
            switch (rotation)
            {
                case 0:
                    // 0
                    break;
                case 1:
                    // 90
                    break;
                case 2:
                    // 180
                    break;
                case 3:
                    // 270
                    break;
                    
                default:
                    return false;
            }
        }
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT :
        {
            enum retro_pixel_format pix_fmt = *(const enum retro_pixel_format*)data;
            switch (pix_fmt)
            {
                case RETRO_PIXEL_FORMAT_0RGB1555:
                    NSLog(@"Environ SET_PIXEL_FORMAT: 0RGB1555");
                    break;
                    
                case RETRO_PIXEL_FORMAT_RGB565:
                    NSLog(@"Environ SET_PIXEL_FORMAT: RGB565");
                    break;
                    
                case RETRO_PIXEL_FORMAT_XRGB8888:
                    NSLog(@"Environ SET_PIXEL_FORMAT: XRGB8888");
                    break;
                    
                default:
                    return false;
            }
//            currentPixFmt = pix_fmt;
            break;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY :
        {
            NSString *appSupportPath = current.biosDirectoryPath;
            
            *(const char **)data = [appSupportPath UTF8String];
            NSLog(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
            break;
        }
        default :
            NSLog(@"Environ UNSUPPORTED (#%u).\n", cmd);
            return false;
    }
    
    return true;
}

static void loadSaveFile(const char* path, int type)
{
    FILE *file;
    
    file = fopen(path, "rb");
    if ( !file )
    {
        return;
    }
    
    size_t size = retro_get_memory_size(type);
    void *data = retro_get_memory_data(type);
    
    if (size == 0 || !data)
    {
        fclose(file);
        return;
    }
    
    int rc = fread(data, sizeof(uint8_t), size, file);
    if ( rc != size )
    {
        NSLog(@"Couldn't load save file.");
    }
    
    NSLog(@"Loaded save file: %s", path);
    
    fclose(file);
}

static void writeSaveFile(const char* path, int type)
{
    size_t size = retro_get_memory_size(type);
    void *data = retro_get_memory_data(type);
    
    if ( data && size > 0 )
    {
        FILE *file = fopen(path, "wb");
        if ( file != NULL )
        {
            NSLog(@"Saving state %s. Size: %d bytes.", path, (int)size);
            retro_serialize(data, size);
            if ( fwrite(data, sizeof(uint8_t), size, file) != size )
                NSLog(@"Did not save state properly.");
            fclose(file);
        }
    }
}

- (oneway void)didPushArcadeButton:(OEArcadeButton)button forPlayer:(NSUInteger)player;
{
    pad[player-1][FBAEmulatorValues[button]] = 1; //1 or 0xFFFF
}

- (oneway void)didReleaseArcadeButton:(OEArcadeButton)button forPlayer:(NSUInteger)player;
{
    pad[player-1][FBAEmulatorValues[button]] = 0;
}

- (id)init
{
	self = [super init];
    if(self != nil)
    {
        if(videoBuffer) 
            free(videoBuffer);
        //videoBuffer = (uint16_t*)malloc(maxVideoWidth * maxVideoHeight * 2);
        videoBuffer = (uint16_t*)malloc(1024 * 1024 * 2);
    }
	
	_current = self;
    
	return self;
}

#pragma mark Exectuion

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame: (BOOL) skip
{
    retro_run();
}

- (BOOL)loadFileAtPath: (NSString*) path
{
    memset(pad, 0, sizeof(int16_t) * 10);
    
    const void *data;
    size_t size;
    romName = [path copy];
    
    //load cart, read bytes, get length
    NSData* dataObj = [NSData dataWithContentsOfFile:[romName stringByStandardizingPath]];
    if(dataObj == nil) return false;
    size = [dataObj length];
    data = (uint8_t*)[dataObj bytes];
    const char *meta = NULL;
    
    retro_set_environment(environment_callback);
    retro_init();
    
    retro_set_audio_sample(audio_callback);
    retro_set_audio_sample_batch(audio_batch_callback);
    retro_set_video_refresh(video_callback);
    retro_set_input_poll(input_poll_callback);
    retro_set_input_state(input_state_callback);
    
    
    const char *fullPath = [path UTF8String];
    
    struct retro_game_info info = {NULL};
    info.path = fullPath;
    info.data = data;
    info.size = size;
    info.meta = meta;
    
    if(retro_load_game(&info))
    {
        NSString *path = romName;
        NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];
        
        NSString *batterySavesDirectory = [self batterySavesDirectoryPath];
        
        if([batterySavesDirectory length] != 0)
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
            
            NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
            
            loadSaveFile([filePath UTF8String], RETRO_MEMORY_SAVE_RAM);
        }
        
        struct retro_system_av_info info;
        retro_get_system_av_info(&info);
        
        frameInterval = info.timing.fps;
        sampleRate = info.timing.sample_rate;
        videoWidth = info.geometry.base_width;
        videoHeight = info.geometry.base_height;
        maxVideoWidth = info.geometry.max_width;
        maxVideoHeight = info.geometry.max_height;
        
        //retro_set_controller_port_device(SNES_PORT_1, RETRO_DEVICE_JOYPAD);
        
        retro_get_region();
        
        retro_run();
        
        return YES;
    }
    
    return NO;
}

#pragma mark Video
- (const void *)videoBuffer
{
    return videoBuffer;
}

-(BOOL)rendersToOpenGL;
{
    return NO;
}

- (OEIntRect)screenRect
{
    return OEIntRectMake(0, 0, videoWidth, videoHeight);
}

- (OEIntSize)bufferSize
{
    return OEIntSizeMake(maxVideoWidth, maxVideoHeight);
}

- (void)setupEmulation
{
}

- (void)resetEmulation
{
    retro_reset();
}

- (void)stopEmulation
{
    NSString *path = romName;
    NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];
    
    NSString *batterySavesDirectory = [self batterySavesDirectoryPath];
    
    if([batterySavesDirectory length] != 0)
    {
        
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
        
        NSLog(@"Trying to save SRAM");
        
        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
        
        writeSaveFile([filePath UTF8String], RETRO_MEMORY_SAVE_RAM);
    }
    
    NSLog(@"retro term");
    retro_unload_game();
    retro_deinit();
    [super stopEmulation];
}

- (void)dealloc
{
    free(videoBuffer);
}

- (GLenum)pixelFormat
{
    return GL_RGB;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_SHORT_5_6_5;
//    return GL_UNSIGNED_SHORT_1_5_5_5_REV;
//    return GL_UNSIGNED_INT_8_8_8_8;
}

- (GLenum)internalPixelFormat
{
    return GL_RGB5;
}

- (double)audioSampleRate
{
    return sampleRate ? sampleRate : 32000;
}

- (NSTimeInterval)frameInterval
{
    return frameInterval ? frameInterval : 60;
}

- (NSUInteger)channelCount
{
    return 2;
}

#pragma mark - Save States

- (NSData *)serializeStateWithError:(NSError **)outError
{
    size_t length = retro_serialize_size();
    void *bytes = malloc(length);
    
    if(retro_serialize(bytes, length))
    {
        return [NSData dataWithBytesNoCopy:bytes length:length];
    }
    else
    {
        if(outError)
        {
            *outError = [NSError errorWithDomain:OEGameCoreErrorDomain
                                            code:OEGameCoreCouldNotSaveStateError
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey : @"Save state data could not be written",
                                                   NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
                                                   }];
        }
        
        return nil;
    }
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
{
    size_t serial_size = retro_serialize_size();
    if(serial_size != [state length])
    {
        if(outError)
        {
            *outError = [NSError errorWithDomain:OEGameCoreErrorDomain
                                            code:OEGameCoreStateHasWrongSizeError
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey : @"Save state has wrong file size.",
                                                   NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The save state does not have the right size, %ld expected, got: %ld.", serial_size, [state length]]
                                                   }];
        }
        return NO;
    }
    
    if(retro_unserialize([state bytes], [state length]))
    {
        return YES;
    }
    else
    {
        if(outError)
        {
            *outError = [NSError errorWithDomain:OEGameCoreErrorDomain
                                            code:OEGameCoreCouldNotLoadStateError
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey : @"The save state data could not be read"
                                                   }];
        }
        
        return NO;
    }
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    int serial_size = retro_serialize_size();
    NSMutableData *stateData = [NSMutableData dataWithLength:serial_size];
    
    if(!retro_serialize([stateData mutableBytes], serial_size))
    {
        NSError *error = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotSaveStateError userInfo:@{
                                                                                                                         NSLocalizedDescriptionKey : @"Save state data could not be written",
                                                                                                                         NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
                                                                                                                         }];
        block(NO, error);
        return;
    }
    
    __autoreleasing NSError *error = nil;
    BOOL success = [stateData writeToFile:fileName options:NSDataWritingAtomic error:&error];
    
    block(success, success ? nil : error);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    __autoreleasing NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:fileName options:NSDataReadingMappedIfSafe | NSDataReadingUncached error:&error];
    
    if(data == nil)
    {
        block(NO, error);
        return;
    }
    
    int serial_size = 678514;
    if(serial_size != [data length])
    {
        NSError *error = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreStateHasWrongSizeError userInfo:@{
                                                                                                                         NSLocalizedDescriptionKey : @"Save state has wrong file size.",
                                                                                                                         NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The size of the file %@ does not have the right size, %d expected, got: %ld.", fileName, serial_size, [data length]],
                                                                                                                         }];
        block(NO, error);
        return;
    }
    
    if(!retro_unserialize([data bytes], serial_size))
    {
        NSError *error = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadStateError userInfo:@{
                                                                                                                         NSLocalizedDescriptionKey : @"The save state data could not be read",
                                                                                                                         NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"Could not read the file state in %@.", fileName]
                                                                                                                         }];
        block(NO, error);
        return;
    }
    
    block(YES, nil);
}

@end

#include "burner.h"

TCHAR szAppPreviewsPath[MAX_PATH]	= _T("support\\previews\\");
TCHAR szAppTitlesPath[MAX_PATH]		= _T("support\\titles\\");
TCHAR szAppSelectPath[MAX_PATH]		= _T("support\\select\\");
TCHAR szAppVersusPath[MAX_PATH]		= _T("support\\versus\\");
TCHAR szAppHowtoPath[MAX_PATH]		= _T("support\\howto\\");
TCHAR szAppScoresPath[MAX_PATH]		= _T("support\\scores\\");
TCHAR szAppBossesPath[MAX_PATH]		= _T("support\\bosses\\");
TCHAR szAppGameoverPath[MAX_PATH]	= _T("support\\gameover\\");
TCHAR szAppFlyersPath[MAX_PATH]		= _T("support\\flyers\\");
TCHAR szAppMarqueesPath[MAX_PATH]	= _T("support\\marquees\\");
TCHAR szAppControlsPath[MAX_PATH]	= _T("support\\controls\\");
TCHAR szAppCabinetsPath[MAX_PATH]	= _T("support\\cabinets\\");
TCHAR szAppPCBsPath[MAX_PATH]		= _T("support\\pcbs\\");
TCHAR szAppCheatsPath[MAX_PATH]		= _T("support\\cheats\\");
TCHAR szAppHistoryPath[MAX_PATH]	= _T("support\\");
TCHAR szAppListsPath[MAX_PATH]		= _T("support\\lists\\lst\\");
TCHAR szAppDatListsPath[MAX_PATH]	= _T("support\\lists\\dat\\");
TCHAR szAppIpsPath[MAX_PATH]		= _T("support\\ips\\");
TCHAR szAppIconsPath[MAX_PATH]		= _T("support\\icons\\");
TCHAR szAppArchivesPath[MAX_PATH]	= _T("support\\archives\\");
//TCHAR szAppHiscorePath[MAX_PATH]	= _T("support\\hiscores\\");
//TCHAR szAppSamplesPath[MAX_PATH]	= _T("support\\samples\\");
TCHAR szAppBlendPath[MAX_PATH]		= _T("support\\blend\\");

TCHAR szCheckIconsPath[MAX_PATH];

char* DecorateGameName(UINT32 nBurnDrv)
{
    static char szDecoratedName[256];
    UINT32 nOldBurnDrv = nBurnDrvActive;
    
    nBurnDrvActive = nBurnDrv;
    
    const char* s1 = "";
    const char* s2 = "";
    const char* s3 = "";
    const char* s4 = "";
    const char* s5 = "";
    const char* s6 = "";
    const char* s7 = "";
    const char* s8 = "";
    const char* s9 = "";
    const char* s10 = "";
    const char* s11 = "";
    const char* s12 = "";
    const char* s13 = "";
    const char* s14 = "";
    
    s1 = BurnDrvGetTextA(DRV_FULLNAME);
    if ((BurnDrvGetFlags() & BDF_DEMO) || (BurnDrvGetFlags() & BDF_HACK) || (BurnDrvGetFlags() & BDF_HOMEBREW) || (BurnDrvGetFlags() & BDF_PROTOTYPE) || (BurnDrvGetFlags() & BDF_BOOTLEG) || (BurnDrvGetTextA(DRV_COMMENT) && strlen(BurnDrvGetTextA(DRV_COMMENT)) > 0)) {
        s2 = " [";
        if (BurnDrvGetFlags() & BDF_DEMO) {
            s3 = "Demo";
            if ((BurnDrvGetFlags() & BDF_HACK) || (BurnDrvGetFlags() & BDF_HOMEBREW) || (BurnDrvGetFlags() & BDF_PROTOTYPE) || (BurnDrvGetFlags() & BDF_BOOTLEG) || (BurnDrvGetTextA(DRV_COMMENT) && strlen(BurnDrvGetTextA(DRV_COMMENT)) > 0)) {
                s4 = ", ";
            }
        }
        if (BurnDrvGetFlags() & BDF_HACK) {
            s5 = "Hack";
            if ((BurnDrvGetFlags() & BDF_HOMEBREW) || (BurnDrvGetFlags() & BDF_PROTOTYPE) || (BurnDrvGetFlags() & BDF_BOOTLEG) || (BurnDrvGetTextA(DRV_COMMENT) && strlen(BurnDrvGetTextA(DRV_COMMENT)) > 0)) {
                s6 = ", ";
            }
        }
        if (BurnDrvGetFlags() & BDF_HOMEBREW) {
            s7 = "Homebrew";
            if ((BurnDrvGetFlags() & BDF_PROTOTYPE) || (BurnDrvGetFlags() & BDF_BOOTLEG) || (BurnDrvGetTextA(DRV_COMMENT) && strlen(BurnDrvGetTextA(DRV_COMMENT)) > 0)) {
                s8 = ", ";
            }
        }
        if (BurnDrvGetFlags() & BDF_PROTOTYPE) {
            s9 = "Prototype";
            if ((BurnDrvGetFlags() & BDF_BOOTLEG) || (BurnDrvGetTextA(DRV_COMMENT) && strlen(BurnDrvGetTextA(DRV_COMMENT)) > 0)) {
                s10 = ", ";
            }
        }
        if (BurnDrvGetFlags() & BDF_BOOTLEG) {
            s11 = "Bootleg";
            if (BurnDrvGetTextA(DRV_COMMENT) && strlen(BurnDrvGetTextA(DRV_COMMENT)) > 0) {
                s12 = ", ";
            }
        }
        if (BurnDrvGetTextA(DRV_COMMENT) && strlen(BurnDrvGetTextA(DRV_COMMENT)) > 0) {
            s13 = BurnDrvGetTextA(DRV_COMMENT);
        }
        s14 = "]";
    }
    
    sprintf(szDecoratedName, "%s%s%s%s%s%s%s%s%s%s%s%s%s%s", s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14);
    
    nBurnDrvActive = nOldBurnDrv;
    return szDecoratedName;
}