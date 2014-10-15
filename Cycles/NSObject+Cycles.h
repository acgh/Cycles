//
//  NSObject+Cycles.h
//  Cycles
//
//  Created by Alexandre on 15/10/2014.
//  Copyright (c) 2014 ALC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (Cycles)

- (NSArray *)strongRelations;
- (NSArray *)findCycleDescriptions;

@end
