//
//  KSPMirroredSectionedFetchedResultsController.m
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 25.11.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPMirroredSectionedFetchedResultsController.h"

#import "KSPTableSection.h"

#import "KSPSectionedFetchedResultsControllerDelegate.h"

@implementation KSPMirroredSectionedFetchedResultsController

- (NSArray*) mirroredFetchedObjects
{
  return [self.fetchedObjects reverseObjectEnumerator].allObjects;
}

- (NSArray*) mirroredSections
{
  return [self.sections reverseObjectEnumerator].allObjects;
}

#pragma mark - Работа с делегатом KPSectionedFetchedResultsController

// * * * Секции * * *.

- (void) didInsertSection: (KSPTableSection*) insertedSection atIndex: (NSUInteger) insertedSectionIndex
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeSection:atIndex:forChangeType:newIndex:)])
  {
    const NSUInteger mirroredIndex = self.sections.count - insertedSectionIndex - 1;

    [self.delegate controller: self didChangeSection: insertedSection atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: mirroredIndex];
  }
}

- (void) didDeleteSection: (KSPTableSection*) deletedSection atIndex: (NSUInteger) deletedSectionIndex
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeSection:atIndex:forChangeType:newIndex:)])
  {
    const NSUInteger mirroredIndex = self.sections.count + 1 - deletedSectionIndex - 1;

    [self.delegate controller: self didChangeSection: deletedSection atIndex: mirroredIndex forChangeType: KSPSectionedFetchedResultsChangeDelete newIndex: NSNotFound];
  }
}

- (void) didMoveSection: (KSPTableSection*) movedSection atIndex: (NSUInteger) movedSectionIndex toIndex: (NSUInteger) newIndex
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeSection:atIndex:forChangeType:newIndex:)])
  {
    const NSUInteger mirroredMovedSectionIndex = self.sections.count - movedSectionIndex - 1;

    const NSUInteger mirroredNewIndex = self.sections.count - newIndex - 1;

    [self.delegate controller: self didChangeSection: movedSection atIndex: mirroredMovedSectionIndex forChangeType: KSPSectionedFetchedResultsChangeMove newIndex: mirroredNewIndex];
  }
}

// * * * Объекты * * *.

- (void) willInsertObject: (NSManagedObject*) insertedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section
{
  if([self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = section.nestedObjects.count - index;

    [self.delegate controller: self willChangeObject: insertedObject atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: mirroredIndex inSection: section];
  }
}

- (void) didInsertObject: (NSManagedObject*) insertedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = section.nestedObjects.count - index - 1;

    [self.delegate controller: self didChangeObject: insertedObject atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: mirroredIndex inSection: section];
  }
}

- (void) willDeleteObject: (NSManagedObject*) deletedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section
{
  if([self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = section.nestedObjects.count - index - 1;

    [self.delegate controller: self willChangeObject: deletedObject atIndex: mirroredIndex inSection: section forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];
  }
}

- (void) didDeleteObject: (NSManagedObject*) deletedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = section.nestedObjects.count + 1 - index - 1;

    [self.delegate controller: self didChangeObject: deletedObject atIndex: mirroredIndex inSection: section forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];
  }
}

- (void) willMoveObject: (NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex inSection: (KSPTableSection*) oldSection newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  if([self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredOldIndex = oldSection.nestedObjects.count - oldIndex - 1;

    // * * *.

    const BOOL moveIsWithinTheSameSection = (oldSection == newSection);

    const NSUInteger correction = moveIsWithinTheSameSection? 1 : 0;

    const NSUInteger mirroredNewIndex = newSection.nestedObjects.count - correction - newIndex;

    // * * *.

    [self.delegate controller: self willChangeObject: movedObject atIndex: mirroredOldIndex inSection: oldSection forChangeType: KSPFetchedResultsChangeMove newIndex: mirroredNewIndex inSection: newSection];
  }
}

- (void) didMoveObject: (NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex inSection: (KSPTableSection*) oldSection newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const BOOL moveIsWithinTheSameSection = (oldSection == newSection);

    const NSUInteger correction = moveIsWithinTheSameSection? 0 : 1;

    const NSUInteger mirroredOldIndex = oldSection.nestedObjects.count + correction - oldIndex - 1;

    const NSUInteger mirroredNewIndex = newSection.nestedObjects.count - newIndex - 1;

    [self.delegate controller: self didChangeObject: movedObject atIndex: mirroredOldIndex inSection: oldSection forChangeType: KSPFetchedResultsChangeMove newIndex: mirroredNewIndex inSection: newSection];
  }
}

- (void) willUpdateObject: (NSManagedObject*) updatedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  if([self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = section.nestedObjects.count - index - 1;

    [self.delegate controller: self willChangeObject: updatedObject atIndex: mirroredIndex inSection: section forChangeType: KSPFetchedResultsChangeUpdate newIndex: newIndex inSection: newSection];
  }
}

- (void) didUpdateObject: (NSManagedObject*) updatedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = section.nestedObjects.count - index - 1;

    [self.delegate controller: self didChangeObject: updatedObject atIndex: mirroredIndex inSection: section forChangeType: KSPFetchedResultsChangeUpdate newIndex: newIndex inSection: newSection];
  }
}

@end
