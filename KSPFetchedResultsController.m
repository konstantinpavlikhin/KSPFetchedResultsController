//
//  KSPFetchedResultsController.m
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
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
  
  NSMutableArray<NSManagedObject*>* _fetchedObjectsBackingStore;
  
  // Оптимизация...
  struct
  {
    BOOL controllerWillChangeContent;

    BOOL controllerWillChangeObject;

    BOOL controllerDidChangeObject;
    
    BOOL controllerDidChangeContent;
  } _delegateRespondsTo;
}

#pragma mark - Initialization

- (nullable instancetype) init
{
  NSAssert(NO, @"Use -%@.", NSStringFromSelector(@selector(initWithFetchRequest:managedObjectContext:)));

  return nil;
}

- (nullable instancetype) initWithFetchRequest: (nonnull NSFetchRequest*) fetchRequest managedObjectContext: (nonnull NSManagedObjectContext*) context
{
  NSParameterAssert(fetchRequest);
  
  NSParameterAssert(context);

  // * * *.

  self = [super init];
  
  if(!self) return nil;
  
  _fetchRequest = fetchRequest;
  
  _managedObjectContext = context;
  
  [self addObserver: self forKeyPath: @"delegate" options: 0 context: &DelegateKVOContext];
  
  __weak typeof(self) const weakSelf = self;
  
  _managedObjectContextObjectsDidChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName: NSManagedObjectContextObjectsDidChangeNotification object: self.managedObjectContext queue: [NSOperationQueue mainQueue] usingBlock: ^(NSNotification* notification)
  {
    __strong typeof(self) const strongSelf = weakSelf;
    
    if(!strongSelf) return;
    
    // * * *.
    
    // Игнорируем нотификации, которые приходят до того, как что-то будет зафетчено.
    if(!strongSelf->_fetchedObjectsBackingStore) return;
    
    //*************************************************************************************.
    
    // Updated objects.
    NSSet* const updatedObjectsOrNil = [notification.userInfo valueForKey: NSUpdatedObjectsKey];
    
    // Refreshed objects.
    NSSet* const refreshedObjectsOrNil = [notification.userInfo valueForKey: NSRefreshedObjectsKey];
    
    // Unite the two conceptually similar object sets.
    NSMutableSet* const updatedAndRefreshedUnion = [NSMutableSet setWithCapacity: updatedObjectsOrNil.count + refreshedObjectsOrNil.count];
    
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

    // Workaround for a Core Data concurrency issue which causes an object that was already fetched to be reported as a newly inserted one.
    {{
      if(insertedObjectsOrNil)
      {
        NSMutableSet* const mutableInsertedObjects = [insertedObjectsOrNil mutableCopy];

        [mutableInsertedObjects minusSet: [NSSet setWithArray: strongSelf.fetchedObjectsNoCopy]];

        insertedObjectsOrNil = [mutableInsertedObjects copy];
      }
    }}

    // Minus the inserted objects that were also refreshed.
    [updatedAndRefreshedUnion minusSet: insertedObjectsOrNil];
    
    // * * *.
    
    // Deleted objects.
    NSSet* const deletedObjectsOrNil = [notification.userInfo valueForKey: NSDeletedObjectsKey];
    
    // Invalidated objects.
    NSSet* const invalidatedObjectsOrNil = [notification.userInfo valueForKey: NSInvalidatedObjectsKey];
    
    // Unite the two conceptually similar object sets.
    NSMutableSet* const deletedAndInvalidatedUnion = [NSMutableSet setWithCapacity: deletedObjectsOrNil.count + invalidatedObjectsOrNil.count];
    
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

      NSMutableSet* const allObjectsSet = [NSMutableSet setWithCapacity: maxRequiredCapacity];

      [allObjectsSet unionSet: updatedAndRefreshedUnion];

      [allObjectsSet unionSet: deletedAndInvalidatedUnion];

      [allObjectsSet unionSet: insertedObjectsOrNil];

      NSPredicate* const relevantEntitiesPredicate = [NSPredicate predicateWithFormat: @"entity.name == %@", strongSelf.fetchRequest.entityName];

      NSSet* const relevantEntitiesSet = [allObjectsSet filteredSetUsingPredicate: relevantEntitiesPredicate];

      // Do not do any processing if managed object context change didn't touch the relevant entity type.
      if(relevantEntitiesSet.count == 0) return;
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

#pragma mark - Cleanup

- (void) dealloc
{
  [self removeObserver: self forKeyPath: @"delegate" context: &DelegateKVOContext];
  
  [[NSNotificationCenter defaultCenter] removeObserver: _managedObjectContextObjectsDidChangeObserver name: NSManagedObjectContextObjectsDidChangeNotification object: self.managedObjectContext];
}

#pragma mark - Обозреватель

- (void) observeValueForKeyPath: (nullable NSString*) keyPath ofObject: (nullable id) object change: (nullable NSDictionary*) change context: (nullable void*) context
{
  if(context == &DelegateKVOContext)
  {
    // Кешируем ответы делегата...
    _delegateRespondsTo.controllerWillChangeContent = [self.delegate respondsToSelector: @selector(controllerWillChangeContent:)];

    _delegateRespondsTo.controllerWillChangeObject = [self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:forChangeType:newIndex:)];

    _delegateRespondsTo.controllerDidChangeObject = [self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)];
    
    _delegateRespondsTo.controllerDidChangeContent = [self.delegate respondsToSelector: @selector(controllerDidChangeContent:)];
  }
}

