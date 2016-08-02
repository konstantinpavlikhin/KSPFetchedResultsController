//
//  NSArray+LongestCommonSubsequence.h
//  LongestCommonSubsequence
//
//  Created by Konstantin Pavlikhin on 14/03/16.
//  Copyright © 2016 Konstantin Pavlikhin. All rights reserved.
//

#import <Foundation/NSArray.h>

@interface NSArray (LongestCommonSubsequence)

- (NSIndexSet*) indexesOfCommonElementsWithArray: (NSArray*) array addedIndexes: (NSIndexSet**) addedIndexes removedIndexes: (NSIndexSet**) removedIndexes;

- (NSSet*) objectsMovedWithArray: (NSArray*) array;

@end
