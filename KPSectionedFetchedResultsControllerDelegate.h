//
//  KPSectionedFetchResultsControllerDelegate.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPFetchedResultsControllerDelegate.h"

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

@class KPTableSection;

@class NSManagedObject;

@protocol KPSectionedFetchedResultsControllerDelegate <NSObject>

// Контроллер собирается менять выходную коллекцию.
- (void) controllerWillChangeContent: (KPFetchedResultsController*) controller;

- (void) controller: (KPSectionedFetchedResultsController*) controller didChangeObject: (NSManagedObject*) anObject atIndex: (NSUInteger) index inSection: (KPTableSection*) section forChangeType: (KPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex inSection: (KPTableSection*) newSection;

- (void) controller: (KPSectionedFetchedResultsController*) controller didChangeSection: (KPTableSection*) section atIndex: (NSUInteger) index forChangeType: (KPSectionedFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

// Контроллер изменил выходную коллекцию.
- (void) controllerDidChangeContent: (KPFetchedResultsController*) controller;

@end
