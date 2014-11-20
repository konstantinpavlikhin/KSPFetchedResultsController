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
  
  NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
  
  NSOperationQueue* mq = [NSOperationQueue mainQueue];
  
  @weakify(self);
  
  _managedObjectContextObjectsDidChangeObserver = [nc addObserverForName: NSManagedObjectContextObjectsDidChangeNotification object: self.managedObjectContext queue: mq usingBlock: ^(NSNotification* notification)
  {
    @strongify(self);
    
    if(!self) return;
    
    // * * *.
    
    // Игнорируем нотификации, которые приходят до того, как что-то будет зафетчено.
    if(!self->_fetchedObjectsBackingStore) return;
    
    // * * *.
    
    [self willChangeContent];
    
    //*************************************************************************************.
    
    // Коллекционируем существующие объекты, вставленные в результате изменения некоторых их свойств.
    NSMutableArray* updatedObjectsThatBecomeInserted = [NSMutableArray array];
    
    // Коллекционируем существующие объекты, удаленные в результате изменения некоторых их свойств.
    NSMutableArray* updatedObjectsThatBecomeDeleted = [NSMutableArray array];
    
    //*************************************************************************************.
    
    // ОБНОВЛЕННЫЕ ОБЪЕКТЫ
    
    {{
      NSSet* updated = [notification.userInfo valueForKey: NSUpdatedObjectsKey];
      
      NSSet* refreshed = [notification.userInfo valueForKey: NSRefreshedObjectsKey];
      
      const BOOL intersects = [updated intersectsSet: refreshed];
      
      if(intersects) NSLog(@"Updated objects set intersects refreshed objects set.");
    }}
    
    NSMutableSet* updatedObjects = [NSMutableSet setWithSet: [notification.userInfo valueForKey: NSUpdatedObjectsKey]];
    
    NSMutableSet* refreshedObjects = [NSMutableSet setWithSet: [notification.userInfo valueForKey: NSRefreshedObjectsKey]];
    
    NSArray* refreshedObjectsOrNil = [[notification.userInfo valueForKey: NSRefreshedObjectsKey] allObjects];
    
    [updatedObjects unionSet: refreshedObjects];
    
    [[updatedObjects allObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* updatedObject, NSUInteger idx, BOOL* stop)
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
        [updatedObjectsThatBecomeDeleted addObject: updatedObject];
      }
      // Объект не присутствовал в коллекции, но теперь он проходит по предикату...
      else if(!updatedObjectWasPresent && predicateEvaluates)
      {
        // ...помечаем объект на вставку.
        [updatedObjectsThatBecomeInserted addObject:updatedObject];
      }
      // Объект присутствовал в коллекции и по прежнему проходит по предикату...
      else if(updatedObjectWasPresent && predicateEvaluates)
      {
        // ...проверяем, изменились ли свойства, по которым производится сортировка коллекции.
        NSArray* sortKeys = [[self.fetchRequest sortDescriptors] valueForKey: NSStringFromSelector(@selector(key))];
        
        NSArray* keysForChangedValues = [[updatedObject changedValues] allKeys];
        
        BOOL changedValuesMayAffectSort = ([sortKeys firstObjectCommonWithArray: keysForChangedValues] != nil);
        
        // Refreshed managed objects seem not to have a changesValues dictionary.
        changedValuesMayAffectSort = changedValuesMayAffectSort || [refreshedObjectsOrNil containsObject: updatedObject];
        
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
    
    //*************************************************************************************.
    
    // УДАЛЕННЫЕ ОБЪЕКТЫ
    {{
      // Testing...
      {{
        NSSet* deleted = [notification.userInfo valueForKey: NSDeletedObjectsKey];
        
        NSSet* invalidated = [notification.userInfo valueForKey: NSInvalidatedObjectsKey];
        
        const BOOL intersects = [deleted intersectsSet: invalidated];
        
        NSAssert(intersects == NO, @"Deleted objects set intersects invalidated objects set.");
      }}
      
      NSArray* deletedObjectsOrNil = [[notification.userInfo valueForKey: NSDeletedObjectsKey] allObjects];
      
      // When individual objects are invalidated, the controller treats these as deleted objects (just like NSFetchedResultsController).
      NSArray* invalidatedObjectsOrNil = [[notification.userInfo valueForKey: NSInvalidatedObjectsKey] allObjects];
      
      // Join all of three object groups together.
      NSArray* compoundArray = [[updatedObjectsThatBecomeDeleted arrayByAddingObjectsFromArray: deletedObjectsOrNil] arrayByAddingObjectsFromArray: invalidatedObjectsOrNil];
      
      [compoundArray enumerateObjectsUsingBlock: ^(NSManagedObject* deletedObject, NSUInteger idx, BOOL* stop)
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
    }}
    
    //*************************************************************************************.
    
    // ДОБАВЛЕННЫЕ ОБЪЕКТЫ
    
    // Testing...
    {{
      NSSet* inserted = [notification.userInfo valueForKey: NSInsertedObjectsKey];
      
      NSSet* refreshed = [notification.userInfo valueForKey: NSRefreshedObjectsKey];
      
      const BOOL intersects = [inserted intersectsSet: refreshed];
      
      NSAssert(intersects == NO, @"Inserted objects set intersects refreshed objects set.");
    }}
    
    NSArray* insertedObjects = [[notification.userInfo valueForKey: NSInsertedObjectsKey] allObjects];
    
    NSMutableArray* filteredInsertedObjects = [NSMutableArray new];
    
    [insertedObjects enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, NSUInteger idx, BOOL* stop)
    {
      // Если новые объекты проходят по типу и предикату...
      if([[insertedObject entity] isKindOfEntity: [self.fetchRequest entity]] && (self.fetchRequest.predicate? [self.fetchRequest.predicate evaluateWithObject: insertedObject] : YES))
      {
        [updatedObjectsThatBecomeInserted addObject: insertedObject];
      }
    }];
    
    // * * *.
    
    [[updatedObjectsThatBecomeInserted arrayByAddingObjectsFromArray: filteredInsertedObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, NSUInteger idx, BOOL* stop)
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
    
    //*************************************************************************************.
    
    [self didChangeContent];
  }];
  
  return self;
}

- (void) dealloc
{
  [self removeObserver: self forKeyPath: @"delegate" context: &DelegateKVOContext];
  
  [[NSNotificationCenter defaultCenter] removeObserver: _managedObjectContextObjectsDidChangeObserver name: NSManagedObjectContextObjectsDidChangeNotification object: self];
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
