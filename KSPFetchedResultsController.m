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
  
  _managedObjectContextObjectsDidChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName: NSManagedObjectContextObjectsDidChangeNotification object: self.managedObjectContext queue: [NSOperationQueue mainQueue] usingBlock: ^(NSNotification* const notification)
  {
    __strong typeof(self) const strongSelf = weakSelf;
    
    if(!strongSelf) return;
    
    // * * *.

    // Ignore notifications that happen before some objects are actually fetched.
    if(!strongSelf->_fetchedObjectsBackingStore) return;
    
    //*************************************************************************************.
    
    // Updated objects.
    NSSet<NSManagedObject*>* _Nullable const updatedObjectsOrNil = [notification.userInfo valueForKey: NSUpdatedObjectsKey];
    
    // Refreshed objects.
    NSSet<NSManagedObject*>* _Nullable const refreshedObjectsOrNil = [notification.userInfo valueForKey: NSRefreshedObjectsKey];
    
    // Unite the two conceptually similar object sets.
    NSMutableSet<NSManagedObject*>* const updatedAndRefreshedUnion = [NSMutableSet setWithCapacity: (updatedObjectsOrNil.count + refreshedObjectsOrNil.count)];
    
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
    NSSet<NSManagedObject*>* _Nullable insertedObjectsOrNil = [notification.userInfo valueForKey: NSInsertedObjectsKey];

    // Workaround for a Core Data concurrency issue which causes an object that was already fetched to be reported as a newly inserted one.
    {{
      if(insertedObjectsOrNil)
      {
        NSMutableSet<NSManagedObject*>* const mutableInsertedObjects = [insertedObjectsOrNil mutableCopy];

        // * * *.

        // Convert _PFArray to a regular NSArray to workaround a weird Core Data memory-management issue.
        NSArray<NSManagedObject*>* const tempArray = [strongSelf.fetchedObjectsNoCopy objectEnumerator].allObjects;

        [mutableInsertedObjects minusSet: [NSSet setWithArray: tempArray]];

        // * * *.

        insertedObjectsOrNil = [mutableInsertedObjects copy];
      }
    }}

    // Minus the inserted objects that were also refreshed.
    [updatedAndRefreshedUnion minusSet: insertedObjectsOrNil];
    
    // * * *.
    
    // Deleted objects.
    NSSet<NSManagedObject*>* _Nullable const deletedObjectsOrNil = [notification.userInfo valueForKey: NSDeletedObjectsKey];
    
    // Invalidated objects.
    NSSet<NSManagedObject*>* _Nullable const invalidatedObjectsOrNil = [notification.userInfo valueForKey: NSInvalidatedObjectsKey];
    
    // Unite the two conceptually similar object sets.
    NSMutableSet<NSManagedObject*>* const deletedAndInvalidatedUnion = [NSMutableSet setWithCapacity: (deletedObjectsOrNil.count + invalidatedObjectsOrNil.count)];
    
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
      const NSUInteger maxRequiredCapacity = (updatedAndRefreshedUnion.count + deletedAndInvalidatedUnion.count + insertedObjectsOrNil.count);

      NSMutableSet<NSManagedObject*>* const allObjectsSet = [NSMutableSet setWithCapacity: maxRequiredCapacity];

      [allObjectsSet unionSet: updatedAndRefreshedUnion];

      [allObjectsSet unionSet: deletedAndInvalidatedUnion];

      [allObjectsSet unionSet: insertedObjectsOrNil];
        
      NSPredicate* const relevantObjectsPredicate = [NSPredicate predicateWithBlock: ^BOOL(NSManagedObject*evaluatedObject, NSDictionary* bindings) {
        return [evaluatedObject.entity isKindOfEntity: strongSelf.fetchRequest.entity];
      }];
        
      NSSet<NSManagedObject*>* const relevantObjectsSet = [allObjectsSet filteredSetUsingPredicate: relevantObjectsPredicate];
        
      // Do not do any processing if managed object context change didn't touch the relevant entity type.
      if(relevantObjectsSet.count == 0) return;
    }}

    // * * *.

    [strongSelf willChangeContent];
    
    NSDictionary<NSString*, NSSet*>* sideEffects = nil;
    
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

