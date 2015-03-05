//
//  KPSectionedFetchedResultsController.m
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPSectionedFetchedResultsController+Private.h"

#import "KSPSectionedFetchedResultsControllerDelegate.h"

#import "KSPTableSection+Private.h"

static void* DelegateKVOContext;

static void* FetchedObjectsKVOContext;

@implementation KSPSectionedFetchedResultsController
{
  NSMutableArray* _sectionsBackingStore;
  
  // Оптимизация...
  struct
  {
    BOOL controllerWillChangeObject;
    
    BOOL controllerDidChangeObject;
    
    BOOL controllerDidChangeSection;
  } delegateRespondsTo;
}

- (instancetype) initWithFetchRequest: (NSFetchRequest*) fetchRequest managedObjectContext: (NSManagedObjectContext*) context
{
  return [self initWithFetchRequest: nil managedObjectContext: nil sectionNameKeyPath: nil];
}

- (instancetype) initWithFetchRequest: (NSFetchRequest*) fetchRequest managedObjectContext: (NSManagedObjectContext*) context sectionNameKeyPath: (NSString*) sectionNameKeyPath
{
  NSParameterAssert(sectionNameKeyPath);
  
  self = [super initWithFetchRequest: fetchRequest managedObjectContext: context];
  
  if(!self) return nil;
  
  _sectionNameKeyPath = sectionNameKeyPath;
  
  // Пробуем модифицировать fetchRequest, чтобы сразу грузить «группировочное» свойство объектов.
  {{
    // TODO: подумать о том, как это должно работать.
    //[self.fetchRequest setPropertiesToFetch: @[[[self.fetchRequest.entity propertiesByName] objectForKey: self.sectionNameKeyPath]]];
    
    [self.fetchRequest setRelationshipKeyPathsForPrefetching: @[self.sectionNameKeyPath]];
  }}
  
  NSKeyValueObservingOptions opts = NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
  
  [self addObserver: self forKeyPath: @"delegate" options: 0 context: &DelegateKVOContext];
  
  [self addObserver: self forKeyPath: @"fetchedObjects" options: opts context: &FetchedObjectsKVOContext];
  
  return self;
}

- (void) dealloc
{
  [self removeObserver: self forKeyPath: @"delegate" context: &DelegateKVOContext];
  
  [self removeObserver: self forKeyPath: @"fetchedObjects" context: &FetchedObjectsKVOContext];
}

#pragma mark - Работа с делегатом KSPFetchedResultsController

- (void) didInsertObject: (NSManagedObject*) insertedManagedObject atIndex: (NSUInteger) insertedObjectIndex
{
  // Пытаемся найти существующую секцию для вставленного объекта.
  KSPTableSection* maybeSection = [self existingSectionForObject: insertedManagedObject];

  BOOL sectionWasCreatedOnDemand = NO;

  // Если подходящая секция не была найдена...
  if(!maybeSection)
  {
    maybeSection = [[KSPTableSection alloc] initWithSectionName: [insertedManagedObject valueForKeyPath: self.sectionNameKeyPath] nestedObjects: nil];
    
    // Поместить секцию в нужный индекс.
    [self insertObject: maybeSection inSectionsAtIndex: [self indexToInsertSection: maybeSection plannedNestedChild: insertedManagedObject]];
    
    sectionWasCreatedOnDemand = YES;
  }
  
  // * * *.
  
  // Уведомить делегата о создании новой или же изменившейся секции.
  const NSUInteger i = [_sectionsBackingStore indexOfObject: maybeSection];
  
  if(sectionWasCreatedOnDemand)
  {
    [self didInsertSection: maybeSection atIndex: i];
  }
  
  // * * *.
  
  // Ищем корректный индекс для вставки объекта.
  NSUInteger managedObjectInsertionIndex = NSNotFound;

  // Для нас была создана новая пустая секция?
  if(sectionWasCreatedOnDemand)
  {
    // Надо просто вставить объект в начало.
    managedObjectInsertionIndex = 0;
  }
  else
  {
    // Секция не пустая: вставляем объект с поддержанием порядка сортировки.
    managedObjectInsertionIndex = [self indexToInsertObject: insertedManagedObject inSection: maybeSection];
  }
  
  // Уведомить делегата о том, что скоро в секцию будет вставлен новый объект.
  [self willInsertObject: insertedManagedObject atIndex: managedObjectInsertionIndex inSection: maybeSection];
  
  // Вставить новый объект в правильную позицию в секции.
  [[maybeSection mutableArrayValueForKey: @"nestedObjects"] insertObject: insertedManagedObject atIndex: managedObjectInsertionIndex];
  
  // Уведомить делегата о новом объекте в секции.
  [self didInsertObject: insertedManagedObject atIndex: managedObjectInsertionIndex inSection: maybeSection];
}

