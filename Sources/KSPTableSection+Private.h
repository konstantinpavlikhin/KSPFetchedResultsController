//
//  KPTableSection+Private.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2016 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPTableSection.h"

@interface KSPTableSection ()

@property(readwrite, strong, nonatomic, nullable) NSArray<__kindof NSManagedObject*>* nestedObjects;

// Returns a backing mutable array without making an immutable copy.
- (nullable NSArray<__kindof NSManagedObject*>*) nestedObjectsNoCopy;

@end
