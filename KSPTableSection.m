//
//  KPTableSection.m
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
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

- (void) setNestedObjects: (NSArray<__kindof NSManagedObject*>*) sections
{
  _nestedObjectsBackingStore = [sections mutableCopy];
}

- (NSUInteger) countOfSections
{
  return _nestedObjectsBackingStore.count;
}

- (NSManagedObject*) objectInSectionsAtIndex: (NSUInteger) index
{
  return [_nestedObjectsBackingStore objectAtIndex: index];
}

- (NSArray<__kindof NSManagedObject*>*) sectionsAtIndexes: (NSIndexSet*) indexes
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

- (void) insertSections: (NSArray<__kindof NSManagedObject*>*) array atIndexes: (NSIndexSet*) indexes
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

- (void) replaceSectionsAtIndexes: (NSIndexSet*) indexes withSections: (NSArray<__kindof NSManagedObject*>*) array
{
  [_nestedObjectsBackingStore replaceObjectsAtIndexes: indexes withObjects: array];
}

@end
