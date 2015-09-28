//
//  KPSectionedFetchedResultsController.m
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPSectionedFetchedResultsController+Private.h"

#import "KSPSectionedFetchedResultsControllerDelegate.h"

#import "KSPTableSection+Private.h"

// * * *.

static void* DelegateKVOContext;

static void* FetchedObjectsKVOContext;

// * * *.

@implementation KSPSectionedFetchedResultsController
{
  NSMutableArray<KSPTableSection*>* _sectionsBackingStore;

  struct
  {
    BOOL controllerWillChangeObject;
    
    BOOL controllerDidChangeObject;
    
    BOOL controllerDidChangeSection;
  } _delegateRespondsTo;
}

@dynamic delegate;

#pragma mark - Initialization

- (nullable instancetype) initWithFetchRequest: (nonnull NSFetchRequest*) fetchRequest managedObjectContext: (nonnull NSManagedObjectContext*) context
{
  NSAssert(NO, @"Use -%@.", NSStringFromSelector(@selector(initWithFetchRequest:managedObjectContext:sectionNameKeyPath:)));

  return nil;
}

- (nullable instancetype) initWithFetchRequest: (nonnull NSFetchRequest*) fetchRequest managedObjectContext: (nonnull NSManagedObjectContext*) context sectionNameKeyPath: (nonnull NSString*) sectionNameKeyPath
{
  NSParameterAssert(sectionNameKeyPath);

  // * * *.

  self = [super initWithFetchRequest: fetchRequest managedObjectContext: context];
  
  if(!self) return nil;
  
  _sectionNameKeyPath = sectionNameKeyPath;

  {{
    //[self.fetchRequest setPropertiesToFetch: @[[[self.fetchRequest.entity propertiesByName] objectForKey: self.sectionNameKeyPath]]];
    
    [self.fetchRequest setRelationshipKeyPathsForPrefetching: @[self.sectionNameKeyPath]];
  }}
  
  const NSKeyValueObservingOptions opts = NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
  
  [self addObserver: self forKeyPath: @"delegate" options: 0 context: &DelegateKVOContext];
  
  [self addObserver: self forKeyPath: @"fetchedObjects" options: opts context: &FetchedObjectsKVOContext];
  
  return self;
}

#pragma mark - Cleanup

- (void) dealloc
{
  [self removeObserver: self forKeyPath: @"delegate" context: &DelegateKVOContext];
  
  [self removeObserver: self forKeyPath: @"fetchedObjects" context: &FetchedObjectsKVOContext];
}

#pragma mark - KSPFetchedResultsController Delegate Stuff

- (void) didInsertObject: (nonnull NSManagedObject*) insertedManagedObject atIndex: (NSUInteger) insertedObjectIndex
{
  // Try to find an existing section for the inserted object.
  KSPTableSection* maybeSection = [self existingSectionForObject: insertedManagedObject];

  BOOL sectionWasCreatedOnDemand = NO;

  // If the acceptable section was not found...
  if(!maybeSection)
  {
    maybeSection = [[KSPTableSection alloc] initWithSectionName: [insertedManagedObject valueForKeyPath: self.sectionNameKeyPath] nestedObjects: nil];

    // Store the section at the correct index.
    [self insertObject: maybeSection inSectionsAtIndex: [self indexToInsertSection: maybeSection plannedNestedChild: insertedManagedObject]];
    
    sectionWasCreatedOnDemand = YES;
  }
  
  // * * *.
  
  // Notify the delegate about new section creation or change of an existing section.
  const NSUInteger i = [_sectionsBackingStore indexOfObject: maybeSection];
  
  if(sectionWasCreatedOnDemand)
  {
    [self didInsertSection: maybeSection atIndex: i];
  }
  
  // * * *.
  
  // Looking for a correct index for the object insertion.
  NSUInteger managedObjectInsertionIndex = NSNotFound;

  // Was an empty section created for us?
  if(sectionWasCreatedOnDemand)
  {
    // Simply place the object at the very beginning.
    managedObjectInsertionIndex = 0;
  }
  else
  {
    // Section is not empty: insert the object keeping the existing sort order.
    managedObjectInsertionIndex = [self indexToInsertObject: insertedManagedObject inSection: maybeSection];
  }
  
  // Notify the delegate about upcoming insertion of the object into section.
  [self willInsertObject: insertedManagedObject atIndex: managedObjectInsertionIndex inSection: maybeSection];
  
  // Insert the new object at the correct position in section.
  [[maybeSection mutableArrayValueForKey: @"nestedObjects"] insertObject: insertedManagedObject atIndex: managedObjectInsertionIndex];
  
  // Notify the delegate about new object in section.
  [self didInsertObject: insertedManagedObject atIndex: managedObjectInsertionIndex inSection: maybeSection];
}