- (void) didDeleteObject: (NSManagedObject*) removedManagedObject atIndex: (NSUInteger) index
{
  // Находим секцию, в которой расположен удаленный объект.
  NSArray* filteredSections = [self.sections filteredArrayUsingPredicate: [NSPredicate predicateWithBlock: ^BOOL(KSPTableSection* section, NSDictionary* bindings)
  {
    return [[section nestedObjectsNoCopy] containsObject: removedManagedObject];
  }]];

  // Объект не может принадлежать более чем одной секции. Если это не так — мы в дерьме.
  NSAssert([filteredSections count] == 1, @"Class invariant violated: object enclosed in more than one section.");

  // Секция, содержащая удаленный объект.
  KSPTableSection* containingSection = [filteredSections firstObject];

  // Определяем индекс содержащей секции.
  const NSUInteger containingSectionIndex = [_sectionsBackingStore indexOfObject: containingSection];

  // Определяем индекс удаленного объекта в коллекции nestedObjects секции containingSection.
  const NSUInteger removedManagedObjectIndex = [[containingSection nestedObjectsNoCopy] indexOfObject: removedManagedObject];

  // Уведомляем делегата о скором удалении объекта из секции.
  [self willDeleteObject: removedManagedObject atIndex: removedManagedObjectIndex inSection: containingSection];

  // Выкидываем удаленный объект из секции.
  [[containingSection mutableArrayValueForKey: @"nestedObjects"] removeObjectAtIndex: removedManagedObjectIndex];

  // Уведомляем делегата об удалении объекта.
  [self didDeleteObject: removedManagedObject atIndex: removedManagedObjectIndex inSection: containingSection];

  // Если после удаления объекта секция опустела...
  if([[containingSection nestedObjectsNoCopy] count] == 0)
  {
    // Удалить секцию.
    [self removeObjectFromSectionsAtIndex: containingSectionIndex];
    
    // Уведомить делегата об удалении секции.
    [self didDeleteSection: containingSection atIndex: containingSectionIndex];
  }
}

