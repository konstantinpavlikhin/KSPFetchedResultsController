//
//  KPFetchedResultsController.m
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPFetchedResultsController+Private.h"

#import "KPFetchedResultsControllerDelegate.h"

@implementation KPFetchedResultsController
{
  id _managedObjectContextObjectsDidChangeObserver;
  
  NSMutableArray* _fetchedObjectsBackingStore;
}

- (instancetype) initWithFetchRequest: (NSFetchRequest*) fetchRequest managedObjectContext: (NSManagedObjectContext*) context
{
  NSParameterAssert(fetchRequest);
  
  NSParameterAssert(context);
  
  self = [super init];
  
  if(!self) return nil;
  
  _fetchRequest = fetchRequest;
  
  _managedObjectContext = context;
  
  NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
  
  NSOperationQueue* mq = [NSOperationQueue mainQueue];
  
  _managedObjectContextObjectsDidChangeObserver = [nc addObserverForName: NSManagedObjectContextObjectsDidChangeNotification object: self.managedObjectContext queue: mq usingBlock: ^(NSNotification* notification)
  {
    if([self.delegate respondsToSelector: @selector(controllerWillChangeContent:)])
    {
      [self.delegate controllerWillChangeContent: self];
    }
    
    //*************************************************************************************.
    
    // Коллекционируем существующие объекты, вставленные в результате изменения некоторых их свойств.
    NSMutableArray* updatedObjectsThatBecomeInserted = [NSMutableArray array];
    
    // Коллекционируем существующие объекты, удаленные в результате изменения некоторых их свойств.
    NSMutableArray* updatedObjectsThatBecomeDeleted = [NSMutableArray array];
    
    //*************************************************************************************.
    
    NSArray* updatedObjects = [[notification.userInfo valueForKey: NSUpdatedObjectsKey] allObjects];
    
    [updatedObjects enumerateObjectsUsingBlock: ^(NSManagedObject* updatedObject, NSUInteger idx, BOOL* stop)
    {
      // Изменение объекта другого типа нас не волнует.
      if(![[updatedObject entity] isKindOfEntity: [self.fetchRequest entity]]) return;
      
      // «Проходит» ли изменившийся объект по предикату?
      NSPredicate* predicate = [self.fetchRequest predicate];
      
      BOOL predicateEvaluates = (predicate != nil) ? [predicate evaluateWithObject: updatedObject] : YES;
      
      // Присутствовал ли изменившийся объект в fetchedObjects?
      NSUInteger updatedObjectIndex = [self.fetchedObjects indexOfObject: updatedObject];
      
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
        NSArray* sortKeys = [[self.fetchRequest sortDescriptors] valueForKey: NSStringFromSelector(@selector(key))];
        
        NSArray* keysForChangedValues = [[updatedObject changedValues] allKeys];
        
        BOOL sortingChanged = ([sortKeys firstObjectCommonWithArray: keysForChangedValues] != nil);
        
        if(sortingChanged)
        {
          // Запоминаем по какому индексу располагался этот объект.
          NSUInteger oldIndex = updatedObjectIndex;
          
          // ...находим индекс, в который надо вставить элемент, чтобы сортировка сохранилась.
          NSRange r = NSMakeRange(0, [self.fetchedObjects count]);
          
          NSUInteger insertionIndex = [self.fetchedObjects indexOfObject: updatedObject inSortedRange: r options: NSBinarySearchingInsertionIndex usingComparator: ^NSComparisonResult (NSManagedObject* object1, NSManagedObject* object2)
          {
            // Функция ожидала компаратор, но критериев сортировки у нас может быть произвольное количество.
            for(NSSortDescriptor* sortDescriptor in fetchRequest.sortDescriptors)
            {
              NSComparisonResult comparisonResult = [sortDescriptor compareObject: object1 toObject: object2];
              
              if(comparisonResult != NSOrderedSame) return comparisonResult;
            }
            
            return NSOrderedSame;
          }];
          
          [self removeObjectFromFetchedObjectsAtIndex: oldIndex];
          
          [self insertObject: updatedObject inFetchedObjectsAtIndex: insertionIndex];
          
          if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)])
          {
            [self.delegate controller: self didChangeObject: updatedObject atIndex: oldIndex forChangeType: KPFetchedResultsChangeMove newIndex: insertionIndex];
          }
        }
        else
        {
          // «Сортировочные» свойства объекта не изменились.
          if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)])
          {
            [self.delegate controller: self didChangeObject: updatedObjects atIndex: updatedObjectIndex forChangeType: KPFetchedResultsChangeUpdate newIndex: updatedObjectIndex];
          }
        }
      }
    }];
    
    //*************************************************************************************.
    
    NSArray* deletedObjects = [[notification.userInfo valueForKey: NSDeletedObjectsKey] allObjects];
    
    [[updatedObjectsThatBecomeDeleted arrayByAddingObjectsFromArray: deletedObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* deletedObject, NSUInteger idx, BOOL* stop)
     {
       // Удаление объекта другого типа нас не волнует.
       if(![[deletedObject entity] isKindOfEntity: [self.fetchRequest entity]]) return;
       
       NSUInteger index = [self.fetchedObjects indexOfObject: deletedObject];
       
       // Если удаленный объект не присутствовал в self.fetchedObjects...
       if(index == NSNotFound) return;
       
       // Модифицируем состояние.
       [self removeObjectFromFetchedObjectsAtIndex: index];
       
       // Уведомляем делегата.
       if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)])
       {
         [self.delegate controller: self didChangeObject: deletedObject atIndex: index forChangeType: KPFetchedResultsChangeDelete newIndex: NSNotFound];
       }
     }];
    
    //*************************************************************************************.
    
    NSArray* insertedObjects = [[notification.userInfo valueForKey: NSInsertedObjectsKey] allObjects];
    
    NSMutableArray* filteredInsertedObjects = [NSMutableArray new];
    
    [insertedObjects enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, NSUInteger idx, BOOL* stop)
    {
      // Если новые объекты проходят по типу и предикату...
      if([[insertedObject entity] isKindOfEntity: [self.fetchRequest entity]] && (fetchRequest.predicate? [fetchRequest.predicate evaluateWithObject: insertedObject] : YES))
      {
        [updatedObjectsThatBecomeInserted addObject: insertedObject];
      }
    }];
    
    // * * *.
    
    [[updatedObjectsThatBecomeInserted arrayByAddingObjectsFromArray: filteredInsertedObjects] enumerateObjectsUsingBlock: ^(NSManagedObject* insertedObject, NSUInteger idx, BOOL* stop)
     {
       // По-умолчанию вставляем в конец массива.
       NSUInteger insertionIndex = [self.fetchedObjects count];
       
       // Если заданы критерии сортировки...
       if([fetchRequest.sortDescriptors count])
       {
         // ...находим индекс, в который надо вставить элемент, чтобы сортировка сохранилась.
         insertionIndex = [self.fetchedObjects indexOfObject: insertedObject inSortedRange: NSMakeRange(0, [self.fetchedObjects count]) options: NSBinarySearchingInsertionIndex usingComparator:
       
        ^NSComparisonResult (NSManagedObject* object1, NSManagedObject* object2)
        {
          // Функция ожидала компаратор, но критериев сортировки у нас может быть произвольное количество.
          for(NSSortDescriptor* sortDescriptor in fetchRequest.sortDescriptors)
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
       if([self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)])
       {
         [self.delegate controller: self didChangeObject: insertedObject atIndex: NSNotFound forChangeType: KPFetchedResultsChangeInsert newIndex: insertionIndex];
       }
     }];
    
    //*************************************************************************************.
    
    if([self.delegate respondsToSelector: @selector(controllerDidChangeContent:)])
    {
      [self.delegate controllerDidChangeContent: self];
    }
  }];
  
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: _managedObjectContextObjectsDidChangeObserver name: NSManagedObjectContextObjectsDidChangeNotification object: self];
}

- (BOOL) performFetch: (NSError* __autoreleasing*) error
{
  if(!self.fetchRequest) return NO;
  
  self.fetchedObjects = [self.managedObjectContext executeFetchRequest: self.fetchRequest error: error];
  
  return (self.fetchedObjects != nil);
}

#pragma mark - fetchedObjects Collection KVC implementation

- (NSArray*) fetchedObjects
{
  return [_fetchedObjectsBackingStore copy];
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

- (void) replaceObjectInFetchedObjectsAtIndex: (NSUInteger) index withObject: (id) object
{
  [_fetchedObjectsBackingStore replaceObjectAtIndex: index withObject: object];
}

- (void) replaceFetchedObjectsAtIndexes: (NSIndexSet*) indexes withFetchedObjects: (NSArray*) array
{
  [_fetchedObjectsBackingStore replaceObjectsAtIndexes: indexes withObjects: array];
}

@end
