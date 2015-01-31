//
//  KSPFetchedResultsController.m
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPFetchedResultsController+Private.h"

#import "KSPFetchedResultsControllerDelegate.h"

static void* DelegateKVOContext;

// * * *.

static NSString* const UpdatedObjectsThatBecomeInserted = @"UpdatedObjectsThatBecomeInserted";

static NSString* const UpdatedObjectsThatBecomeDeleted = @"UpdatedObjectsThatBecomeDeleted";

// * * *.

@implementation KSPFetchedResultsController
{
  id _managedObjectContextObjectsDidChangeObserver;
  
  NSMutableArray* _fetchedObjectsBackingStore;
  
  // Оптимизация...
  struct
  {
    BOOL controllerWillChangeContent;
    
    BOOL controllerDidChangeObject;
    
    BOOL controllerDidChangeContent;
  } delegateRespondsTo;
}

- (instancetype) initWithFetchRequest: (NSFetchRequest*) fetchRequest managedObjectContext: (NSManagedObjectContext*) context
{
  NSParameterAssert(fetchRequest);
  
  NSParameterAssert(context);
  
  self = [super init];
  
  if(!self) return nil;
  
  _fetchRequest = fetchRequest;
  
  _managedObjectContext = context;
  
  [self addObserver: self forKeyPath: @"delegate" options: 0 context: &DelegateKVOContext];
  
  __weak typeof(self) weakSelf = self;
  
  _managedObjectContextObjectsDidChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName: NSManagedObjectContextObjectsDidChangeNotification object: self.managedObjectContext queue: [NSOperationQueue mainQueue] usingBlock: ^(NSNotification* notification)
  {
    __strong typeof(self) strongSelf = weakSelf;
    
    if(!strongSelf) return;
    
    // * * *.
    
    // Игнорируем нотификации, которые приходят до того, как что-то будет зафетчено.
    if(!strongSelf->_fetchedObjectsBackingStore) return;
    
    //*************************************************************************************.
    
    // Updated objects.
    NSSet* updatedObjectsOrNil = [notification.userInfo valueForKey: NSUpdatedObjectsKey];
    
    // Refreshed objects.
    NSSet* refreshedObjectsOrNil = [notification.userInfo valueForKey: NSRefreshedObjectsKey];
    
    // Unite the two conceptually similar object sets.
    NSMutableSet* updatedAndRefreshedUnion = [NSMutableSet setWithCapacity: updatedObjectsOrNil.count + refreshedObjectsOrNil.count];
    
    if(updatedObjectsOrNil)
    {
      [updatedAndRefreshedUnion unionSet: updatedObjectsOrNil];
    }
    
    if(refreshedObjectsOrNil)
    {
      [updatedAndRefreshedUnion unionSet: refreshedObjectsOrNil];
    }
    
    // * * *.
    
    // Inserted objects.
    NSSet* insertedObjectsOrNil = [notification.userInfo valueForKey: NSInsertedObjectsKey];
    
    // Minus the inserted objects that were also refreshed.
    [updatedAndRefreshedUnion minusSet: insertedObjectsOrNil];
    
    // * * *.
    
    // Deleted objects.
    NSSet* deletedObjectsOrNil = [notification.userInfo valueForKey: NSDeletedObjectsKey];
    
    // Invalidated objects.
    NSSet* invalidatedObjectsOrNil = [notification.userInfo valueForKey: NSInvalidatedObjectsKey];
    
    // Unite the two conceptually similar object sets.
    NSMutableSet* deletedAndInvalidatedUnion = [NSMutableSet setWithCapacity: deletedObjectsOrNil.count + invalidatedObjectsOrNil.count];
    
    if(deletedObjectsOrNil)
    {
      [deletedAndInvalidatedUnion unionSet: deletedObjectsOrNil];
    }
    
    // When individual objects are invalidated, the controller treats these as deleted objects (just like NSFetchedResultsController).
    if(invalidatedObjectsOrNil)
    {
      [deletedAndInvalidatedUnion unionSet: invalidatedObjectsOrNil];
    }
    
    // Minus the deleted and invalidated objects that were also refreshed.
    [updatedAndRefreshedUnion minusSet: deletedAndInvalidatedUnion];
    
    //*************************************************************************************.

    {{
      const NSUInteger maxRequiredCapacity = updatedAndRefreshedUnion.count + deletedAndInvalidatedUnion.count + insertedObjectsOrNil.count;

      NSMutableSet* allObjectsSet = [NSMutableSet setWithCapacity: maxRequiredCapacity];

      [allObjectsSet unionSet: updatedAndRefreshedUnion];

      [allObjectsSet unionSet: deletedAndInvalidatedUnion];

      [allObjectsSet unionSet: insertedObjectsOrNil];

      NSPredicate* const relevantEntitiesPredicate = [NSPredicate predicateWithFormat: @"entity.name == %@", strongSelf.fetchRequest.entityName];

      NSSet* relevantEntitiesSet = [allObjectsSet filteredSetUsingPredicate: relevantEntitiesPredicate];

      // Do not do any processing if managed object context change didn't touch the relevant entity type.
      if(!relevantEntitiesSet.count) return;
    }}

    // * * *.

    [strongSelf willChangeContent];
    
    NSDictionary* sideEffects = nil;
    
    // Process all 'updated' objects.
    {{
      sideEffects = [strongSelf processUpdatedObjects: updatedAndRefreshedUnion objectsLackingChangeDictionary: refreshedObjectsOrNil];
    }}
    
    // * * *.
    
    // Process all 'deleted' objects.
    {{
      [strongSelf processDeletedObjects: deletedAndInvalidatedUnion updatedObjectsThatBecomeDeleted: sideEffects[UpdatedObjectsThatBecomeDeleted]];
    }}
    
    // * * *.
    
    // Process all 'inserted' objects.
    {{
      [strongSelf processInsertedObjects: insertedObjectsOrNil updatedObjectsThatBecomeInserted: sideEffects[UpdatedObjectsThatBecomeInserted]];
    }}
    
    [strongSelf didChangeContent];
  }];
  
  return self;
}

