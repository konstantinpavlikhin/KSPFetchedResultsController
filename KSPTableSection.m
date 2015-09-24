//
//  KPTableSection.m
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPTableSection+Private.h"

// * * *.

@class NSManagedObject;

// * * *.

@implementation KSPTableSection
{
  NSMutableArray<NSManagedObject*>* _nestedObjectsBackingStore;
}

#pragma mark - Initialization

- (instancetype) initWithSectionName: (NSObject*) sectionName nestedObjects: (NSArray<NSManagedObject*>*) nestedObjects
{
  NSParameterAssert(sectionName);

  // * * *.

  self = [super init];
  
  if(!self) return nil;
  
  _sectionName = [sectionName copy];
  
  _nestedObjectsBackingStore = nestedObjects? [nestedObjects mutableCopy] : [NSMutableArray array];
  
  return self;
}

#pragma mark - Equality Testing

- (BOOL) isEqual: (id) object
{
  if(self == object) return YES;
  
  if(![object isKindOfClass: [self class]]) return NO;
  
  return [self isEqualToTableSection: object];
}

- (BOOL) isEqualToTableSection: (KSPTableSection*) section
{
  // We intentionally do not compare nestedObjects here.
  return [self.sectionName isEqual: section.sectionName];
}

- (NSUInteger) hash
{
  // We intentionally do not include nestedObjects hash here.
  return [self.sectionName hash];
}

#pragma mark - nestedObjects Collection KVC Implementation

- (NSArray<__kindof NSManagedObject*>*) nestedObjects
{
  return [_nestedObjectsBackingStore copy];
}

// Danger mode ON!
- (NSArray<__kindof NSManagedObject*>*) nestedObjectsNoCopy
{
  return _nestedObjectsBackingStore;
}

- (void) setNestedObjects: (NSArray<__kindof NSManagedObject*>*) nestedObjects
{
  _nestedObjectsBackingStore = [nestedObjects mutableCopy];
}

- (NSUInteger) countOfNestedObjects
{
  return _nestedObjectsBackingStore.count;
}

- (NSManagedObject*) objectInNestedObjectsAtIndex: (NSUInteger) index
{
  return [_nestedObjectsBackingStore objectAtIndex: index];
}

- (NSArray<__kindof NSManagedObject*>*) nestedObjectsAtIndexes: (NSIndexSet*) indexes
{
  return [_nestedObjectsBackingStore objectsAtIndexes: indexes];
}

- (void) getNestedObjects: (NSManagedObject* __unsafe_unretained*) buffer range: (NSRange) inRange
{
  [_nestedObjectsBackingStore getObjects: buffer range: inRange];
}

- (void) insertObject: (NSManagedObject*) object inNestedObjectsAtIndex: (NSUInteger) index
{
  [_nestedObjectsBackingStore insertObject: object atIndex: index];
}

- (void) removeObjectFromNestedObjectsAtIndex: (NSUInteger) index
{
  [_nestedObjectsBackingStore removeObjectAtIndex: index];
}

- (void) insertNestedObjects: (NSArray<__kindof NSManagedObject*>*) array atIndexes: (NSIndexSet*) indexes
{
  [_nestedObjectsBackingStore insertObjects: array atIndexes: indexes];
}

- (void) removeNestedObjectsAtIndexes: (NSIndexSet*) indexes
{
  [_nestedObjectsBackingStore removeObjectsAtIndexes: indexes];
}

- (void) replaceObjectInNestedObjectsAtIndex: (NSUInteger) index withObject: (NSManagedObject*) object
{
  [_nestedObjectsBackingStore replaceObjectAtIndex: index withObject: object];
}

- (void) replaceNestedObjectsAtIndexes: (NSIndexSet*) indexes withNestedObjects: (NSArray<__kindof NSManagedObject*>*) array
{
  [_nestedObjectsBackingStore replaceObjectsAtIndexes: indexes withObjects: array];
}

@end
