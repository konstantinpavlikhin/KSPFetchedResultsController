//
//  NSArray+LongestCommonSubsequence.m
//  LongestCommonSubsequence
//
//  Created by Konstantin Pavlikhin on 14/03/16.
//  Copyright © 2016 Konstantin Pavlikhin. All rights reserved.
//

#import "NSArray+LongestCommonSubsequence.h"

#import <Foundation/Foundation.h>

@implementation NSArray (LongestCommonSubsequence)

- (NSIndexSet*) indexesOfCommonElementsWithArray: (NSArray*) array addedIndexes: (NSIndexSet**) addedIndexes removedIndexes: (NSIndexSet**) removedIndexes
{
  const NSInteger firstDimension = self.count + 1;

  NSInteger **lengths = calloc(firstDimension, sizeof(NSInteger*));

  const NSInteger secondDimension = array.count + 1;

  for(NSInteger i = 0; i < firstDimension; i++)
  {
    lengths[i] = calloc(secondDimension, sizeof(NSInteger));
  }

  // * * *.

  for(NSInteger i = self.count; i >= 0; i--)
  {
    for(NSInteger j = array.count; j >= 0; j--)
    {
      if((i == self.count) || (j == array.count))
      {
        lengths[i][j] = 0;
      }
      else if([self[i] isEqual: array[j]])
      {
        lengths[i][j] = (1 + lengths[i + 1][j + 1]);
      }
      else
      {
        lengths[i][j] = MAX(lengths[i + 1][j], lengths[i][j + 1]);
      }
    }
  }

  // * * *.

  NSMutableIndexSet* const commonIndexes = [NSMutableIndexSet indexSet];

  NSInteger i = 0, j = 0;

  while((i < self.count) && (j < array.count))
  {
    if([self[i] isEqual: array[j]])
    {
      [commonIndexes addIndex: i];

      i++;

      j++;
    }
    else if(lengths[i + 1][j] >= lengths[i][j + 1])
    {
      i++;
    }
    else
    {
      j++;
    }
  }

  // * * *.

  for(NSInteger i = 0; i < firstDimension; i++)
  {
    free(lengths[i]);
  }

  free(lengths);

  // * * *.

  if(removedIndexes)
  {
    NSMutableIndexSet* const _removedIndexes = [NSMutableIndexSet indexSet];

    for(NSInteger i = 0; i < self.count; i++)
    {
      if(![commonIndexes containsIndex: i])
      {
        [_removedIndexes addIndex: i];
      }
    }

    *removedIndexes = _removedIndexes;
  }

  // * * *.

  if(addedIndexes)
  {
    NSArray* const commonObjects = [self objectsAtIndexes: commonIndexes];

    NSMutableIndexSet* const _addedIndexes = [NSMutableIndexSet indexSet];

    NSInteger i = 0, j = 0;

    while((i < commonObjects.count) || (j < array.count))
    {
      if((i < commonObjects.count) && (j < array.count) && [commonObjects[i] isEqual: array[j]])
      {
        i++;

        j++;
      }
      else
      {
        [_addedIndexes addIndex: j];

        j++;
      }
    }

    *addedIndexes = _addedIndexes;
  }

  return commonIndexes;
}

- (NSSet*) objectsMovedWithArray: (NSArray*) array
{
  NSParameterAssert(self.count == array.count);

  // * * *.

  NSIndexSet* addedIndices = nil;

  NSIndexSet* removedIndices = nil;

  [self indexesOfCommonElementsWithArray: array addedIndexes: &addedIndices removedIndexes: &removedIndices];

  // * * *.

  NSSet* const removedObjects = [NSSet setWithArray: [self objectsAtIndexes: removedIndices]];

  NSSet* const addedObjects = [NSSet setWithArray: [array objectsAtIndexes: addedIndices]];

  // * * *.

  NSMutableSet* const movedObjects = [NSMutableSet setWithSet: removedObjects];

  [movedObjects intersectSet: addedObjects];

  return movedObjects;
}

@end
