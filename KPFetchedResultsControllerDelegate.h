//
//  KPFetchedResultsControllerDelegate.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, KPFetchedResultsChangeType)
{
  KPFetchedResultsChangeInsert,
  
  KPFetchedResultsChangeDelete,
  
  // Move подразумевает так же и Update.
  KPFetchedResultsChangeMove,
  
  KPFetchedResultsChangeUpdate
};

@class KPFetchedResultsController;

@class NSManagedObject;

@protocol KPFetchedResultsControllerDelegate <NSObject>

@optional

// Контроллер собирается менять выходную коллекцию.
- (void) controllerWillChangeContent: (KPFetchedResultsController*) controller;

- (void) controller: (KPFetchedResultsController*) controller didChangeObject: (NSManagedObject*) anObject atIndex: (NSUInteger) index forChangeType: (KPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

// Контроллер изменил выходную коллекцию.
- (void) controllerDidChangeContent: (KPFetchedResultsController*) controller;

@end
