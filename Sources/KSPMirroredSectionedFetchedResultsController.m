//
//  KSPMirroredSectionedFetchedResultsController.m
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 25.11.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPMirroredSectionedFetchedResultsController.h"

#import "KSPTableSection.h"

#import "KSPSectionedFetchedResultsControllerDelegate.h"

@implementation KSPMirroredSectionedFetchedResultsController

- (nullable NSArray<__kindof NSManagedObject*>*) mirroredFetchedObjects
{
  return [self.fetchedObjects reverseObjectEnumerator].allObjects;
}

- (nullable NSArray<KSPTableSection*>*) mirroredSections
{
  return [self.sections reverseObjectEnumerator].allObjects;
}

#pragma mark - KPSectionedFetchedResultsController Delegate Stuff

// * * * Sections * * *.

- (void) didInsertSection: (nonnull KSPTableSection*) insertedSection atIndex: (NSUInteger) insertedSectionIndex
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeSection:atIndex:forChangeType:newIndex:)])
  {
    const NSUInteger mirroredIndex = (self.sections.count - insertedSectionIndex - 1);

    [self.delegate controller: self didChangeSection: insertedSection atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: mirroredIndex];
  }
}

- (void) didDeleteSection: (nonnull KSPTableSection*) deletedSection atIndex: (NSUInteger) deletedSectionIndex
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeSection:atIndex:forChangeType:newIndex:)])
  {
    const NSUInteger mirroredIndex = (self.sections.count + 1 - deletedSectionIndex - 1);

    [self.delegate controller: self didChangeSection: deletedSection atIndex: mirroredIndex forChangeType: KSPSectionedFetchedResultsChangeDelete newIndex: NSNotFound];
  }
}

- (void) didMoveSection: (nonnull KSPTableSection*) movedSection atIndex: (NSUInteger) movedSectionIndex toIndex: (NSUInteger) newIndex
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeSection:atIndex:forChangeType:newIndex:)])
  {
    const NSUInteger mirroredMovedSectionIndex = (self.sections.count - movedSectionIndex - 1);

    const NSUInteger mirroredNewIndex = (self.sections.count - newIndex - 1);

    [self.delegate controller: self didChangeSection: movedSection atIndex: mirroredMovedSectionIndex forChangeType: KSPSectionedFetchedResultsChangeMove newIndex: mirroredNewIndex];
  }
}

// * * * Objects * * *.

- (void) willInsertObject: (nonnull NSManagedObject*) insertedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section
{
  if([self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = (section.nestedObjects.count - index);

    [self.delegate controller: self willChangeObject: insertedObject atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: mirroredIndex inSection: section];
  }
}

- (void) didInsertObject: (nonnull NSManagedObject*) insertedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = (section.nestedObjects.count - index - 1);

    [self.delegate controller: self didChangeObject: insertedObject atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: mirroredIndex inSection: section];
  }
}

- (void) willDeleteObject: (nonnull NSManagedObject*) deletedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section
{
  if([self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = (section.nestedObjects.count - index - 1);

    [self.delegate controller: self willChangeObject: deletedObject atIndex: mirroredIndex inSection: section forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];
  }
}

- (void) didDeleteObject: (nonnull NSManagedObject*) deletedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = (section.nestedObjects.count + 1 - index - 1);

    [self.delegate controller: self didChangeObject: deletedObject atIndex: mirroredIndex inSection: section forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];
  }
}

- (void) willMoveObject: (nonnull NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex inSection: (nonnull KSPTableSection*) oldSection newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  if([self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredOldIndex = (oldSection.nestedObjects.count - oldIndex - 1);

    // * * *.

    const BOOL moveIsWithinTheSameSection = (oldSection == newSection);

    const NSUInteger correction = (moveIsWithinTheSameSection? 1 : 0);

    const NSUInteger mirroredNewIndex = (newSection.nestedObjects.count - correction - newIndex);

    // * * *.

    [self.delegate controller: self willChangeObject: movedObject atIndex: mirroredOldIndex inSection: oldSection forChangeType: KSPFetchedResultsChangeMove newIndex: mirroredNewIndex inSection: newSection];
  }
}

- (void) didMoveObject: (nonnull NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex inSection: (nonnull KSPTableSection*) oldSection newIndex: (NSUInteger) newIndex inSection: (nonnull KSPTableSection*) newSection
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const BOOL moveIsWithinTheSameSection = (oldSection == newSection);

    const NSUInteger correction = (moveIsWithinTheSameSection? 0 : 1);

    const NSUInteger mirroredOldIndex = (oldSection.nestedObjects.count + correction - oldIndex - 1);

    const NSUInteger mirroredNewIndex = (newSection.nestedObjects.count - newIndex - 1);

    [self.delegate controller: self didChangeObject: movedObject atIndex: mirroredOldIndex inSection: oldSection forChangeType: KSPFetchedResultsChangeMove newIndex: mirroredNewIndex inSection: newSection];
  }
}

- (void) willUpdateObject: (nonnull NSManagedObject*) updatedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section newIndex: (NSUInteger) newIndex inSection: (nullable KSPTableSection*) newSection
{
  if([self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = (section.nestedObjects.count - index - 1);

    [self.delegate controller: self willChangeObject: updatedObject atIndex: mirroredIndex inSection: section forChangeType: KSPFetchedResultsChangeUpdate newIndex: newIndex inSection: newSection];
  }
}

- (void) didUpdateObject: (nonnull NSManagedObject*) updatedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section newIndex: (NSUInteger) newIndex inSection: (nullable KSPTableSection*) newSection
{
  if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)])
  {
    const NSUInteger mirroredIndex = (section.nestedObjects.count - index - 1);

    [self.delegate controller: self didChangeObject: updatedObject atIndex: mirroredIndex inSection: section forChangeType: KSPFetchedResultsChangeUpdate newIndex: newIndex inSection: newSection];
  }
}

@end
