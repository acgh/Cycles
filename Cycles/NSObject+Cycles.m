//
//  NSObject+Cycles.m
//  Cycles
//
//  Created by Alexandre on 15/10/2014.
//  Copyright (c) 2014 ALC. All rights reserved.
//

#import "NSObject+Cycles.h"
#import <objc/runtime.h>

@interface Queue : NSObject

-(void)enqueue:(id)object;
-(void)enqueueObjects:(NSArray *)objects;
-(id)dequeue;

@end

@interface Queue ()

// Yeah...busted, let's pretend it's properly implemented with a linked list (please see Quinn Taylor's CHDatasStructures)
@property (nonatomic) NSMutableArray * objects;

@end

@implementation Queue

-(id)init
{
    if (self = [super init]) {
        _objects = [NSMutableArray new];
    }
    
    return self;
}

-(void)enqueue:(id)object
{
    [_objects addObject:object];
}

-(void)enqueueObjects:(NSArray *)objects
{
    for (id object in objects) {
        [self enqueue:object];
    }
}

-(id)dequeue
{
    id object = [_objects firstObject];
    if (object) {
        [_objects removeObjectAtIndex:0];
    }
    return object;
}

-(NSString *)description
{
    return [_objects description];
}

@end

#pragma mark -

@interface ObjectRelation : NSObject

-(instancetype)initWithName:(NSString *)name toObject:(id)toObject;

@property (nonatomic) NSString * name;
@property (nonatomic, weak) id toObject;

// The preceding relations chain will be needed to do the backtracking at the end
@property (nonatomic, strong) ObjectRelation * fromRelation;

// A set of pointers of the objects that belong to the path from the `root` to the last `toObject`.
// The path could be looked into from the preceding-relations chain, but this set is a shortcut to avoid a potentially long backtracking for this particular purpose.
@property (nonatomic) NSSet * knownObjects;

-(NSString *)relationDescription;

@end

@implementation ObjectRelation

-(instancetype)initWithName:(NSString *)name toObject:(id)toObject
{
    if (self = [super init]) {
        _name = name;
        _toObject = toObject;
        _knownObjects = [NSSet setWithObject:@((NSUInteger)toObject)];
    }
    return self;
}

-(void)linkToPrecedingRelation:(ObjectRelation *)fromRelation
{
    self.fromRelation = fromRelation;
    
    if (fromRelation) {
        self.knownObjects = [fromRelation.knownObjects setByAddingObjectsFromSet:self.knownObjects];
    }
}

-(void)followingRelations:(void(^)(NSArray *, NSArray *))block
{
    NSArray * followingRelations = [self.toObject strongRelations];
    NSMutableArray * followableRelations = [NSMutableArray new];
    NSMutableArray * cyclingRelations = [NSMutableArray new];
    
    for (ObjectRelation * relation in followingRelations) {
        [relation linkToPrecedingRelation:self];
        
        if (NO == [self.knownObjects containsObject:@((NSUInteger)relation.toObject)]) {
            [followableRelations addObject:relation];
        }
        else {
            [cyclingRelations addObject:relation];
        }
    }
    
    block(followableRelations, cyclingRelations);
}

-(NSString *)description
{
    return [self relationDescription];
}

-(NSString *)relationDescription
{
    NSString * precedingDescription = [self.fromRelation relationDescription];
    NSString * selfDescription = [NSString stringWithFormat:@".%@->%@[%p]", self.name, [self.toObject class], self.toObject];
    if (precedingDescription) {
        selfDescription = [precedingDescription stringByAppendingString:selfDescription];
    }
    return selfDescription;
}

@end

#pragma mark -

@implementation NSObject (Cycles)

- (NSArray *)strongRelations
{
    NSMutableArray * relations = [NSMutableArray new];
    
    unsigned int numberOfProperties = 0;
    objc_property_t * propertyList = class_copyPropertyList(self.class, &numberOfProperties);
    
    for (NSUInteger i = 0; i < numberOfProperties; i++) {
        objc_property_t property = propertyList[i];
        
        unsigned int numberOfAttributes = 0;
        objc_property_attribute_t * propertyAttributes = property_copyAttributeList(property, &numberOfAttributes);
        for (unsigned int j = 0; j < numberOfAttributes; j++) {
            // & denotes a strong relationship attribute (by opposition to W):
            if (propertyAttributes[j].name[0] == '&') {
                NSString * key = [NSString stringWithUTF8String:property_getName(property)];
                NSString * value = [self valueForKey:key];
                if (value) {
                    ObjectRelation * relation = [[ObjectRelation alloc] initWithName:key toObject:value];
                    [relations addObject:relation];
                }
                break;
            }
        }
        free(propertyAttributes);
    }
    free(propertyList);
    
    return relations;
}

- (NSArray *)findCycleDescriptions
{
    // Will perform a Breadth-First-Search to find cycles
    Queue * queue = [Queue new];
    NSMutableArray * cycles = [NSMutableArray new];
    
    // The root of the in-memory graph to search
    ObjectRelation * aRelation = [[ObjectRelation alloc] initWithName:@"" toObject:self];
    
    while (aRelation) {
        @autoreleasepool {
            [aRelation followingRelations:^(NSArray * followableRelations, NSArray * cyclingRelations){
                [queue enqueueObjects:followableRelations];
                [cycles addObjectsFromArray:[cyclingRelations valueForKey:@"description"]];
            }];
            aRelation.knownObjects = nil;
            aRelation = (ObjectRelation *)[queue dequeue];
        }
    }
    
    return cycles;
}

@end

@implementation NSDictionary (Cycles)

- (NSArray *)strongRelations
{
    NSMutableArray * relations = [NSMutableArray new];
    
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL * stop){
        ObjectRelation * relation = [[ObjectRelation alloc] initWithName:[key description] toObject:value];
        [relations addObject:relation];
    }];
    
    return relations;
}

@end

@implementation NSArray (Cycles)

- (NSArray *)strongRelations
{
    NSMutableArray * relations = [NSMutableArray new];
    
    [self enumerateObjectsUsingBlock:^(id value, NSUInteger relationIndex, BOOL * stop){
        ObjectRelation * relation = [[ObjectRelation alloc] initWithName:[NSString stringWithFormat:@"%lu", relationIndex] toObject:value];
        [relations addObject:relation];
    }];
    
    return relations;
}

@end

@implementation NSSet (Cycles)

- (NSArray *)strongRelations
{
    return [[self allObjects] strongRelations];
}

@end
