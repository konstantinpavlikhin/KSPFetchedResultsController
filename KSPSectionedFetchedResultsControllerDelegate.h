//
//  KPSectionedFetchResultsControllerDelegate.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPFetchedResultsControllerDelegate.h"

// Типы изменений секций.
typedef NS_ENUM(NSUInteger, KPSectionedFetchedResultsChangeType)
{
  // Новая секция появилась.
  KPSectionedFetchedResultsChangeInsert,
  
  // Секция удалена.
  KPSectionedFetchedResultsChangeDelete,
  
  // Секция переместилась (перемещение подразумевает так же и изменение).
  KPSectionedFetchedResultsChangeMove,
};

@class KPSectionedFetchedResultsController;

@class KSPTableSection;

@class NSManagedObject;

@protocol KSPSectionedFetchedResultsControllerDelegate <KSPFetchedResultsControllerDelegate>

@optional

// Метод протокола KPFetchedResultsControllerDelegate -controller:didChangeObject:atIndex:forChangeType:newIndex: не вызывается!

- (void) controller: (KPSectionedFetchedResultsController*) controller didChangeObject: (NSManagedObject*) anObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section forChangeType: (KPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection;

- (void) controller: (KPSectionedFetchedResultsController*) controller didChangeSection: (KSPTableSection*) section atIndex: (NSUInteger) index forChangeType: (KPSectionedFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

@end