- (void) didDeleteObject: (nonnull NSManagedObject*) removedManagedObject atIndex: (NSUInteger) index
{
  // Find the section that contains the deleted object.
  NSArray* const filteredSections = [self.sections filteredArrayUsingPredicate: [NSPredicate predicateWithBlock: ^BOOL(KSPTableSection* section, NSDictionary* bindings)
  {
    return [[section nestedObjectsNoCopy] containsObject: removedManagedObject];
  }]];

  // An object should not be a member of more than one section.
  NSAssert(filteredSections.count == 1, @"Class invariant violated: object enclosed in more than one section.");

  // The section that contains the deleted object.
  KSPTableSection* const containingSection = [filteredSections firstObject];

  // Find the index of a containing section.
  const NSUInteger containingSectionIndex = [_sectionsBackingStore indexOfObject: containingSection];

  // Find the index of a deleted object in a nestedObjects collection of a containingSection.
  const NSUInteger removedManagedObjectIndex = [[containingSection nestedObjectsNoCopy] indexOfObject: removedManagedObject];

  // Notify the delegate about upcoming deletion of the object from its containing section.
  [self willDeleteObject: removedManagedObject atIndex: removedManagedObjectIndex inSection: containingSection];

  // Remove the deleted object from the section.
  [[containingSection mutableArrayValueForKey: @"nestedObjects"] removeObjectAtIndex: removedManagedObjectIndex];

  // Notify the delegate about object deletion.
  [self didDeleteObject: removedManagedObject atIndex: removedManagedObjectIndex inSection: containingSection];

  // Check whether the section become empty after the object removal...
  if([containingSection nestedObjectsNoCopy].count == 0)
  {
    // Remove the section.
    [self removeObjectFromSectionsAtIndex: containingSectionIndex];
    
    // Notify the delegate about section deletion.
    [self didDeleteSection: containingSection atIndex: containingSectionIndex];
  }
}

