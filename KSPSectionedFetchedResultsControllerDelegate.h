//
//  KPSectionedFetchResultsControllerDelegate.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPFetchedResultsControllerDelegate.h"

// * * *.

// Типы изменений секций.
typedef NS_ENUM(NSUInteger, KSPSectionedFetchedResultsChangeType)
{
  // Новая секция появилась.
  KSPSectionedFetchedResultsChangeInsert,
  
  // Секция удалена.
  KSPSectionedFetchedResultsChangeDelete,
  
  // Секция переместилась (перемещение подразумевает так же и изменение).
  KSPSectionedFetchedResultsChangeMove,
};

// * * *.

@class KSPSectionedFetchedResultsController;

@class KSPTableSection;

@class NSManagedObject;

// * * *.

@protocol KSPSectionedFetchedResultsControllerDelegate <KSPFetchedResultsControllerDelegate>

@optional

// Метод протокола KSPFetchedResultsControllerDelegate -controller:willChangeObject:atIndex:forChangeType:newIndex: не вызывается!

// Метод протокола KSPFetchedResultsControllerDelegate -controller:didChangeObject:atIndex:forChangeType:newIndex: не вызывается!

- (void) controller: (KSPSectionedFetchedResultsController*) controller willChangeObject: (NSManagedObject*) anObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection;

- (void) controller: (KSPSectionedFetchedResultsController*) controller didChangeObject: (NSManagedObject*) anObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection;

// * * *.

- (void) controller: (KSPSectionedFetchedResultsController*) controller didChangeSection: (KSPTableSection*) section atIndex: (NSUInteger) index forChangeType: (KSPSectionedFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

@end