- (void) didMoveObject: (NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex toIndex: (NSUInteger) newIndex
{
  KSPTableSection* section = [self sectionThatContainsObject: movedObject];
  
  [self sectionsNeedToChangeBecauseOfUpdatedObject: movedObject inSection: section];
}

- (void) didUpdateObject: (NSManagedObject*) updatedObject atIndex: (NSUInteger) updatedObjectIndex
{
  // Находим секцию, в которой располагается объект.
  KSPTableSection* sectionThatContainsUpdatedObject = [self sectionThatContainsObject: updatedObject];
  
  // Изменилось ли свойство объекта, на основании которого производится разбиение на группы?
  const BOOL objectUpdateAffectedSectioning = ![[updatedObject valueForKeyPath: self.sectionNameKeyPath] isEqual: sectionThatContainsUpdatedObject.sectionName];
  
  // Если группировка не изменилась...
  if(objectUpdateAffectedSectioning == NO)
  {
    // Определяем индекс объекта в секции.
    const NSUInteger index = [[sectionThatContainsUpdatedObject nestedObjectsNoCopy] indexOfObject: updatedObject];
    
    // Уведомить делегата о скором изменении объекта в секции.
    [self willUpdateObject: updatedObject atIndex: index inSection: sectionThatContainsUpdatedObject newIndex: NSNotFound inSection: nil];
    
    // Уведомить делегата об изменении объекта в секции.
    [self didUpdateObject: updatedObject atIndex: index inSection: sectionThatContainsUpdatedObject newIndex: NSNotFound inSection: nil];
    
    // Больше в этом случае ничего делать не надо.
    return;
  }
  // Если группировка изменилась...
  else
  {
    [self sectionsNeedToChangeBecauseOfUpdatedObject: updatedObject inSection: sectionThatContainsUpdatedObject];
  }
}

#pragma mark - Работа с делегатом KPSectionedFetchedResultsController

// * * * Секции * * *.

- (void) didInsertSection: (KSPTableSection*) insertedSection atIndex: (NSUInteger) insertedSectionIndex
{
  if(delegateRespondsTo.controllerDidChangeSection)
  {
    [self.delegate controller: self didChangeSection: insertedSection atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: insertedSectionIndex];
  }
}

- (void) didDeleteSection: (KSPTableSection*) deletedSection atIndex: (NSUInteger) deletedSectionIndex
{
  if(delegateRespondsTo.controllerDidChangeSection)
  {
    [self.delegate controller: self didChangeSection: deletedSection atIndex: deletedSectionIndex forChangeType: KSPSectionedFetchedResultsChangeDelete newIndex: NSNotFound];
  }
}

- (void) didMoveSection: (KSPTableSection*) movedSection atIndex: (NSUInteger) movedSectionIndex toIndex: (NSUInteger) newIndex
{
  if(delegateRespondsTo.controllerDidChangeSection)
  {
    [self.delegate controller: self didChangeSection: movedSection atIndex: movedSectionIndex forChangeType: KSPSectionedFetchedResultsChangeMove newIndex: newIndex];
  }
}

// * * * Объекты * * *.

- (void) willInsertObject: (NSManagedObject*) insertedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section
{
  if(delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: insertedObject atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: index inSection: section];
  }
}

- (void) didInsertObject: (NSManagedObject*) insertedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: insertedObject atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: index inSection: section];
  }
}

- (void) willDeleteObject: (NSManagedObject*) deletedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section
{
  if(delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: deletedObject atIndex: index inSection: section forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];
  }
}

- (void) didDeleteObject: (NSManagedObject*) deletedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: deletedObject atIndex: index inSection: section forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];
  }
}

- (void) willMoveObject: (NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex inSection: (KSPTableSection*) oldSection newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  if(delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: movedObject atIndex: oldIndex inSection: oldSection forChangeType: KSPFetchedResultsChangeMove newIndex: newIndex inSection: newSection];
  }
}

- (void) didMoveObject: (NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex inSection: (KSPTableSection*) oldSection newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: movedObject atIndex: oldIndex inSection: oldSection forChangeType: KSPFetchedResultsChangeMove newIndex: newIndex inSection: newSection];
  }
}

- (void) willUpdateObject: (NSManagedObject*) updatedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  if(delegateRespondsTo.controllerWillChangeObject)
  {
    [self.delegate controller: self willChangeObject: updatedObject atIndex: index inSection: section forChangeType: KSPFetchedResultsChangeUpdate newIndex: newIndex inSection: newSection];
  }
}

- (void) didUpdateObject: (NSManagedObject*) updatedObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  if(delegateRespondsTo.controllerDidChangeObject)
  {
    [self.delegate controller: self didChangeObject: updatedObject atIndex: index inSection: section forChangeType: KSPFetchedResultsChangeUpdate newIndex: newIndex inSection: newSection];
  }
}

#pragma mark -