- (void) didMoveObject: (nonnull NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex toIndex: (NSUInteger) newIndex
{
  KSPTableSection* const section = [self sectionThatContainsObject: movedObject];
  
  [self sectionsNeedToChangeBecauseOfUpdatedObject: movedObject inSection: section];
}

- (void) didUpdateObject: (nonnull NSManagedObject*) updatedObject atIndex: (NSUInteger) updatedObjectIndex
{
  // Find the section that contains the object.
  KSPTableSection* const sectionThatContainsUpdatedObject = [self sectionThatContainsObject: updatedObject];
  
  // Whether or not the property that breaks the objects into sections was actually changed?
  const BOOL objectUpdateAffectedSectioning = ![[updatedObject valueForKeyPath: self.sectionNameKeyPath] isEqual: sectionThatContainsUpdatedObject.sectionName];
  
  // If the grouping was not altered...
  if(objectUpdateAffectedSectioning == NO)
  {
    // Find the index of the object in section.
    const NSUInteger index = [[sectionThatContainsUpdatedObject nestedObjectsNoCopy] indexOfObject: updatedObject];
    
    // Notify the delegate of an upcoming change of the object in section.
    [self willUpdateObject: updatedObject atIndex: index inSection: sectionThatContainsUpdatedObject newIndex: NSNotFound inSection: nil];
    
    // Notify the delegate of a change of the object in section.
    [self didUpdateObject: updatedObject atIndex: index inSection: sectionThatContainsUpdatedObject newIndex: NSNotFound inSection: nil];
    
    // We are done here.
    return;
  }
  // If the grouping was altered...
  else
  {
    [self sectionsNeedToChangeBecauseOfUpdatedObject: updatedObject inSection: sectionThatContainsUpdatedObject];
  }
}

#pragma mark - KPSectionedFetchedResultsController Delegate Stuff

// * * * Sections * * *.

- (void) didInsertSection: (nonnull KSPTableSection*) insertedSection atIndex: (NSUInteger) insertedSectionIndex
{
  if(_delegateRespondsTo.controllerDidChangeSection)
  {
    [self.delegate controller: self didChangeSection: insertedSection atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: insertedSectionIndex];
  }
}

- (void) didDeleteSection: (nonnull KSPTableSection*) deletedSection atIndex: (NSUInteger) deletedSectionIndex
{
  if(_delegateRespondsTo.controllerDidChangeSection)
  {
    [self.delegate controller: self didChangeSection: deletedSection atIndex: deletedSectionIndex forChangeType: KSPSectionedFetchedResultsChangeDelete newIndex: NSNotFound];
  }
}

- (void) didMoveSection: (nonnull KSPTableSection*) movedSection atIndex: (NSUInteger) movedSectionIndex toIndex: (NSUInteger) newIndex
{
  if(_delegateRespondsTo.controllerDidChangeSection)
  {
    [self.delegate controller: self didChangeSection: movedSection atIndex: movedSectionIndex forChangeType: KSPSectionedFetchedResultsChangeMove newIndex: newIndex];
  }
}

// * * * Objects * * *.

- (void) willInsertObject: (nonnull NSManagedObject*) insertedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section
{
  if(_delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: insertedObject atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: index inSection: section];
  }
}

- (void) didInsertObject: (nonnull NSManagedObject*) insertedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section
{
  if(_delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: insertedObject atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: index inSection: section];
  }
}

- (void) willDeleteObject: (nonnull NSManagedObject*) deletedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section
{
  if(_delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: deletedObject atIndex: index inSection: section forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];
  }
}

- (void) didDeleteObject: (nonnull NSManagedObject*) deletedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section
{
  if(_delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: deletedObject atIndex: index inSection: section forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];
  }
}

- (void) willMoveObject: (nonnull NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex inSection: (nonnull KSPTableSection*) oldSection newIndex: (NSUInteger) newIndex inSection: (nonnull KSPTableSection*) newSection
{
  if(_delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: movedObject atIndex: oldIndex inSection: oldSection forChangeType: KSPFetchedResultsChangeMove newIndex: newIndex inSection: newSection];
  }
}

- (void) didMoveObject: (nonnull NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex inSection: (nonnull KSPTableSection*) oldSection newIndex: (NSUInteger) newIndex inSection: (nonnull KSPTableSection*) newSection
{
  if(_delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: movedObject atIndex: oldIndex inSection: oldSection forChangeType: KSPFetchedResultsChangeMove newIndex: newIndex inSection: newSection];
  }
}

- (void) willUpdateObject: (nonnull NSManagedObject*) updatedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section newIndex: (NSUInteger) newIndex inSection: (nullable KSPTableSection*) newSection
{
  if(_delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: updatedObject atIndex: index inSection: section forChangeType: KSPFetchedResultsChangeUpdate newIndex: newIndex inSection: newSection];
  }
}

- (void) didUpdateObject: (nonnull NSManagedObject*) updatedObject atIndex: (NSUInteger) index inSection: (nonnull KSPTableSection*) section newIndex: (NSUInteger) newIndex inSection: (nullable KSPTableSection*) newSection
{
  if(_delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: updatedObject atIndex: index inSection: section forChangeType: KSPFetchedResultsChangeUpdate newIndex: newIndex inSection: newSection];
  }
}

#pragma mark -

