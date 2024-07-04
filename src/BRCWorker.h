//
//  BRCWorker.h
//  calc_1brc
//
//  Created by Earl Robsham on 7/3/24.
//

#import <Foundation/Foundation.h>
#import "BRCFileReader.h"
#import "BRCStationEntry.h"

//#define HASH_CHECK
//#define BETTER_HASH_TEST

static const uint32_t MAX_STATIONS_NAME_LEN = 100;
static const uint32_t MAX_NUM_STATIONS      = 10000;

#ifdef BETTER_HASH_TEST
static const uint32_t STATION_LIST_LEN      = INT32_MAX / 512;
#else
static const uint32_t STATION_LIST_LEN      = MAX_NUM_STATIONS;
#endif

@interface BRCWorker : NSObject

@property (readonly) BOOL isDone;
@property (readonly) uint32_t linesRead;

-(instancetype)initWith:(id<BRCDataLoader>)dataLoader;

-(NSMutableDictionary<NSString *, BRCStationEntry *> *)stationReport;

@end
