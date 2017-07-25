//
//  KPTableSection.m
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2016 Konstantin Pavlikhin. All rights reserved.
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

- (nullable instancetype) init
{
  NSAssert(NO, @"Use -%@.", NSStringFromSelector(@selector(initWithSectionName:nestedObjects:)));

  return nil;
}

- (nullable instancetype) initWithSectionName: (nonnull NSObject*) sectionName nestedObjects: (nullable NSArray<NSManagedObject*>*) nestedObjects
{
  NSParameterAssert(sectionName);

  // * * *.

  self = [super init];
  
  if(!self) return nil;
  
  _sectionName = [sectionName copy];
  
  _nestedObjectsBackingStore = (nestedObjects? [nestedObjects mutableCopy] : [NSMutableArray array]);
  
  return self;
}

#pragma mark - nestedObjects Collection KVC Implementation

- (nullable NSArray<__kindof NSManagedObject*>*) nestedObjects
{
  return [_nestedObjectsBackingStore copy];
}

- (nullable NSArray<__kindof NSManagedObject*>*) nestedObjectsNoCopy
{
  return _nestedObjectsBackingStore;
}

- (void) setNestedObjects: (nullable NSArray<__kindof NSManagedObject*>*) nestedObjects
{
  _nestedObjectsBackingStore = [nestedObjects mutableCopy];
}

- (NSUInteger) countOfNestedObjects
{
  return _nestedObjectsBackingStore.count;
}

- (nonnull NSManagedObject*) objectInNestedObjectsAtIndex: (NSUInteger) index
{
  return [_nestedObjectsBackingStore objectAtIndex: index];
}

- (nonnull NSArray<__kindof NSManagedObject*>*) nestedObjectsAtIndexes: (nonnull NSIndexSet*) indexes
{
  return [_nestedObjectsBackingStore objectsAtIndexes: indexes];
}

- (void) getNestedObjects: (NSManagedObject* __unsafe_unretained*) buffer range: (NSRange) inRange
{
  [_nestedObjectsBackingStore getObjects: buffer range: inRange];
}

- (void) insertObject: (nonnull NSManagedObject*) object inNestedObjectsAtIndex: (NSUInteger) index
{
  [_nestedObjectsBackingStore insertObject: object atIndex: index];
}

- (void) removeObjectFromNestedObjectsAtIndex: (NSUInteger) index
{
  [_nestedObjectsBackingStore removeObjectAtIndex: index];
}

- (void) insertNestedObjects: (NSArray<__kindof NSManagedObject*>*) array atIndexes: (nonnull NSIndexSet*) indexes
{
  [_nestedObjectsBackingStore insertObjects: array atIndexes: indexes];
}

- (void) removeNestedObjectsAtIndexes: (nonnull NSIndexSet*) indexes
{
  [_nestedObjectsBackingStore removeObjectsAtIndexes: indexes];
}

- (void) replaceObjectInNestedObjectsAtIndex: (NSUInteger) index withObject: (nonnull NSManagedObject*) object
{
  [_nestedObjectsBackingStore replaceObjectAtIndex: index withObject: object];
}

- (void) replaceNestedObjectsAtIndexes: (nonnull NSIndexSet*) indexes withNestedObjects: (nonnull NSArray<__kindof NSManagedObject*>*) array
{
  [_nestedObjectsBackingStore replaceObjectsAtIndexes: indexes withObjects: array];
}

@end
