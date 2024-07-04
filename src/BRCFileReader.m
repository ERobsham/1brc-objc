//
//  BRCFileReader.m
//  calc_1brc
//
//  Created by Earl Robsham on 6/30/24.
//

#import "BRCFileReader.h"

static const uint32_t BUFF_LEN = (1<<25);
static const uint32_t READER_BUFF_LEN = 128;

@interface BRCFileReader () {
    uint8_t  _data[READER_BUFF_LEN];
}
@property (nonatomic, assign) uint32_t leftover;

@property (nonatomic, retain) NSInputStream * stream;
@property (nonatomic, retain) NSArray<BRCDataBuffer *> * buffers;
@property (nonatomic, retain) NSMutableArray<BRCDataBuffer *> * buffers_ready;

@property (nonatomic, assign) NSThread * workThread;
@end

@interface BRCDataBuffer () {
    uint8_t _data[BUFF_LEN];
}
@end


#pragma mark -
@implementation BRCFileReader

- (instancetype)initWith:(NSString *)path andBuffers:(uint32_t)numBuffers {
    self = [super init];
    if (self) {
        memset(_data, 0, sizeof(_data));
        self.stream = [NSInputStream inputStreamWithFileAtPath:path];
        [self.stream open];
        
        NSMutableArray * buffers = [NSMutableArray arrayWithCapacity:numBuffers];
        for (uint32_t i=0; i<numBuffers; i++) {
            BRCDataBuffer * buff = [BRCDataBuffer new];
            [self loadNextChunkInto:buff];
            [buffers addObject:buff];
        }
        
        self.buffers       = [NSArray arrayWithArray:buffers];
        self.buffers_ready = [NSMutableArray arrayWithArray:buffers];
        
        self.workThread = [NSThread currentThread];
    }
    return self;
}

- (void)dealloc {
    @synchronized (self.stream) {
        if (self.stream) {
            [self.stream close];
            self.stream = nil;
        }
    }
    @synchronized (self.buffers_ready) {
        self.buffers_ready = nil;
    }
    
    self.buffers = nil;
    self.workThread = nil;
}

- (BOOL)loadNextChunkInto:(BRCDataBuffer *)buffer {
    uint8_t * data = buffer.buffer;
    uint32_t len   = buffer.len;
    
    if (self.stream == nil) { return NO; }
    
    // load any 'leftovers' we're hanging onto into the next buffer.
    uint32_t idx = 0;
    while (self.leftover > 0) {
        data[idx] = _data[idx];
        idx += 1;
        self.leftover -= 1;
    }
    
    // load data into the remainder of the buffer
    uint32_t remainingSpace = len - idx;
    uint32_t bytesRead      = (uint32_t)[self.stream read:&data[idx] maxLength:remainingSpace];
    uint32_t eod            = idx + bytesRead;
    
    // if we're finished reading the file, close it up and nil it out.
    if (bytesRead < remainingSpace) {
        data[eod] = 0;
    }
    
    if (![self.stream hasBytesAvailable]) {
        return NO;
    }
    
    // walk backwards until we hit a newline, and save any 'incomplete' chunks.
    idx = eod;
    while (data[idx] != '\n') {
        idx -= 1;
    }
    
    self.leftover = eod - (idx+1);
    memcpy(_data, &data[idx+1], self.leftover);
    
    // ensure NULL termination.
    data[idx+1] = 0;
    _data[self.leftover] = 0;
    
    return YES;
}


- (BRCDataBuffer *)nextChunk {
    BRCDataBuffer * buffer = nil;
    BOOL streamClosed = NO;
    do {
        if (!streamClosed) {
            @synchronized (self.stream) {
                if (self.stream == nil) { streamClosed = YES; }
            }
        }
        
        @synchronized (self.buffers_ready) {
            if ([self.buffers_ready count] > 0) {
                buffer = [self.buffers_ready lastObject];
                [self.buffers_ready removeLastObject];
            }
        }
        
        if (streamClosed && buffer == nil) {
            return nil;
        }
        usleep(100);
    } while (buffer == nil);
    return buffer;
}

- (void)returnChunk:(BRCDataBuffer *)chunk {
    if ([NSThread currentThread] != self.workThread) {
        [self performSelector:_cmd onThread:self.workThread withObject:chunk waitUntilDone:NO];
        return;
    }
    
    if ([self loadNextChunkInto:chunk]) {
        @synchronized (self.buffers_ready) {
            [self.buffers_ready addObject:chunk];
        }
    }
    
    if (![self.stream hasBytesAvailable]) {
        [self.stream close];
        @synchronized (self.stream) {
            self.stream = nil;
        }
    }
}

@end

#pragma mark -
@implementation BRCDataBuffer

- (instancetype)init {
    self = [super init];
    if (self) {
        memset(_data, 0, sizeof(_data));
    }
    return self;
}

-(uint32_t)len {
    return sizeof(_data) - 1;
}

-(uint8_t *)buffer {
    return &_data[0];
}

@end
