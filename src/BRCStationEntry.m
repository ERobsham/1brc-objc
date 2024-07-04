//
//  BRCStationEntry.m
//  calc_1brc
//
//  Created by Earl Robsham on 7/3/24.
//

#import "BRCStationEntry.h"

@implementation BRCStationEntry

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
