//
//  KSPFetchedResultsControllerDelegate.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import <Foundation/Foundation.h>

// * * *.

typedef NS_ENUM(NSUInteger, KSPFetchedResultsChangeType)
{
  KSPFetchedResultsChangeInsert,
  
  KSPFetchedResultsChangeDelete,
  
  // Move подразумевает так же и Update.
  KSPFetchedResultsChangeMove,
  
  KSPFetchedResultsChangeUpdate
};

// * * *.

@class KSPFetchedResultsController;

@class NSManagedObject;

// * * *.

@protocol KSPFetchedResultsControllerDelegate <NSObject>

@optional

// Контроллер собирается менять выходную коллекцию.
- (void) controllerWillChangeContent: (nonnull KSPFetchedResultsController*) controller;

- (void) controller: (nonnull KSPFetchedResultsController*) controller willChangeObject: (nonnull NSManagedObject*) anObject atIndex: (NSUInteger) index forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

- (void) controller: (nonnull KSPFetchedResultsController*) controller didChangeObject: (nonnull NSManagedObject*) anObject atIndex: (NSUInteger) index forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

// Контроллер изменил выходную коллекцию.
- (void) controllerDidChangeContent: (nonnull KSPFetchedResultsController*) controller;

@end