- (void) sectionsNeedToChangeBecauseOfUpdatedObject: (nonnull NSManagedObject*) updatedObject inSection: (nonnull KSPTableSection*) sectionThatContainsUpdatedObject
{
  // Does the section consisted solely from the changed object?
  const BOOL canReuseExistingSection = ([sectionThatContainsUpdatedObject nestedObjectsNoCopy].count == 1);
  
  // Find the suitable section among existing ones (the method would not return a current section, because the grouping property of the object has already changed.
  KSPTableSection* const maybeAppropriateSection = [self existingSectionForObject: updatedObject];
  
  // The object change lead to the section movement...
  if(canReuseExistingSection && !maybeAppropriateSection)
  {
    // Refresh the section title.
    sectionThatContainsUpdatedObject.sectionName = [updatedObject valueForKeyPath: self.sectionNameKeyPath];
    
    // The index where the section was located before the object was updated.
    const NSUInteger sectionOldIndex = [_sectionsBackingStore indexOfObject: sectionThatContainsUpdatedObject];
    
    // Remove the section from the old position.
    [self removeObjectFromSectionsAtIndex: sectionOldIndex];
    
    // Find the index for the section insertion.
    const NSUInteger sectionNewIndex = [self indexToInsertSection: sectionThatContainsUpdatedObject plannedNestedChild: nil];
    
    // Insert the section into the new position.
    [self insertObject: sectionThatContainsUpdatedObject inSectionsAtIndex: sectionNewIndex];
    
    // Notify the delegate about the section move.
    [self didMoveSection: sectionThatContainsUpdatedObject atIndex: sectionOldIndex toIndex: sectionNewIndex];
  }
  // The object change lead to deletion of an existing section and its insertion into another existing section...
  else if(canReuseExistingSection && maybeAppropriateSection)
  {
    // Remember the index of the updatedObject in the old section.
    const NSUInteger updatedObjectIndex = [[sectionThatContainsUpdatedObject nestedObjectsNoCopy] indexOfObject: updatedObject];
    
    // Calculate the isertion index for the updated object insertion into another section.
    const NSUInteger newIndex = [self indexToInsertObject: updatedObject inSection: maybeAppropriateSection];
    
    // Notify the delegate about an upcoming move of the object.
    [self willMoveObject: updatedObject atIndex: updatedObjectIndex inSection: sectionThatContainsUpdatedObject newIndex: newIndex inSection: maybeAppropriateSection];
    
    // Remove the updated object from the old section.
    [[sectionThatContainsUpdatedObject mutableArrayValueForKey: @"nestedObjects"] removeObjectAtIndex: updatedObjectIndex];
    
    // Insert the object into another existing section maintaining the sort order.
    [maybeAppropriateSection insertObject: updatedObject inNestedObjectsAtIndex: newIndex];
    
    // Notify the delegate about object move.
    [self didMoveObject: updatedObject atIndex: updatedObjectIndex inSection: sectionThatContainsUpdatedObject newIndex: newIndex inSection: maybeAppropriateSection];
    
    // Index of the old section.
    const NSUInteger sectionThatContainsUpdatedObjectIndex = [_sectionsBackingStore indexOfObject: sectionThatContainsUpdatedObject];
    
    // Remove the old section.
    [self removeObjectFromSectionsAtIndex: sectionThatContainsUpdatedObjectIndex];
    
    // Notify the delegate about old section deletion.
    [self didDeleteSection: sectionThatContainsUpdatedObject atIndex: sectionThatContainsUpdatedObjectIndex];
  }
  // The object change lead to its deletion from the section and insertion into a new/existing section...
  else if(!canReuseExistingSection)
  {
    // * * * Prepare a new section * * *.
    
    KSPTableSection* appropriateSection = nil;
    
    // Suitable section was not found.
    if(maybeAppropriateSection)
    {
      appropriateSection = maybeAppropriateSection;
    }
    // Existing sections do not fit.
    else
    {
      // Create a new section with a correct 'name'.
      appropriateSection = [[KSPTableSection alloc] initWithSectionName: [updatedObject valueForKeyPath: self.sectionNameKeyPath] nestedObjects: nil];
      
      // Calculate an insertion index.
      const NSUInteger indexToInsertNewSection = [self indexToInsertSection: appropriateSection plannedNestedChild: updatedObject];
      
      // Insert a new section keeping the sort order intact.
      [self insertObject: appropriateSection inSectionsAtIndex: indexToInsertNewSection];
      
      // Notify the delegate about new empty section creation.
      [self didInsertSection: appropriateSection atIndex: indexToInsertNewSection];
    }

    // * * *.

    // Check if the object move is happening within the bounds of the same section.
    const BOOL theMoveIsWithinTheSameSection = (sectionThatContainsUpdatedObject == appropriateSection);

    // * * * Object move * * *.
    
    // Remember the index of the updated object in the old section.
    const NSUInteger updatedObjectIndexInOldSection = [[sectionThatContainsUpdatedObject nestedObjectsNoCopy] indexOfObject: updatedObject];

    // Calculate the index for insertion of the updated object into the new section.
    NSUInteger indexToInsertUpdatedObject = NSNotFound;

    // If the object move is happening within the bounds of the same section...
    if(theMoveIsWithinTheSameSection)
    {
      NSMutableArray* const mutableArray = [appropriateSection.nestedObjectsNoCopy mutableCopy];

      [mutableArray removeObjectAtIndex: updatedObjectIndexInOldSection];

      indexToInsertUpdatedObject = [self indexToInsertObject: updatedObject inArray: mutableArray];
    }
    else
    {
      indexToInsertUpdatedObject = [self indexToInsertObject: updatedObject inSection: appropriateSection];
    }

    // Notify the delegate about an upcoming move of the object between the sections.
    [self willMoveObject: updatedObject atIndex: updatedObjectIndexInOldSection inSection: sectionThatContainsUpdatedObject newIndex: indexToInsertUpdatedObject inSection: appropriateSection];
    {{
      // Remove the updated object from the old section.
      [[sectionThatContainsUpdatedObject mutableArrayValueForKey: @"nestedObjects"] removeObjectAtIndex: updatedObjectIndexInOldSection];
      
      // Insert the updated object into the new section keeping the sort order intact.
      [appropriateSection insertObject: updatedObject inNestedObjectsAtIndex: indexToInsertUpdatedObject];
    }}
    // Notify the delegate about object move between the sections.
    [self didMoveObject: updatedObject atIndex: updatedObjectIndexInOldSection inSection: sectionThatContainsUpdatedObject newIndex: indexToInsertUpdatedObject inSection: appropriateSection];
  }
}