#pragma mark - Key-Value Observing

- (void) observeValueForKeyPath: (nullable NSString*) keyPath ofObject: (nullable id) object change: (nullable NSDictionary*) change context: (nullable void*) context
{
  if(context == &DelegateKVOContext)
  {
    _delegateRespondsTo.controllerWillChangeContent = [self.delegate respondsToSelector: @selector(controllerWillChangeContent:)];

    _delegateRespondsTo.controllerWillChangeObject = [self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:forChangeType:newIndex:)];

    _delegateRespondsTo.controllerDidChangeObject = [self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)];
    
    _delegateRespondsTo.controllerDidChangeContent = [self.delegate respondsToSelector: @selector(controllerDidChangeContent:)];
  }
}

#pragma mark - Change Processing

/// Returns a dictionary with two key-value pairs: @{UpdatedObjectsThatBecomeDeleted: [NSSet set], UpdatedObjectsThatBecomeInserted: [NSSet set]};
- (nonnull NSDictionary<NSString*, NSSet*>*) processUpdatedObjects: (nullable NSSet<NSManagedObject*>*) updatedObjectsOrNil objectsLackingChangeDictionary: (nullable NSSet<NSManagedObject*>*) objectsLackingChangeDictionaryOrNil
{
  NSDictionary<NSString*, NSMutableSet*>* const sideEffects = @{UpdatedObjectsThatBecomeDeleted: [NSMutableSet set],
                                                                UpdatedObjectsThatBecomeInserted: [NSMutableSet set]};
    
  NSMutableSet* updatedObjects = [NSMutableSet set];
  NSMutableSet* movedObjects = [NSMutableSet set];
    
  [updatedObjectsOrNil enumerateObjectsUsingBlock: ^(NSManagedObject* const updatedObject, BOOL* stop)
  {
    // We don't care about changes of a different kind of entity.
    if(![updatedObject.entity isKindOfEntity: self.fetchRequest.entity]) return;
         
    // Does the changed object passes the predicate?
    NSPredicate* const predicate = self.fetchRequest.predicate;
         
    const BOOL predicateEvaluates = ((predicate != nil) ? [predicate evaluateWithObject: updatedObject] : YES);
         
    // Was the changed object present in a fetchedObjects?
    const NSUInteger updatedObjectIndex = [self->_fetchedObjectsBackingStore indexOfObject: updatedObject];
         
    const BOOL updatedObjectWasPresent = (updatedObjectIndex != NSNotFound);
         
    // Object was present in a collection, but predicate no longer evaluates.
    if(updatedObjectWasPresent && !predicateEvaluates)
    {
      // ...mark it for a deletion.
      [sideEffects[UpdatedObjectsThatBecomeDeleted] addObject: updatedObject];
    }
    // Object was not present in a collection, but now the predicate evaluates...
    else if(!updatedObjectWasPresent && predicateEvaluates)
    {
      // ...mark it for insertion.
      [sideEffects[UpdatedObjectsThatBecomeInserted] addObject: updatedObject];
    }
    // Object was present in a collection and predicate still evaluates...
    else if(updatedObjectWasPresent && predicateEvaluates)
    {
      // ...check whether or not the properties that affect collection sorting were changed.
      NSArray<NSString*>* const sortKeyPaths = [self.fetchRequest.sortDescriptors valueForKey: NSStringFromSelector(@selector(key))];
      
      // Trim the key paths to the first keys.
      NSMutableArray<NSString*>* const sortKeys = [NSMutableArray array];
      
      [sortKeyPaths enumerateObjectsUsingBlock: ^(NSString* const keyPath, const NSUInteger idx, BOOL* stop)
       {
           NSArray<NSString*>* const components = [keyPath componentsSeparatedByString: @"."];
           
           NSAssert(components.count > 0, @"Invalid key path.");
           
           [sortKeys addObject: components[0]];
       }];
      
      NSArray<NSString*>* const keysForChangedValues = [updatedObject changedValues].allKeys;
      
      BOOL changedValuesMayAffectSort = ([sortKeys firstObjectCommonWithArray: keysForChangedValues] != nil);
      
      // Refreshed managed objects seem not to have a changesValues dictionary.
      changedValuesMayAffectSort = changedValuesMayAffectSort || [objectsLackingChangeDictionaryOrNil containsObject: updatedObject];
      
      if (changedValuesMayAffectSort) {
          [movedObjects addObject: updatedObject];
      } else {
          [updatedObjects addObject: updatedObject];
      }
    }
  }];
    
  [movedObjects enumerateObjectsUsingBlock: ^(NSManagedObject* const updatedObject, BOOL* stop)
  {
    const NSUInteger oldIndex = [self->_fetchedObjectsBackingStore indexOfObject: updatedObject];
    NSUInteger newIndex = NSNotFound;
      
    // Check whether or not the property change lead to the resorting or the object was altered keeping the same order.

    NSMutableArray<NSManagedObject*>* const arrayCopy = [self->_fetchedObjectsBackingStore mutableCopy];
      
    [arrayCopy removeObjectsInArray: movedObjects.allObjects];
    [movedObjects removeObject: updatedObject];
      
    // ...find the index at which the object should be inserted to preserve the order.
    const NSRange range = NSMakeRange(0, arrayCopy.count);
          
    newIndex = [arrayCopy indexOfObject: updatedObject inSortedRange: range options: NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual usingComparator: ^NSComparisonResult (NSManagedObject* const object1, NSManagedObject* const object2)
    {
      // The function expected a comparator, but we can have an arbitraty number of a sorting criterias.
      for(NSSortDescriptor* const sortDescriptor in self.fetchRequest.sortDescriptors)
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
          return (sortDescriptor.ascending? NSOrderedAscending : NSOrderedDescending);
        }
        
        if(value1 && !value2)
        {
          return (sortDescriptor.ascending? NSOrderedDescending : NSOrderedAscending);
        }
        
        // * * *.
        
        // Handle the case when both objects have a meaningful value for key.
        const NSComparisonResult comparisonResult = [sortDescriptor compareObject: object1 toObject: object2];
        
        if(comparisonResult != NSOrderedSame) return comparisonResult;
      }
                                
      return NSOrderedSame;
    }];
      
    if(oldIndex != newIndex)
    {
      [self willMoveObject: updatedObject atIndex: oldIndex toIndex: newIndex];
      
      [self removeObjectFromFetchedObjectsAtIndex: oldIndex];
      
      NSAssert(newIndex <= self.fetchedObjectsNoCopy.count, @"Attempt to insert object at index greater than the count of elements in the array.");
      
      [self insertObject: updatedObject inFetchedObjectsAtIndex: newIndex];
      
      [self didMoveObject: updatedObject atIndex: oldIndex toIndex: newIndex];
    } else {
      [updatedObjects addObject: updatedObject];
    }
  }];
    
  [movedObjects enumerateObjectsUsingBlock: ^(NSManagedObject* const updatedObject, BOOL* stop)
  {
    const NSUInteger index = [self->_fetchedObjectsBackingStore indexOfObject: updatedObject];
    
    [self willUpdateObject: updatedObject atIndex: index];
    [self didUpdateObject: updatedObject atIndex: index];
  }];
  
  return sideEffects;
}