#pragma mark - Change Processing

/// Returns a dictionary with two key-value pairs: @{UpdatedObjectsThatBecomeDeleted: [NSSet set], UpdatedObjectsThatBecomeInserted: [NSSet set]};
- (nonnull NSDictionary*) processUpdatedObjects: (nullable NSSet*) updatedObjectsOrNil objectsLackingChangeDictionary: (nullable NSSet*) objectsLackingChangeDictionaryOrNil
{
  NSDictionary* const sideEffects = @{UpdatedObjectsThatBecomeDeleted: [NSMutableSet set],

                                      UpdatedObjectsThatBecomeInserted: [NSMutableSet set]};
  
  [[updatedObjectsOrNil allObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* updatedObject, NSUInteger idx, BOOL* stop)
   {
     // Изменение объекта другого типа нас не волнует.
     if(![[updatedObject entity] isKindOfEntity: [self.fetchRequest entity]]) return;
     
     // «Проходит» ли изменившийся объект по предикату?
     NSPredicate* const predicate = [self.fetchRequest predicate];
     
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
       NSArray* const sortKeyPaths = [[self.fetchRequest sortDescriptors] valueForKey: NSStringFromSelector(@selector(key))];

       // Обрезаем все key paths до первых ключей.
       NSMutableArray* const sortKeys = [NSMutableArray array];

       [sortKeyPaths enumerateObjectsUsingBlock: ^(NSString* keyPath, NSUInteger idx, BOOL* stop)
       {
         NSArray* const components = [keyPath componentsSeparatedByString: @"."];

         NSAssert(components.count > 0, @"Invalid key path.");

         [sortKeys addObject: components[0]];
       }];

       NSArray* const keysForChangedValues = [[updatedObject changedValues] allKeys];
       
       BOOL changedValuesMayAffectSort = ([sortKeys firstObjectCommonWithArray: keysForChangedValues] != nil);
       
       // Refreshed managed objects seem not to have a changesValues dictionary.
       changedValuesMayAffectSort = changedValuesMayAffectSort || [objectsLackingChangeDictionaryOrNil containsObject: updatedObject];
       
       NSUInteger insertionIndex = NSUIntegerMax;
       
       // Проверять, действительно ли изменение свойства объекта привело к пересортировке или же объект просто изменился сохранив прежний порядок.
       const BOOL changedPropertiesDidAffectSort = changedValuesMayAffectSort &&
       ({
         // ...находим индекс, в который надо вставить элемент, чтобы сортировка сохранилась.
         const NSRange r = NSMakeRange(0, self->_fetchedObjectsBackingStore.count);
         
         insertionIndex = [self->_fetchedObjectsBackingStore indexOfObject: updatedObject inSortedRange: r options: NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual usingComparator: ^NSComparisonResult (NSManagedObject* object1, NSManagedObject* object2)
         {
           // Функция ожидала компаратор, но критериев сортировки у нас может быть произвольное количество.
           for(NSSortDescriptor* sortDescriptor in self.fetchRequest.sortDescriptors)
           {
             // Handle the case when one or both objects lack a meaningful value for key.
             id const value1 = [object1 valueForKeyPath: sortDescriptor.key];
             
             id const value2 = [object2 valueForKeyPath: sortDescriptor.key];
             
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
             const NSComparisonResult comparisonResult = [sortDescriptor compareObject: object1 toObject: object2];
             
             if(comparisonResult != NSOrderedSame) return comparisonResult;
           }
           
           return NSOrderedSame;
         }];
         
         // Запоминаем по какому индексу располагался этот объект.
         updatedObjectIndex != insertionIndex;
       });
       
       if(changedPropertiesDidAffectSort)
       {
         // Индекс уже не такой, все зависит от того, располагался ли удаленный объект до или после insertionIndex.
         insertionIndex = (insertionIndex > updatedObjectIndex)? (insertionIndex - 1) : insertionIndex;

         [self willMoveObject: updatedObject atIndex: updatedObjectIndex toIndex: insertionIndex];

         [self removeObjectFromFetchedObjectsAtIndex: updatedObjectIndex];
         
         NSAssert(insertionIndex <= self.fetchedObjectsNoCopy.count, @"Attempt to insert object at index greater than the count of elements in the array.");

         [self insertObject: updatedObject inFetchedObjectsAtIndex: insertionIndex];
         
         [self didMoveObject: updatedObject atIndex: updatedObjectIndex toIndex: insertionIndex];
       }
       else
       {
         // «Сортировочные» свойства объекта не изменились.
         [self willUpdateObject: updatedObject atIndex: updatedObjectIndex];

         [self didUpdateObject: updatedObject atIndex: updatedObjectIndex];
       }
     }
   }];
  
  return sideEffects;
}

