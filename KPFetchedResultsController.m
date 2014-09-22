//
//  KPFetchedResultsController.m
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPFetchedResultsController+Private.h"

#import "KPFetchedResultsControllerDelegate.h"

static void* DelegateKVOContext;

@implementation KPFetchedResultsController
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
  
  __weak typeof(self) weakSelf = self;
  
  _managedObjectContextObjectsDidChangeObserver = [nc addObserverForName: NSManagedObjectContextObjectsDidChangeNotification object: self.managedObjectContext queue: mq usingBlock: ^(NSNotification* notification)
  {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    
    if(strongSelf == nil) return;
    
    // * * *.
    
    [strongSelf willChangeContent];
    
    //*************************************************************************************.
    
    // Коллекционируем существующие объекты, вставленные в результате изменения некоторых их свойств.
    NSMutableArray* updatedObjectsThatBecomeInserted = [NSMutableArray array];
    
    // Коллекционируем существующие объекты, удаленные в результате изменения некоторых их свойств.
    NSMutableArray* updatedObjectsThatBecomeDeleted = [NSMutableArray array];
    
    //*************************************************************************************.
    
    // ОБНОВЛЕННЫЕ ОБЪЕКТЫ
    
    // Testing...
    {{
      NSSet* updated = [notification.userInfo valueForKey: NSUpdatedObjectsKey];
      
      NSSet* refreshed = [notification.userInfo valueForKey: NSRefreshedObjectsKey];
      
      BOOL intersects = [updated intersectsSet: refreshed];
      
      // TODO: !!!
      //NSAssert(intersects == NO, @"Updated objects set intersects refreshed objects set.");
    }}
    
    NSArray* updatedObjects = [[notification.userInfo valueForKey: NSUpdatedObjectsKey] allObjects];
    
    NSArray* refreshedObjects = [[notification.userInfo valueForKey: NSRefreshedObjectsKey] allObjects];
    
    [[updatedObjects arrayByAddingObjectsFromArray: refreshedObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* updatedObject, NSUInteger idx, BOOL* stop)
    {
      // Изменение объекта другого типа нас не волнует.
      if(![[updatedObject entity] isKindOfEntity: [strongSelf.fetchRequest entity]]) return;
      
      // «Проходит» ли изменившийся объект по предикату?
      NSPredicate* predicate = [strongSelf.fetchRequest predicate];
      
      BOOL predicateEvaluates = (predicate != nil) ? [predicate evaluateWithObject: updatedObject] : YES;
      
      // Присутствовал ли изменившийся объект в fetchedObjects?
      NSUInteger updatedObjectIndex = [strongSelf->_fetchedObjectsBackingStore indexOfObject: updatedObject];
      
      BOOL updatedObjectWasPresent = (updatedObjectIndex != NSNotFound);
      
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
        NSArray* sortKeys = [[strongSelf.fetchRequest sortDescriptors] valueForKey: NSStringFromSelector(@selector(key))];
        
        NSArray* keysForChangedValues = [[updatedObject changedValues] allKeys];
        
        BOOL changedValuesMayAffectSort = ([sortKeys firstObjectCommonWithArray: keysForChangedValues] != nil);
        
        // Refreshed managed objects seem not to have a changesValues dictionary.
        changedValuesMayAffectSort = changedValuesMayAffectSort || [refreshedObjects containsObject: updatedObject];
        
        NSUInteger insertionIndex = NSUIntegerMax;
        
        // Проверять, действительно ли изменение свойства объекта привело к пересортировке или же объект просто изменился сохранив прежний порядок.
        BOOL changedPropertiesDidAffectSort = changedValuesMayAffectSort &&
        ({
          // ...находим индекс, в который надо вставить элемент, чтобы сортировка сохранилась.
          NSRange r = NSMakeRange(0, [strongSelf->_fetchedObjectsBackingStore count]);
          
          // TODO: | ...FirstEqual?
          insertionIndex = [strongSelf->_fetchedObjectsBackingStore indexOfObject: updatedObject inSortedRange: r options: NSBinarySearchingInsertionIndex usingComparator: ^NSComparisonResult (NSManagedObject* object1, NSManagedObject* object2)
         {
           // Функция ожидала компаратор, но критериев сортировки у нас может быть произвольное количество.
           for(NSSortDescriptor* sortDescriptor in strongSelf.fetchRequest.sortDescriptors)
           {
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
          [strongSelf removeObjectFromFetchedObjectsAtIndex: updatedObjectIndex];
          
          // Эпикфейл с индексом! он уже не такой. все зависит от того, располагался ли удаленный объект до или после insertionIndex.
          insertionIndex = insertionIndex > updatedObjectIndex? insertionIndex - 1 : insertionIndex;
          
          [strongSelf insertObject: updatedObject inFetchedObjectsAtIndex: insertionIndex];
          
          [strongSelf didMoveObject: updatedObject atIndex: updatedObjectIndex toIndex: insertionIndex];
        }
        else
        {
          // «Сортировочные» свойства объекта не изменились.
          [strongSelf didUpdateObject: updatedObject atIndex: updatedObjectIndex];
        }
      }
    }];
    
    //*************************************************************************************.
    
    // УДАЛЕННЫЕ ОБЪЕКТЫ
    
    // Testing...
    {{
      NSSet* deleted = [notification.userInfo valueForKey: NSDeletedObjectsKey];
      
      NSSet* invalidated = [notification.userInfo valueForKey: NSInvalidatedObjectsKey];
      
      BOOL intersects = [deleted intersectsSet: invalidated];
      
      // TODO: !!!
      //NSAssert(intersects == NO, @"Deleted objects set intersects invalidated objects set.");
    }}
    
    NSArray* deletedObjects = [[notification.userInfo valueForKey: NSDeletedObjectsKey] allObjects];
    
    // When individual objects are invalidated, the controller treats these as deleted objects (just like NSFetchedResultsController).
    NSArray* invalidatedObjects = [notification.userInfo valueForKey: NSInvalidatedObjectsKey];
    
    // Join all of three object groups together.
    NSArray* allDeletedObjects = [[deletedObjects arrayByAddingObjectsFromArray: invalidatedObjects] arrayByAddingObjectsFromArray: updatedObjectsThatBecomeDeleted];
    
    [[allDeletedObjects arrayByAddingObjectsFromArray: deletedObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* deletedObject, NSUInteger idx, BOOL* stop)
     {
       // Удаление объекта другого типа нас не волнует.
       if(![[deletedObject entity] isKindOfEntity: [strongSelf.fetchRequest entity]]) return;
       
       NSUInteger index = [strongSelf->_fetchedObjectsBackingStore indexOfObject: deletedObject];
       
       // Если удаленный объект не присутствовал в _fetchedObjectsBackingStore...
       if(index == NSNotFound) return;
       
       // Модифицируем состояние.
       [strongSelf removeObjectFromFetchedObjectsAtIndex: index];
       
       // Уведомляем делегата.
       [strongSelf didDeleteObject: deletedObject atIndex: index];
     }];
    
    //*************************************************************************************.
    
    // ДОБАВЛЕННЫЕ ОБЪЕКТЫ
    
    NSArray* insertedObjects = [[notification.userInfo valueForKey: NSInsertedObjectsKey] allObjects];
    
    NSMutableArray* filteredInsertedObjects = [NSMutableArray new];
    
    [insertedObjects enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, NSUInteger idx, BOOL* stop)
    {
      // Если новые объекты проходят по типу и предикату...
      if([[insertedObject entity] isKindOfEntity: [strongSelf.fetchRequest entity]] && (strongSelf.fetchRequest.predicate? [strongSelf.fetchRequest.predicate evaluateWithObject: insertedObject] : YES))
      {
        [updatedObjectsThatBecomeInserted addObject: insertedObject];
      }
    }];
    
    // * * *.
    
    [[updatedObjectsThatBecomeInserted arrayByAddingObjectsFromArray: filteredInsertedObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, NSUInteger idx, BOOL* stop)
     {
       // По-умолчанию вставляем в конец массива.
       NSUInteger insertionIndex = [strongSelf->_fetchedObjectsBackingStore count];
       
       // Если заданы критерии сортировки...
       if([strongSelf.fetchRequest.sortDescriptors count])
       {
         // ...находим индекс, в который надо вставить элемент, чтобы сортировка сохранилась.
         insertionIndex = [strongSelf->_fetchedObjectsBackingStore indexOfObject: insertedObject inSortedRange: NSMakeRange(0, [strongSelf->_fetchedObjectsBackingStore count]) options: NSBinarySearchingInsertionIndex usingComparator:
       
        ^NSComparisonResult (NSManagedObject* object1, NSManagedObject* object2)
        {
          // Функция ожидала компаратор, но критериев сортировки у нас может быть произвольное количество.
          for(NSSortDescriptor* sortDescriptor in strongSelf.fetchRequest.sortDescriptors)
          {
            NSComparisonResult comparisonResult = [sortDescriptor compareObject: object1 toObject: object2];
            
            if(comparisonResult != NSOrderedSame) return comparisonResult;
          }
          
          return NSOrderedSame;
        }];
       }
       
       // Вставляем элемент по вычисленному индексу.
       [strongSelf insertObject: insertedObject inFetchedObjectsAtIndex: insertionIndex];
       
       // Уведомляем делегата о произведенной вставке.
       [strongSelf didInsertObject: insertedObject atIndex: insertionIndex];
     }];
    
    //*************************************************************************************.
    
    [strongSelf didChangeContent];
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
    [self.delegate controller: self didChangeObject: insertedObject atIndex: NSNotFound forChangeType: KPFetchedResultsChangeInsert newIndex: insertedObjectIndex];
  }
}

- (void) didDeleteObject: (NSManagedObject*) deletedObject atIndex: (NSUInteger) deletedObjectIndex
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: deletedObject atIndex: deletedObjectIndex forChangeType: KPFetchedResultsChangeDelete newIndex: NSNotFound];
  }
}

- (void) didMoveObject: (NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex toIndex: (NSUInteger) newIndex
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: movedObject atIndex: oldIndex forChangeType: KPFetchedResultsChangeMove newIndex: newIndex];
  }
}

- (void) didUpdateObject: (NSManagedObject*) updatedObject atIndex: (NSUInteger) updatedObjectIndex
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: updatedObject atIndex: updatedObjectIndex forChangeType: KPFetchedResultsChangeUpdate newIndex: NSNotFound];
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