- (void) dealloc
{
  [self removeObserver: self forKeyPath: @"delegate" context: &DelegateKVOContext];
  
  [[NSNotificationCenter defaultCenter] removeObserver: _managedObjectContextObjectsDidChangeObserver name: NSManagedObjectContextObjectsDidChangeNotification object: self.managedObjectContext];
}

#pragma mark - Обозреватель

- (void) observeValueForKeyPath: (NSString*) keyPath ofObject: (id) object change: (NSDictionary*) change context: (void*) context
{
  if(context == &DelegateKVOContext)
  {
    // Кешируем ответы делегата...
    delegateRespondsTo.controllerWillChangeContent = [self.delegate respondsToSelector: @selector(controllerWillChangeContent:)];
    
    delegateRespondsTo.controllerDidChangeObject = [self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)];
    
    delegateRespondsTo.controllerDidChangeContent = [self.delegate respondsToSelector: @selector(controllerDidChangeContent:)];
  }
}

#pragma mark - Change Processing

/// Returns a dictionary with two key-value pairs: @{UpdatedObjectsThatBecomeDeleted: [NSSet set], UpdatedObjectsThatBecomeInserted: [NSSet set]};
- (NSDictionary*) processUpdatedObjects: (NSSet*) updatedObjectsOrNil objectsLackingChangeDictionary: (NSSet*) objectsLackingChangeDictionaryOrNil
{
  NSDictionary* sideEffects = @{UpdatedObjectsThatBecomeDeleted: [NSMutableSet set],
                                
                                UpdatedObjectsThatBecomeInserted: [NSMutableSet set]};
  
  [[updatedObjectsOrNil allObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* updatedObject, NSUInteger idx, BOOL* stop)
   {
     // Изменение объекта другого типа нас не волнует.
     if(![[updatedObject entity] isKindOfEntity: [self.fetchRequest entity]]) return;
     
     // «Проходит» ли изменившийся объект по предикату?
     NSPredicate* predicate = [self.fetchRequest predicate];
     
     const BOOL predicateEvaluates = (predicate != nil) ? [predicate evaluateWithObject: updatedObject] : YES;
     
     // Присутствовал ли изменившийся объект в fetchedObjects?
     const NSUInteger updatedObjectIndex = [self->_fetchedObjectsBackingStore indexOfObject: updatedObject];
     
     const BOOL updatedObjectWasPresent = (updatedObjectIndex != NSNotFound);
     
     // Объект присутствовал в коллекции, но по предикату он больше не проходит...
     if(updatedObjectWasPresent && !predicateEvaluates)
     {
       // ...помечаем объект на удаление.
       [sideEffects[UpdatedObjectsThatBecomeDeleted] addObject: updatedObject];
     }
     // Объект не присутствовал в коллекции, но теперь он проходит по предикату...
     else if(!updatedObjectWasPresent && predicateEvaluates)
     {
       // ...помечаем объект на вставку.
       [sideEffects[UpdatedObjectsThatBecomeInserted] addObject: updatedObject];
     }
     // Объект присутствовал в коллекции и по прежнему проходит по предикату...
     else if(updatedObjectWasPresent && predicateEvaluates)
     {
       // ...проверяем, изменились ли свойства, по которым производится сортировка коллекции.
       NSArray* sortKeys = [[self.fetchRequest sortDescriptors] valueForKey: NSStringFromSelector(@selector(key))];
       
       NSArray* keysForChangedValues = [[updatedObject changedValues] allKeys];
       
       BOOL changedValuesMayAffectSort = ([sortKeys firstObjectCommonWithArray: keysForChangedValues] != nil);
       
       // Refreshed managed objects seem not to have a changesValues dictionary.
       changedValuesMayAffectSort = changedValuesMayAffectSort || [objectsLackingChangeDictionaryOrNil containsObject: updatedObject];
       
       NSUInteger insertionIndex = NSUIntegerMax;
       
       // Проверять, действительно ли изменение свойства объекта привело к пересортировке или же объект просто изменился сохранив прежний порядок.
       const BOOL changedPropertiesDidAffectSort = changedValuesMayAffectSort &&
       ({
         // ...находим индекс, в который надо вставить элемент, чтобы сортировка сохранилась.
         NSRange r = NSMakeRange(0, [self->_fetchedObjectsBackingStore count]);
         
         insertionIndex = [self->_fetchedObjectsBackingStore indexOfObject: updatedObject inSortedRange: r options: NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual usingComparator: ^NSComparisonResult (NSManagedObject* object1, NSManagedObject* object2)
         {
           // Функция ожидала компаратор, но критериев сортировки у нас может быть произвольное количество.
           for(NSSortDescriptor* sortDescriptor in self.fetchRequest.sortDescriptors)
           {
             // Handle the case when one or both objects lack a meaningful value for key.
             id value1 = [object1 valueForKey: sortDescriptor.key];
             
             id value2 = [object2 valueForKey: sortDescriptor.key];
             
             if(!value1 && !value2)
             {
               // If both values are nil proceed to the evaluation of a next sort descriptor.
               continue;
             }
             
             if(!value1 && value2)
             {
               return sortDescriptor.ascending? NSOrderedAscending : NSOrderedDescending;
             }
             
             if(value1 && !value2)
             {
               return sortDescriptor.ascending? NSOrderedDescending : NSOrderedAscending;
             }
             
             // * * *.
             
             // Handle the case when both objects have a meaningful value for key.
             NSComparisonResult comparisonResult = [sortDescriptor compareObject: object1 toObject: object2];
             
             if(comparisonResult != NSOrderedSame) return comparisonResult;
           }
           
           return NSOrderedSame;
         }];
         
         // Запоминаем по какому индексу располагался этот объект.
         updatedObjectIndex != insertionIndex;
       });
       
       if(changedPropertiesDidAffectSort)
       {
         [self removeObjectFromFetchedObjectsAtIndex: updatedObjectIndex];
         
         // Эпикфейл с индексом! он уже не такой. все зависит от того, располагался ли удаленный объект до или после insertionIndex.
         insertionIndex = insertionIndex > updatedObjectIndex? insertionIndex - 1 : insertionIndex;
         
         NSAssert(insertionIndex <= self.fetchedObjectsNoCopy.count, @"Attempt to insert object at index greater than the count of elements in the array.");
         
         [self insertObject: updatedObject inFetchedObjectsAtIndex: insertionIndex];
         
         [self didMoveObject: updatedObject atIndex: updatedObjectIndex toIndex: insertionIndex];
       }
       else
       {
         // «Сортировочные» свойства объекта не изменились.
         [self didUpdateObject: updatedObject atIndex: updatedObjectIndex];
       }
     }
   }];
  
  return sideEffects;
}