- (void) processDeletedObjects: (nullable NSSet*) deletedObjectsOrNil updatedObjectsThatBecomeDeleted: (nullable NSSet*) updatedObjectsThatbecomeDeletedOrNil
{
  NSMutableSet* const unionSet = [NSMutableSet setWithCapacity: deletedObjectsOrNil.count + updatedObjectsThatbecomeDeletedOrNil.count];
  
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

     [self willDeleteObject: deletedObject atIndex: index];

     // Модифицируем состояние.
     [self removeObjectFromFetchedObjectsAtIndex: index];
     
     // Уведомляем делегата.
     [self didDeleteObject: deletedObject atIndex: index];
   }];
}

- (void) processInsertedObjects: (nullable NSSet*) insertedObjectsOrNil updatedObjectsThatBecomeInserted: (nullable NSSet*) updatedObjectsThatBecomeInsertedOrNil
{
  NSMutableSet* const filteredInsertedObjects = [NSMutableSet setWithCapacity: insertedObjectsOrNil.count];
  
  [insertedObjectsOrNil enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, BOOL* stop)
   {
     // Если новые объекты проходят по типу и предикату...
     if([[insertedObject entity] isKindOfEntity: [self.fetchRequest entity]] && (self.fetchRequest.predicate? [self.fetchRequest.predicate evaluateWithObject: insertedObject] : YES))
     {
       [filteredInsertedObjects addObject: insertedObject];
     }
   }];
  
  // * * *.
  
  NSSet* const allInsertedObjects = [filteredInsertedObjects setByAddingObjectsFromSet: updatedObjectsThatBecomeInsertedOrNil];
  
  [allInsertedObjects enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, BOOL* stop)
   {
     // По-умолчанию вставляем в конец массива.
     NSUInteger insertionIndex = self->_fetchedObjectsBackingStore.count;
     
     // Если заданы критерии сортировки...
     if(self.fetchRequest.sortDescriptors.count > 0)
     {
       // ...находим индекс, в который надо вставить элемент, чтобы сортировка сохранилась.
       insertionIndex = [self->_fetchedObjectsBackingStore indexOfObject: insertedObject inSortedRange: NSMakeRange(0, self->_fetchedObjectsBackingStore.count) options: NSBinarySearchingInsertionIndex usingComparator:

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

     const BOOL hasNoFetchLimit = (self.fetchRequest.fetchLimit == 0);

     // Вставляем объект, только если его индекс находится в пределах фетч-лимита.
     if(hasNoFetchLimit || (insertionIndex < self.fetchRequest.fetchLimit))
     {
       [self willInsertObject: insertedObject atIndex: insertionIndex];

       // Вставляем элемент по вычисленному индексу.
       [self insertObject: insertedObject inFetchedObjectsAtIndex: insertionIndex];

       // Уведомляем делегата о произведенной вставке.
       [self didInsertObject: insertedObject atIndex: insertionIndex];
     }
   }];
}

#pragma mark - Работа с делегатом

- (void) willChangeContent
{
  if(_delegateRespondsTo.controllerWillChangeContent)
  {
    [self.delegate controllerWillChangeContent: self];
  }
}

- (void) willInsertObject: (nonnull NSManagedObject*) insertedObject atIndex: (NSUInteger) insertedObjectIndex
{
  if(_delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: insertedObject atIndex: NSNotFound forChangeType: KSPFetchedResultsChangeInsert newIndex: insertedObjectIndex];
  }
}

- (void) didInsertObject: (nonnull NSManagedObject*) insertedObject atIndex: (NSUInteger) insertedObjectIndex
{
  if(_delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: insertedObject atIndex: NSNotFound forChangeType: KSPFetchedResultsChangeInsert newIndex: insertedObjectIndex];
  }
}

- (void) willDeleteObject: (nonnull NSManagedObject*) deletedObject atIndex: (NSUInteger) deletedObjectIndex
{
  if(_delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: deletedObject atIndex: deletedObjectIndex forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound];
  }
}

