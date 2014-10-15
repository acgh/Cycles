//
//  main.m
//  Cycles
//
//  Created by Alexandre on 14/10/2014.
//  Copyright (c) 2014 ALC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+Cycles.h"

@interface SomeClass : NSObject

@property (nonatomic, strong) id object;

@end

@implementation SomeClass

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        // Feel free to test a more complex graph...
        SomeClass * someObject = [SomeClass new];
        NSSet * set = [NSSet setWithObject:someObject];
        someObject.object = @{@"set": set};
        
        NSArray * cycles = [someObject findCycleDescriptions];
        if (0 < cycles.count) {
            NSLog(@"Cycles:");
            for (NSString * cycleDescription in cycles) {
                NSLog(@"%@", cycleDescription);
            }
        }
        else {
            NSLog(@"No cycle :(");
        }
    }
    return 0;
}