- (void) sectionsNeedToChangeBecauseOfUpdatedObject: (NSManagedObject*) updatedObject inSection: (KSPTableSection*) sectionThatContainsUpdatedObject
{
  // Секция состояла из одного только изменившегося объекта?
  const BOOL canReuseExistingSection = [[sectionThatContainsUpdatedObject nestedObjectsNoCopy] count] == 1;
  
  // Ищем подходящую секцию среди существующих (метод не будет возвращать текущую секцию, так как группировочное свойство объекта уже изменилось).
  KSPTableSection* const maybeAppropriateSection = [self existingSectionForObject: updatedObject];
  
  // Обновление объекта привело к перемещению секции...
  if(canReuseExistingSection && !maybeAppropriateSection)
  {
    // Обновляем заголовок секции.
    sectionThatContainsUpdatedObject.sectionName = [updatedObject valueForKeyPath: self.sectionNameKeyPath];
    
    // Индекс, по которому секция располагалась до обновления объекта.
    const NSUInteger sectionOldIndex = [_sectionsBackingStore indexOfObject: sectionThatContainsUpdatedObject];
    
    // Выкидываем секцию из старой позиции.
    [self removeObjectFromSectionsAtIndex: sectionOldIndex];
    
    // Ищем индекс для вставки секции.
    const NSUInteger sectionNewIndex = [self indexToInsertSection: sectionThatContainsUpdatedObject plannedNestedChild: nil];
    
    // Вставляем секцию в новую позицию.
    [self insertObject: sectionThatContainsUpdatedObject inSectionsAtIndex: sectionNewIndex];
    
    // Уведомляем делегата о перемещении секции.
    [self didMoveSection: sectionThatContainsUpdatedObject atIndex: sectionOldIndex toIndex: sectionNewIndex];
  }
  // Обновление объекта привело к удалению существующей секции и внедрению его в другую существующую...
  else if(canReuseExistingSection && maybeAppropriateSection)
  {
    // Сохраняем индекс обновленного объекта в старой секции.
    const NSUInteger updatedObjectIndex = [[sectionThatContainsUpdatedObject nestedObjectsNoCopy] indexOfObject: updatedObject];
    
    // Вычисляем индекс для вставки обновленного объекта в другую существующую секцию.
    const NSUInteger newIndex = [self indexToInsertObject: updatedObject inSection: maybeAppropriateSection];
    
    // Уведомляем делегата о скором перемещении объекта.
    [self willMoveObject: updatedObject atIndex: updatedObjectIndex inSection: sectionThatContainsUpdatedObject newIndex: newIndex inSection: maybeAppropriateSection];
    
    // Выкидываем обновленный объект из старой секции.
    [[sectionThatContainsUpdatedObject mutableArrayValueForKey: @"nestedObjects"] removeObjectAtIndex: updatedObjectIndex];
    
    // Вставляем объект в другую существующую секцию с поддержанием порядка сортировки.
    [maybeAppropriateSection insertObject: updatedObject inSectionsAtIndex: newIndex];
    
    // Уведомляем делегата о перемещении объекта.
    [self didMoveObject: updatedObject atIndex: updatedObjectIndex inSection: sectionThatContainsUpdatedObject newIndex: newIndex inSection: maybeAppropriateSection];
    
    // Индекс, по которому располагалась старая секция.
    const NSUInteger sectionThatContainsUpdatedObjectIndex = [_sectionsBackingStore indexOfObject: sectionThatContainsUpdatedObject];
    
    // Выкидываем старую секцию.
    [self removeObjectFromSectionsAtIndex: sectionThatContainsUpdatedObjectIndex];
    
    // Уведомляем делегата об удалении старой секции.
    [self didDeleteSection: sectionThatContainsUpdatedObject atIndex: sectionThatContainsUpdatedObjectIndex];
  }
  // Обновление объекта привело к его удалению из секции и внедрению в новую/существующую...
  else if(!canReuseExistingSection)
  {
    // * * * Подготовка новой секции * * *.
    
    KSPTableSection* appropriateSection = nil;
    
    // Подходящая существующая секция была найдена.
    if(maybeAppropriateSection)
    {
      appropriateSection = maybeAppropriateSection;
    }
    // Ни одна из существующих секций не подошла.
    else
    {
      // Создаем новую секцию с подходящим «заголовком».
      appropriateSection = [[KSPTableSection alloc] initWithSectionName: [updatedObject valueForKeyPath: self.sectionNameKeyPath] nestedObjects: nil];
      
      // Рассчитываем индекс вставки.
      const NSUInteger indexToInsertNewSection = [self indexToInsertSection: appropriateSection plannedNestedChild: updatedObject];
      
      // Вставляем новую секцию с поддержанием порядка сортировки.
      [self insertObject: appropriateSection inSectionsAtIndex: indexToInsertNewSection];
      
      // Уведомляем делегата о создании новой пустой секции.
      [self didInsertSection: appropriateSection atIndex: indexToInsertNewSection];
    }

    // * * *.

    // Check if the object move is happening within the bounds of the same section.
    BOOL theMoveIsWithinTheSameSection = (sectionThatContainsUpdatedObject == appropriateSection);

    // * * * Перемещение объекта * * *.
    
    // Запоминаем индекс обновленного объекта в старой секции.
    const NSUInteger updatedObjectIndexInOldSection = [[sectionThatContainsUpdatedObject nestedObjectsNoCopy] indexOfObject: updatedObject];

    // Вычисляем индекс для вставки обновленного объекта в новую секцию.
    NSUInteger indexToInsertUpdatedObject = NSNotFound;

    // If the object move is happening within the bounds of the same section...
    if(theMoveIsWithinTheSameSection)
    {
      NSMutableArray* mutableArray = [appropriateSection.nestedObjectsNoCopy mutableCopy];

      [mutableArray removeObjectAtIndex: updatedObjectIndexInOldSection];

      indexToInsertUpdatedObject = [self indexToInsertObject: updatedObject inArray: mutableArray];
    }
    else
    {
      indexToInsertUpdatedObject = [self indexToInsertObject: updatedObject inSection: appropriateSection];
    }

    // Уведомляем делегата о скором перемещении объекта между секциями.
    [self willMoveObject: updatedObject atIndex: updatedObjectIndexInOldSection inSection: sectionThatContainsUpdatedObject newIndex: indexToInsertUpdatedObject inSection: appropriateSection];
    {{
      // Выкидываем обновленный объект из старой секции.
      [[sectionThatContainsUpdatedObject mutableArrayValueForKey: @"nestedObjects"] removeObjectAtIndex: updatedObjectIndexInOldSection];
      
      // Вставляем обновленный объект в новую секцию с поддержанием порядка сортировки.
      [appropriateSection insertObject: updatedObject inSectionsAtIndex: indexToInsertUpdatedObject];
    }}
    // Уведомляем делегата о перемещении объекта между секциями.
    [self didMoveObject: updatedObject atIndex: updatedObjectIndexInOldSection inSection: sectionThatContainsUpdatedObject newIndex: indexToInsertUpdatedObject inSection: appropriateSection];
  }
}

