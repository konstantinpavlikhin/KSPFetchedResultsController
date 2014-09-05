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
  
  KPFetchedResultsChangeMove,
  
  KPFetchedResultsChangeUpdate
};

@class KPFetchedResultsController;

@protocol KPFetchedResultsControllerDelegate <NSObject>

@optional

- (void) controllerWillChangeContent: (KPFetchedResultsController*) controller;

- (void) controller: (KPFetchedResultsController*) controller didChangeObject: (id) anObject atIndex: (NSUInteger) index forChangeType: (KPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

- (void) controllerDidChangeContent: (KPFetchedResultsController*) controller;

@end
