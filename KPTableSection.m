//
//  KPTableSection.m
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPTableSection+Private.h"

@class NSManagedObject;

@implementation KPTableSection
{
  NSMutableArray* _nestedObjectsBackingStore;
}

- (instancetype) initWithSectionName: (id<NSObject>) sectionName nestedObjects: (NSArray*) nestedObjects
{
  NSParameterAssert(sectionName);
  
  self = [super init];
  
  if(!self) return nil;
  
  _sectionName = sectionName;
  
  _nestedObjectsBackingStore = nestedObjects? [nestedObjects mutableCopy] : [NSMutableArray array];
  
  return self;
}

// TODO: isEqual:

#pragma mark - nestedObjects Collection KVC Implementation

- (NSArray*) nestedObjects
{
  return [_nestedObjectsBackingStore copy];
}

// Danger mode ON!
- (NSArray*) nestedObjectsNoCopy
{
  return _nestedObjectsBackingStore;
}

- (void) setNestedObjects: (NSArray*) sections
{
  _nestedObjectsBackingStore = [sections mutableCopy];
}

- (NSUInteger) countOfSections
{
  return [_nestedObjectsBackingStore count];
}

- (KPTableSection*) objectInSectionsAtIndex: (NSUInteger) index
{
  return [_nestedObjectsBackingStore objectAtIndex: index];
}

- (NSArray*) sectionsAtIndexes: (NSIndexSet*) indexes
{
  return [_nestedObjectsBackingStore objectsAtIndexes: indexes];
}

- (void) getSections: (NSManagedObject* __unsafe_unretained*) buffer range: (NSRange) inRange
{
  [_nestedObjectsBackingStore getObjects: buffer range: inRange];
}

- (void) insertObject: (NSManagedObject*) object inSectionsAtIndex: (NSUInteger) index
{
  [_nestedObjectsBackingStore insertObject: object atIndex: index];
}

- (void) removeObjectFromSectionsAtIndex: (NSUInteger) index
{
  [_nestedObjectsBackingStore removeObjectAtIndex: index];
}

- (void) insertSections: (NSArray*) array atIndexes: (NSIndexSet*) indexes
{
  [_nestedObjectsBackingStore insertObjects: array atIndexes: indexes];
}

- (void) removeSectionsAtIndexes: (NSIndexSet*) indexes
{
  [_nestedObjectsBackingStore removeObjectsAtIndexes: indexes];
}

- (void) replaceObjectInSectionsAtIndex: (NSUInteger) index withObject: (NSManagedObject*) object
{
  [_nestedObjectsBackingStore replaceObjectAtIndex: index withObject: object];
}

- (void) replaceSectionsAtIndexes: (NSIndexSet*) indexes withSections: (NSArray*) array
{
  [_nestedObjectsBackingStore replaceObjectsAtIndexes: indexes withObjects: array];
}

@end
