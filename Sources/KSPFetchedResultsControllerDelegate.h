//
//  KSPFetchedResultsControllerDelegate.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2016 Konstantin Pavlikhin. All rights reserved.
//

#import <Foundation/Foundation.h>

// * * *.

typedef NS_CLOSED_ENUM(NSUInteger, KSPFetchedResultsChangeType)
{
  KSPFetchedResultsChangeInsert,
  
  KSPFetchedResultsChangeDelete,

  // Move also assumes an update.
  KSPFetchedResultsChangeMove,
  
  KSPFetchedResultsChangeUpdate
};

// * * *.

@class KSPFetchedResultsController;

@class NSManagedObject;

// * * *.

@protocol KSPFetchedResultsControllerDelegate <NSObject>

@optional

- (void) controllerWillChangeContent: (nonnull KSPFetchedResultsController*) controller;

- (void) controller: (nonnull KSPFetchedResultsController*) controller willChangeObject: (nonnull NSManagedObject*) anObject atIndex: (NSUInteger) index forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

- (void) controller: (nonnull KSPFetchedResultsController*) controller didChangeObject: (nonnull NSManagedObject*) anObject atIndex: (NSUInteger) index forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

- (void) controllerDidChangeContent: (nonnull KSPFetchedResultsController*) controller;

@end
