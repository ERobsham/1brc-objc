//
//  main.m
//  calc_1brc
//
//  Created by Earl Robsham on 6/29/24.
//

#import <Foundation/Foundation.h>
#import "BRCCoordinator.h"

#define DATA_DIR [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:@"data"]

//#define DATA_FILE @"measurements-100k.txt"
//#define DATA_FILE @"measurements-1m.txt"
//#define DATA_FILE @"measurements-10m.txt"
//#define DATA_FILE @"measurements-100m.txt"
#define DATA_FILE @"measurements.txt"

//#define DEBUG_LOGS
#define WRITE_OUTPUT

static const uint8_t NUM_CORES = 4;


int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSString * path = [DATA_DIR stringByAppendingPathComponent:DATA_FILE];
#ifdef DEBUG_LOGS
        NSLog(@"parsing file at path: %@", path);
#endif
        
        BRCCoordinator * coordinator = [[BRCCoordinator alloc] initWith:path numWorkers:NUM_CORES];
        
        [coordinator run];

#ifdef DEBUG_LOGS
        [coordinator printStats];
#endif
        
#ifdef WRITE_OUTPUT
        [coordinator outputResults];
#endif
    }
    return 0;
}