- (void) processDeletedObjects: (nullable NSSet<NSManagedObject*>*) deletedObjectsOrNil updatedObjectsThatBecomeDeleted: (nullable NSSet<NSManagedObject*>*) updatedObjectsThatbecomeDeletedOrNil
{
  NSMutableSet<NSManagedObject*>* const unionSet = [NSMutableSet setWithCapacity: (deletedObjectsOrNil.count + updatedObjectsThatbecomeDeletedOrNil.count)];
  
  if(deletedObjectsOrNil)
  {
    [unionSet unionSet: deletedObjectsOrNil];
  }
  
  if(updatedObjectsThatbecomeDeletedOrNil)
  {
    [unionSet unionSet: updatedObjectsThatbecomeDeletedOrNil];
  }
  
  // * * *.
  
  [unionSet.allObjects enumerateObjectsUsingBlock: ^(NSManagedObject* const deletedObject, const NSUInteger idx, BOOL* stop)
  {
    // Objects deletion of a different entity kind is out of interest.
    if(![deletedObject.entity isKindOfEntity: self.fetchRequest.entity]) return;
    
    const NSUInteger index = [self->_fetchedObjectsBackingStore indexOfObject: deletedObject];
    
    // If the deleted object was not present in a _fetchedObjectsBackingStore...
    if(index == NSNotFound) return;

    [self willDeleteObject: deletedObject atIndex: index];

    // Modify the state.
    [self removeObjectFromFetchedObjectsAtIndex: index];
    
    // Notify the delegate.
    [self didDeleteObject: deletedObject atIndex: index];
  }];
}