// Возвращает индекс, по которому нужно разместить новую секцию, чтобы сохранить порядок сортировки.
- (NSUInteger) indexToInsertSection: (KSPTableSection*) section plannedNestedChild: (NSManagedObject*) child
{
  NSParameterAssert(section);

  // * * *.

  KSPTableSection* sectionToInsert = section;
  
  // For empty sections...
  if([[section nestedObjectsNoCopy] count] == 0)
  {
    // ...the planned nested child parameter is mandatory.
    NSParameterAssert(child);
    
    // We can only find insertion indices for non-empy sections.
    sectionToInsert = [[KSPTableSection alloc] initWithSectionName: section.sectionName nestedObjects: @[child]];
  }
  
  NSComparator comparator = ^NSComparisonResult(KSPTableSection* section1, KSPTableSection* section2)
  {
    // Секции сортируются по первому сорт-дескриптору.
    NSSortDescriptor* sortDescriptor = [self.fetchRequest.sortDescriptors firstObject];
    
    // * * *.
    
    id firstObject = [[section1 nestedObjectsNoCopy] firstObject];
    
    NSAssert(firstObject, @"This should never happen.");
    
    // * * *.
    
    id secondObject = [[section2 nestedObjectsNoCopy] firstObject];
    
    NSAssert(secondObject, @"This should never happen.");
    
    // * * *.
    
    return [sortDescriptor compareObject: firstObject toObject: secondObject];
  };
  
  return [_sectionsBackingStore indexOfObject: sectionToInsert inSortedRange: NSMakeRange(0, _sectionsBackingStore.count) options: NSBinarySearchingInsertionIndex usingComparator: comparator];
}

