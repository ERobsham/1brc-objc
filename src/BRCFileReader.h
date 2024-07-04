//
//  BRCFileReader.h
//  calc_1brc
//
//  Created by Earl Robsham on 6/30/24.
//

#import <Foundation/Foundation.h>
#import "BRCProtocols.h"

@interface BRCDataBuffer : NSObject <BRCData>
@property (nonatomic, readonly) uint32_t len;
@property (nonatomic, readonly) uint8_t * buffer;
@end


#pragma mark - implemenation

@interface BRCFileReader : NSObject <BRCDataLoader>

/// performs all work on thread it was initialized on.  Preloads all buffers before returning an instance.
-(instancetype)initWith:(NSString *)path andBuffers:(uint32_t)numBuffers;

-(id<BRCData>)nextChunk;
-(void)returnChunk:(id<BRCData>)chunk;
@end

