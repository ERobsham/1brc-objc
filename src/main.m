//
//  main.m
//  calc_1brc
//
//  Created by Earl Robsham on 6/29/24.
//

#import <Foundation/Foundation.h>

#define DATA_DIR [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:@"data"]

//#define DATA_FILE @"measurements-100k.txt"
//#define DATA_FILE @"measurements-1m.txt"
//#define DATA_FILE @"measurements-10m.txt"
//#define DATA_FILE @"measurements-100m.txt"
#define DATA_FILE @"measurements.txt"

//#define DEBUG_LOGS
#define WRITE_OUTPUT

typedef union {
    char characters[101];
} stationName;

static const uint32_t BUFF_LEN = (1<<15);
static const uint32_t NUM_STATIONS = 10000;

static uint32_t parseLine(uint8_t * data, stationName * name, int32_t * temp);
static uint32_t parseName(uint8_t * data, stationName * name);
static uint32_t parseTemp(uint8_t * data, int32_t * temp);


@interface StationEntry : NSObject
// average tracking
@property (nonatomic, assign) NSInteger  total;
@property (nonatomic, assign) NSUInteger num;

@property (nonatomic, assign) NSInteger min;
@property (nonatomic, assign) NSInteger max;
@end


int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSString * path = [DATA_DIR stringByAppendingPathComponent:DATA_FILE];
#ifdef DEBUG_LOGS
        NSLog(@"parsing file at path: %@", path);
#endif
        
        NSInputStream * stream = [NSInputStream inputStreamWithFileAtPath:path];
        NSUInteger bytesRead = 0;
        [stream open];
        
        uint8_t buf[BUFF_LEN] = {0};
        uint32_t leftover = 0;
        uint32_t remainingLen = (BUFF_LEN - 1);
        uint32_t linesRead = 0;
        
        NSMutableDictionary<NSString *, StationEntry *> * stationInfo = [NSMutableDictionary dictionaryWithCapacity:NUM_STATIONS];
        
        while ((bytesRead = [stream read:&buf[leftover]
                               maxLength:remainingLen]) > 0) {
            if (bytesRead < remainingLen) {
                buf[bytesRead+1] = 0;
            }
            
            stationName nameBuf = {0};
            int32_t temp = 0;
            uint32_t offset = 0;
            uint32_t lineOffset = 0;
            while ((lineOffset = parseLine(&buf[offset], &nameBuf, &temp)) > 0) {
                offset += lineOffset;
                linesRead++;
                
                NSString * name = [NSString stringWithUTF8String:nameBuf.characters];
                StationEntry * entry = stationInfo[name];
                if (entry == nil) {
                    entry = [StationEntry new];
                    stationInfo[name] = entry;
                }
                
                entry.total += temp;
                entry.num += 1;
                entry.min = MIN(entry.min, temp);
                entry.max = MAX(entry.max, temp);
            }
            
            
            // shuffle any remaining bytes to the front of the buffer
            uint32_t idx = 0;
            while (offset < (BUFF_LEN-1)) {
                buf[idx++] = buf[offset++];
            }
            
            leftover = idx;
            remainingLen = (BUFF_LEN - (leftover + 1));
        }
        [stream close];
        
        
        NSArray<NSString *> * stationNameList = [stationInfo allKeys];
        stationNameList = [stationNameList sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [obj1 compare:obj2];
        }];

#ifdef DEBUG_LOGS
        NSLog(@"read %d lines and found %ld unique stations", linesRead, [stationNameList count]);
#endif
        
#ifdef WRITE_OUTPUT
        fprintf(stdout, "{");
        NSUInteger idx = 0;
        for (NSString * name in stationNameList) {
            StationEntry *entry = stationInfo[name];
            
            fprintf(stdout, "%s=%s",
                    [name cStringUsingEncoding:NSUTF8StringEncoding],
                    [[entry description] cStringUsingEncoding:NSUTF8StringEncoding]);
            
            if (++idx != [stationNameList count]) {
                fprintf(stdout, ", ");
            }
        }
        fprintf(stdout, "}\n");
#endif
    }
    return 0;
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

@implementation StationEntry

- (instancetype)init {
    self = [super init];
    if (self) {
        self.min = NSIntegerMax;
        self.max = NSIntegerMin;
    }
    return self;
}

- (NSString *)description {
    double min  = (double)self.min / 10.0;
    double mean = ((double)self.total / (double)self.num) / 10.0;
    double max  = (double)self.max / 10.0;
    
    return [NSString stringWithFormat:@"%.1f/%.1f/%.1f", min, mean, max];
}

@end
