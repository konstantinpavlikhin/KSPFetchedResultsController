//
//  KPSectionedFetchResultsControllerDelegate.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPFetchedResultsControllerDelegate.h"

// TODO: отказаться от этого энума и испольщовать доставшийся от суперкласса.

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

// WARNING: мы не можем поддержать операцию move, потому что следим за изменениями через collection-KVO :(.

@class KPSectionedFetchedResultsController;

@class KPTableSection;

@class NSManagedObject;

// TODO: не наследовать протокол!!!

@protocol KPSectionedFetchedResultsControllerDelegate <KPFetchedResultsControllerDelegate>

- (void) controller: (KPSectionedFetchedResultsController*) controller didChangeObject: (NSManagedObject*) anObject atIndex: (NSUInteger) index inSection: (KPTableSection*) section forChangeType: (KPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex inSection: (KPTableSection*) newSection;

- (void) controller: (KPSectionedFetchedResultsController*) controller didChangeSection: (KPTableSection*) section atIndex: (NSUInteger) index forChangeType: (KPSectionedFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex;

@end