- (void) processInsertedObjects: (nullable NSSet<NSManagedObject*>*) insertedObjectsOrNil updatedObjectsThatBecomeInserted: (nullable NSSet<NSManagedObject*>*) updatedObjectsThatBecomeInsertedOrNil
{
  NSMutableSet<NSManagedObject*>* const filteredInsertedObjects = [NSMutableSet setWithCapacity: insertedObjectsOrNil.count];
  
  [insertedObjectsOrNil enumerateObjectsUsingBlock: ^(NSManagedObject* const insertedObject, BOOL* stop)
  {
    // Check whether the new objects are of a valid entity type and successfuly evaluate the predicate.
    if([insertedObject.entity isKindOfEntity: self.fetchRequest.entity] && (self.fetchRequest.predicate? [self.fetchRequest.predicate evaluateWithObject: insertedObject] : YES))
    {
      [filteredInsertedObjects addObject: insertedObject];
    }
  }];
  
  // * * *.
  
  NSSet<NSManagedObject*>* const allInsertedObjects = [filteredInsertedObjects setByAddingObjectsFromSet: updatedObjectsThatBecomeInsertedOrNil];
  
  [allInsertedObjects enumerateObjectsUsingBlock: ^(NSManagedObject* const insertedObject, BOOL* stop)
  {
    // Append the object to the end of an array by default.
    NSUInteger insertionIndex = self->_fetchedObjectsBackingStore.count;
    
    // If there are some sorting criterias present...
    if(self.fetchRequest.sortDescriptors.count > 0)
    {
      // ...find the index at which the element should be inserted to preserve the existing sort order.
      insertionIndex = [self->_fetchedObjectsBackingStore indexOfObject: insertedObject inSortedRange: NSMakeRange(0, self->_fetchedObjectsBackingStore.count) options: NSBinarySearchingInsertionIndex usingComparator:

      ^NSComparisonResult (NSManagedObject* const object1, NSManagedObject* const object2)
      {
        // The function expects a comparator, but we can have an arbitrary number of a sorting criterias.
        for(NSSortDescriptor* const sortDescriptor in self.fetchRequest.sortDescriptors)
        {
          const NSComparisonResult comparisonResult = [sortDescriptor compareObject: object1 toObject: object2];
          
          if(comparisonResult != NSOrderedSame) return comparisonResult;
        }
        
        return NSOrderedSame;
      }];
    }

    const BOOL hasNoFetchLimit = (self.fetchRequest.fetchLimit == 0);

    // Insert the object only if its index is within the bounds of a fetch limit.
    if(hasNoFetchLimit || (insertionIndex < self.fetchRequest.fetchLimit))
    {
      [self willInsertObject: insertedObject atIndex: insertionIndex];

      // Insert the object at the calculated index.
      [self insertObject: insertedObject inFetchedObjectsAtIndex: insertionIndex];

      // Notify the delegate about the performed insertion.
      [self didInsertObject: insertedObject atIndex: insertionIndex];
    }
  }];
}

#pragma mark - Working With a Delegate

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

// This getter should be called only by the class clients. Do not call within the class implementation.
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