// Returns an index at which a new section should be inserted in order to maintain an existing sort order.
- (NSUInteger) indexToInsertSection: (nonnull KSPTableSection*) section plannedNestedChild: (nullable NSManagedObject*) child
{
  NSParameterAssert(section);

  // * * *.

  KSPTableSection* sectionToInsert = section;
  
  // For empty sections...
  if([section nestedObjectsNoCopy].count == 0)
  {
    // ...the planned nested child parameter is mandatory.
    NSParameterAssert(child);
    
    // We can only find insertion indices for non-empy sections.
    sectionToInsert = [[KSPTableSection alloc] initWithSectionName: section.sectionName nestedObjects: @[child]];
  }
  
  NSComparator comparator = ^NSComparisonResult(KSPTableSection* section1, KSPTableSection* section2)
  {
    // Sections are sorted by the first sort descriptor.
    NSSortDescriptor* sortDescriptor = [self.fetchRequest.sortDescriptors firstObject];
    
    // * * *.
    
    id const firstObject = [[section1 nestedObjectsNoCopy] firstObject];
    
    NSAssert(firstObject, @"This should never happen.");
    
    // * * *.
    
    id const secondObject = [[section2 nestedObjectsNoCopy] firstObject];
    
    NSAssert(secondObject, @"This should never happen.");
    
    // * * *.
    
    return [sortDescriptor compareObject: firstObject toObject: secondObject];
  };
  
  return [_sectionsBackingStore indexOfObject: sectionToInsert inSortedRange: NSMakeRange(0, _sectionsBackingStore.count) options: NSBinarySearchingInsertionIndex usingComparator: comparator];
}