- (void) processDeletedObjects: (NSSet*) deletedObjectsOrNil updatedObjectsThatBecomeDeleted: (NSSet*) updatedObjectsThatbecomeDeletedOrNil
{
  NSMutableSet* unionSet = [NSMutableSet setWithCapacity: deletedObjectsOrNil.count + updatedObjectsThatbecomeDeletedOrNil.count];
  
  if(deletedObjectsOrNil)
  {
    [unionSet unionSet: deletedObjectsOrNil];
  }
  
  if(updatedObjectsThatbecomeDeletedOrNil)
  {
    [unionSet unionSet: updatedObjectsThatbecomeDeletedOrNil];
  }
  
  // * * *.
  
  [[unionSet allObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* deletedObject, NSUInteger idx, BOOL* stop)
   {
     // Удаление объекта другого типа нас не волнует.
     if(![[deletedObject entity] isKindOfEntity: [self.fetchRequest entity]]) return;
     
     const NSUInteger index = [self->_fetchedObjectsBackingStore indexOfObject: deletedObject];
     
     // Если удаленный объект не присутствовал в _fetchedObjectsBackingStore...
     if(index == NSNotFound) return;
     
     // Модифицируем состояние.
     [self removeObjectFromFetchedObjectsAtIndex: index];
     
     // Уведомляем делегата.
     [self didDeleteObject: deletedObject atIndex: index];
   }];
}

