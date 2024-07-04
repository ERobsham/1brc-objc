//
//  BRCWorker.m
//  calc_1brc
//
//  Created by Earl Robsham on 7/3/24.
//

#import "BRCWorker.h"

typedef struct {
    char characters[MAX_STATIONS_NAME_LEN+1];
    uint32_t key;
} stationName;

typedef struct {
    stationName name;
    int64_t total;
    uint32_t num;
    
    int32_t min;
    int32_t max;
} stationEntry;

static uint32_t parseLine(uint8_t * data, stationName * name, int32_t * temp);
static uint32_t parseName(uint8_t * data, stationName * name);
static uint32_t parseTemp(uint8_t * data, int32_t * temp);


@interface BRCWorker () {
    stationEntry _stationList[STATION_LIST_LEN];
}
@property (nonatomic, retain) id<BRCDataLoader> dataLoader;

@property (atomic, assign) BOOL isDone;
@property (nonatomic, assign) uint32_t linesRead;
@end

@implementation BRCWorker

- (instancetype)initWith:(id<BRCDataLoader>)dataLoader {
    self = [super init];
    if (self) {
        memset(_stationList, 0, sizeof(_stationList));
        self.dataLoader = dataLoader;
        self.linesRead = 0;
        
        self.isDone = NO;
        [NSThread detachNewThreadSelector:@selector(runLoop) toTarget:self withObject:nil];
    }
    return self;
}


-(void)runLoop {
#ifdef HASH_CHECK
    uint32_t collisons = 0;
#endif
    
    stationName nameBuf = {0};
    id<BRCData> buffer = nil;
    while((buffer = [self.dataLoader nextChunk]) != nil) {
        uint8_t * buf = buffer.buffer;
        
        stationEntry *entry = NULL;
        int32_t temp = 0;
        
        uint32_t offset = 0;
        uint32_t lineOffset = 0;
        while ((lineOffset = parseLine(&buf[offset], &nameBuf, &temp)) > 0) {
            offset += lineOffset;
            self.linesRead += 1;
            
            entry = &_stationList[nameBuf.key];
            if (entry->name.characters[0] == 0) {
                for (uint32_t i=0; nameBuf.characters[i] != 0; i++) {
                    entry->name.characters[i] = nameBuf.characters[i];
                }
                entry->name.key = nameBuf.key;
                entry->min = INT32_MAX;
                entry->max = INT32_MIN;
            }
            
#ifdef HASH_CHECK
            for (uint32_t i=0; entry->name.characters[i] != 0; i++) {
//                assert(entry->name.characters[i] == nameBuf.characters[i]);
                if (entry->name.characters[i] != nameBuf.characters[i]) {
                    collisons += 1;
                    break;
                }
            }
#endif
            
            entry->total += temp;
            entry->num += 1;
            entry->min = MIN(entry->min, temp);
            entry->max = MAX(entry->max, temp);
        }
        
        [self.dataLoader returnChunk:buffer];
        buffer = nil;
    }
    
    self.isDone = YES;
    
#ifdef HASH_CHECK
    if (collisons > 0) {
        NSLog(@" critical fail!  %d hash collsions blew up our results", collisons);
    }
#endif
}

-(NSMutableDictionary<NSString *, BRCStationEntry *> *)stationReport {
    NSMutableDictionary * results = [NSMutableDictionary dictionaryWithCapacity:MAX_NUM_STATIONS];
    for (uint32_t i=0; i < STATION_LIST_LEN; i++) {
        stationEntry *entry = &_stationList[i];
        if (entry->name.characters[0] == 0) { continue; }
        
        NSString * name = [NSString stringWithUTF8String:entry->name.characters];
        BRCStationEntry * stationEntry = [BRCStationEntry new];
        stationEntry.total = entry->total;
        stationEntry.num   = entry->num;
        stationEntry.min   = entry->min;
        stationEntry.max   = entry->max;
        
        results[name] = stationEntry;
    }
    
    return results;
}

@end


#pragma mark - C parsing helpers

#ifdef BETTER_HASH_TEST
static uint32_t MurmurOAAT_32(const uint8_t * data, uint32_t len) {
    // One-byte-at-a-time hash based on Murmur's mix
    // Source: https://github.com/aappleby/smhasher/blob/master/src/Hashes.cpp
    uint32_t h = 0x12345678;
    for (int i=0; i<len; i++) {
        h ^= data[i];
        h *= 0x5bd1e995;
        h ^= h >> 15;
    }
    return h;
}

static uint32_t Jenkins_one_at_a_time_hash(const uint8_t * data, uint32_t len) {
    uint32_t h = 0x12345678;
    for (int i=0; i<len; i++) {
        h += data[i];
        h += (h << 10);
        h ^= (h >> 6);
    }
    h += (h << 3);
    h ^= (h >> 11);
    h += (h << 15);
    return h;
}

#else

static uint32_t simpleHash(const uint8_t * data, uint32_t len) {
    uint32_t h = 0;
    for (int i=0; i<len; i++) {
        h = h*1999 + data[i];
    }
    
    return h;
}
#endif

static uint32_t hash(const uint8_t * data, uint32_t len) {
    uint32_t hash = 0;
#ifdef BETTER_HASH_TEST
    const uint32_t l_mask = 0x0000ffff;
    const uint32_t h_mask = 0xffff0000;
    
    uint32_t h1 = MurmurOAAT_32(data, len);
    uint32_t h2 = Jenkins_one_at_a_time_hash(data, len);
    hash = ((h1 & l_mask) + (h2 & h_mask));
#else
    hash = simpleHash(data, len);
#endif
    
    return hash % STATION_LIST_LEN;
}



static uint32_t parseLine(uint8_t * data, stationName * name, int32_t * temp) {
    uint32_t offsetName = 0;
    uint32_t offsetTemp = 0;
    
    if ((offsetName = parseName(data, name)) == 0) { return 0; }
    if ((offsetTemp = parseTemp(&data[offsetName], temp)) == 0) { return 0; }
    
    return offsetName + offsetTemp;
}

static uint32_t parseName(uint8_t * data, stationName * name) {
    uint32_t offset = 0;
    
    while (data[offset] != ';') {
        if (data[offset] == 0) { return 0; }
        name->characters[offset] = data[offset];
        offset++;
    }
    
    name->characters[offset] = 0;
    name->key = hash(data, offset);
    
    return ++offset;
}

static uint32_t parseTemp(uint8_t * data, int32_t * temp) {
    uint32_t offset = 0;
    
    int8_t multi = 1;
    uint32_t accum = 0;
    
    while (data[offset] != '\n') {
        if (data[offset] == 0) { return 0; }
        
        switch (data[offset]) {
            case '-': { multi = -1; } break;
            case '.': { } break;
            default: {
                uint8_t val = data[offset] - '0';
                ((accum *= 10) && (accum += val)) ||
                (accum = val);
            } break;
        }
        
        offset++;
    }
    
    *temp = (accum * multi);
    
    return ++offset;
}