- (void) didDeleteObject: (nonnull NSManagedObject*) deletedObject atIndex: (NSUInteger) deletedObjectIndex
{
  if(_delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: deletedObject atIndex: deletedObjectIndex forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound];
  }
}

- (void) willMoveObject: (nonnull NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex toIndex: (NSUInteger) newIndex
{
  if(_delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: movedObject atIndex: oldIndex forChangeType: KSPFetchedResultsChangeMove newIndex: newIndex];
  }
}

- (void) didMoveObject: (nonnull NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex toIndex: (NSUInteger) newIndex
{
  if(_delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: movedObject atIndex: oldIndex forChangeType: KSPFetchedResultsChangeMove newIndex: newIndex];
  }
}

- (void) willUpdateObject: (nonnull NSManagedObject*) updatedObject atIndex: (NSUInteger) updatedObjectIndex
{
  if(_delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: updatedObject atIndex: updatedObjectIndex forChangeType: KSPFetchedResultsChangeUpdate newIndex: NSNotFound];
  }
}

- (void) didUpdateObject: (nonnull NSManagedObject*) updatedObject atIndex: (NSUInteger) updatedObjectIndex
{
  if(_delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: updatedObject atIndex: updatedObjectIndex forChangeType: KSPFetchedResultsChangeUpdate newIndex: NSNotFound];
  }
}

- (void) didChangeContent
{
  if(_delegateRespondsTo.controllerDidChangeContent)
  {
    [self.delegate controllerDidChangeContent: self];
  }
}

#pragma mark - Public Methods

- (BOOL) performFetch: (NSError* __autoreleasing*) error
{
  if(!self.fetchRequest) return NO;
  
  self.fetchedObjects = [self.managedObjectContext executeFetchRequest: self.fetchRequest error: error];
  
  return (_fetchedObjectsBackingStore != nil);
}

#pragma mark - fetchedObjects Collection KVC Implementation

// Warning: этот геттер предназначен только для доступа извне! Не вызывать из реализации этого класса!
- (nullable NSArray<__kindof NSManagedObject*>*) fetchedObjects
{
  // There is a bug in Core Data that prevents us from using a simple [_fetchedObjectsBackingStore copy] here.
  return [_fetchedObjectsBackingStore objectEnumerator].allObjects;
}

- (nullable NSArray<__kindof NSManagedObject*>*) fetchedObjectsNoCopy
{
  return _fetchedObjectsBackingStore;
}

- (void) setFetchedObjects: (NSArray<NSManagedObject*>*) fetchedObjects
{
  _fetchedObjectsBackingStore = [fetchedObjects mutableCopy];
}

- (NSUInteger) countOfFetchedObjects
{
  return _fetchedObjectsBackingStore.count;
}

- (nonnull NSManagedObject*) objectInFetchedObjectsAtIndex: (NSUInteger) index
{
  return [_fetchedObjectsBackingStore objectAtIndex: index];
}

- (nonnull NSArray<__kindof NSManagedObject*>*) fetchedObjectsAtIndexes: (nonnull NSIndexSet*) indexes
{
  return [_fetchedObjectsBackingStore objectsAtIndexes: indexes];
}

- (void) getFetchedObjects: (NSManagedObject* __unsafe_unretained*) buffer range: (NSRange) inRange
{
  [_fetchedObjectsBackingStore getObjects: buffer range: inRange];
}

- (void) insertObject: (nonnull NSManagedObject*) object inFetchedObjectsAtIndex: (NSUInteger) index
{
  [_fetchedObjectsBackingStore insertObject: object atIndex: index];
}

- (void) removeObjectFromFetchedObjectsAtIndex: (NSUInteger) index
{
  [_fetchedObjectsBackingStore removeObjectAtIndex: index];
}

- (void) insertFetchedObjects: (nonnull NSArray<NSManagedObject*>*) array atIndexes: (nonnull NSIndexSet*) indexes
{
  [_fetchedObjectsBackingStore insertObjects: array atIndexes: indexes];
}

- (void) removeFetchedObjectsAtIndexes: (nonnull NSIndexSet*) indexes
{
  [_fetchedObjectsBackingStore removeObjectsAtIndexes: indexes];
}

- (void) replaceObjectInFetchedObjectsAtIndex: (NSUInteger) index withObject: (nonnull NSManagedObject*) object
{
  [_fetchedObjectsBackingStore replaceObjectAtIndex: index withObject: object];
}

- (void) replaceFetchedObjectsAtIndexes: (nonnull NSIndexSet*) indexes withFetchedObjects: (nonnull NSArray<NSManagedObject*>*) array
{
  [_fetchedObjectsBackingStore replaceObjectsAtIndexes: indexes withObjects: array];
}

@end
