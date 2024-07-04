//
//  BRCStationEntry.h
//  calc_1brc
//
//  Created by Earl Robsham on 7/3/24.
//

#import <Foundation/Foundation.h>

@interface BRCStationEntry : NSObject
// average tracking
@property (nonatomic, assign) NSInteger  total;
@property (nonatomic, assign) NSUInteger num;

@property (nonatomic, assign) NSInteger min;
@property (nonatomic, assign) NSInteger max;
@end