- (void) processInsertedObjects: (NSSet*) insertedObjectsOrNil updatedObjectsThatBecomeInserted: (NSSet*) updatedObjectsThatBecomeInsertedOrNil
{
  NSMutableSet* filteredInsertedObjects = [NSMutableSet setWithCapacity: insertedObjectsOrNil.count];
  
  [insertedObjectsOrNil enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, BOOL* stop)
   {
     // Если новые объекты проходят по типу и предикату...
     if([[insertedObject entity] isKindOfEntity: [self.fetchRequest entity]] && (self.fetchRequest.predicate? [self.fetchRequest.predicate evaluateWithObject: insertedObject] : YES))
     {
       [filteredInsertedObjects addObject: insertedObject];
     }
   }];
  
  // * * *.
  
  NSSet* allInsertedObjects = [filteredInsertedObjects setByAddingObjectsFromSet: updatedObjectsThatBecomeInsertedOrNil];
  
  [allInsertedObjects enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, BOOL* stop)
   {
     // По-умолчанию вставляем в конец массива.
     NSUInteger insertionIndex = [self->_fetchedObjectsBackingStore count];
     
     // Если заданы критерии сортировки...
     if([self.fetchRequest.sortDescriptors count])
     {
       // ...находим индекс, в который надо вставить элемент, чтобы сортировка сохранилась.
       insertionIndex = [self->_fetchedObjectsBackingStore indexOfObject: insertedObject inSortedRange: NSMakeRange(0, [self->_fetchedObjectsBackingStore count]) options: NSBinarySearchingInsertionIndex usingComparator:

       ^NSComparisonResult (NSManagedObject* object1, NSManagedObject* object2)
       {
         // Функция ожидала компаратор, но критериев сортировки у нас может быть произвольное количество.
         for(NSSortDescriptor* sortDescriptor in self.fetchRequest.sortDescriptors)
         {
           NSComparisonResult comparisonResult = [sortDescriptor compareObject: object1 toObject: object2];
           
           if(comparisonResult != NSOrderedSame) return comparisonResult;
         }
         
         return NSOrderedSame;
       }];
     }
     
     // Вставляем элемент по вычисленному индексу.
     [self insertObject: insertedObject inFetchedObjectsAtIndex: insertionIndex];
     
     // Уведомляем делегата о произведенной вставке.
     [self didInsertObject: insertedObject atIndex: insertionIndex];
   }];
}

#pragma mark - Работа с делегатом