// Возвращает индекс, по которому нужно разместить объект в секции, чтобы сохранить порядок сортировки.
- (NSUInteger) indexToInsertObject: (NSManagedObject*) object inSection: (KSPTableSection*) section
{
  NSAssert([section.nestedObjects containsObject: object] == NO, @"Section already containts the object.");

  return [self indexToInsertObject: object inArray: section.nestedObjectsNoCopy];
}

- (NSUInteger) indexToInsertObject: (NSManagedObject*) object inArray: (NSArray*) array
{
  NSComparator comparator = ^NSComparisonResult (NSManagedObject* object1, NSManagedObject* object2)
  {
    // Функция ожидала компаратор, но критериев сортировки у нас может быть произвольное количество.
    for(NSSortDescriptor* sortDescriptor in self.fetchRequest.sortDescriptors)
    {
      NSComparisonResult comparisonResult = [sortDescriptor compareObject: object1 toObject: object2];

      if(comparisonResult != NSOrderedSame) return comparisonResult;
    }

    return NSOrderedSame;
  };

  return [array indexOfObject: object inSortedRange: NSMakeRange(0, array.count) options: NSBinarySearchingInsertionIndex usingComparator: comparator];
}

// Находит существующую секцию с (sectionName == [object valueForKeyPath: self.sectionNameKeyPath]). Может вернуть nil.
- (KSPTableSection*) existingSectionForObject: (NSManagedObject*) object
{
  NSParameterAssert(object);
  
  NSArray* maybeSections = [_sectionsBackingStore filteredArrayUsingPredicate: [NSPredicate predicateWithBlock: ^BOOL(KSPTableSection* section, NSDictionary* bindings)
  {
    // Секция нам подходит, если значение ее имени совпадает со значением по ключу sectionNameKeyPath в объекте.
    return [section.sectionName isEqual: [object valueForKeyPath: self.sectionNameKeyPath]];
  }]];
  
  // В результате поиска должна быть найдена максимум одна секция. Если это не так — мы в дерьме.
  NSAssert([maybeSections count] <= 1, @"Class invariant violated: more than one section found.");
  
  return [maybeSections firstObject];
}

// Находит секцию, которая содержит переданный объект.
- (KSPTableSection*) sectionThatContainsObject: (NSManagedObject*) object
{
  NSParameterAssert(object);
  
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
  NSMutableDictionary *mutDictOfMutArrays = [NSMutableDictionary dictionary];
  
  for (id obj in arr)
  {
    id transformed = block(obj);
    
    if([mutDictOfMutArrays objectForKey:transformed]==nil)
    {
      [mutDictOfMutArrays setObject:[NSMutableArray array] forKey:transformed];
    }
    
    NSMutableArray *itemsInThisGroup = [mutDictOfMutArrays objectForKey:transformed];
    
    [itemsInThisGroup addObject:obj];
  }
  
  return mutDictOfMutArrays;
}

#pragma mark - Обозреватель

