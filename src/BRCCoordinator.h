//
//  BRCCoordinator.h
//  calc_1brc
//
//  Created by Earl Robsham on 7/3/24.
//

#import <Foundation/Foundation.h>

@interface BRCCoordinator : NSObject

-(instancetype)initWith:(NSString*)path numWorkers:(uint8_t)numWorkers;

-(void) run;

-(void) printStats;
-(void) outputResults;

@end
