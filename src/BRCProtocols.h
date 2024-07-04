//
//  BRCProtocols.h
//  calc_1brc
//
//  Created by Earl Robsham on 7/3/24.
//

#ifndef BRCProtocols_h
#define BRCProtocols_h

@protocol BRCData <NSObject>
-(uint8_t *)buffer;
-(uint32_t)len;
@end

@protocol BRCDataLoader <NSObject>
-(id<BRCData>)nextChunk;
-(void)returnChunk:(id<BRCData>)chunk;
@end

#endif /* BRCProtocols_h */