- (void) willChangeContent
{
  if(delegateRespondsTo.controllerWillChangeContent)
  {
    [self.delegate controllerWillChangeContent: self];
  }
}

- (void) didInsertObject: (NSManagedObject*) insertedObject atIndex: (NSUInteger) insertedObjectIndex
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: insertedObject atIndex: NSNotFound forChangeType: KSPFetchedResultsChangeInsert newIndex: insertedObjectIndex];
  }
}

- (void) didDeleteObject: (NSManagedObject*) deletedObject atIndex: (NSUInteger) deletedObjectIndex
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: deletedObject atIndex: deletedObjectIndex forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound];
  }
}

- (void) didMoveObject: (NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex toIndex: (NSUInteger) newIndex
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: movedObject atIndex: oldIndex forChangeType: KSPFetchedResultsChangeMove newIndex: newIndex];
  }
}

- (void) didUpdateObject: (NSManagedObject*) updatedObject atIndex: (NSUInteger) updatedObjectIndex
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: updatedObject atIndex: updatedObjectIndex forChangeType: KSPFetchedResultsChangeUpdate newIndex: NSNotFound];
  }
}

- (void) didChangeContent
{
  if(delegateRespondsTo.controllerDidChangeContent)
  {
    [self.delegate controllerDidChangeContent: self];
  }
}

#pragma mark -

- (BOOL) performFetch: (NSError* __autoreleasing*) error
{
  if(!self.fetchRequest) return NO;
  
  self.fetchedObjects = [self.managedObjectContext executeFetchRequest: self.fetchRequest error: error];
  
  return (_fetchedObjectsBackingStore != nil);
}

#pragma mark - fetchedObjects Collection KVC Implementation

// Warning: этот геттер предназначен только для доступа извне! Не вызывать из реализации этого класса!
- (NSArray*) fetchedObjects
{
  // Чтобы избежать неумышленного воздействия на сторонний код, возвращаем иммутабельную копию.
  return [_fetchedObjectsBackingStore copy];
}

- (NSArray*) fetchedObjectsNoCopy
{
  return _fetchedObjectsBackingStore;
}

- (void) setFetchedObjects: (NSArray*) fetchedObjects
{
  _fetchedObjectsBackingStore = [fetchedObjects mutableCopy];
}

- (NSUInteger) countOfFetchedObjects
{
  return [_fetchedObjectsBackingStore count];
}

- (NSManagedObject*) objectInFetchedObjectsAtIndex: (NSUInteger) index
{
  return [_fetchedObjectsBackingStore objectAtIndex: index];
}

- (NSArray*) fetchedObjectsAtIndexes: (NSIndexSet*) indexes
{
  return [_fetchedObjectsBackingStore objectsAtIndexes: indexes];
}

- (void) getFetchedObjects: (NSManagedObject* __unsafe_unretained*) buffer range: (NSRange) inRange
{
  [_fetchedObjectsBackingStore getObjects: buffer range: inRange];
}

- (void) insertObject: (NSManagedObject*) object inFetchedObjectsAtIndex: (NSUInteger) index
{
  [_fetchedObjectsBackingStore insertObject: object atIndex: index];
}

- (void) removeObjectFromFetchedObjectsAtIndex: (NSUInteger) index
{
  [_fetchedObjectsBackingStore removeObjectAtIndex: index];
}

- (void) insertFetchedObjects: (NSArray*) array atIndexes: (NSIndexSet*) indexes
{
  [_fetchedObjectsBackingStore insertObjects: array atIndexes: indexes];
}

- (void) removeFetchedObjectsAtIndexes: (NSIndexSet*) indexes
{
  [_fetchedObjectsBackingStore removeObjectsAtIndexes: indexes];
}

- (void) replaceObjectInFetchedObjectsAtIndex: (NSUInteger) index withObject: (NSManagedObject*) object
{
  [_fetchedObjectsBackingStore replaceObjectAtIndex: index withObject: object];
}

- (void) replaceFetchedObjectsAtIndexes: (NSIndexSet*) indexes withFetchedObjects: (NSArray*) array
{
  [_fetchedObjectsBackingStore replaceObjectsAtIndexes: indexes withObjects: array];
}

@end