- (void) observeValueForKeyPath: (NSString*) keyPath ofObject: (id) object change: (NSDictionary*) change context: (void*) context
{
  if(context == &DelegateKVOContext)
  {
    // Кешируем ответы делегата...
    delegateRespondsTo.controllerWillChangeObject = [self.delegate respondsToSelector: @selector(controller:willChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)];
    
    delegateRespondsTo.controllerDidChangeObject = [self.delegate respondsToSelector: @selector(controller:didChangeObject:atIndex:inSection:forChangeType:newIndex:inSection:)];
    
    delegateRespondsTo.controllerDidChangeSection = [self.delegate respondsToSelector: @selector(controller:didChangeSection:atIndex:forChangeType:newIndex:)];
  }
  else if(context == &FetchedObjectsKVOContext)
  {
    switch([change[NSKeyValueChangeKindKey] unsignedIntegerValue])
    {
      // Коллекция fetchedObjects заменена на новую.
      case NSKeyValueChangeSetting:
      {
        id<NSObject> (^groupingBlock)(NSManagedObject* object) = ^(NSManagedObject* object)
        {
          return [object valueForKeyPath: self.sectionNameKeyPath];
        };
        
        // Сохраняется ли в группах оригинальный порядок следования элементов? Вроде сохраняется...
        NSDictionary* sectionNameValueToManagedObjects = [[self class] groupArray: [self fetchedObjectsNoCopy] withBlock: groupingBlock];
        
        // В эту коллекцию будем набивать экземпляры KPTableSection.
        NSMutableArray* temp = [NSMutableArray array];
        
        [sectionNameValueToManagedObjects enumerateKeysAndObjectsUsingBlock: ^(id<NSObject> sectionNameValue, NSArray* managedObjects, BOOL* stop)
        {
          [temp addObject: [[KSPTableSection alloc] initWithSectionName: sectionNameValue nestedObjects: managedObjects]];
        }];
        
        // Сортируем секции в порядке сортировки первых объектов в nestedObjects (по первому сорт-дескриптору).
        [temp sortUsingComparator: ^NSComparisonResult(KSPTableSection* tableSection1, KSPTableSection* tableSection2)
        {
          NSManagedObject* objectFromSection1 = [[tableSection1 nestedObjectsNoCopy] firstObject];
          
          NSManagedObject* objectFromSection2 = [[tableSection2 nestedObjectsNoCopy] firstObject];
          
          return [[self.fetchRequest.sortDescriptors firstObject] compareObject: objectFromSection1 toObject: objectFromSection2];
        }];
        
        self.sections = temp;
        
        break;
      }
      
      // Коллекция fetchedObjects претерпела замену элементов.
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

- (NSArray*) sections
{
  return [_sectionsBackingStore copy];
}

- (void) setSections: (NSArray*) sections
{
  _sectionsBackingStore = [sections mutableCopy];
}

- (NSUInteger) countOfSections
{
  return [_sectionsBackingStore count];
}

- (KSPTableSection*) objectInSectionsAtIndex: (NSUInteger) index
{
  return [_sectionsBackingStore objectAtIndex: index];
}

- (NSArray*) sectionsAtIndexes: (NSIndexSet*) indexes
{
  return [_sectionsBackingStore objectsAtIndexes: indexes];
}

- (void) getSections: (KSPTableSection* __unsafe_unretained*) buffer range: (NSRange) inRange
{
  [_sectionsBackingStore getObjects: buffer range: inRange];
}

- (void) insertObject: (KSPTableSection*) object inSectionsAtIndex: (NSUInteger) index
{
  [_sectionsBackingStore insertObject: object atIndex: index];
}

- (void) removeObjectFromSectionsAtIndex: (NSUInteger) index
{
  [_sectionsBackingStore removeObjectAtIndex: index];
}

- (void) insertSections: (NSArray*) array atIndexes: (NSIndexSet*) indexes
{
  [_sectionsBackingStore insertObjects: array atIndexes: indexes];
}

- (void) removeSectionsAtIndexes: (NSIndexSet*) indexes
{
  [_sectionsBackingStore removeObjectsAtIndexes: indexes];
}

- (void) replaceObjectInSectionsAtIndex: (NSUInteger) index withObject: (KSPTableSection*) object
{
  [_sectionsBackingStore replaceObjectAtIndex: index withObject: object];
}

- (void) replaceSectionsAtIndexes: (NSIndexSet*) indexes withSections: (NSArray*) array
{
  [_sectionsBackingStore replaceObjectsAtIndexes: indexes withObjects: array];
}

@end
