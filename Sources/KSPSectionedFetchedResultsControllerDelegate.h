//
//  KPSectionedFetchResultsControllerDelegate.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2016 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPFetchedResultsControllerDelegate.h"

// * * *.

typedef NS_ENUM(NSUInteger, KSPSectionedFetchedResultsChangeType)
{
  // A new section was inserted.
  KSPSectionedFetchedResultsChangeInsert,

  // An existing section was deleted.
  KSPSectionedFetchedResultsChangeDelete,

  // An existing section was moved (a move also assumes an update).
  KSPSectionedFetchedResultsChangeMove,
};

// * * *.

@class KSPSectionedFetchedResultsController;

@class KSPTableSection;

@class NSManagedObject;

// * * *.

@protocol KSPSectionedFetchedResultsControllerDelegate <KSPFetchedResultsControllerDelegate>

@optional

// The KSPFetchedResultsControllerDelegate method -controller:willChangeObject:atIndex:forChangeType:newIndex: is not called!

// The KSPFetchedResultsControllerDelegate method -controller:didChangeObject:atIndex:forChangeType:newIndex: is not called!

- (void) controller: (nonnull KSPSectionedFetchedResultsController*) controller willChangeObject: (nonnull NSManagedObject*) anObject atIndex: (NSUInteger) index inSection: (nullable KSPTableSection*) section forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex inSection: (nullable KSPTableSection*) newSection;

- (void) controller: (nonnull KSPSectionedFetchedResultsController*) controller didChangeObject: (nonnull NSManagedObject*) anObject atIndex: (NSUInteger) index inSection: (nullable KSPTableSection*) section forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex inSection: (nullable KSPTableSection*) newSection;

// * * *.

- (void) controller: (nonnull KSPSectionedFetchedResultsController*) controller didChangeSection: (nonnull KSPTableSection*) section atIndex: (NSUInteger) index forChangeType: (KSPSectionedFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

@end