// Returns an index at which an object should be inserted in section in order to maintain an existing sorting intact.
- (NSUInteger) indexToInsertObject: (nonnull NSManagedObject*) object inSection: (nonnull KSPTableSection*) section
{
  NSAssert([section.nestedObjects containsObject: object] == NO, @"Section already containts the object.");

  return [self indexToInsertObject: object inArray: section.nestedObjectsNoCopy];
}

- (NSUInteger) indexToInsertObject: (nonnull NSManagedObject*) object inArray: (nonnull NSArray*) array
{
  NSComparator comparator = ^NSComparisonResult (NSManagedObject* object1, NSManagedObject* object2)
  {
    // Function expects a comparator, but we can have an arbitrary number of sorting criterias.
    for(NSSortDescriptor* sortDescriptor in self.fetchRequest.sortDescriptors)
    {
      const NSComparisonResult comparisonResult = [sortDescriptor compareObject: object1 toObject: object2];

      if(comparisonResult != NSOrderedSame) return comparisonResult;
    }

    return NSOrderedSame;
  };

  return [array indexOfObject: object inSortedRange: NSMakeRange(0, array.count) options: NSBinarySearchingInsertionIndex usingComparator: comparator];
}

// Finds an existing section with (sectionName == [object valueForKeyPath: self.sectionNameKeyPath]).
- (nullable KSPTableSection*) existingSectionForObject: (nonnull NSManagedObject*) object
{
  NSParameterAssert(object);

  // * * *.

  NSArray* const maybeSections = [_sectionsBackingStore filteredArrayUsingPredicate: [NSPredicate predicateWithBlock: ^BOOL(KSPTableSection* section, NSDictionary* bindings)
  {
    // Section is acceptable if a value of its name is equal to value for sectionNameKeyPath key of the object.
    return [section.sectionName isEqual: [object valueForKeyPath: self.sectionNameKeyPath]];
  }]];
  
  // There should be at most one suitable section.
  NSAssert(maybeSections.count <= 1, @"Class invariant violated: more than one section found.");
  
  return [maybeSections firstObject];
}

// Finds a section that contains a passed object.
- (nonnull KSPTableSection*) sectionThatContainsObject: (nonnull NSManagedObject*) object
{
  NSParameterAssert(object);

  // * * *.

  for(KSPTableSection* section in _sectionsBackingStore)
  {
    if([[section nestedObjectsNoCopy] containsObject: object]) return section;
  }
  
  NSAssert(NO, @"Something terrible happened!");
  
  return nil;
}

typedef id (^MapArrayBlock)(id obj);

+ (NSDictionary*) groupArray: (NSArray*) arr withBlock: (MapArrayBlock) block
{
  NSMutableDictionary* const mutDictOfMutArrays = [NSMutableDictionary dictionary];
  
  for(id obj in arr)
  {
    id const transformed = block(obj);
    
    if([mutDictOfMutArrays objectForKey: transformed] == nil)
    {
      [mutDictOfMutArrays setObject:[NSMutableArray array] forKey: transformed];
    }
    
    NSMutableArray* const itemsInThisGroup = [mutDictOfMutArrays objectForKey: transformed];
    
    [itemsInThisGroup addObject: obj];
  }
  
  return mutDictOfMutArrays;
}

#pragma mark - Key-Value Observation

