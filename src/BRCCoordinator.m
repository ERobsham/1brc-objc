//
//  BRCCoordinator.m
//  calc_1brc
//
//  Created by Earl Robsham on 7/3/24.
//

#import "BRCCoordinator.h"
#import "BRCFileReader.h"
#import "BRCWorker.h"
#import "BRCStationEntry.h"

// how many extra buffers should we have (above the number of workers we have)
static const uint32_t BUF_BUFFER = 2;

@interface BRCCoordinator ()
@property (nonatomic, retain) BRCFileReader * reader;
@property (nonatomic, retain) NSMutableArray<BRCWorker *> * workers;

@property (nonatomic, assign) uint32_t linesRead;
@property (nonatomic, retain) NSMutableDictionary<NSString*, BRCStationEntry*> * results;

@property (nonatomic, assign) NSThread * mainThread;
@end

@implementation BRCCoordinator

- (instancetype)initWith:(NSString *)path numWorkers:(uint8_t)numWorkers {
    self = [super init];
    if (self) {
        self.mainThread = [NSThread currentThread];
        self.reader = [[BRCFileReader alloc] initWith:path andBuffers:numWorkers+BUF_BUFFER];
        self.results = [NSMutableDictionary dictionaryWithCapacity:MAX_NUM_STATIONS];
        
        self.workers = [NSMutableArray arrayWithCapacity:numWorkers];
        for (int i = 0; i<numWorkers; i++) {
            BRCWorker *worker = [[BRCWorker alloc] initWith:self.reader];
            [self.workers addObject:worker];
        }
    }
    return self;
}

- (void)run {
    while ([self.workers count] > 0) {
        
        NSMutableIndexSet * indexes = [NSMutableIndexSet new];
        for (BRCWorker * worker in self.workers) {
            if (!worker.isDone) { continue; }
            
            NSDictionary * results = [worker stationReport];
            self.linesRead += worker.linesRead;
            
            [self performSelector:@selector(processResults:) onThread:self.mainThread withObject:results waitUntilDone:NO];
            [indexes addIndex:[self.workers indexOfObject:worker]];
        }
        [self.workers removeObjectsAtIndexes:indexes];
        
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
    }
}

-(void)processResults:(NSDictionary<NSString *, BRCStationEntry *> *)results {
    for (NSString * name in results) {
        BRCStationEntry * newEntry = results[name];
        BRCStationEntry * existingEntry = self.results[name];
        
        if (existingEntry == nil) {
            self.results[name] = newEntry;
            continue;
        }
        
        existingEntry.num += newEntry.num;
        existingEntry.total += newEntry.total;
        
        existingEntry.min = MIN(newEntry.min, existingEntry.min);
        existingEntry.max = MAX(newEntry.max, existingEntry.max);
    }
}

- (void)printStats {
    NSLog(@"read %d lines and found %ld unique stations", self.linesRead, [self.results count]);
}

- (void)outputResults {
    NSArray<NSString *> * stationNameList = [[self.results allKeys] sortedArrayUsingSelector:@selector(compare:)];
    fprintf(stdout, "{");
    NSUInteger idx = 0;
    for (NSString * name in stationNameList) {
        BRCStationEntry *entry = self.results[name];
        
        fprintf(stdout, "%s=%s",
                [name cStringUsingEncoding:NSUTF8StringEncoding],
                [[entry description] cStringUsingEncoding:NSUTF8StringEncoding]);
        
        if (++idx != [stationNameList count]) {
            fprintf(stdout, ", ");
        }
    }
    fprintf(stdout, "}\n");
}

@end