- (void) observeValueForKeyPath: (nullable NSString*) keyPath ofObject: (nullable id) object change: (nullable NSDictionary*) change context: (nullable void*) context
{
  if(context == &DelegateKVOContext)
  {
    _delegateRespondsTo.controllerWillChangeObject = [self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)];
    
    _delegateRespondsTo.controllerDidChangeObject = [self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)];
    
    _delegateRespondsTo.controllerDidChangeSection = [self.delegate respondsToSelector: @selector(controller:didChangeSection:atIndex:forChangeType:newIndex:)];
  }
  else if(context == &FetchedObjectsKVOContext)
  {
    switch([change[NSKeyValueChangeKindKey] unsignedIntegerValue])
    {
      // fetchedObjects collection was set to a new value.
      case NSKeyValueChangeSetting:
      {
        id<NSObject> (^groupingBlock)(NSManagedObject* object) = ^(NSManagedObject* object)
        {
          return [object valueForKeyPath: self.sectionNameKeyPath];
        };

        NSDictionary* const sectionNameValueToManagedObjects = [[self class] groupArray: [self fetchedObjectsNoCopy] withBlock: groupingBlock];
        
        // Temporary collection for a KPTableSection instances.
        NSMutableArray* const temp = [NSMutableArray array];
        
        [sectionNameValueToManagedObjects enumerateKeysAndObjectsUsingBlock: ^(id<NSObject> sectionNameValue, NSArray* managedObjects, BOOL* stop)
        {
          [temp addObject: [[KSPTableSection alloc] initWithSectionName: sectionNameValue nestedObjects: managedObjects]];
        }];

        // Sort the sections in order of a first objects in their's nestedObjects (by a first sort descriptor).
        [temp sortUsingComparator: ^NSComparisonResult(KSPTableSection* tableSection1, KSPTableSection* tableSection2)
        {
          NSManagedObject* const objectFromSection1 = [[tableSection1 nestedObjectsNoCopy] firstObject];
          
          NSManagedObject* const objectFromSection2 = [[tableSection2 nestedObjectsNoCopy] firstObject];
          
          return [[self.fetchRequest.sortDescriptors firstObject] compareObject: objectFromSection1 toObject: objectFromSection2];
        }];
        
        self.sections = temp;
        
        break;
      }

      case NSKeyValueChangeReplacement:
      {
        NSAssert(NO, @"This should never happen!");
        
        break;
      }
    }
  }
  else
  {
    [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
  }
}

#pragma mark - sections Collection KVC Implementation

- (nullable NSArray<KSPTableSection*>*) sections
{
  return [_sectionsBackingStore copy];
}

- (void) setSections: (nullable NSArray<KSPTableSection*>*) sections
{
  _sectionsBackingStore = [sections mutableCopy];
}

- (NSUInteger) countOfSections
{
  return _sectionsBackingStore.count;
}

- (nonnull KSPTableSection*) objectInSectionsAtIndex: (NSUInteger) index
{
  return [_sectionsBackingStore objectAtIndex: index];
}

- (nonnull NSArray<KSPTableSection*>*) sectionsAtIndexes: (NSIndexSet*) indexes
{
  return [_sectionsBackingStore objectsAtIndexes: indexes];
}

- (void) getSections: (KSPTableSection* __unsafe_unretained*) buffer range: (NSRange) inRange
{
  [_sectionsBackingStore getObjects: buffer range: inRange];
}

- (void) insertObject: (nonnull KSPTableSection*) object inSectionsAtIndex: (NSUInteger) index
{
  [_sectionsBackingStore insertObject: object atIndex: index];
}

- (void) removeObjectFromSectionsAtIndex: (NSUInteger) index
{
  [_sectionsBackingStore removeObjectAtIndex: index];
}

- (void) insertSections: (nonnull NSArray<KSPTableSection*>*) array atIndexes: (nonnull NSIndexSet*) indexes
{
  [_sectionsBackingStore insertObjects: array atIndexes: indexes];
}

- (void) removeSectionsAtIndexes: (nonnull NSIndexSet*) indexes
{
  [_sectionsBackingStore removeObjectsAtIndexes: indexes];
}

- (void) replaceObjectInSectionsAtIndex: (NSUInteger) index withObject: (nonnull KSPTableSection*) object
{
  [_sectionsBackingStore replaceObjectAtIndex: index withObject: object];
}

- (void) replaceSectionsAtIndexes: (nonnull NSIndexSet*) indexes withSections: (nonnull NSArray<KSPTableSection*>*) array
{
  [_sectionsBackingStore replaceObjectsAtIndexes: indexes withObjects: array];
}

@end
